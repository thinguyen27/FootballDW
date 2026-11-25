/* =====================================================================
   etl_source_queries.sql
   Main_ETL_Master.dtsx xu ly ETL chu yeu bang component SSIS:
     OLE DB Source chi SELECT CAST(cot AS NVARCHAR(n)) cac cot da chon tu stg_raw
     (bat buoc vi NVARCHAR(MAX) duoc SSIS doc thanh DT_NTEXT, khong dung duoc ham chuoi);
     lam sach, ep kieu, khu trung, chuan hoa, kiem tra, cua so nap, Lookup ... deu la component SSIS.
   File nay chi giu cac cau SQL con lai:
     [S_VAL]   nguon FactPlayerValuation: value_change_eur can LAG (SSIS khong co LAG)
     [PREPARE] Execute SQL dau Container 03
   ===================================================================== */
USE football_dwh_staging;
GO

/* ---------------------------------------------------------------------
   [S_VAL] DF - Load FactPlayerValuation -> SRC - stg Player Valuations
   Ngoai le duy nhat dung SQL: tinh value_change_eur bang LAG theo player_id, sap theo ngay.
   Cac cot khac van tra ve dang chuoi de SSIS lam sach / ep kieu.
   --------------------------------------------------------------------- */
WITH v AS (
    SELECT CAST(player_id AS NVARCHAR(20))                            AS player_id,
           CAST([date] AS NVARCHAR(30))                               AS valuation_date_raw,
           CAST(market_value_in_eur AS NVARCHAR(30))                  AS market_value,
           CAST(current_club_id AS NVARCHAR(20))                      AS current_club_id,
           CAST(player_club_domestic_competition_id AS NVARCHAR(20))  AS competition_id,
           CAST(batch_id AS NVARCHAR(30))                             AS batch_id,
           TRY_CAST(LEFT(CAST([date] AS NVARCHAR(30)), 10) AS DATE)   AS d,
           TRY_CAST(CAST(market_value_in_eur AS NVARCHAR(30)) AS BIGINT) AS mv
    FROM dbo.stg_raw_player_valuations
)
SELECT player_id, valuation_date_raw, market_value, current_club_id, competition_id, batch_id,
       CAST(mv - LAG(mv) OVER (PARTITION BY player_id ORDER BY d) AS BIGINT) AS value_change_eur
FROM v;
GO

USE football_dwh_dw;
GO

/* ---------------------------------------------------------------------
   [PREPARE] Container 03 -> SQL - Set Load Window (phan sau lenh UPDATE etl_load_window
   duoc package sinh tu bien LoadFrom/LoadTo): xoa reject cu cua fact trong staging.
   (Khong UPDATE bang nao trong kho: is_future_date duoc tinh 1 lan khi sinh Dim_Date.)
   --------------------------------------------------------------------- */
DELETE FROM football_dwh_staging.dbo.etl_reject
WHERE source_table IN (N'stg_raw_club_games', N'stg_raw_appearances', N'stg_raw_player_valuations', N'stg_raw_transfers');
GO
