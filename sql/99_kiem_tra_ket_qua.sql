-- Kiểm tra kết quả sau mỗi lần chạy package Main_ETL_Master
-- Chạy trong SSMS (F5). Các cột tên "..._loi" / "..._sai" mong đợi = 0.
USE football_dwh_dw;
GO

-- 1. Số dòng các bảng (so với lần chạy trước để thấy nạp gia tăng)
SELECT 'dim_competition' AS bang, COUNT(*) AS so_dong FROM dbo.dim_competition
UNION ALL SELECT 'dim_club', COUNT(*) FROM dbo.dim_club
UNION ALL SELECT 'dim_player', COUNT(*) FROM dbo.dim_player
UNION ALL SELECT 'dim_match', COUNT(*) FROM dbo.dim_match
UNION ALL SELECT 'dim_manager', COUNT(*) FROM dbo.dim_manager
UNION ALL SELECT 'fact_team_match', COUNT(*) FROM dbo.fact_team_match
UNION ALL SELECT 'fact_player_appearance', COUNT(*) FROM dbo.fact_player_appearance
UNION ALL SELECT 'fact_player_valuation', COUNT(*) FROM dbo.fact_player_valuation
UNION ALL SELECT 'fact_transfer', COUNT(*) FROM dbo.fact_transfer;

-- 2. Cửa sổ vừa nạp và ngày lớn nhất trong từng fact (không được vượt window_to)
SELECT w.window_from, w.window_to,
       (SELECT MAX(date_key) FROM dbo.fact_team_match)        AS max_ngay_team_match,
       (SELECT MAX(date_key) FROM dbo.fact_player_appearance) AS max_ngay_appearance,
       (SELECT MAX(date_key) FROM dbo.fact_player_valuation)  AS max_ngay_valuation,
       (SELECT MAX(date_key) FROM dbo.fact_transfer)          AS max_ngay_transfer
FROM dbo.etl_load_window w;

-- 2b. Nhật ký các lần chạy: mỗi lần 1 dòng; lần chạy lại toàn bộ có so_dong_them = 0
SELECT run_id, batch_id, window_from, window_to, started_at, finished_at, status,
       fact_rows_before, fact_rows_after, fact_rows_after - fact_rows_before AS so_dong_them
FROM dbo.etl_batch
ORDER BY run_id;

-- 2c. Số dòng fact theo từng lần chạy (batch_id)
SELECT batch_id,
       SUM(CASE WHEN f = 'team_match' THEN n ELSE 0 END) AS team_match,
       SUM(CASE WHEN f = 'appearance' THEN n ELSE 0 END) AS appearance,
       SUM(CASE WHEN f = 'valuation'  THEN n ELSE 0 END) AS valuation,
       SUM(CASE WHEN f = 'transfer'   THEN n ELSE 0 END) AS transfer
FROM (SELECT 'team_match' f, batch_id, COUNT(*) n FROM dbo.fact_team_match GROUP BY batch_id
      UNION ALL SELECT 'appearance', batch_id, COUNT(*) FROM dbo.fact_player_appearance GROUP BY batch_id
      UNION ALL SELECT 'valuation',  batch_id, COUNT(*) FROM dbo.fact_player_valuation GROUP BY batch_id
      UNION ALL SELECT 'transfer',   batch_id, COUNT(*) FROM dbo.fact_transfer GROUP BY batch_id) x
GROUP BY batch_id
ORDER BY batch_id;

-- 3. Dòng lỗi bị đẩy vào etl_reject
SELECT source_table, reason, COUNT(*) AS so_dong
FROM football_dwh_staging.dbo.etl_reject
GROUP BY source_table, reason
ORDER BY source_table;

-- 4. Toàn vẹn dữ liệu
SELECT
    (SELECT COUNT(*) FROM (SELECT match_key FROM dbo.fact_team_match
                           GROUP BY match_key HAVING COUNT(*) <> 2) x)               AS tran_khong_du_2_dong_loi,
    (SELECT COUNT(*) FROM (SELECT appearance_id FROM dbo.fact_player_appearance
                           GROUP BY appearance_id HAVING COUNT(*) > 1) x)            AS appearance_trung_loi,
    (SELECT COUNT(*) FROM (SELECT player_key, date_key FROM dbo.fact_player_valuation
                           GROUP BY player_key, date_key HAVING COUNT(*) > 1) x)     AS valuation_trung_loi,
    (SELECT COUNT(*) FROM (SELECT player_key, date_key, from_club_key, to_club_key FROM dbo.fact_transfer
                           GROUP BY player_key, date_key, from_club_key, to_club_key
                           HAVING COUNT(*) > 1) x)                                   AS transfer_trung_rat_it,
    (SELECT COUNT(*) FROM (SELECT club_id FROM dbo.dim_club WHERE is_current = 1
                           GROUP BY club_id HAVING COUNT(*) > 1) x)                  AS club_nhieu_ban_hien_tai_loi,
    (SELECT COUNT(*) FROM (SELECT player_id FROM dbo.dim_player WHERE is_current = 1
                           GROUP BY player_id HAVING COUNT(*) > 1) x)                AS player_nhieu_ban_hien_tai_loi;

-- 5. Các cột tính trong ETL có đúng công thức không
SELECT
    SUM(CASE WHEN points <> CASE WHEN goals_for > goals_against THEN 3
                                 WHEN goals_for = goals_against THEN 1 ELSE 0 END THEN 1 ELSE 0 END) AS points_sai,
    SUM(CASE WHEN goal_difference <> goals_for - goals_against THEN 1 ELSE 0 END)                    AS goal_difference_sai,
    SUM(CASE WHEN is_win + is_draw + is_loss <> 1 THEN 1 ELSE 0 END)                                AS co_ket_qua_sai,
    SUM(CASE WHEN is_clean_sheet <> CASE WHEN goals_against = 0 THEN 1 ELSE 0 END THEN 1 ELSE 0 END) AS clean_sheet_sai
FROM dbo.fact_team_match;

-- 6. Miền giá trị tuổi (4–45 cho chuyển nhượng, >= 14 cho định giá)
SELECT
    (SELECT COUNT(*) FROM dbo.fact_player_valuation WHERE age_at_valuation < 14)              AS dinh_gia_duoi_14_loi,
    (SELECT COUNT(*) FROM dbo.fact_transfer WHERE age_at_transfer NOT BETWEEN 4 AND 45)       AS ck_ngoai_mien_tuoi_loi,
    (SELECT COUNT(*) FROM dbo.fact_transfer
      WHERE is_youth_transfer <> CASE WHEN age_at_transfer < 18 THEN 1 ELSE 0 END)            AS co_youth_sai,
    (SELECT COUNT(*) FROM dbo.fact_transfer
      WHERE (is_youth_transfer IS NULL AND age_at_transfer IS NOT NULL)
         OR (is_youth_transfer IS NOT NULL AND age_at_transfer IS NULL))                      AS youth_null_lech_loi;

-- 7. Thị trường đội trẻ và chuyên nghiệp (minh họa is_youth_transfer)
SELECT CASE is_youth_transfer WHEN 1 THEN N'Đội trẻ (<18)' WHEN 0 THEN N'Chuyên nghiệp' ELSE N'Không rõ tuổi' END AS nhom,
       COUNT(*)                 AS so_thuong_vu,
       AVG(age_at_transfer * 1.0) AS tuoi_tb,
       AVG(transfer_fee_eur)    AS phi_tb_eur
FROM dbo.fact_transfer
GROUP BY is_youth_transfer;

-- 8. Kiểm tra nghiệp vụ: BXH Premier League 2024/25 (mong đợi Liverpool 84 điểm, +45, 38 trận)
SELECT TOP 5 c.club_name,
       COUNT(*)               AS so_tran,
       SUM(f.points)          AS diem,
       SUM(f.goal_difference) AS hieu_so,
       SUM(f.is_win)          AS thang
FROM dbo.fact_team_match f
JOIN dbo.dim_club c        ON c.club_key = f.club_key
JOIN dbo.dim_competition k ON k.competition_key = f.competition_key
JOIN dbo.dim_season s      ON s.season_key = f.season_key
WHERE k.competition_id = 'GB1' AND s.season_label = '2024/25'
GROUP BY c.club_name
ORDER BY diem DESC, hieu_so DESC;

-- 9. Kiểm tra nghiệp vụ: Vua phá lưới Premier League 2024/25 (mong đợi Salah 29)
SELECT TOP 5 p.full_name,
       SUM(a.goals)          AS ban_thang,
       SUM(a.minutes_played) AS so_phut,
       CAST(SUM(a.goals) * 90.0 / NULLIF(SUM(a.minutes_played), 0) AS DECIMAL(4,2)) AS ban_moi_90_phut
FROM dbo.fact_player_appearance a
JOIN dbo.dim_player p      ON p.player_key = a.player_key
JOIN dbo.dim_competition k ON k.competition_key = a.competition_key
JOIN dbo.dim_season s      ON s.season_key = a.season_key
WHERE k.competition_id = 'GB1' AND s.season_label = '2024/25'
GROUP BY p.full_name
ORDER BY ban_thang DESC;
