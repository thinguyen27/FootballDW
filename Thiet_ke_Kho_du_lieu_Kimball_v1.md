# THIẾT KẾ KHO DỮ LIỆU BÓNG ĐÁ (Kimball – Transfermarkt)

> **Phiên bản:** v1 (đóng băng sau DW-01) · **Loại tài liệu:** context thiết kế cho đồ án môn Thiết kế kho dữ liệu
> **Công nghệ:** SQL Server (TransfermarktDB → FootballDW, schema etl/stg/dw), SSIS, SSAS Multidimensional

## Tóm tắt nhanh

- **4 business process:** Thành tích đội, Thành tích cầu thủ, Định giá cầu thủ, Chuyển nhượng.
- **Mô hình:** Fact Constellation, 2 tầng grain.
  - 4 fact chi tiết: Fact_Team_Match (1 đội/1 trận), Fact_Player_Appearance (1 cầu thủ/1 trận), Fact_Player_Valuation (1 lần định giá), Fact_Transfer (1 thương vụ).
  - 2 fact tổng hợp: Fact_Player_Season_Summary (cầu thủ × CLB × giải × mùa), Fact_Club_Season_Summary (CLB × giải × mùa).
- **8 dimension:** Dim_Date, Dim_Season, Dim_Competition, Dim_Club, Dim_Player, Dim_Manager, Dim_Match_Profile (junk), Dim_Transfer_Type (junk). Mọi dimension có dòng Unknown key = -1.
- **SCD:** Dim_Club (Type 2: giải, sân; Type 3: HLV; Type 1: phần còn lại), Dim_Player (Type 2: vị trí, người đại diện; Type 1: phần còn lại). CDC bằng hash (scd2_hash).
- **Measure phái sinh** tính bằng window function trong ETL, đánh dấu (PS) ở mục 6.

## 1. Giới thiệu

Tài liệu này trình bày thiết kế kho dữ liệu cho bộ dữ liệu bóng đá thu thập từ Transfermarkt. Thiết kế đi theo 4 bước của phương pháp Kimball:

- **Bước 1 – Business process:** chọn những hoạt động nghiệp vụ cần phân tích.

- **Bước 2 – Grain và Bus matrix:** quy định mỗi dòng trong bảng fact đại diện cho cái gì, và fact nào dùng dimension nào.

- **Bước 3 – Dimension:** xác định các bảng mô tả ngữ cảnh (ai, ở đâu, khi nào, giải nào).

- **Bước 4 – Fact và Measure:** xác định các con số cần đo lường và ý nghĩa của từng con số.

**Phạm vi:** 4 business process là Thành tích đội, Thành tích cầu thủ, Định giá cầu thủ và Chuyển nhượng.

**Mô hình lựa chọn:** Fact Constellation (Galaxy Schema), gồm nhiều Star Schema dùng chung các dimension như Dim_Season, Dim_Club, Dim_Player. Thông tin quốc gia và liên đoàn được gộp thẳng vào dimension, không tách bảng riêng, để giữ đúng dạng Star Schema.

**Triết lý thiết kế:** Kho dữ liệu được thiết kế kết hợp 2 mức độ grain:

- **(1) Mức chi tiết nhất (Atomic Transaction Grain):** lưu trữ từng trận, từng lần ra sân, từng lần định giá, từng thương vụ, để bảo toàn khả năng linh hoạt và drill-down sâu nhất. Không một câu hỏi nào về sau bị giới hạn vì dữ liệu đã bị gộp mất.

- **(2) Bảng tổng hợp (Aggregate Facts) theo mùa giải:** giải quyết bài toán hiệu năng OLAP cho các báo cáo dashboard định kỳ, tránh việc hệ thống phải tính toán lại hàng triệu dòng dữ liệu mỗi lần truy vấn.

### 1.1 Kho dữ liệu khác gì so với sao chép OLTP

Việc lưu mức chi tiết không có nghĩa là sao chép nguyên cơ sở dữ liệu nguồn. Kho dữ liệu này tạo ra giá trị mà hệ thống OLTP không có ở 5 điểm:

- **Chọn lọc:** chỉ nạp 4 process cần phân tích; loại bỏ các cột không có giá trị phân tích như đường dẫn web, ảnh, slug, cột rỗng, tên lặp (mục 2.2).

- **Tích hợp và làm sạch:** hợp nhất CLB và đội tuyển vào một Dim_Club, chuẩn hóa tên giải và tên liên đoàn, xử lý giá trị bất thường.

- **Lưu lịch sử:** dùng SCD Type 2 và Type 3 để giữ lại các thay đổi mà nguồn chỉ ghi đè (CLB xuống hạng, cầu thủ đổi vị trí, đổi HLV).

- **Measure phái sinh:** tính sẵn trong ETL các chỉ số nguồn không có, ví dụ điểm lũy kế, chuỗi trận thắng, số ngày nghỉ giữa hai trận, biến động giá trị cầu thủ (mục 6).

- **Tổng hợp và phân cấp:** các fact tổng hợp theo mùa và các hierarchy (Confederation → Country → League → Club, Year → Quarter → Month) cho phép drill-up, drill-down mà OLTP không hỗ trợ.

## 2. Dữ liệu nguồn

### 2.1 Các bảng nguồn sử dụng

Database nguồn TransfermarktDB trên SQL Server chỉ nạp 10 bảng phục vụ thiết kế. Hai bảng game_events và game_lineups không được nạp vì nằm ngoài phạm vi.

| Bảng nguồn        | Số dòng | Nội dung                             | Dùng để xây dựng                                        |
|-----------------------|-------------|------------------------------------------|-------------------------------------------------------------|
| club_games            | 177.916     | Kết quả mỗi trận theo góc độ một đội     | Fact_Team_Match → Fact_Club_Season_Summary                  |
| games                 | 88.958      | Trận đấu: lấy ngày, mùa, giải, vòng đấu  | Bổ sung khóa cho các fact trận đấu                          |
| appearances           | 1.894.350   | Thống kê cá nhân mỗi trận                | Fact_Player_Appearance → Fact_Player_Season_Summary         |
| player_valuations     | 656.301     | Lịch sử định giá cầu thủ                 | Fact_Player_Valuation                                       |
| transfers             | 175.165     | Lịch sử chuyển nhượng                    | Fact_Transfer                                               |
| players               | 50.149      | Thông tin cầu thủ                        | Dim_Player                                                  |
| clubs, national_teams | 796 + 124   | CLB và đội tuyển quốc gia                | Dim_Club                                                    |
| competitions          | 65          | Giải đấu, quốc gia và liên đoàn của giải | Dim_Competition; tên giải, quốc gia, liên đoàn cho Dim_Club |

### 2.2 Dữ liệu không đưa vào kho

| Cột / bảng bị loại                                                                                | Bảng nguồn                                   | Lý do                                                                                                                    |
|-------------------------------------------------------------------------------------------------------|--------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------|
| url, image_url, team_image_url                                                                        | Tất cả các bảng                                  | Đường dẫn web, ảnh; không dùng để phân tích                                                                                  |
| filename                                                                                              | clubs                                            | Metadata của quá trình cào dữ liệu                                                                                           |
| player_code, club_code, competition_code, team_code                                                   | players, clubs, competitions, national_teams     | Slug URL, trùng nghĩa với tên                                                                                                |
| clubs.total_market_value, national_teams.coach_name                                                   | clubs, national_teams                            | Rỗng 100%. Lưu ý: clubs.coach_name vẫn được giữ (có giá trị ở khoảng một nửa số CLB) để làm SCD Type 3 cho Dim_Club          |
| player_name, club_name, from/to_club_name, current_club_name, home/away_club_name                     | appearances, transfers, player_valuations, games | Tên bị lặp; lấy qua dimension                                                                                                |
| player_current_club_id                                                                                | appearances                                      | Không phản ánh CLB tại thời điểm thi đấu                                                                                     |
| first_name, last_name, city_of_birth                                                                  | players                                          | Đã có tên đầy đủ; nơi sinh cấp thành phố quá chi tiết (hơn 12.000 giá trị)                                                   |
| referee, stadium, attendance, formations, aggregate, manager names                                    | games                                            | Không thuộc 4 process đã chọn, hoặc trùng với club_games                                                                     |
| domestic_league_code, total_clubs                                                                     | competitions                                     | Trùng với competition_id hoặc không dùng                                                                                     |
| net_transfer_record                                                                                   | clubs                                            | Chuỗi tiền tệ tổng hợp sẵn (ví dụ +€5.90m) tại thời điểm cào dữ liệu; chi tiêu ròng được tính lại chính xác từ Fact_Transfer |
| foreigners_number, foreigners_percentage, national_team_players, last_season                          | clubs                                            | Chỉ số tổng hợp tại một thời điểm, không có lịch sử nên không gắn được với từng mùa                                          |
| country_code, fifa_ranking, foreigners_number, foreigners_percentage, total_market_value, last_season | national_teams                                   | Tương tự clubs: chỉ số tại một thời điểm; country_code trùng nghĩa với country_name                                          |
| Toàn bộ bảng                                                                                          | game_events, game_lineups                        | Ngoài phạm vi                                                                                                                |
| Toàn bộ bảng countries                                                                                | countries                                        | Quốc gia và liên đoàn đã có sẵn trong competitions và national_teams                                                         |

### 2.3 Các vấn đề dữ liệu cần xử lý khi ETL

| Vấn đề                                        | Ở đâu                          | Cách xử lý                                                                             |
|---------------------------------------------------|------------------------------------|--------------------------------------------------------------------------------------------|
| Nhiều club_id trong fact không có trong clubs.csv | club_games, appearances, transfers | Thêm vào Dim_Club với club_type = Other, lấy tên từ bảng nguồn                             |
| Giá trị -1 nghĩa là không xác định                | competitions.country_id            | Trỏ về dòng Unknown (key = -1)                                                             |
| Ngày dạng chuỗi kèm giờ                           | players.date_of_birth              | Ép kiểu DATE                                                                               |
| Giá trị bất thường (chiều cao 17 cm, sức chứa 0)  | players, clubs                     | Đặt NULL                                                                                   |
| Ngày chuyển nhượng trong tương lai (đến 2030)     | transfers                          | Giữ lại, đánh dấu is_future_date; loại khỏi báo cáo lịch sử                                |
| Dữ liệu chỉ gồm các giải được theo dõi            | games, club_games                  | days_since_last_match có thể lớn hơn thực tế nếu CLB đá trận ở giải không có trong dữ liệu |
| appearances không có mùa giải                     | appearances                        | Lấy season từ games qua game_id để gán season_key                                          |
| Định giá không có mùa giải                        | player_valuations                  | Quy đổi ngày sang mùa: từ 01/07 năm N đến 30/06 năm N+1 là mùa N/N+1                       |

## 3. Bước 1 – Xác định Business Process

| # | Business process | Diễn giải                                                   | Câu hỏi phân tích                                                             |
|--------|----------------------|-----------------------------------------------------------------|-----------------------------------------------------------------------------------|
| 1      | Thành tích đội       | Kết quả thi đấu của mỗi đội: thắng/hòa/thua, bàn thắng, điểm số | Bảng xếp hạng mỗi mùa? Tỉ lệ thắng sân nhà theo giải? HLV nào hiệu quả nhất?      |
| 2      | Thành tích cầu thủ   | Số phút, bàn thắng, kiến tạo, thẻ phạt của cầu thủ              | Vua phá lưới, vua kiến tạo từng giải mỗi mùa? Hiệu suất ghi bàn mỗi 90 phút?      |
| 3      | Định giá cầu thủ     | Giá trị thị trường của cầu thủ qua thời gian                    | Giá trị cầu thủ tăng giảm thế nào qua các mùa? Giải nào có tổng giá trị cao nhất? |
| 4      | Chuyển nhượng        | Các thương vụ cầu thủ chuyển CLB                                | Thương vụ nào đắt nhất? CLB nào chi tiêu ròng nhiều nhất mỗi mùa?                 |

## 4. Bước 2 – Xác định Grain và Bus Matrix

### 4.1 Grain

Grain trả lời câu hỏi: "Mỗi dòng trong bảng fact đại diện cho điều gì?". Kho gồm 6 fact chia thành 2 tầng:

- **Tầng chi tiết (atomic):** 4 fact, mỗi dòng là một sự kiện nghiệp vụ ở mức nhỏ nhất mà nguồn ghi nhận.

- **Tầng tổng hợp (aggregate):** 2 fact, được tính từ tầng chi tiết bằng cách gom theo mùa giải, phục vụ dashboard.

| Tầng | Fact table             | Grain (1 dòng = ...)                            | Loại fact | Số dòng | Tính từ            |
|----------|----------------------------|-----------------------------------------------------|---------------|-------------|------------------------|
| Chi tiết | Fact_Team_Match            | 1 đội trong 1 trận                                  | Transaction   | 177.916     | club_games + games     |
| Chi tiết | Fact_Player_Appearance     | 1 cầu thủ ra sân trong 1 trận                       | Transaction   | 1.894.350   | appearances + games    |
| Chi tiết | Fact_Player_Valuation      | 1 lần định giá của 1 cầu thủ tại 1 ngày             | Transaction   | 656.301     | player_valuations      |
| Chi tiết | Fact_Transfer              | 1 thương vụ chuyển nhượng                           | Transaction   | 175.165     | transfers              |
| Tổng hợp | Fact_Player_Season_Summary | 1 cầu thủ, thi đấu cho 1 CLB, ở 1 giải, trong 1 mùa | Aggregate     | ≈ 196.566   | Fact_Player_Appearance |
| Tổng hợp | Fact_Club_Season_Summary   | 1 CLB ở 1 giải trong 1 mùa                          | Aggregate     | 21.646      | Fact_Team_Match        |

Ví dụ: trận Arsenal gặp Chelsea ở Premier League tạo ra 2 dòng trong Fact_Team_Match và khoảng 28–32 dòng trong Fact_Player_Appearance. Đến cuối mùa, toàn bộ 38 trận của Arsenal được gom thành 1 dòng trong Fact_Club_Season_Summary.

**Về tên gọi Aggregate:** hai bảng tổng hợp được xếp loại Aggregate Fact (còn gọi là periodic snapshot theo mùa), không phải Accumulating Snapshot. Theo Kimball, Accumulating Snapshot dành cho một quy trình có nhiều mốc thời gian nối tiếp nhau (ví dụ đơn hàng: đặt → duyệt → giao → thanh toán), mỗi dòng có nhiều khóa ngày tương ứng với từng mốc và được cập nhật khi quy trình đi qua mốc mới. Thành tích theo mùa không có các mốc như vậy, mà là phép gom các trận trong một kỳ.

**Cách làm mới:** trong mùa đang diễn ra, dòng của mùa hiện tại được tính lại sau mỗi lần nạp; các mùa đã kết thúc không thay đổi.

### 4.2 Bus Matrix

Dấu ✓ là fact có dùng dimension đó; chữ trong ngoặc là vai trò khi một dimension được dùng nhiều lần hoặc với nghĩa cụ thể (role-playing).

| Fact / Dim            | Date | Season | Giải | Club             | Player | Manager              | Match Profile | Transfer Type |
|----------------------------|----------|------------|----------|----------------------|------------|--------------------------|-------------------|-------------------|
| Fact_Team_Match            | ✓        | ✓          | ✓        | ✓ (đội, đối thủ)     |            | ✓ (HLV đội, HLV đối thủ) | ✓                 |                   |
| Fact_Player_Appearance     | ✓        | ✓          | ✓        | ✓ (CLB của cầu thủ)  | ✓          |                          |                   |                   |
| Fact_Player_Valuation      | ✓        | ✓          | ✓        | ✓ (CLB lúc định giá) | ✓          |                          |                   |                   |
| Fact_Transfer              | ✓        | ✓          |          | ✓ (CLB đi, CLB đến)  | ✓          |                          |                   | ✓                 |
| Fact_Player_Season_Summary |          | ✓          | ✓        | ✓                    | ✓          |                          |                   |                   |
| Fact_Club_Season_Summary   |          | ✓          | ✓        | ✓                    |            | ✓ (HLV cuối mùa)         |                   |                   |

**Conformed dimension:** Dim_Season và Dim_Club được dùng bởi cả 6 fact; Dim_Date dùng bởi 4 fact chi tiết; Dim_Player và Dim_Competition dùng bởi nhiều fact. Nhờ vậy có thể so sánh chéo (drill-across), ví dụ đặt tổng bàn thắng mùa 2023/24 của một cầu thủ (Fact_Player_Season_Summary) cạnh biến động giá trị của cầu thủ đó trong cùng mùa (Fact_Player_Valuation).

### 4.3 Sơ đồ tổng thể

> Sơ đồ Fact Constellation (Hình 1 trong bản Word) không đưa vào file này. Quan hệ fact – dimension được mô tả đầy đủ ở Bus Matrix mục 4.2 và các bảng khóa ngoại ở mục 6.

*Hình 1. Mô hình Fact Constellation (cam: fact chi tiết, vàng: fact tổng hợp, xanh: dimension)*

## 5. Bước 3 – Xác định Dimension

Quy ước chung cho mọi dimension:

- **Surrogate key** (ví dụ player_key) là số nguyên tự sinh, dùng để nối với fact. Mã gốc từ nguồn (player_id) vẫn được giữ lại.

- **Dòng Unknown** có key = -1 để hứng các giá trị không xác định hoặc không tìm thấy.

- **SCD** (Slowly Changing Dimension): Type 1 ghi đè giá trị mới; Type 2 thêm dòng mới để giữ lịch sử; Type 3 thêm cột lưu giá trị trước đó.

- **Chỉ giữ thuộc tính dùng để lọc, nhóm hoặc hiển thị** khi phân tích; các cột khác đã bị loại ở mục 2.2.

### 5.1 Dim_Date – Ngày

Dùng cho 4 fact chi tiết. Bảng lịch sinh sẵn từ 1990 đến 2030 (transfers có thương vụ từ năm 1993), không áp dụng SCD.

| Thuộc tính                    | Ý nghĩa                                                                      | Ví dụ      |
|-----------------------------------|----------------------------------------------------------------------------------|----------------|
| date_key                          | Khóa chính, dạng YYYYMMDD                                                        | 20240817       |
| full_date                         | Ngày đầy đủ                                                                      | 2024-08-17     |
| day_of_week, day_name, is_weekend | Thứ trong tuần, cuối tuần                                                        | 6, Saturday, 1 |
| month, month_name                 | Tháng                                                                            | 8, August      |
| quarter, year                     | Quý, năm                                                                         | 3, 2024        |
| quarter_label                     | Nhãn quý kèm năm, làm khóa cho cấp Quarter trong cube (tránh gộp Q3 của mọi năm) | Q3-2024        |
| year_month                        | Tháng kèm năm, làm khóa cho cấp Month trong cube                                 | 2024-08        |
| is_transfer_window                | Có nằm trong kỳ chuyển nhượng hè (6–8) hoặc đông (1)                             | 1              |
| is_future_date                    | Ngày sau thời điểm nạp dữ liệu                                                   | 0              |

**Hierarchy:** Year → Quarter → Month → Day

### 5.2 Dim_Season – Mùa giải

Dimension trung tâm của kho: cả 6 fact đều có season_key, và 2 fact tổng hợp có grain theo mùa. Mùa giải được quy ước từ 01/07 đến 30/06 năm sau. Không áp dụng SCD.

| Thuộc tính       | Nguồn                 | Ý nghĩa                                                               | Ví dụ              |
|----------------------|---------------------------|---------------------------------------------------------------------------|------------------------|
| season_key           | = season_start_year       | Khóa chính (smart key bằng năm bắt đầu mùa, giống date_key dạng YYYYMMDD) | 2024                   |
| season_start_year    | games.season              | Năm bắt đầu mùa                                                           | 2024                   |
| season_label         | Suy ra                    | Tên mùa đầy đủ                                                            | 2024/25                |
| season_short         | transfers.transfer_season | Tên mùa rút gọn                                                           | 24/25                  |
| start_date, end_date | Suy ra                    | Ngày bắt đầu, kết thúc mùa                                                | 2024-07-01, 2025-06-30 |
| decade               | Suy ra                    | Thập kỷ                                                                   | 2020s                  |

**Hierarchy:** Decade → Season

### 5.3 Dim_Competition – Giải đấu

SCD Type 1 cho toàn bộ bảng, vì các thuộc tính hầu như không đổi.

Ngoài 65 giải trong competitions.csv, bảng được bổ sung 5 mã giải chỉ xuất hiện trong games (CGB, COL1, KLUB, POCP, UKRS, tổng cộng 1.214 trận). Các giải này có loại other, tên lấy theo mã giải, để các trận không bị rơi vào dòng Unknown.

| Thuộc tính   | Nguồn                   | Ý nghĩa                               | Ví dụ       |
|------------------|-----------------------------|-------------------------------------------|-----------------|
| competition_key  | Tự sinh                     | Khóa chính                                | 5               |
| competition_id   | competitions.competition_id | Mã giải gốc                               | GB1             |
| competition_name | competitions.name           | Tên giải, đã chuẩn hóa                    | Premier League  |
| competition_type | competitions.type           | Loại giải                                 | domestic_league |
| country_name     | competitions.country_name   | Quốc gia (giải quốc tế ghi International) | England         |
| confederation    | competitions.confederation  | Liên đoàn, chuẩn hóa về UEFA, AFC...      | UEFA            |

**Hierarchy:** Confederation → Country → Competition; Competition type → Competition

### 5.4 Dim_Club – Câu lạc bộ

Hợp nhất từ clubs.csv, national_teams.csv và các club_id chỉ xuất hiện trong fact. Đây là giá trị tích hợp mà nguồn không có sẵn: một đội bóng luôn có một mã duy nhất dù là CLB hay đội tuyển.

| Thuộc tính                          | Nguồn                                      | Ý nghĩa                                                                                            | SCD |
|-----------------------------------------|------------------------------------------------|--------------------------------------------------------------------------------------------------------|---------|
| club_key                                | Tự sinh                                        | Khóa chính                                                                                             | –       |
| club_id                                 | clubs.club_id, national_teams.national_team_id | Mã gốc                                                                                                 | –       |
| club_name                               | clubs.name                                     | Tên CLB                                                                                                | 1       |
| club_type                               | Suy ra                                         | Club / National Team / Other                                                                           | 1       |
| league_id                               | clubs.domestic_competition_id                  | Mã giải VĐQG gốc, dùng để so sánh khi phát hiện thay đổi                                               | 2   |
| league_name                             | competitions.name, nối qua league_id           | Giải VĐQG đang thi đấu                                                                                 | 2   |
| country_name, confederation             | competitions, national_teams                   | Quốc gia, liên đoàn                                                                                    | 1       |
| stadium_name                            | clubs.stadium_name                             | Sân nhà                                                                                                | 2   |
| stadium_size_band                       | Suy ra từ stadium_seats                        | Nhóm sức chứa: < 20.000, 20.000–40.000, > 40.000                                                     | 1       |
| stadium_seats, squad_size, average_age  | clubs, national_teams                          | Sức chứa sân, số cầu thủ trong đội hình, tuổi trung bình                                               | 1       |
| current_coach                           | clubs.coach_name                               | HLV hiện tại                                                                                           | 3   |
| previous_coach                          | Giá trị current_coach lần nạp trước            | HLV trước đó                                                                                           | 3   |
| scd2_hash                               | ETL                                            | Giá trị băm SHA-256 của các cột SCD Type 2 (league_id, stadium_name), dùng để phát hiện thay đổi (CDC) | –       |
| effective_date, expiry_date, is_current | ETL                                            | Quản lý lịch sử SCD Type 2                                                                             | –       |

**Hierarchy:** Confederation → Country → League → Club

**Lý do chọn SCD:** CLB có thể thăng hoặc xuống hạng, nên giải đấu dùng Type 2 để các mùa trong quá khứ vẫn thuộc đúng giải cũ. HLV thay đổi thường xuyên nhưng chỉ cần biết HLV hiện tại và HLV trước đó, nên dùng Type 3. Tên CLB nếu thay đổi thường là sửa lỗi, nên dùng Type 1.

### 5.5 Dim_Player – Cầu thủ

| Thuộc tính                          | Nguồn                      | Ý nghĩa                                                                       | SCD |
|-----------------------------------------|--------------------------------|-----------------------------------------------------------------------------------|---------|
| player_key                              | Tự sinh                        | Khóa chính                                                                        | –       |
| player_id                               | players.player_id              | Mã gốc                                                                            | –       |
| full_name                               | players.name                   | Họ tên                                                                            | 1       |
| birth_year                              | players.date_of_birth          | Năm sinh (dùng để tính tuổi theo mùa)                                             | 1       |
| date_of_birth                           | players.date_of_birth          | Ngày sinh, dùng để tính tuổi lúc định giá và lúc chuyển nhượng                    | 1       |
| citizenship                             | players.country_of_citizenship | Quốc tịch                                                                         | 1       |
| position                                | players.position               | Vị trí chính (Defender, Midfield, Attack, Goalkeeper)                             | 2   |
| sub_position                            | players.sub_position           | Vị trí chi tiết (Centre-Back, Left Winger...)                                     | 2   |
| foot                                    | players.foot                   | Chân thuận                                                                        | 1       |
| height_band                             | Suy ra từ height_in_cm         | Nhóm chiều cao: < 175, 175–185, > 185 cm                                        | 1       |
| agent_name                              | players.agent_name             | Người đại diện                                                                    | 2   |
| scd2_hash                               | ETL                            | Giá trị băm các cột SCD Type 2 (position, sub_position, agent_name), dùng cho CDC | –       |
| effective_date, expiry_date, is_current | ETL                            | Quản lý lịch sử SCD Type 2                                                        | –       |

**Hierarchy:** Position → Sub position → Player; Citizenship → Player

**Lý do chọn SCD:** vị trí và người đại diện là những thay đổi có ý nghĩa phân tích (ví dụ cầu thủ chuyển từ tiền vệ lên tiền đạo), nên dùng Type 2. Tên, quốc tịch, chiều cao nếu thay đổi thường là sửa lỗi, nên dùng Type 1. CLB của cầu thủ không đặt trong Dim_Player vì đã có sẵn club_key trong từng fact, phản ánh đúng CLB tại thời điểm phát sinh sự kiện.

### 5.6 Dim_Manager – Huấn luyện viên

Nguồn chỉ có tên HLV, nên bảng gồm manager_key và manager_name, lấy từ club_games. SCD Type 1. Dùng cho Fact_Team_Match (HLV từng trận) và Fact_Club_Season_Summary (HLV cuối mùa).

### 5.7 Dim_Match_Profile – Hồ sơ trận đấu (junk dimension)

Thay vì nạp nguyên bảng games vào một dimension, các cờ phân loại nhỏ của trận được gom thành một junk dimension chỉ có 8 dòng (2 × 4 tổ hợp). Không áp dụng SCD.

| Thuộc tính    | Ý nghĩa                          | Giá trị                             |
|-------------------|--------------------------------------|-----------------------------------------|
| match_profile_key | Khóa chính                           | 1–8                                     |
| hosting           | Sân nhà hay sân khách                | Home / Away                             |
| round_type        | Nhóm vòng đấu, suy ra từ games.round | League / Group stage / Knockout / Final |

### 5.8 Dim_Transfer_Type – Loại chuyển nhượng (junk dimension)

| Thuộc tính    | Ý nghĩa    | Giá trị                                                                                                          |
|-------------------|----------------|----------------------------------------------------------------------------------------------------------------------|
| transfer_type_key | Khóa chính     | 1–6                                                                                                                  |
| fee_status        | Tình trạng phí | Có phí / Miễn phí hoặc cho mượn (phí = 0) / Không công bố (phí trống)                                                |
| fee_band          | Nhóm mức phí   | < 1 triệu, 1–10 triệu, 10–50 triệu, > 50 triệu EUR (khi có phí); Không áp dụng (phí = 0); Không rõ (không công bố) |

**Hierarchy:** Fee status → Fee band

### 5.9 Tổng hợp SCD

| Dimension                                              | Type 1                                                                | Type 2             | Type 3                |
|------------------------------------------------------------|---------------------------------------------------------------------------|------------------------|---------------------------|
| Dim_Club                                                   | Tên, loại, quốc gia, sức chứa, nhóm sức chứa, số cầu thủ, tuổi trung bình | Giải đấu, sân nhà      | HLV (hiện tại / trước đó) |
| Dim_Player                                                 | Tên, ngày sinh, năm sinh, quốc tịch, chân thuận, nhóm chiều cao           | Vị trí, người đại diện | –                         |
| Dim_Competition, Dim_Manager                               | Toàn bộ                                                                   | –                      | –                         |
| Dim_Date, Dim_Season, Dim_Match_Profile, Dim_Transfer_Type | Tĩnh, không thay đổi                                                      | –                      | –                         |

**Lưu ý:** bộ dữ liệu là ảnh chụp tại một thời điểm, nên lịch sử SCD Type 2 chỉ bắt đầu hình thành từ lần nạp dữ liệu thứ hai trở đi.

## 6. Bước 4 – Xác định Fact và Measure

Mỗi fact được mô tả theo cùng một khuôn: grain, nguồn, các khóa ngoại, và bảng measure gồm tên measure, measure đó đo cái gì, cách tính trong ETL và tính cộng dồn. Measure đánh dấu (PS) là measure phái sinh: nguồn không có sẵn, phải tính trong ETL.

Ngoài các khóa và measure dưới đây, mọi fact có thêm cột kỹ thuật load_batch_id để truy vết dòng thuộc lần nạp nào; Fact_Transfer có thêm stg_transfer_id để chống nạp trùng khi chạy lại ETL.

Tính cộng dồn quyết định cách dùng measure khi tổng hợp:

- **Additive:** cộng được theo mọi chiều (ví dụ số bàn thắng).

- **Semi-additive:** cộng được theo một số chiều nhưng không theo thời gian (ví dụ giá trị thị trường: cộng giá trị các cầu thủ tại cùng thời điểm thì hợp lý, cộng giá trị một cầu thủ qua nhiều năm thì vô nghĩa).

- **Non-additive:** không cộng được, chỉ dùng MAX, MIN, AVG hoặc lấy giá trị cuối (ví dụ thứ hạng, tỉ lệ, chỉ số lũy kế).

### 6.1 Fact_Team_Match – Thành tích đội theo trận

**Tầng:** chi tiết. **Grain:** 1 đội trong 1 trận. **Nguồn:** club_games, lấy thêm ngày, mùa, giải, vòng đấu từ games.

| Khóa ngoại       | Tham chiếu            | Lấy từ                       |
|----------------------|---------------------------|----------------------------------|
| date_key             | Dim_Date (ngày thi đấu)   | games.date                       |
| season_key           | Dim_Season                | games.season                     |
| competition_key      | Dim_Competition           | games.competition_id             |
| club_key             | Dim_Club (đội)            | club_games.club_id               |
| opponent_club_key    | Dim_Club (đối thủ)        | club_games.opponent_id           |
| manager_key          | Dim_Manager (HLV đội)     | club_games.own_manager_name      |
| opponent_manager_key | Dim_Manager (HLV đối thủ) | club_games.opponent_manager_name |
| match_profile_key    | Dim_Match_Profile         | club_games.hosting + games.round |
| game_id (degenerate) | –                         | club_games.game_id               |

| Measure                | Đo cái gì                                                | Cách tính (ETL)                                                                                | Tính chất |
|----------------------------|--------------------------------------------------------------|----------------------------------------------------------------------------------------------------|---------------|
| goals_for                  | Số bàn đội ghi được trong trận                               | own_goals                                                                                          | Additive      |
| goals_against              | Số bàn đội để thủng lưới                                     | opponent_goals                                                                                     | Additive      |
| goal_difference            | Chênh lệch bàn thắng – bàn thua                              | goals_for − goals_against                                                                          | Additive      |
| is_win, is_draw, is_loss   | Kết quả trận (dùng SUM để đếm số trận thắng/hòa/thua)        | Cờ 0/1 so sánh tỉ số                                                                               | Additive      |
| points                     | Điểm giành được trong trận                                   | Thắng 3, hòa 1, thua 0                                                                             | Additive      |
| is_clean_sheet             | Trận giữ sạch lưới                                           | 1 nếu goals_against = 0                                                                            | Additive      |
| league_position            | Thứ hạng trên bảng xếp hạng ghi nhận ở trận này              | own_position (chỉ có ở giải VĐQG)                                                                  | Non-additive  |
| points_accumulated (PS)    | Tổng điểm của đội tính đến hết trận này trong giải và mùa đó | SUM(points) OVER (PARTITION BY club, competition, season ORDER BY date)                            | Non-additive  |
| current_win_streak (PS)    | Số trận thắng liên tiếp của đội tính đến trận này (phong độ) | Đếm trận thắng liên tiếp theo thứ tự ngày của CLB trong mùa, trên mọi giải; về 0 khi hòa hoặc thua | Non-additive  |
| days_since_last_match (PS) | Số ngày nghỉ kể từ trận trước của đội (độ mệt mỏi, lịch dày) | date − LAG(date) OVER (PARTITION BY club ORDER BY date); trận đầu tiên để NULL                     | Non-additive  |

Ba measure phái sinh cuối cần hàm cửa sổ (window function) trên toàn bộ lịch thi đấu của CLB, nên phải tính trong ETL chứ không đọc thẳng từ một dòng nguồn. points_accumulated chỉ có ý nghĩa với giải VĐQG; ở giải cúp để NULL.

### 6.2 Fact_Player_Appearance – Thành tích cầu thủ theo trận

**Tầng:** chi tiết. **Grain:** 1 cầu thủ ra sân trong 1 trận. **Nguồn:** appearances, lấy thêm mùa giải từ games. Khi tra player_key, chọn phiên bản cầu thủ có hiệu lực tại ngày thi đấu (Dim_Player dùng SCD Type 2).

| Khóa ngoại       | Tham chiếu                        | Lấy từ                     |
|----------------------|---------------------------------------|--------------------------------|
| date_key             | Dim_Date (ngày thi đấu)               | appearances.date               |
| season_key           | Dim_Season                            | games.season (nối qua game_id) |
| competition_key      | Dim_Competition                       | appearances.competition_id     |
| club_key             | Dim_Club (CLB của cầu thủ trong trận) | appearances.player_club_id     |
| player_key           | Dim_Player                            | appearances.player_id          |
| game_id (degenerate) | –                                     | appearances.game_id            |

| Measure                 | Đo cái gì                                                                 | Cách tính (ETL)                                                          | Tính chất |
|-----------------------------|-------------------------------------------------------------------------------|------------------------------------------------------------------------------|---------------|
| minutes_played              | Số phút cầu thủ có mặt trên sân                                               | Từ nguồn                                                                     | Additive      |
| goals                       | Số bàn thắng                                                                  | Từ nguồn                                                                     | Additive      |
| assists                     | Số đường kiến tạo                                                             | Từ nguồn                                                                     | Additive      |
| yellow_cards, red_cards     | Số thẻ vàng, thẻ đỏ                                                           | Từ nguồn                                                                     | Additive      |
| goal_contributions (PS)     | Tổng đóng góp trực tiếp vào bàn thắng                                         | goals + assists                                                              | Additive      |
| is_full_match (PS)          | Cầu thủ thi đấu trọn trận                                                     | 1 nếu minutes_played ≥ 90                                                    | Additive      |
| is_goal_involved (PS)       | Trận cầu thủ có ghi bàn hoặc kiến tạo                                         | 1 nếu goal_contributions > 0                                                | Additive      |
| discipline_points (PS)      | Mức độ vi phạm kỷ luật                                                        | yellow × 1 + red × 3 (theo cách tính fair-play của UEFA)                     | Additive      |
| season_goals_to_date (PS)   | Tổng bàn của cầu thủ trong giải và mùa đó tính đến hết trận này               | SUM(goals) OVER (PARTITION BY player, competition, season ORDER BY date)     | Non-additive  |
| season_minutes_to_date (PS) | Tổng phút thi đấu tương ứng tính đến hết trận này                             | SUM(minutes) OVER (... cùng partition ...)                                   | Non-additive  |
| goals_per_90_to_date (PS)   | Hiệu suất ghi bàn mỗi 90 phút tính đến trận này (theo dõi phong độ trong mùa) | season_goals_to_date × 90 / season_minutes_to_date; NULL nếu chưa đủ 90 phút | Non-additive  |

Chỉ số goals_per_90 không được tính cho riêng từng trận, vì với một trận đơn lẻ con số này bị méo (ví dụ vào sân 10 phút ghi 1 bàn sẽ cho 9,0 bàn/90 phút). Thay vào đó, ETL tính sẵn dạng lũy kế trong mùa (goals_per_90_to_date), vừa có ý nghĩa ở mức trận đấu, vừa không cần tính lại khi truy vấn.

### 6.3 Fact_Player_Valuation – Định giá cầu thủ

**Tầng:** chi tiết. **Grain:** 1 lần định giá của 1 cầu thủ tại 1 ngày. **Nguồn:** player_valuations.

| Khóa ngoại  | Tham chiếu                    | Lấy từ                                            |
|-----------------|-----------------------------------|-------------------------------------------------------|
| date_key        | Dim_Date (ngày định giá)          | player_valuations.date                                |
| season_key      | Dim_Season                        | Quy đổi từ player_valuations.date                     |
| player_key      | Dim_Player                        | player_valuations.player_id                           |
| club_key        | Dim_Club (CLB lúc định giá)       | player_valuations.current_club_id                     |
| competition_key | Dim_Competition (giải của CLB đó) | player_valuations.player_club_domestic_competition_id |

| Measure                    | Đo cái gì                                    | Cách tính (ETL)                                            | Tính chất |
|--------------------------------|--------------------------------------------------|----------------------------------------------------------------|---------------|
| market_value_eur               | Giá trị thị trường của cầu thủ tại ngày định giá | Từ nguồn                                                       | Semi-additive |
| value_change_eur (PS)          | Mức tăng/giảm giá trị so với lần định giá trước  | market_value − LAG(market_value) theo cầu thủ; lần đầu để NULL | Additive      |
| value_change_pct (PS)          | Tỉ lệ % tăng/giảm so với lần trước               | value_change / giá trị lần trước × 100                         | Non-additive  |
| days_since_last_valuation (PS) | Khoảng cách giữa 2 lần định giá                  | date − LAG(date) theo cầu thủ                                  | Non-additive  |
| player_age_at_valuation (PS)   | Tuổi cầu thủ tại ngày định giá                   | Ngày định giá − ngày sinh (Dim_Player)                         | Non-additive  |

Giá trị cuối mùa của một cầu thủ được lấy bằng dòng có ngày định giá lớn nhất trong mùa đó.

### 6.4 Fact_Transfer – Chuyển nhượng

**Tầng:** chi tiết. **Grain:** 1 thương vụ chuyển nhượng. **Nguồn:** transfers.

| Khóa ngoại    | Tham chiếu                | Lấy từ                |
|-------------------|-------------------------------|---------------------------|
| date_key          | Dim_Date (ngày chuyển nhượng) | transfers.transfer_date   |
| season_key        | Dim_Season                    | transfers.transfer_season |
| player_key        | Dim_Player                    | transfers.player_id       |
| from_club_key     | Dim_Club (CLB đi)             | transfers.from_club_id    |
| to_club_key       | Dim_Club (CLB đến)            | transfers.to_club_id      |
| transfer_type_key | Dim_Transfer_Type             | Suy ra từ transfer_fee    |

| Measure                 | Đo cái gì                                                | Cách tính (ETL)                                                                                   | Tính chất |
|-----------------------------|--------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|---------------|
| transfer_fee_eur            | Số tiền CLB đến trả cho CLB đi                               | Từ nguồn; NULL nếu không công bố                                                                      | Additive      |
| market_value_eur            | Giá trị thị trường của cầu thủ lúc chuyển nhượng             | Từ nguồn                                                                                              | Semi-additive |
| fee_premium_eur (PS)        | Mua đắt hay rẻ so với giá trị (dương là trả cao hơn giá trị) | transfer_fee − market_value; chỉ tính khi phí > 0 (vụ miễn phí, cho mượn hoặc không công bố để NULL) | Additive      |
| player_age_at_transfer (PS) | Tuổi cầu thủ lúc chuyển nhượng                               | Ngày chuyển nhượng − ngày sinh                                                                        | Non-additive  |
| transfer_count              | Số thương vụ (dùng để đếm)                                   | Luôn bằng 1                                                                                           | Additive      |

Chi tiêu, thu nhập và chi tiêu ròng của CLB theo mùa được tính trực tiếp từ fact này (SUM transfer_fee theo to_club_key hoặc from_club_key), vì bảng chỉ khoảng 175 nghìn dòng nên không cần bảng tổng hợp riêng.

### 6.5 Fact_Player_Season_Summary – Thành tích cầu thủ theo mùa

**Tầng:** tổng hợp. **Grain:** 1 cầu thủ, thi đấu cho 1 CLB, ở 1 giải, trong 1 mùa. **Loại:** Aggregate fact. **Nguồn:** Fact_Player_Appearance, GROUP BY player_id, club_id (lấy qua dimension), competition_key, season_key. Khóa lưu vào bảng là phiên bản mới nhất của cầu thủ và CLB trong mùa, nhờ vậy cầu thủ đổi phiên bản SCD Type 2 giữa mùa không bị tách thành 2 dòng.

Grain phải gồm đủ CLB và giải, vì trong một mùa cầu thủ có thể đá nhiều giải (VĐQG, cúp quốc gia, cúp châu Âu) và có thể chuyển CLB giữa mùa. Nếu grain chỉ là "1 cầu thủ trong 1 mùa" thì không thể gắn club_key và competition_key vào dòng. Muốn xem tổng cả mùa của cầu thủ trên mọi giải, chỉ cần SUM các dòng của cầu thủ đó.

| Khóa ngoại  | Tham chiếu                           | Lấy từ                             |
|-----------------|------------------------------------------|----------------------------------------|
| season_key      | Dim_Season                               | Fact_Player_Appearance.season_key      |
| competition_key | Dim_Competition                          | Fact_Player_Appearance.competition_key |
| club_key        | Dim_Club                                 | Fact_Player_Appearance.club_key        |
| player_key      | Dim_Player (phiên bản hiệu lực cuối mùa) | Fact_Player_Appearance.player_key      |

| Measure                         | Đo cái gì                           | Cách tính (ETL)                                            | Tính chất |
|-------------------------------------|-----------------------------------------|----------------------------------------------------------------|---------------|
| total_appearances                   | Số trận ra sân                          | COUNT(*)                                                      | Additive      |
| total_minutes_played                | Tổng số phút thi đấu                    | SUM(minutes_played)                                            | Additive      |
| total_goals                         | Tổng số bàn thắng                       | SUM(goals)                                                     | Additive      |
| total_assists                       | Tổng số kiến tạo                        | SUM(assists)                                                   | Additive      |
| total_goal_contributions            | Tổng bàn thắng + kiến tạo               | SUM(goal_contributions)                                        | Additive      |
| total_yellow_cards, total_red_cards | Tổng thẻ vàng, thẻ đỏ                   | SUM tương ứng                                                  | Additive      |
| total_full_matches                  | Số trận đá trọn 90 phút                 | SUM(is_full_match)                                             | Additive      |
| goals_per_90 (PS)                   | Hiệu suất ghi bàn mỗi 90 phút trong mùa | total_goals × 90 / total_minutes_played; NULL nếu dưới 90 phút | Non-additive  |
| minutes_per_goal (PS)               | Trung bình bao nhiêu phút ghi 1 bàn     | total_minutes_played / total_goals; NULL nếu chưa ghi bàn      | Non-additive  |

goals_per_90 và minutes_per_goal được tính sẵn để dashboard hiển thị trực tiếp. Tuy nhiên đây là tỉ lệ, nên khi gộp nhiều dòng (ví dụ cả mùa trên mọi giải) không được lấy SUM hay AVG của tỉ lệ, mà phải tính lại từ total_goals và total_minutes_played.

### 6.6 Fact_Club_Season_Summary – Thành tích CLB theo mùa

**Tầng:** tổng hợp. **Grain:** 1 CLB ở 1 giải trong 1 mùa. **Loại:** Aggregate fact. **Nguồn:** Fact_Team_Match, GROUP BY club_id (lấy qua Dim_Club), competition_key, season_key, với club_key là phiên bản mới nhất của CLB trong mùa. Với giải VĐQG, bảng này chính là bảng xếp hạng cuối mùa.

Một CLB có thể thay HLV giữa mùa, trong khi grain chỉ cho phép một giá trị mỗi dòng. Vì vậy khóa manager được định nghĩa rõ là HLV dẫn dắt ở trận cuối cùng của mùa (last_manager_key), kèm measure managers_used cho biết mùa đó CLB đã dùng bao nhiêu HLV.

| Khóa ngoại   | Tham chiếu                    | Lấy từ                            |
|------------------|-----------------------------------|---------------------------------------|
| season_key       | Dim_Season                        | Fact_Team_Match.season_key            |
| competition_key  | Dim_Competition                   | Fact_Team_Match.competition_key       |
| club_key         | Dim_Club                          | Fact_Team_Match.club_key              |
| last_manager_key | Dim_Manager (HLV ở trận cuối mùa) | manager_key của trận có ngày lớn nhất |

| Measure                           | Đo cái gì                                     | Cách tính (ETL)                                                                                                                                                                           | Tính chất |
|---------------------------------------|---------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------------|
| total_matches_played                  | Số trận đã đá                                     | COUNT(*)                                                                                                                                                                                     | Additive      |
| total_wins, total_draws, total_losses | Số trận thắng, hòa, thua                          | SUM(is_win), SUM(is_draw), SUM(is_loss)                                                                                                                                                       | Additive      |
| total_home_wins, total_away_wins      | Số trận thắng trên sân nhà, sân khách             | SUM(is_win) theo hosting                                                                                                                                                                      | Additive      |
| total_goals_for, total_goals_against  | Tổng bàn thắng, bàn thua                          | SUM tương ứng                                                                                                                                                                                 | Additive      |
| goal_difference                       | Hiệu số bàn thắng bại                             | total_goals_for − total_goals_against                                                                                                                                                         | Additive      |
| final_points                          | Tổng điểm cuối mùa                                | SUM(points), bằng points_accumulated của trận cuối; chỉ tính với giải VĐQG                                                                                                                    | Additive      |
| final_rank                            | Thứ hạng cuối mùa                                 | league_position của trận cuối cùng trong mùa                                                                                                                                                  | Non-additive  |
| total_clean_sheets                    | Số trận giữ sạch lưới                             | SUM(is_clean_sheet)                                                                                                                                                                           | Additive      |
| win_rate (PS)                         | Tỉ lệ % trận thắng                                | total_wins / total_matches_played × 100                                                                                                                                                       | Non-additive  |
| longest_win_streak (PS)               | Chuỗi thắng dài nhất của CLB trong giải và mùa đó | Gaps-and-islands trên các trận của CLB trong giải × mùa. Không lấy MAX(current_win_streak), vì chỉ số đó tính trên mọi giải (Arsenal GB1 2023/24: 8, còn MAX của current_win_streak chỉ là 6) | Non-additive  |
| managers_used (PS)                    | Số HLV đã dẫn dắt trong mùa                       | COUNT(DISTINCT manager_key)                                                                                                                                                                   | Non-additive  |

final_points và final_rank chỉ có ý nghĩa với giải VĐQG. Với giải cúp, cả hai measure này để NULL.

## 7. Ví dụ câu hỏi phân tích

Các câu hỏi dưới đây cho thấy mỗi fact và mỗi hierarchy đều có mục đích sử dụng. Cột cuối ghi rõ thao tác drill-up/drill-down trên hierarchy.

| Câu hỏi                                                                                                                | Fact                                           | Dimension và hierarchy sử dụng                                                          |
|----------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------|---------------------------------------------------------------------------------------------|
| Tổng chi tiêu chuyển nhượng giữa các liên đoàn (ví dụ UEFA so với AFC) biến động thế nào qua các quý trong 5 năm gần nhất? | Fact_Transfer                                      | Drill-up Dim_Club (CLB đến) lên cấp Confederation; drill-up Dim_Date lên cấp Year → Quarter |
| Đóng góp bàn thắng phân bổ theo vị trí chính và vị trí chi tiết thay đổi ra sao qua các mùa?                               | Fact_Player_Season_Summary                         | Dim_Player: Position → Sub position; Dim_Season                                             |
| Tổng giá trị cầu thủ theo quốc gia, drill-down xuống từng giải và từng CLB, cuối mùa 2024/25                               | Fact_Player_Valuation                              | Dim_Club: Country → League → Club; Dim_Season                                               |
| Tỉ lệ bàn thắng ở vòng loại trực tiếp so với vòng bảng của các cúp châu Âu                                                 | Fact_Team_Match                                    | Dim_Match_Profile: round_type; Dim_Competition: Competition type → Competition              |
| Bảng xếp hạng Premier League mùa 2024/25                                                                                   | Fact_Club_Season_Summary                           | Dim_Season, Dim_Competition, Dim_Club                                                       |
| Top 10 cầu thủ có goals_per_90 cao nhất (tối thiểu 1.500 phút) mỗi giải                                                    | Fact_Player_Season_Summary                         | Dim_Player, Dim_Season, Dim_Competition                                                     |
| Đội có nhiều ngày nghỉ hơn đối thủ có thắng nhiều hơn không?                                                               | Fact_Team_Match                                    | So sánh days_since_last_match của 2 đội qua game_id                                         |
| HLV có tỉ lệ thắng cao nhất (tối thiểu 50 trận)                                                                            | Fact_Team_Match                                    | Dim_Manager                                                                                 |
| Cầu thủ ghi nhiều bàn có tăng giá trị mạnh hơn không?                                                                      | Fact_Player_Season_Summary + Fact_Player_Valuation | Dim_Player, Dim_Season (drill-across)                                                       |

**Lưu ý dữ liệu cho câu hỏi theo liên đoàn:** chỉ các CLB có trong clubs.csv và national_teams.csv mới có thông tin quốc gia và liên đoàn. Các thương vụ liên quan đến CLB ngoài phạm vi theo dõi sẽ rơi vào nhóm Unknown, và báo cáo nên hiển thị riêng nhóm này.
