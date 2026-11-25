# DAWH Football Transfermarkt

## 1. Giới thiệu

Đây là đồ án môn **Data Warehouse**, xây dựng kho dữ liệu phân tích bóng đá dựa trên dữ liệu từ **Transfermarkt**.

Đề tài áp dụng phương pháp **Kimball Dimensional Modeling** để thiết kế Data Warehouse theo mô hình **Fact Constellation (Galaxy Schema)**.

Mục tiêu của hệ thống là tích hợp dữ liệu bóng đá từ nhiều bảng dữ liệu nguồn và tổ chức lại thành các bảng Fact và Dimension, phục vụ cho việc phân tích đội bóng, cầu thủ, giá trị cầu thủ và hoạt động chuyển nhượng.

## 2. Nguồn dữ liệu

### Nguồn dữ liệu gốc

**Transfermarkt**

Website:

https://www.transfermarkt.com/

Transfermarkt là nguồn dữ liệu bóng đá được sử dụng để cung cấp thông tin về cầu thủ, câu lạc bộ, trận đấu, giá trị thị trường và chuyển nhượng.

### Dataset sử dụng trong đồ án

Đồ án sử dụng bộ dữ liệu:

**Transfermarkt Datasets**

Repository:

https://github.com/dcaribou/transfermarkt-datasets

Dataset được xây dựng từ dữ liệu Transfermarkt và cung cấp các bảng dữ liệu có thể liên kết với nhau thông qua các ID. Bộ dữ liệu bao gồm các thông tin về competitions, games, clubs, players, appearances, player valuations, club games, transfers và các bảng liên quan.

Tại thời điểm hiện tại, repository công bố dữ liệu với quy mô khoảng:

* 88,000+ trận đấu
* 50,000+ cầu thủ
* 1,890,000+ lượt cầu thủ xuất hiện trong trận đấu
* 650,000+ bản ghi lịch sử giá trị cầu thủ
* 175,000+ bản ghi chuyển nhượng
* 177,000+ bản ghi `club_games`
* 790+ câu lạc bộ
* 65 competitions

Các số liệu trên là quy mô được công bố trong dataset và có thể thay đổi tùy phiên bản dữ liệu được sử dụng. Repository hiện ghi nhận dữ liệu được cập nhật đến **06/07/2026** và quá trình cập nhật tự động đang tạm dừng.

## 3. Các bảng dữ liệu nguồn

Một số bảng dữ liệu chính được sử dụng:

| Bảng                | Nội dung                                    |
| ------------------- | ------------------------------------------- |
| `players`           | Thông tin cầu thủ                           |
| `clubs`             | Thông tin câu lạc bộ                        |
| `competitions`      | Giải đấu và các cuộc thi                    |
| `games`             | Thông tin trận đấu                          |
| `club_games`        | Thông tin trận đấu theo góc nhìn câu lạc bộ |
| `appearances`       | Thống kê cầu thủ trong từng trận            |
| `player_valuations` | Lịch sử giá trị thị trường của cầu thủ      |
| `transfers`         | Thông tin chuyển nhượng cầu thủ             |
| `countries`         | Thông tin quốc gia                          |
| `national_teams`    | Thông tin đội tuyển quốc gia                |

Dataset nguồn mô tả `appearances` là dữ liệu theo từng cầu thủ trong từng trận đấu, `player_valuations` lưu các bản ghi thay đổi giá trị cầu thủ và `transfers` lưu thông tin cầu thủ, câu lạc bộ đi, câu lạc bộ đến và phí chuyển nhượng.

## 4. Mục tiêu của Data Warehouse

Data Warehouse được xây dựng nhằm:

* Tích hợp dữ liệu bóng đá từ nhiều bảng dữ liệu nguồn.
* Chuẩn hóa dữ liệu phục vụ phân tích.
* Thiết kế mô hình dữ liệu theo phương pháp Kimball.
* Xây dựng các Dimension và Fact.
* Xử lý dữ liệu thay đổi theo thời gian bằng SCD.
* Hỗ trợ phân tích theo cầu thủ, câu lạc bộ, giải đấu, mùa giải và thời gian.
* Cung cấp fact chi tiết để tầng phân tích (SSAS) tổng hợp phục vụ báo cáo và trực quan hóa.

## 5. Phạm vi phân tích

Đồ án tập trung vào 4 quy trình nghiệp vụ chính:

### 5.1. Hiệu suất đội bóng trong trận đấu

Phân tích:

* Số bàn thắng ghi được.
* Số bàn thua.
* Kết quả thắng, hòa, thua.
* Clean sheet.
* Điểm (3 thắng / 1 hòa / 0 thua) và hiệu số bàn thắng.
* Vị trí của đội bóng.

### 5.2. Hiệu suất cầu thủ trong trận đấu

Phân tích:

* Số phút thi đấu.
* Bàn thắng.
* Kiến tạo.
* Thẻ vàng.
* Thẻ đỏ.
* Số lần ra sân.

### 5.3. Giá trị cầu thủ

Phân tích:

* Giá trị thị trường của cầu thủ.
* Biến động giá trị theo thời gian.
* Giá trị cầu thủ theo câu lạc bộ.
* Giá trị cầu thủ theo mùa giải.

### 5.4. Chuyển nhượng

Phân tích:

* Lịch sử chuyển nhượng.
* Câu lạc bộ đi và câu lạc bộ đến.
* Phí chuyển nhượng.
* Giá trị thị trường tại thời điểm chuyển nhượng.
* Chênh lệch giữa phí chuyển nhượng và giá trị thị trường.
* Tuổi cầu thủ lúc chuyển nhượng, tách thị trường đội trẻ (dưới 18 tuổi) và chuyên nghiệp.

## 6. Mô hình Data Warehouse

Kho dữ liệu được thiết kế theo **Fact Constellation / Galaxy Schema**, trong đó nhiều Fact sử dụng các Dimension dùng chung.

### Fact

* `Fact_Team_Match`
* `Fact_Player_Appearance`
* `Fact_Player_Valuation`
* `Fact_Transfer`

### Dimension

* `Dim_Date`
* `Dim_Club`
* `Dim_Player`
* `Dim_Season`
* `Dim_Competition`
* `Dim_Match`
* `Dim_Manager`
* `Dim_Transfer_Type`

Fact lưu ở grain chi tiết nhất (mỗi trận theo đội, mỗi lượt ra sân, mỗi lần định giá, mỗi thương vụ) và chỉ thêm dòng mới. Kho không có bảng tổng hợp; các phép tổng hợp như bảng xếp hạng mùa, bàn thắng mỗi 90 phút, chi tiêu ròng của CLB do SSAS tính trên fact chi tiết.

Bảng điều khiển ETL:

* `etl_load_window`: cửa sổ thời gian của lần nạp gần nhất.
* `etl_batch`: nhật ký mỗi lần chạy (mã lần chạy, cửa sổ nạp, thời gian, trạng thái, số dòng fact trước và sau).

## 7. Thiết kế ETL

ETL được xây dựng bằng **SSIS** (package `Main_ETL_Master.dtsx`), gồm 3 Sequence Container chạy nối tiếp:

```
10 file CSV ──01──► Staging (stg_raw_*) ──02──► 8 Dimension ──03──► 4 Fact chi tiết ──► SSAS
              Extract                   Transform + Load      Transform + Load        (tổng hợp)
```

| Container | Việc làm |
| --- | --- |
| `01 - Trích xuất file CSV vào Staging` | Xóa dữ liệu cũ trong Staging, chép nguyên trạng 10 file CSV vào 10 bảng `stg_raw_*` |
| `02 - Làm sạch và nạp Dimension` | Làm sạch, chuẩn hóa, loại trùng và nạp 6 dimension theo SCD1 / SCD2 / SCD3 |
| `03 - Làm sạch tính toán và nạp Fact` | Làm sạch, kiểm tra quy tắc, tính measure mức từng dòng, tra surrogate key, nạp gia tăng 4 fact; ghi nhật ký lần chạy |

Nguyên tắc:

1. **Tính toán mức từng dòng nằm trong ETL**, trước khi ghi kho: cờ thắng/hòa/thua, `points`, `goal_difference`, `is_clean_sheet`, `value_change_eur`, tuổi, `is_youth_transfer`, loại phí, phí chênh, các band của dimension.
2. **Kho chỉ lưu**: fact chỉ thêm dòng mới (append-only), không chạy SQL tính toán hay sửa fact sau khi nạp.
3. **Tổng hợp ở tầng phân tích** (SSAS).
4. **Nạp gia tăng** theo cửa sổ `LoadFrom`–`LoadTo`; dòng đã có trong fact được bỏ qua nên chạy lại không bị trùng.
5. Dòng lỗi ép kiểu hoặc vi phạm quy tắc được ghi vào `etl_reject`; khóa không tra được gán dòng Unknown (-1).

Cách chạy và kiểm tra: xem [`docs/Huong_dan_chay_ETL_SSIS.md`](docs/Huong_dan_chay_ETL_SSIS.md). Diễn giải từng component: [`docs/Dien_giai_chi_tiet_SSIS.md`](docs/Dien_giai_chi_tiet_SSIS.md). Danh mục phép tính và measure: [`docs/Tinh_toan_trong_ETL_va_Measure.md`](docs/Tinh_toan_trong_ETL_va_Measure.md).

| Script | Việc làm |
| --- | --- |
| `sql/00_create_staging_raw.sql` | Tạo database Staging, 10 bảng `stg_raw_*` và `etl_reject` |
| `sql/01_create_dw.sql` | Tạo kho dữ liệu: 8 dimension, 4 fact, bảng điều khiển ETL, dim tĩnh, dòng Unknown, procedure SCD2 |
| `sql/99_kiem_tra_ket_qua.sql` | Kiểm tra kết quả sau mỗi lần chạy |

## 8. Công nghệ sử dụng

* Data Warehouse: Kimball Dimensional Modeling (Galaxy Schema)
* Database: SQL Server 2022
* ETL: SQL Server Integration Services (SSIS), Visual Studio 2022
* Data Source: Transfermarkt
* Dataset: Transfermarkt Datasets
* Phân tích OLAP: SSAS (Multidimensional), truy vấn MDX

## 9. Tài liệu tham khảo và nguồn dữ liệu

1. Transfermarkt
   https://www.transfermarkt.com/

2. Transfermarkt Datasets - GitHub
   https://github.com/dcaribou/transfermarkt-datasets

3. Transfermarkt Datasets - Dataset Metadata
   https://github.com/dcaribou/transfermarkt-datasets/blob/master/data/prep/dataset-metadata.json

4. Kimball Group - Dimensional Modeling
   https://www.kimballgroup.com/

## 10. Lưu ý về dữ liệu

Dữ liệu được sử dụng cho mục đích học tập và xây dựng đồ án Data Warehouse.

Dữ liệu gốc có nguồn từ Transfermarkt và được cung cấp thông qua bộ Transfermarkt Datasets. Repository của dataset mô tả rõ nguồn dữ liệu, cấu trúc các bảng và quy trình thu thập/xử lý dữ liệu.
