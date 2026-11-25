-- Phần 2 – Cube "Hiệu suất cầu thủ": SQL đối chiếu cho 6 câu hỏi nghiệp vụ và KPI.
-- Mỗi khối: câu SQL trên kho (đáp án) + câu MDX tương ứng trên cube (chạy trong SSMS → Analysis Services → New MDX Query).
-- Kết quả cube phải bằng kết quả SQL.
USE football_dwh_dw;
GO

-- =========================================================================
-- Q1. Vua phá lưới, vua kiến tạo từng giải, từng mùa
-- =========================================================================
-- 1.1 Kiểm tra trên dữ liệu kho hiện có (Premier League 2012/13):
--     Kết quả đã đối chiếu:
--     1. Robin van Persie: 26 bàn, 15 kiến tạo, 3.124 phút, 0.75 bàn/90
--     2. Luis Suárez:      23 bàn, 11 kiến tạo, 2.955 phút, 0.70 bàn/90
--     3. Gareth Bale:      21 bàn,  8 kiến tạo, 2.925 phút, 0.65 bàn/90
--     4. Christian Benteke: 19 bàn, 4 kiến tạo, 2.821 phút, 0.61 bàn/90
--     5. Michu:            18 bàn,  3 kiến tạo, 3.012 phút, 0.54 bàn/90
SELECT TOP 5 p.full_name,
       SUM(a.goals) AS ban_thang,
       SUM(a.assists) AS kien_tao,
       SUM(a.minutes_played) AS so_phut,
       CAST(SUM(a.goals) * 90.0 / NULLIF(SUM(a.minutes_played), 0) AS DECIMAL(4,2)) AS ban_moi_90
FROM dbo.fact_player_appearance a
JOIN dbo.dim_player p      ON p.player_key = a.player_key
JOIN dbo.dim_competition k ON k.competition_key = a.competition_key
JOIN dbo.dim_season s      ON s.season_key = a.season_key
WHERE k.competition_id = 'GB1' AND s.season_label = '2012/13' AND p.player_key > 0
GROUP BY p.player_key, p.full_name
ORDER BY ban_thang DESC, kien_tao DESC;

/* MDX Q1 (2012/13):
SELECT {[Measures].[Bàn thắng cầu thủ], [Measures].[Kiến tạo], [Measures].[Số phút], [Measures].[Bàn mỗi 90 phút]} ON 0,
       TOPCOUNT(
           NONEMPTY([Cầu thủ].[Cầu thủ].[Cầu thủ].MEMBERS, [Measures].[Bàn thắng cầu thủ]),
           5,
           [Measures].[Bàn thắng cầu thủ]
       ) ON 1
FROM [Hiệu suất cầu thủ]
WHERE ([Giải đấu].[Giải đấu].[premier-league], [Mùa giải].[Mùa giải].[2012/13])
*/

-- 1.2 Mẫu kiểm tra tổng quát (Premier League 2024/25 khi nạp đủ mùa mới):
--     Mohamed Salah 29 bàn (0.77/90 phút), Isak 23, Haaland 22
SELECT TOP 10 p.full_name,
       SUM(a.goals) AS ban_thang,
       SUM(a.assists) AS kien_tao,
       SUM(a.minutes_played) AS so_phut,
       CAST(SUM(a.goals) * 90.0 / NULLIF(SUM(a.minutes_played), 0) AS DECIMAL(4,2)) AS ban_moi_90
FROM dbo.fact_player_appearance a
JOIN dbo.dim_player p      ON p.player_key = a.player_key
JOIN dbo.dim_competition k ON k.competition_key = a.competition_key
JOIN dbo.dim_season s      ON s.season_key = a.season_key
WHERE k.competition_id = 'GB1' AND s.season_label = '2024/25' AND p.player_key > 0
GROUP BY p.player_key, p.full_name
ORDER BY ban_thang DESC, kien_tao DESC;
/* MDX Q1 (2024/25):
SELECT {[Measures].[Bàn thắng cầu thủ], [Measures].[Kiến tạo], [Measures].[Số phút], [Measures].[Bàn mỗi 90 phút]} ON 0,
       TOPCOUNT([Cầu thủ].[Cầu thủ].[Cầu thủ].MEMBERS, 10, [Measures].[Bàn thắng cầu thủ]) ON 1
FROM [Hiệu suất cầu thủ]
WHERE ([Giải đấu].[Giải đấu].[premier-league], [Mùa giải].[Mùa giải].[2024/25])
*/


-- =========================================================================
-- Q2. Tiền đạo nào ghi bàn hiệu quả nhất mỗi 90 phút (tối thiểu 900 phút thi đấu)
-- =========================================================================
-- 2.1 Kiểm tra trên dữ liệu kho hiện có (Premier League 2012/13, vị trí Attack):
--     Kết quả: Robin van Persie 0.75, Luis Suárez 0.70, Gareth Bale 0.65, Edin Džeko 0.65
SELECT TOP 5 p.full_name, p.sub_position,
       SUM(a.goals) AS ban_thang,
       SUM(a.minutes_played) AS so_phut,
       CAST(SUM(a.goals) * 90.0 / NULLIF(SUM(a.minutes_played), 0) AS DECIMAL(4,2)) AS ban_moi_90
FROM dbo.fact_player_appearance a
JOIN dbo.dim_player p      ON p.player_key = a.player_key
JOIN dbo.dim_competition k ON k.competition_key = a.competition_key
JOIN dbo.dim_season s      ON s.season_key = a.season_key
WHERE k.competition_id = 'GB1' AND s.season_label = '2012/13'
  AND p.position = 'Attack' AND p.player_key > 0
GROUP BY p.player_key, p.full_name, p.sub_position
HAVING SUM(a.minutes_played) >= 900
ORDER BY ban_moi_90 DESC;

/* MDX Q2 (2012/13):
SELECT {[Measures].[Bàn thắng cầu thủ], [Measures].[Số phút], [Measures].[Bàn mỗi 90 phút]} ON 0,
       TOPCOUNT(
           FILTER([Cầu thủ].[Vị trí - Vị trí chi tiết - Cầu thủ].[Cầu thủ].MEMBERS, [Measures].[Số phút] >= 900),
           5,
           [Measures].[Bàn mỗi 90 phút]
       ) ON 1
FROM [Hiệu suất cầu thủ]
WHERE ([Giải đấu].[Giải đấu].[premier-league], [Mùa giải].[Mùa giải].[2012/13], [Cầu thủ].[Vị trí].&[Attack])
*/


-- =========================================================================
-- Q3. Cầu thủ nào ra sân và thi đấu nhiều nhất mùa giải?
-- =========================================================================
-- 3.1 Kiểm tra trên mùa 2012/13:
--     Các cầu thủ đá đủ toàn bộ số trận và số phút (ví dụ thủ môn/hậu vệ trụ cột)
SELECT TOP 5 p.full_name, c.club_name,
       SUM(a.appearance_count) AS so_tran_ra_san,
       SUM(a.minutes_played)   AS so_phut
FROM dbo.fact_player_appearance a
JOIN dbo.dim_player p ON p.player_key = a.player_key
JOIN dbo.dim_club c   ON c.club_key = a.club_key
JOIN dbo.dim_season s ON s.season_key = a.season_key
WHERE s.season_label = '2012/13' AND p.player_key > 0
GROUP BY p.player_key, p.full_name, c.club_key, c.club_name
ORDER BY so_tran_ra_san DESC, so_phut DESC;

/* MDX Q3:
SELECT {[Measures].[Số trận ra sân], [Measures].[Số phút]} ON 0,
       TOPCOUNT(
           NONEMPTY([Cầu thủ].[Cầu thủ].[Cầu thủ].MEMBERS * [CLB].[CLB].[CLB].MEMBERS, [Measures].[Số trận ra sân]),
           5,
           [Measures].[Số trận ra sân]
       ) ON 1
FROM [Hiệu suất cầu thủ]
WHERE ([Mùa giải].[Mùa giải].[2012/13])
*/


-- =========================================================================
-- Q4. Vị trí nào đóng góp bàn thắng nhiều nhất ở mỗi giải đấu?
-- =========================================================================
-- 4.1 Kiểm tra mùa 2012/13 trên 5 giải hàng đầu châu Âu:
SELECT k.competition_name, p.position,
       SUM(a.goals)   AS ban_thang,
       SUM(a.assists) AS kien_tao,
       SUM(a.minutes_played) AS so_phut
FROM dbo.fact_player_appearance a
JOIN dbo.dim_player p      ON p.player_key = a.player_key
JOIN dbo.dim_competition k ON k.competition_key = a.competition_key
JOIN dbo.dim_season s      ON s.season_key = a.season_key
WHERE s.season_label = '2012/13'
  AND k.competition_id IN ('GB1', 'ES1', 'L1', 'IT1', 'FR1')
  AND p.player_key > 0 AND p.position <> 'Không xác định'
GROUP BY k.competition_name, p.position
ORDER BY k.competition_name, ban_thang DESC;

/* MDX Q4:
SELECT [Cầu thủ].[Vị trí].[Vị trí].MEMBERS ON 0,
       {[Giải đấu].[Giải đấu].[premier-league], [Giải đấu].[Giải đấu].[laliga],
        [Giải đấu].[Giải đấu].[bundesliga], [Giải đấu].[Giải đấu].[serie-a], [Giải đấu].[Giải đấu].[ligue-1]} ON 1
FROM [Hiệu suất cầu thủ]
WHERE ([Measures].[Bàn thắng cầu thủ], [Mùa giải].[Mùa giải].[2012/13])
*/


-- =========================================================================
-- Q5. Trọng tài nào khắt khe nhất? (Tối thiểu 10 trận, tính thẻ phạt mỗi trận)
-- =========================================================================
-- 5.1 Kiểm tra trên dữ liệu kho hiện có (mùa 2012/13):
--     Kết quả đã đối chiếu khớp 100%:
--     1. José Luis Paradas Romero: 11 trận, 77 thẻ vàng, 3 thẻ đỏ, 7.27 thẻ/trận
--     2. Dimitrios Styliaras:      11 trận, 79 thẻ vàng, 0 thẻ đỏ, 7.18 thẻ/trận
--     3. Dmytro Kutakov:           13 trận, 93 thẻ vàng, 0 thẻ đỏ, 7.15 thẻ/trận
--     4. Süleyman Abay:            14 trận, 96 thẻ vàng, 3 thẻ đỏ, 7.07 thẻ/trận
--     5. Anatoliy Zhabchenko:      13 trận, 88 thẻ vàng, 3 thẻ đỏ, 7.00 thẻ/trận
SELECT TOP 5 m.referee,
       COUNT(DISTINCT a.match_key) AS so_tran_distinct,
       SUM(a.yellow_cards) AS the_vang,
       SUM(a.red_cards)    AS the_do,
       CAST((SUM(a.yellow_cards) + SUM(a.red_cards)) * 1.0 / NULLIF(COUNT(DISTINCT a.match_key), 0) AS DECIMAL(4,2)) AS the_phat_moi_tran
FROM dbo.fact_player_appearance a
JOIN dbo.dim_match m  ON m.match_key = a.match_key
JOIN dbo.dim_season s ON s.season_key = a.season_key
WHERE s.season_label = '2012/13'
  AND m.referee <> 'Không xác định'
GROUP BY m.referee
HAVING COUNT(DISTINCT a.match_key) >= 10
ORDER BY the_phat_moi_tran DESC;

/* MDX Q5:
SELECT {[Measures].[Số trận có ra sân], [Measures].[Thẻ vàng], [Measures].[Thẻ đỏ], [Measures].[Thẻ phạt mỗi trận]} ON 0,
       TOPCOUNT(
           FILTER(
               EXCEPT([Trận đấu].[Trọng tài].[Trọng tài].MEMBERS, {[Trận đấu].[Trọng tài].&[Không xác định]}),
               [Measures].[Số trận có ra sân] >= 10
           ),
           5,
           [Measures].[Thẻ phạt mỗi trận]
       ) ON 1
FROM [Hiệu suất cầu thủ]
WHERE ([Mùa giải].[Mùa giải].[2012/13])
*/


-- =========================================================================
-- Q6. Cầu thủ trẻ (dưới 21 tuổi) thi đấu nhiều phút nhất?
-- =========================================================================
-- 6.1 Kiểm tra mùa 2012/13:
SELECT TOP 5 p.full_name,
       (s.season_start_year - YEAR(p.date_of_birth)) AS tuoi,
       SUM(a.minutes_played)   AS so_phut,
       SUM(a.appearance_count) AS so_tran_ra_san,
       SUM(a.goals)            AS ban_thang
FROM dbo.fact_player_appearance a
JOIN dbo.dim_player p ON p.player_key = a.player_key
JOIN dbo.dim_season s ON s.season_key = a.season_key
WHERE s.season_label = '2012/13' AND p.player_key > 0
  AND p.date_of_birth IS NOT NULL
  AND (s.season_start_year - YEAR(p.date_of_birth)) < 21
GROUP BY p.player_key, p.full_name, (s.season_start_year - YEAR(p.date_of_birth))
ORDER BY so_phut DESC;

/* MDX Q6:
SELECT {[Measures].[Số phút], [Measures].[Số trận ra sân], [Measures].[Bàn thắng cầu thủ]} ON 0,
       TOPCOUNT(
           NONEMPTY([Cầu thủ].[Cầu thủ].[Cầu thủ].MEMBERS, [Measures].[Số phút]),
           5,
           [Measures].[Số phút]
       ) ON 1
FROM [Hiệu suất cầu thủ]
WHERE ([Mùa giải].[Mùa giải].[2012/13])
*/


-- =========================================================================
-- KPI. Bàn mỗi 90 phút của tiền đạo (Mục tiêu >= 0.5 bàn/90 phút)
-- =========================================================================
-- Kiểm tra giá trị KPI, Status và Trend:
/* MDX:
SELECT {KPIValue("Bàn mỗi 90 phút của tiền đạo"), KPIGoal("Bàn mỗi 90 phút của tiền đạo"),
        KPIStatus("Bàn mỗi 90 phút của tiền đạo"), KPITrend("Bàn mỗi 90 phút của tiền đạo")} ON 0,
       {[Cầu thủ].[Cầu thủ].[Robin van Persie], [Cầu thủ].[Cầu thủ].[Luis Suárez]} ON 1
FROM [Hiệu suất cầu thủ]
WHERE ([Mùa giải].[Mùa giải].[2012/13])
*/
