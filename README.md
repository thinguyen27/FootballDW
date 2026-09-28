# FootballDW – Kho dữ liệu bóng đá Transfermarkt

Đồ án môn Thiết kế kho dữ liệu. Kho được thiết kế theo phương pháp Kimball, dạng Fact Constellation với 2 tầng grain:
- 4 fact chi tiết: trận đấu theo đội, lần ra sân, lần định giá, thương vụ chuyển nhượng.
- 2 fact tổng hợp theo mùa.

Công nghệ sử dụng:
- SQL Server 2022: database nguồn TransfermarktDB và kho FootballDW.
- SSIS: toàn bộ luồng ETL.
- SSAS Multidimensional: cube và truy vấn MDX.

Tài liệu thiết kế chính thức: [`docs/Thiet_ke_v1.md`](docs/Thiet_ke_v1.md) (bản Word: `docs/Thiet_ke_v1.docx`).

## Thành viên và phân công

| Người | Vai trò chính | Review chéo với |
|---|---|---|
| A | Kiến trúc, staging từ DB, Dim_Club, Dim_Player, master package, CDC | D |
| B | Fact_Team_Match, Fact_Club_Season_Summary, Dim_Date, Dim_Season, Dim_Manager | C |
| C | Fact_Player_Appearance, Fact_Player_Valuation, Fact_Player_Season_Summary, Dim_Competition | B |
| D | Transfers từ CSV, Fact_Transfer, demo incremental, cube SSAS | A |

Chi tiết ticket và tiến độ: `docs/Phan_cong_Ticket_DWH.xlsx`.

## Cấu trúc thư mục

```
FootballDW/
├── README.md
├── docs/                  Tài liệu thiết kế, hướng dẫn triển khai, file ticket
│   └── bien_ban_hop/      Biên bản họp nhóm (đặt tên YYYY-MM-DD_noi-dung.md)
├── data/                  transfers_dot1.csv, transfers_dot2.csv (demo 2 đợt)
├── sql/                   Script SQL, chạy theo thứ tự số
├── ssis/                  Solution SSIS FootballDW_ETL
├── ssas/                  Project SSAS FootballDW_Cube
├── queries/
│   ├── sql/               Truy vấn phân tích SQL (DW-33, DW-36, DW-37)
│   └── mdx/               Truy vấn MDX (DW-34, DW-35)
└── report/                Báo cáo cuối kỳ và hình minh họa
```

10 file CSV gốc của Transfermarkt **không** nằm trong repo. appearances.csv nặng khoảng 190 MB, vượt giới hạn 100 MB của GitHub. Mỗi người tự đặt các file này tại `C:\TransfermarktData\`.

## Cài đặt trên một máy mới

1. Cài theo DW-03 trong `docs/Huong_dan_trien_khai_DW01-DW32.docx`:
   - SQL Server 2022 Developer, có kèm Analysis Services.
   - SSMS.
   - Visual Studio 2022 và 2 extension: SSIS Projects, Analysis Services Projects.
2. Chép 10 file CSV gốc và 2 file trong `data/` vào `C:\TransfermarktData\`.
3. Mở từng script trong SSMS và chạy theo thứ tự:

| Thứ tự | File | Chạy trên | Ghi chú |
|---|---|---|---|
| 1 | `sql/00_Load_Transfermarkt_CSV.sql` | master | Tạo TransfermarktDB, nạp 10 bảng |
| 2 | `sql/00a_Tach_du_lieu_dot_1.sql` | TransfermarktDB | Chỉ chạy 1 lần; cắt nguồn về đợt 1 |
| 3 | `sql/01_FootballDW_DDL.sql` | master | **Xóa và tạo lại** FootballDW |
| 4 | `sql/02` → `sql/06` | FootballDW | Tạo thủ tục; chạy lại toàn bộ mỗi khi chạy lại 01 |
| 5 | `ssis/FootballDW_ETL.sln` → chạy `pkg_Master.dtsx` | | Nạp đợt 1 |
| 6 | `sql/07_Kiem_tra_ket_qua.sql` | FootballDW | So với con số kỳ vọng trong file |
| 7 | `sql/00b_Ap_dung_dot_2.sql`, rồi chạy lại `pkg_Master` | TransfermarktDB | Demo incremental đợt 2 |

Khi chưa có SSIS, có thể chạy thử toàn bộ bằng SQL (xem cuối file `sql/06`):

```sql
EXEC etl.usp_Run_All_SQL @effective_date = NULL,
     @transfers_csv = N'C:\TransfermarktData\transfers_dot1.csv';
```

## Quy ước đặt tên

### Database

| Đối tượng | Quy ước | Ví dụ |
|---|---|---|
| Database nguồn | TransfermarktDB, giữ nguyên tên bảng gốc | `dbo.club_games` |
| Kho dữ liệu | FootballDW | |
| Schema | `etl` = điều khiển ETL, `stg` = staging, `dw` = kho | |
| Bảng staging | Schema `stg`, giữ tên bảng nguồn | `stg.games`, `stg.transfers` |
| Bảng tính toán trung gian | `stg.calc_<fact>` | `stg.calc_team_match` |
| Dimension | `dw.dim_<tên>`, chữ thường, gạch dưới | `dw.dim_club` |
| Fact | `dw.fact_<tên>` | `dw.fact_player_appearance` |
| Surrogate key | `<tên dim>_key`, kiểu INT; dòng Unknown = -1 | `club_key`, `player_key` |
| Khóa gốc từ nguồn | Giữ tên nguồn | `club_id`, `player_id` |
| Cột cờ 0/1 | Tiền tố `is_` | `is_win`, `is_current` |
| Cột SCD Type 2 | `effective_date`, `expiry_date`, `is_current`, `scd2_hash` | |
| Stored procedure | `etl.usp_<Động từ>_<Đối tượng>`, viết PascalCase | `etl.usp_Load_DimClub`, `etl.usp_Calc_TeamMatch` |
| Hàm | `etl.fn_<Tên>` | `etl.fn_RoundType` |
| Chỉ mục | `IX_<bảng>_<cột>` | `IX_ftm_club_season` |

> Ticket ghi "stg_ cho staging". Nhóm dùng **schema** `stg` thay cho tiền tố tên bảng: gọn hơn, phân quyền theo schema được, và tên bảng staging trùng tên nguồn nên dễ đối chiếu.

### SSIS

| Đối tượng | Quy ước | Ví dụ |
|---|---|---|
| Package | `pkg_<Tầng>_<Đối tượng>` | `pkg_Stg_FromDB`, `pkg_Fact_TeamMatch`, `pkg_Master` |
| Connection Manager | `CM_<tên>` | `CM_Source`, `CM_DW`, `CM_TransfersCSV` |
| Execute SQL Task | `EST_<việc>` | `EST_CalcTeamMatch` |
| Data Flow Task | `DFT_<việc>` | `DFT_LoadFactTeamMatch` |
| Sequence Container | `SEQ_<nhóm>` | `SEQ_Dimensions` |
| Execute Package Task | `EPT_<package>` | `EPT_Fact_Transfer` |
| Thành phần trong Data Flow | `SRC_`, `LKP_`, `DER_`, `CNV_`, `RC_`, `DST_` | `LKP_Competition`, `DST_FactTeamMatch` |
| Tham số | Project: PascalCase; package: `BatchId` | `TransfersCsvPath` |

### SSAS và truy vấn

| Đối tượng | Quy ước | Ví dụ |
|---|---|---|
| Dimension trong cube | Tên tiếng Anh, có dấu cách | `Club`, `Opponent Club`, `Transfer Type` |
| Hierarchy | Danh từ mô tả | `Calendar`, `Geography`, `Positions` |
| File truy vấn | `<ticket>_<số thứ tự>_<nội dung>.sql` hoặc `.mdx` | `DW-33_01_bang_xep_hang.sql` |

## Quy trình làm việc với Git

1. **Mỗi ticket một nhánh**, đặt tên `DW-xx-mo-ta-ngan` (ví dụ `DW-10-stg-from-db`).
2. **Commit** bắt đầu bằng mã ticket: `DW-10: thêm data flow club_games`.
3. **Pull request** vào `main`. Người review chéo (theo bảng phân công) duyệt rồi mới merge. PR là minh chứng làm việc nhóm cho tiêu chí 2.
4. **Trước khi bắt đầu làm:** Pull (Fetch origin) để lấy bản mới nhất.
5. **Mỗi package `.dtsx` chỉ một người sửa**, đúng chủ ticket. File `.dtsx` là XML rất khó gộp; hai người cùng sửa gần như chắc chắn hỏng file. Muốn góp ý thì comment trong PR.
6. **File `FootballDW_ETL.dtproj` và `Project.params`** do A quản lý. Ai thêm package mới thì báo A.

## Lưu ý kỹ thuật khi làm SSIS trong nhóm

- **ProtectionLevel = DontSaveSensitive** cho project và mọi package:
  - Chuột phải project → Properties → Protection Level.
  - Mặc định EncryptSensitiveWithUserKey làm package báo lỗi mật khẩu trên máy người khác.
- Connection Manager dùng Server name = `localhost` (hoặc `.`) và Windows Authentication, để chạy được trên mọi máy mà không cần sửa.
- Đường dẫn file đi qua project parameter `TransfersCsvPath`, không ghi cứng trong package.
- **Không commit** thư mục `bin/`, `obj/`, `.vs/` (đã có trong `.gitignore`).
