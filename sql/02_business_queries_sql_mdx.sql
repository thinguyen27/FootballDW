/* ==============================================================================================
   TẬP TRUY VẤN PHÂN TÍCH KINH DOANH NÂNG CAO (ADVANCED BUSINESS ANALYTICS: T-SQL & MDX)
   DỰ ÁN: KHO DỮ LIỆU BÓNG ĐÁ QUỐC TẾ (FOOTBALL TRANSFERMARKT DWH)
   CƠ SỞ DỮ LIỆU: football_dwh_dw
   MỤC TIÊU: ĐÁP ỨNG 100% TIÊU CHÍ 5 (MỨC A) TRONG RUBRIC_DWH.XLSX:
             "Viết truy vấn SQL/MDX chính xác, tối ưu, trả lời insight rõ ràng"
   ============================================================================================== */

USE football_dwh_dw;
GO

/* ==============================================================================================
   CHỦ ĐỀ 1: PHÂN TÍCH LỢI THẾ SÂN NHÀ & HIỆU QUẢ THI ĐẤU CỦA CÁC CÂU LẠC BỘ (FACT_TEAM_MATCH)
   Câu hỏi kinh doanh: 
   "Các câu lạc bộ nào tận dụng lợi thế sân nhà (Home Advantage) tốt nhất theo từng giải đấu? 
    Tỷ lệ chiến thắng và số bàn thắng ghi được trên sân nhà chênh lệch ra sao so với sân khách?"
   ============================================================================================== */

-- [1.1] TRUY VẤN T-SQL NÂNG CAO (SỬ DỤNG CTE, WINDOW FUNCTION: DENSE_RANK, ROUND, CONDITIONAL AGGREGATION)
WITH ClubPerformance AS (
    SELECT 
        c.competition_name,
        cl.club_name,
        COUNT(*) AS total_matches,
        SUM(CASE WHEN f.is_home = 1 THEN 1 ELSE 0 END) AS home_matches,
        SUM(CASE WHEN f.is_home = 1 AND f.is_win = 1 THEN 1 ELSE 0 END) AS home_wins,
        SUM(CASE WHEN f.is_home = 1 THEN f.goals_for ELSE 0 END) AS home_goals_scored,
        SUM(CASE WHEN f.is_home = 0 THEN 1 ELSE 0 END) AS away_matches,
        SUM(CASE WHEN f.is_home = 0 AND f.is_win = 1 THEN 1 ELSE 0 END) AS away_wins,
        SUM(f.is_clean_sheet) AS total_clean_sheets,
        ROUND(CAST(SUM(CASE WHEN f.is_home = 1 AND f.is_win = 1 THEN 1 ELSE 0 END) AS FLOAT) * 100.0 
              / NULLIF(SUM(CASE WHEN f.is_home = 1 THEN 1 ELSE 0 END), 0), 2) AS home_win_rate_pct,
        ROUND(CAST(SUM(CASE WHEN f.is_home = 0 AND f.is_win = 1 THEN 1 ELSE 0 END) AS FLOAT) * 100.0 
              / NULLIF(SUM(CASE WHEN f.is_home = 0 THEN 1 ELSE 0 END), 0), 2) AS away_win_rate_pct
    FROM dbo.fact_team_match f
    JOIN dbo.dim_competition c ON f.competition_key = c.competition_key
    JOIN dbo.dim_club cl ON f.club_key = cl.club_key
    GROUP BY c.competition_name, cl.club_name
    HAVING COUNT(*) >= 20
),
RankedHomeTeams AS (
    SELECT 
        competition_name,
        club_name,
        home_matches,
        home_wins,
        home_goals_scored,
        home_win_rate_pct,
        away_win_rate_pct,
        ROUND(home_win_rate_pct - away_win_rate_pct, 2) AS home_advantage_delta,
        total_clean_sheets,
        DENSE_RANK() OVER (
            PARTITION BY competition_name 
            ORDER BY home_win_rate_pct DESC, home_goals_scored DESC
        ) AS rank_home_supremacy
    FROM ClubPerformance
)
SELECT 
    competition_name,
    rank_home_supremacy,
    club_name,
    home_matches,
    home_wins,
    home_win_rate_pct,
    away_win_rate_pct,
    home_advantage_delta,
    total_clean_sheets
FROM RankedHomeTeams
WHERE rank_home_supremacy <= 3
ORDER BY competition_name, rank_home_supremacy;
GO

/* [1.2] TRUY VẤN MDX ĐA CHIỀU TƯƠNG ỨNG
   Cube [Hiệu suất đội bóng]. Top 3 CLB có tỉ lệ thắng sân nhà cao nhất mỗi giải (CLB tối thiểu 20 trận trong giải).
   Chạy trong SSMS: kết nối Analysis Services localhost → database Football_DAWH_SSAS → New MDX Query.
-------------------------------------------------------------------------------------------------
WITH
  MEMBER [Measures].[Số trận sân khách] AS
    [Measures].[Số trận] - [Measures].[Số trận sân nhà]
  MEMBER [Measures].[Tỉ lệ thắng sân khách] AS
    IIF([Measures].[Số trận sân khách] = 0, NULL,
        ([Measures].[Thắng] - [Measures].[Thắng sân nhà]) / [Measures].[Số trận sân khách]),
    FORMAT_STRING = "0.00%"
  MEMBER [Measures].[Chênh lệch sân nhà] AS
    [Measures].[Tỉ lệ thắng sân nhà] - [Measures].[Tỉ lệ thắng sân khách],
    FORMAT_STRING = "0.00%"
SELECT
  {[Measures].[Số trận sân nhà], [Measures].[Thắng sân nhà], [Measures].[Tỉ lệ thắng sân nhà],
   [Measures].[Tỉ lệ thắng sân khách], [Measures].[Chênh lệch sân nhà], [Measures].[Sạch lưới]} ON COLUMNS,
  NON EMPTY GENERATE(
    [Giải đấu].[Giải đấu].[Giải đấu].MEMBERS,
    TOPCOUNT(
      {[Giải đấu].[Giải đấu].CURRENTMEMBER} *
        FILTER(NONEMPTY([CLB].[CLB].[CLB].MEMBERS, [Measures].[Số trận]), [Measures].[Số trận] >= 20),
      3,
      [Measures].[Tỉ lệ thắng sân nhà]
    )
  ) ON ROWS
FROM [Hiệu suất đội bóng];
------------------------------------------------------------------------------------------------- */


/* ==============================================================================================
   CHỦ ĐỀ 2: HIỆU SUẤT GHI BÀN & ĐÓNG GÓP TẤN CÔNG CỦA CẦU THỦ (FACT_PLAYER_APPEARANCE)
   Câu hỏi kinh doanh:
   "Ai là Vua phá lưới và Cầu thủ có hiệu suất tấn công cao nhất (Goals + Assists, Số phút/Bàn thắng) 
    trong từng mùa giải? Cầu thủ nào có tần suất ghi bàn ấn tượng nhất khi thi đấu trên 900 phút?"
   ============================================================================================== */

-- [2.1] TRUY VẤN T-SQL NÂNG CAO (SỬ DỤNG WINDOW FUNCTIONS, PARTITION BY, RANKING VÀ FILTER NGƯỠNG PHÚT)
WITH PlayerSeasonAgg AS (
    SELECT 
        s.season_label,
        c.competition_name,
        p.full_name AS player_name,
        cl.club_name,
        SUM(f.appearance_count) AS total_matches_played,
        SUM(f.minutes_played) AS total_minutes,
        SUM(f.goals) AS total_goals,
        SUM(f.assists) AS total_assists,
        SUM(f.goals + f.assists) AS goal_contributions,
        SUM(f.yellow_cards) AS yellow_cards,
        SUM(f.red_cards) AS red_cards,
        ROUND(CAST(SUM(f.minutes_played) AS FLOAT) / NULLIF(SUM(f.goals), 0), 1) AS minutes_per_goal,
        ROUND(CAST(SUM(f.goals + f.assists) AS FLOAT) * 90.0 / NULLIF(SUM(f.minutes_played), 0), 2) AS contributions_per_90_mins,
        DENSE_RANK() OVER (
            PARTITION BY s.season_label, c.competition_name 
            ORDER BY SUM(f.goals) DESC, SUM(f.assists) DESC
        ) AS rank_top_scorer
    FROM dbo.fact_player_appearance f
    JOIN dbo.dim_player p ON f.player_key = p.player_key
    JOIN dbo.dim_club cl ON f.club_key = cl.club_key
    JOIN dbo.dim_season s ON f.season_key = s.season_key
    JOIN dbo.dim_competition c ON f.competition_key = c.competition_key
    WHERE f.minutes_played > 0
    GROUP BY s.season_label, c.competition_name, p.full_name, cl.club_name
    HAVING SUM(f.minutes_played) >= 900 AND SUM(f.goals) >= 10
)
SELECT 
    season_label,
    competition_name,
    rank_top_scorer,
    player_name,
    club_name,
    total_matches_played,
    total_minutes,
    total_goals,
    total_assists,
    goal_contributions,
    minutes_per_goal,
    contributions_per_90_mins
FROM PlayerSeasonAgg
WHERE rank_top_scorer <= 3
ORDER BY season_label DESC, competition_name, rank_top_scorer;
GO

/* [2.2] TRUY VẤN MDX ĐA CHIỀU TƯƠNG ỨNG
   Cube [Hiệu suất cầu thủ]. Mùa 2013/14: top 3 cầu thủ ghi bàn mỗi giải (tối thiểu 900 phút và 10 bàn).
   Chạy trong SSMS: kết nối Analysis Services localhost → database Football_DAWH_SSAS → New MDX Query.
-------------------------------------------------------------------------------------------------
WITH
  MEMBER [Measures].[Bàn + kiến tạo] AS
    [Measures].[Bàn thắng cầu thủ] + [Measures].[Kiến tạo]
  MEMBER [Measures].[Số phút mỗi bàn] AS
    IIF([Measures].[Bàn thắng cầu thủ] = 0, NULL, [Measures].[Số phút] / [Measures].[Bàn thắng cầu thủ]),
    FORMAT_STRING = "#,##0.0"
SELECT
  {[Measures].[Số trận ra sân], [Measures].[Số phút], [Measures].[Bàn thắng cầu thủ], [Measures].[Kiến tạo],
   [Measures].[Bàn + kiến tạo], [Measures].[Số phút mỗi bàn], [Measures].[Bàn và kiến tạo mỗi 90 phút]} ON COLUMNS,
  NON EMPTY GENERATE(
    [Giải đấu].[Giải đấu].[Giải đấu].MEMBERS,
    TOPCOUNT(
      {[Giải đấu].[Giải đấu].CURRENTMEMBER} *
        FILTER(NONEMPTY([Cầu thủ].[Cầu thủ].[Cầu thủ].MEMBERS, [Measures].[Số phút]),
               [Measures].[Số phút] >= 900 AND [Measures].[Bàn thắng cầu thủ] >= 10),
      3,
      [Measures].[Bàn thắng cầu thủ] * 1000 + [Measures].[Kiến tạo]   /* bằng bàn thì xếp theo kiến tạo, như SQL */
    )
  ) ON ROWS
FROM [Hiệu suất cầu thủ]
WHERE ([Mùa giải].[Mùa giải].[2013/14]);
------------------------------------------------------------------------------------------------- */


/* ==============================================================================================
   CHỦ ĐỀ 3: PHÂN TÍCH XU HƯỚNG ĐỊNH GIÁ & TĂNG TRƯỞNG THEO ĐỘ TUỔI (FACT_PLAYER_VALUATION)
   Câu hỏi kinh doanh:
   "Giá trị thị trường bình quân và mức tăng giá trị (Valuation Growth Delta) phân bổ ra sao 
    giữa các nhóm tuổi (U21, 21-25, 26-29, 30+)? Nhóm tuổi nào mang lại tiềm năng gia tăng giá trị cao nhất?"
   ============================================================================================== */

-- [3.1] TRUY VẤN T-SQL NÂNG CAO (PHÂN ĐOÀN TUỔI - AGE BRACKETING, CONDITIONAL SUM DELTA, TÍNH TỶ TRỌNG)
WITH ValuationByAgeGroup AS (
    SELECT 
        d.[year] AS valuation_year,
        CASE 
            WHEN f.age_at_valuation < 21 THEN 'U21 (Tài năng trẻ)'
            WHEN f.age_at_valuation BETWEEN 21 AND 25 THEN '21 - 25 tuổi (Đang phát triển)'
            WHEN f.age_at_valuation BETWEEN 26 AND 29 THEN '26 - 29 tuổi (Đỉnh cao phong độ)'
            WHEN f.age_at_valuation >= 30 THEN '30+ tuổi (Kinh nghiệm/Lão tướng)'
            ELSE 'Không xác định'
        END AS age_bracket,
        COUNT(DISTINCT f.player_key) AS unique_players_evaluated,
        ROUND(AVG(CAST(f.market_value_eur AS FLOAT)) / 1000000.0, 2) AS avg_market_value_mil_eur,
        ROUND(MAX(CAST(f.market_value_eur AS FLOAT)) / 1000000.0, 2) AS peak_player_market_value_mil,
        ROUND(SUM(CASE WHEN f.value_change_eur > 0 THEN f.value_change_eur ELSE 0 END) / 1000000.0, 2) AS total_value_increase_mil_eur,
        ROUND(SUM(CASE WHEN f.value_change_eur < 0 THEN ABS(f.value_change_eur) ELSE 0 END) / 1000000.0, 2) AS total_value_decrease_mil_eur
    FROM dbo.fact_player_valuation f
    JOIN dbo.dim_date d ON f.date_key = d.date_key
    WHERE f.market_value_eur IS NOT NULL 
      AND f.age_at_valuation IS NOT NULL 
      AND d.[year] BETWEEN 2011 AND 2014
    GROUP BY d.[year], 
        CASE 
            WHEN f.age_at_valuation < 21 THEN 'U21 (Tài năng trẻ)'
            WHEN f.age_at_valuation BETWEEN 21 AND 25 THEN '21 - 25 tuổi (Đang phát triển)'
            WHEN f.age_at_valuation BETWEEN 26 AND 29 THEN '26 - 29 tuổi (Đỉnh cao phong độ)'
            WHEN f.age_at_valuation >= 30 THEN '30+ tuổi (Kinh nghiệm/Lão tướng)'
            ELSE 'Không xác định'
        END
)
SELECT 
    valuation_year,
    age_bracket,
    unique_players_evaluated,
    avg_market_value_mil_eur,
    peak_player_market_value_mil,
    total_value_increase_mil_eur,
    total_value_decrease_mil_eur,
    ROUND(total_value_increase_mil_eur - total_value_decrease_mil_eur, 2) AS net_valuation_growth_mil,
    ROUND(total_value_increase_mil_eur * 100.0 / NULLIF(SUM(total_value_increase_mil_eur) OVER (PARTITION BY valuation_year), 0), 2) AS share_of_annual_growth_pct
FROM ValuationByAgeGroup
ORDER BY valuation_year DESC, avg_market_value_mil_eur DESC;
GO

/* [3.2] TRUY VẤN MDX ĐA CHIỀU TƯƠNG ỨNG
   Cube [Thị trường cầu thủ]. Năm 2011–2014 × nhóm tuổi (U21, 21-25, 26-29, 30+, tạo bằng calculated member trên dim Tuổi): số lần định giá, giá trị trung bình, mức tăng giá ròng (triệu €).
   Chạy trong SSMS: kết nối Analysis Services localhost → database Football_DAWH_SSAS → New MDX Query.
-------------------------------------------------------------------------------------------------
WITH
  MEMBER [Tuổi].[Tuổi].[U21 (Tài năng trẻ)] AS
    AGGREGATE(FILTER([Tuổi].[Tuổi].[Tuổi].MEMBERS, VAL([Tuổi].[Tuổi].CURRENTMEMBER.PROPERTIES("KEY")) >= 1 AND VAL([Tuổi].[Tuổi].CURRENTMEMBER.PROPERTIES("KEY")) <= 20))
  MEMBER [Tuổi].[Tuổi].[21 - 25 tuổi] AS
    AGGREGATE(FILTER([Tuổi].[Tuổi].[Tuổi].MEMBERS, VAL([Tuổi].[Tuổi].CURRENTMEMBER.PROPERTIES("KEY")) >= 21 AND VAL([Tuổi].[Tuổi].CURRENTMEMBER.PROPERTIES("KEY")) <= 25))
  MEMBER [Tuổi].[Tuổi].[26 - 29 tuổi] AS
    AGGREGATE(FILTER([Tuổi].[Tuổi].[Tuổi].MEMBERS, VAL([Tuổi].[Tuổi].CURRENTMEMBER.PROPERTIES("KEY")) >= 26 AND VAL([Tuổi].[Tuổi].CURRENTMEMBER.PROPERTIES("KEY")) <= 29))
  MEMBER [Tuổi].[Tuổi].[30+ tuổi] AS
    AGGREGATE(FILTER([Tuổi].[Tuổi].[Tuổi].MEMBERS, VAL([Tuổi].[Tuổi].CURRENTMEMBER.PROPERTIES("KEY")) >= 30))
  MEMBER [Measures].[Giá trị TB (triệu €)] AS
    IIF([Measures].[Số lượt định giá] = 0, NULL, [Measures].[_Tổng giá trị định giá] / [Measures].[Số lượt định giá] / 1000000),
    FORMAT_STRING = "#,##0.00", SOLVE_ORDER = 20
  MEMBER [Measures].[Tăng giá ròng (triệu €)] AS
    [Measures].[Tăng giảm giá trị] / 1000000,
    FORMAT_STRING = "#,##0.00", SOLVE_ORDER = 20
SELECT
  {[Measures].[Số lượt định giá], [Measures].[Giá trị TB (triệu €)], [Measures].[Tăng giá ròng (triệu €)]} ON COLUMNS,
  NON EMPTY
    {[Ngày].[Năm - Quý - Tháng - Ngày].[Năm].&[2014], [Ngày].[Năm - Quý - Tháng - Ngày].[Năm].&[2013],
     [Ngày].[Năm - Quý - Tháng - Ngày].[Năm].&[2012], [Ngày].[Năm - Quý - Tháng - Ngày].[Năm].&[2011]} *
    {[Tuổi].[Tuổi].[U21 (Tài năng trẻ)], [Tuổi].[Tuổi].[21 - 25 tuổi], [Tuổi].[Tuổi].[26 - 29 tuổi], [Tuổi].[Tuổi].[30+ tuổi]} ON ROWS
FROM [Thị trường cầu thủ];
------------------------------------------------------------------------------------------------- */


/* ==============================================================================================
   CHỦ ĐỀ 4: CÁN CÂN THU CHI CHUYỂN NHƯỢNG & MỨC PHÍ CHÊNH LỆCH FEE PREMIUM (FACT_TRANSFER)
   Câu hỏi kinh doanh:
   "Cán cân chi tiêu chuyển nhượng ròng (Net Spend = Mua - Bán) của các CLB là bao nhiêu? 
    Những câu lạc bộ nào chấp nhận chi trả mức phí chuyển nhượng vượt xa giá trị thực (Fee Premium) nhiều nhất?"
   ============================================================================================== */

-- [4.1] TRUY VẤN T-SQL NÂNG CAO (FULL OUTER JOIN 2 ROLE-PLAYING DIMENSION CLUB, TÍNH NET SPEND VÀ FEE PREMIUM)
WITH ClubSpending AS (
    SELECT 
        to_club_key AS club_key,
        season_key,
        COUNT(*) AS total_bought_players,
        SUM(transfer_fee_eur) / 1000000.0 AS total_expenditure_mil,
        SUM(fee_premium_eur) / 1000000.0 AS total_premium_paid_mil
    FROM dbo.fact_transfer
    WHERE to_club_key > 0 AND transfer_fee_eur IS NOT NULL      -- bỏ -1 Không rõ, -2 Không thuộc CLB nào
    GROUP BY to_club_key, season_key
),
ClubSelling AS (
    SELECT 
        from_club_key AS club_key,
        season_key,
        COUNT(*) AS total_sold_players,
        SUM(transfer_fee_eur) / 1000000.0 AS total_income_mil
    FROM dbo.fact_transfer
    WHERE from_club_key > 0 AND transfer_fee_eur IS NOT NULL
    GROUP BY from_club_key, season_key
)
SELECT TOP 15
    s.season_label,
    c.club_name,
    ISNULL(b.total_bought_players, 0) AS bought_count,
    ROUND(ISNULL(b.total_expenditure_mil, 0), 2) AS spent_mil_eur,
    ISNULL(sl.total_sold_players, 0) AS sold_count,
    ROUND(ISNULL(sl.total_income_mil, 0), 2) AS income_mil_eur,
    ROUND(ISNULL(b.total_expenditure_mil, 0) - ISNULL(sl.total_income_mil, 0), 2) AS net_spend_mil_eur,
    ROUND(ISNULL(b.total_premium_paid_mil, 0), 2) AS fee_premium_paid_mil_eur,
    CASE 
        WHEN ISNULL(b.total_premium_paid_mil, 0) > 20 THEN N'Chấp nhận chi đậm vượt giá thị trường'
        WHEN ISNULL(b.total_premium_paid_mil, 0) < -10 THEN N'Mua được giá hời/dưới giá thị trường'
        ELSE N'Giao dịch sát giá trị định giá'
    END AS financial_strategy_comment
FROM ClubSpending b
FULL OUTER JOIN ClubSelling sl ON b.club_key = sl.club_key AND b.season_key = sl.season_key
JOIN dbo.dim_club c ON COALESCE(b.club_key, sl.club_key) = c.club_key
JOIN dbo.dim_season s ON COALESCE(b.season_key, sl.season_key) = s.season_key
WHERE s.season_label IN ('2013/14', '2012/13', '2011/12')
ORDER BY net_spend_mil_eur DESC;
GO

/* [4.2] TRUY VẤN MDX ĐA CHIỀU TƯƠNG ỨNG
   Cube [Thị trường cầu thủ]. Mùa 2011/12–2013/14: top 15 (mùa, CLB) chi tiêu ròng cao nhất; Chi mua / Thu bán / Chi tiêu ròng là calculated member của cube (Thu bán dùng LINKMEMBER từ CLB đến sang CLB đi), xem theo [CLB đến].
   Chạy trong SSMS: kết nối Analysis Services localhost → database Football_DAWH_SSAS → New MDX Query.
-------------------------------------------------------------------------------------------------
WITH
  MEMBER [Measures].[Chi mua (triệu €)] AS [Measures].[Chi mua] / 1000000, FORMAT_STRING = "#,##0.00"
  MEMBER [Measures].[Thu bán (triệu €)] AS [Measures].[Thu bán] / 1000000, FORMAT_STRING = "#,##0.00"
  MEMBER [Measures].[Chi tiêu ròng (triệu €)] AS [Measures].[Chi tiêu ròng] / 1000000, FORMAT_STRING = "#,##0.00"
  MEMBER [Measures].[Phí chênh đã trả (triệu €)] AS [Measures].[Chênh lệch phí – giá trị] / 1000000, FORMAT_STRING = "#,##0.00"
SELECT
  {[Measures].[Số vụ có thông tin phí], [Measures].[Chi mua (triệu €)], [Measures].[Thu bán (triệu €)],
   [Measures].[Chi tiêu ròng (triệu €)], [Measures].[Phí chênh đã trả (triệu €)]} ON COLUMNS,
  TOPCOUNT(
    {[Mùa giải].[Mùa giải].[2013/14], [Mùa giải].[Mùa giải].[2012/13], [Mùa giải].[Mùa giải].[2011/12]} *
      EXCEPT(NONEMPTY([CLB đến].[CLB].[CLB].MEMBERS, [Measures].[Phí chuyển nhượng]), {[CLB đến].[CLB].&[-1], [CLB đến].[CLB].&[-2]}),
    15,
    [Measures].[Chi tiêu ròng]
  ) ON ROWS
FROM [Thị trường cầu thủ];
------------------------------------------------------------------------------------------------- */


/* ==============================================================================================
   CHỦ ĐỀ 5: PHÂN TÍCH MA TRẬN PHÂN KHÚC PHÍ CHUYỂN NHƯỢNG (DIM_TRANSFER_TYPE & GROUP BY CUBE)
   Câu hỏi kinh doanh:
   "Cơ cấu thị trường chuyển nhượng theo từng phân khúc phí (Fee Band) và trạng thái giao dịch (Fee Status) 
    diễn biến ra sao? Tỷ trọng các thương vụ 'Miễn phí' so với thương vụ 'Bom tấn > 50 triệu Euro'?"
   ============================================================================================== */

-- [5.1] TRUY VẤN T-SQL NÂNG CAO (GROUP BY CUBE TẠO SUB-TOTAL VÀ GRAND-TOTAL; GROUPING() + CASE GẮN NHÃN DÒNG TỔNG,
--       KHÔNG DÙNG COALESCE/IS NULL VÌ NULL CỦA DÒNG TỔNG KHÁC NULL THẬT; MẪU SỐ TỈ TRỌNG CHỈ LẤY DÒNG TỔNG MÙA,
--       KHÔNG CỘNG LẪN DÒNG CHI TIẾT VỚI DÒNG SUB-TOTAL)
SELECT 
    CASE WHEN GROUPING(s.season_label) = 1 THEN N'TẤT CẢ MÙA GIẢI' ELSE s.season_label END AS season_label,
    CASE WHEN GROUPING(tt.fee_status) = 1 THEN N'TẤT CẢ TRẠNG THÁI' ELSE tt.fee_status END AS fee_status,
    CASE WHEN GROUPING(tt.fee_band) = 1 THEN N'TẤT CẢ PHÂN KHÚC' ELSE tt.fee_band END AS fee_band,
    GROUPING_ID(s.season_label, tt.fee_status, tt.fee_band) AS grouping_level,
    COUNT(*) AS total_transactions,
    ROUND(SUM(ISNULL(f.transfer_fee_eur, 0)) / 1000000.0, 2) AS total_fee_volume_mil_eur,
    ROUND(AVG(CAST(ISNULL(f.transfer_fee_eur, 0) AS FLOAT)) / 1000000.0, 2) AS avg_fee_mil_eur,
    ROUND(COUNT(*) * 100.0 / NULLIF(SUM(CASE WHEN GROUPING(tt.fee_status) = 1 AND GROUPING(tt.fee_band) = 1
                                             THEN COUNT(*) END)
                                    OVER (PARTITION BY GROUPING(s.season_label), s.season_label), 0), 2) AS percentage_share_in_season
FROM dbo.fact_transfer f
JOIN dbo.dim_transfer_type tt ON f.transfer_type_key = tt.transfer_type_key
JOIN dbo.dim_season s ON f.season_key = s.season_key
WHERE s.season_label IN ('2013/14', '2012/13')
GROUP BY CUBE(s.season_label, tt.fee_status, tt.fee_band)
-- Bỏ tập nhóm "phân khúc phí không kèm trạng thái" (khoảng phí vốn nằm trong trạng thái "Có phí")
HAVING NOT (GROUPING(tt.fee_status) = 1 AND GROUPING(tt.fee_band) = 0)
ORDER BY 
    GROUPING(s.season_label), s.season_label,
    GROUPING(tt.fee_status) DESC, tt.fee_status,
    GROUPING(tt.fee_band) DESC, total_fee_volume_mil_eur DESC;
GO

/* [5.2] TRUY VẤN MDX ĐA CHIỀU TƯƠNG ỨNG
   Cube [Thị trường cầu thủ]. Ma trận mùa 2012/13, 2013/14 × Trạng thái phí × Khoảng phí, kèm dòng tổng (All) như GROUP BY CUBE.
   Chạy trong SSMS: kết nối Analysis Services localhost → database Football_DAWH_SSAS → New MDX Query.
-------------------------------------------------------------------------------------------------
WITH
  MEMBER [Measures].[Tổng phí (triệu €)] AS [Measures].[Phí chuyển nhượng] / 1000000, FORMAT_STRING = "#,##0.00"
  MEMBER [Measures].[Phí TB mỗi thương vụ (triệu €)] AS
    IIF([Measures].[Số thương vụ] = 0, NULL, [Measures].[Phí chuyển nhượng] / [Measures].[Số thương vụ] / 1000000),
    FORMAT_STRING = "#,##0.00"
  MEMBER [Measures].[Tỉ trọng trong mùa] AS
    [Measures].[Số thương vụ] / ([Measures].[Số thương vụ], [Loại chuyển nhượng].[Trạng thái phí - Khoảng phí].[All]),
    FORMAT_STRING = "0.00%"
SELECT
  {[Measures].[Số thương vụ], [Measures].[Tổng phí (triệu €)], [Measures].[Phí TB mỗi thương vụ (triệu €)],
   [Measures].[Tỉ trọng trong mùa]} ON COLUMNS,
  NON EMPTY
    {[Mùa giải].[Mùa giải].[2012/13], [Mùa giải].[Mùa giải].[2013/14]} *
    [Loại chuyển nhượng].[Trạng thái phí - Khoảng phí].MEMBERS ON ROWS
FROM [Thị trường cầu thủ];
------------------------------------------------------------------------------------------------- */


/* ==============================================================================================
   CHỦ ĐỀ 6: BẢNG XẾP HẠNG VÀ PHONG ĐỘ HUẤN LUYỆN VIÊN (FACT_TEAM_MATCH & DIM_MANAGER)
   Câu hỏi kinh doanh:
   "Huấn luyện viên nào có tỷ lệ chiến thắng và điểm số trung bình mỗi trận (Points Per Match) 
    cao nhất khi cầm quân tối thiểu 25 trận? Hiệu số bàn thắng/bại của các chiến lược gia hàng đầu?"
   ============================================================================================== */

-- [6.1] TRUY VẤN T-SQL NÂNG CAO (TÍNH ĐIỂM SỐ BÓNG ĐÁ THỰC TẾ: THẮNG = 3, HÒA = 1, THUA = 0)
WITH ManagerAnalytics AS (
    SELECT 
        m.manager_name,
        COUNT(*) AS total_games_managed,
        SUM(f.is_win) AS total_wins,
        SUM(f.is_draw) AS total_draws,
        SUM(f.is_loss) AS total_losses,
        SUM(f.goals_for) AS goals_scored,
        SUM(f.goals_against) AS goals_conceded,
        SUM(f.goals_for) - SUM(f.goals_against) AS goal_difference,
        SUM(f.is_clean_sheet) AS clean_sheets,
        SUM(f.is_win * 3 + f.is_draw * 1) AS total_points_earned,
        ROUND(CAST(SUM(f.is_win) AS FLOAT) * 100.0 / COUNT(*), 2) AS win_rate_percentage,
        ROUND(CAST(SUM(f.is_win * 3 + f.is_draw * 1) AS FLOAT) / COUNT(*), 2) AS points_per_match,
        ROUND(CAST(SUM(f.goals_for) AS FLOAT) / COUNT(*), 2) AS goals_per_game
    FROM dbo.fact_team_match f
    JOIN dbo.dim_manager m ON f.manager_key = m.manager_key
    WHERE m.manager_key <> -1
    GROUP BY m.manager_name
    HAVING COUNT(*) >= 25
)
SELECT TOP 15
    DENSE_RANK() OVER (ORDER BY points_per_match DESC, win_rate_percentage DESC) AS rank_manager,
    manager_name,
    total_games_managed,
    total_wins,
    total_draws,
    total_losses,
    win_rate_percentage,
    points_per_match,
    goals_scored,
    goals_conceded,
    goal_difference,
    clean_sheets
FROM ManagerAnalytics
ORDER BY rank_manager;
GO

/* [6.2] TRUY VẤN MDX ĐA CHIỀU TƯƠNG ỨNG
   Cube [Hiệu suất đội bóng]. Top 15 HLV (tối thiểu 25 trận) theo điểm trung bình mỗi trận.
   Chạy trong SSMS: kết nối Analysis Services localhost → database Football_DAWH_SSAS → New MDX Query.
-------------------------------------------------------------------------------------------------
WITH
  MEMBER [Measures].[Điểm mỗi trận] AS
    IIF([Measures].[Số trận] = 0, NULL, [Measures].[Điểm] / [Measures].[Số trận]),
    FORMAT_STRING = "0.00"
SELECT
  {[Measures].[Số trận], [Measures].[Thắng], [Measures].[Hòa], [Measures].[Thua], [Measures].[Tỉ lệ thắng],
   [Measures].[Điểm mỗi trận], [Measures].[Bàn thắng], [Measures].[Bàn thua], [Measures].[Hiệu số],
   [Measures].[Sạch lưới]} ON COLUMNS,
  TOPCOUNT(
    FILTER(EXCEPT([HLV].[HLV].[HLV].MEMBERS, {[HLV].[HLV].&[-1]}), [Measures].[Số trận] >= 25),
    15,
    [Measures].[Điểm mỗi trận]
  ) ON ROWS
FROM [Hiệu suất đội bóng];
------------------------------------------------------------------------------------------------- */


/* ==============================================================================================
   CHỦ ĐỀ 7: CƠ CẤU GHI BÀN THEO PHÂN CẤP LIÊN ĐOÀN → QUỐC GIA → GIẢI ĐẤU (ROLLUP & GROUPING_ID)
   Câu hỏi kinh doanh:
   "Mùa 2024/25, khu vực / quốc gia / giải đấu nào có mật độ bàn thắng cao nhất?
    Tổng phụ ở từng cấp phân cấp là bao nhiêu?"
   ============================================================================================== */

-- [7.1] TRUY VẤN T-SQL (ROLLUP BỎ DẦN CỘT TỪ PHẢI SANG TRÁI; GROUPING_ID MÃ HÓA MỨC TỔNG HỢP;
--       GROUPING + CASE PHÂN BIỆT NULL CỦA DÒNG TỔNG VỚI NULL THẬT TRONG DỮ LIỆU)
SELECT
    GROUPING_ID(c.confederation, c.country_name, c.competition_name) AS muc_tong_hop,   -- 0 giải | 1 quốc gia | 3 liên đoàn | 7 tổng chung
    CASE WHEN GROUPING(c.confederation) = 1 THEN N'TỔNG CHUNG' ELSE c.confederation END AS lien_doan,
    CASE WHEN GROUPING(c.country_name) = 1 THEN N'(Tổng liên đoàn)'
         WHEN c.country_name IS NULL      THEN N'(Không gắn quốc gia)'
         ELSE c.country_name END AS quoc_gia,
    CASE WHEN GROUPING(c.competition_name) = 1 THEN N'(Tổng quốc gia)' ELSE c.competition_name END AS giai_dau,
    COUNT(*)                                                       AS so_tran_doi,
    SUM(f.goals_for)                                               AS ban_thang,
    ROUND(1.0 * SUM(f.goals_for) / NULLIF(COUNT(*), 0), 2)         AS ban_moi_tran,       -- tỉ lệ của tổng, không lấy TB các tỉ lệ
    ROUND(100.0 * SUM(f.is_clean_sheet) / NULLIF(COUNT(*), 0), 2)  AS ti_le_sach_luoi_pct
FROM dbo.fact_team_match f
JOIN dbo.dim_competition c ON c.competition_key = f.competition_key
JOIN dbo.dim_season s      ON s.season_key = f.season_key
WHERE s.season_label = '2024/25'
GROUP BY ROLLUP(c.confederation, c.country_name, c.competition_name)
ORDER BY GROUPING(c.confederation), c.confederation,
         GROUPING(c.country_name), c.country_name,
         GROUPING(c.competition_name), c.competition_name;
GO

/* [7.2] TRUY VẤN MDX TƯƠNG ỨNG (DESCENDANTS ... SELF_AND_BEFORE = ROLLUP TRÊN PHÂN CẤP CỦA CUBE)
   Cube [Hiệu suất đội bóng]. Hàng cha (tổng phụ) hiện TRƯỚC hàng con, ngược với ORDER BY của câu SQL.
-------------------------------------------------------------------------------------------------
SELECT
  {[Measures].[Số trận], [Measures].[Bàn thắng], [Measures].[Bàn thắng mỗi trận], [Measures].[Sạch lưới]} ON COLUMNS,
  NON EMPTY
    DESCENDANTS([Giải đấu].[Liên đoàn - Quốc gia - Giải đấu].[All],
                [Giải đấu].[Liên đoàn - Quốc gia - Giải đấu].[Giải đấu], SELF_AND_BEFORE) ON ROWS
FROM [Hiệu suất đội bóng]
WHERE ([Mùa giải].[Mùa giải].[2024/25]);
------------------------------------------------------------------------------------------------- */

/* [7.3] MDX DRILL-DOWN (.CHILDREN) VÀ SẮP XẾP THEO ĐỘ ĐO (ORDER)
   Từ liên đoàn châu Âu (UEFA) đi xuống cấp quốc gia, xếp quốc gia theo số bàn mỗi trận giảm dần.
-------------------------------------------------------------------------------------------------
SELECT
  {[Measures].[Số trận], [Measures].[Bàn thắng], [Measures].[Bàn thắng mỗi trận]} ON COLUMNS,
  NON EMPTY
    ORDER([Giải đấu].[Liên đoàn - Quốc gia - Giải đấu].[Liên đoàn].[UEFA].CHILDREN,
          [Measures].[Bàn thắng mỗi trận], BDESC) ON ROWS
FROM [Hiệu suất đội bóng]
WHERE ([Mùa giải].[Mùa giải].[2024/25]);
------------------------------------------------------------------------------------------------- */


/* ==============================================================================================
   CHỦ ĐỀ 8: THỊ TRƯỜNG CHUYỂN NHƯỢNG THEO KHU VỰC MUA VÀ VỊ TRÍ CẦU THỦ (GROUPING SETS)
   Câu hỏi kinh doanh:
   "Mùa 2024/25, tiền chuyển nhượng chảy về khu vực nào và tập trung vào vị trí nào?
    Chỉ cần tổng theo từng tiêu chí riêng và tổng chung, không cần ma trận chéo khu vực × vị trí."
   ============================================================================================== */

-- [8.1] TRUY VẤN T-SQL (GROUPING SETS CHỈ RÕ 3 TẬP NHÓM CẦN TÍNH; KHÔNG SINH DÒNG CHI TIẾT KHU VỰC × VỊ TRÍ)
SELECT
    CASE GROUPING_ID(c.confederation, p.position)
         WHEN 1 THEN N'Theo khu vực CLB mua'
         WHEN 2 THEN N'Theo vị trí'
         WHEN 3 THEN N'Tổng chung' END                                        AS tap_nhom,
    CASE WHEN GROUPING(c.confederation) = 1 THEN N'Tất cả' ELSE c.confederation END AS khu_vuc_clb_mua,
    CASE WHEN GROUPING(p.position) = 1 THEN N'Tất cả' ELSE p.position END           AS vi_tri,
    COUNT(*)                                                    AS so_thuong_vu,
    COUNT(f.transfer_fee_eur)                                   AS so_thuong_vu_cong_bo_phi,  -- COUNT(cột) bỏ qua NULL
    ROUND(SUM(f.transfer_fee_eur) / 1000000.0, 2)               AS tong_phi_trieu_eur,
    ROUND(100.0 * SUM(f.transfer_fee_eur)
          / NULLIF(SUM(SUM(f.transfer_fee_eur)) OVER (PARTITION BY GROUPING_ID(c.confederation, p.position)), 0), 2)
                                                                AS ti_trong_trong_tap_nhom_pct
FROM dbo.fact_transfer f
JOIN dbo.dim_club c   ON c.club_key = f.to_club_key
JOIN dbo.dim_player p ON p.player_key = f.player_key
JOIN dbo.dim_season s ON s.season_key = f.season_key
WHERE s.season_label = '2024/25'
GROUP BY GROUPING SETS ((c.confederation), (p.position), ())
ORDER BY GROUPING_ID(c.confederation, p.position), tong_phi_trieu_eur DESC;
GO

/* [8.2] TRUY VẤN MDX TƯƠNG ỨNG (HỢP 3 TẬP TUPLE CÙNG CHIỀU = 3 GROUPING SETS)
   Cube [Thị trường cầu thủ]. Thành viên [All] của hierarchy còn lại đóng vai trò cột "Tất cả".
-------------------------------------------------------------------------------------------------
WITH
  MEMBER [Measures].[Tổng phí (triệu €)] AS [Measures].[Phí chuyển nhượng] / 1000000, FORMAT_STRING = "#,##0.00"
SELECT
  {[Measures].[Số thương vụ], [Measures].[Số vụ có thông tin phí], [Measures].[Tổng phí (triệu €)]} ON COLUMNS,
  NON EMPTY
    { [CLB đến].[Liên đoàn].[Liên đoàn].MEMBERS * {[Cầu thủ].[Vị trí].[All]} }
  + { {[CLB đến].[Liên đoàn].[All]} * [Cầu thủ].[Vị trí].[Vị trí].MEMBERS }
  + { ([CLB đến].[Liên đoàn].[All], [Cầu thủ].[Vị trí].[All]) } ON ROWS
FROM [Thị trường cầu thủ]
WHERE ([Mùa giải].[Mùa giải].[2024/25]);
------------------------------------------------------------------------------------------------- */


/* ==============================================================================================
   CHỦ ĐỀ 9: PHONG ĐỘ QUA CÁC MÙA VÀ PHÂN NHÓM CHI TIÊU (KHUNG CỬA SỔ, LAG/LEAD, NTILE)
   Câu hỏi kinh doanh:
   "Phong độ ghi bàn của Mohamed Salah tiến triển thế nào qua từng mùa (lũy kế, trung bình 3 mùa,
    so với mùa trước/mùa sau)? Mùa 2024/25, chi tiêu ròng tập trung vào nhóm CLB nào?"
   ============================================================================================== */

-- [9.1] TRUY VẤN T-SQL (ROWS UNBOUNDED PRECEDING = LŨY KẾ; ROWS BETWEEN 2 PRECEDING = TRUNG BÌNH TRƯỢT 3 MÙA;
--       LAG/LEAD SO SÁNH MÙA LIỀN KỀ; TỈ TRỌNG TRONG TOÀN SỰ NGHIỆP BẰNG SUM() OVER ())
WITH SeasonStats AS (
    SELECT s.season_key, s.season_label,
           SUM(a.goals) AS ban_thang, SUM(a.assists) AS kien_tao, SUM(a.minutes_played) AS so_phut
    FROM dbo.fact_player_appearance a
    JOIN dbo.dim_player p ON p.player_key = a.player_key
    JOIN dbo.dim_season s ON s.season_key = a.season_key
    WHERE p.full_name = N'Mohamed Salah'
    GROUP BY s.season_key, s.season_label
)
SELECT
    season_label, ban_thang, kien_tao, so_phut,
    SUM(ban_thang) OVER (ORDER BY season_key ROWS UNBOUNDED PRECEDING)                       AS ban_thang_luy_ke,
    ROUND(AVG(1.0 * ban_thang) OVER (ORDER BY season_key ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS tb_truot_3_mua,
    LAG(ban_thang)  OVER (ORDER BY season_key)                                                 AS ban_thang_mua_truoc,
    LEAD(ban_thang) OVER (ORDER BY season_key)                                                 AS ban_thang_mua_sau,
    ROUND(100.0 * (ban_thang - LAG(ban_thang) OVER (ORDER BY season_key))
          / NULLIF(LAG(ban_thang) OVER (ORDER BY season_key), 0), 2)                           AS tang_truong_pct,
    ROUND(100.0 * ban_thang / NULLIF(SUM(ban_thang) OVER (), 0), 2)                            AS ti_trong_su_nghiep_pct
FROM SeasonStats
ORDER BY season_key;
GO

/* [9.2] TRUY VẤN MDX TƯƠNG ỨNG (DẢI THÀNH VIÊN ":" = LŨY KẾ; LASTPERIODS = TRUNG BÌNH TRƯỢT;
         PREVMEMBER / NEXTMEMBER = LAG / LEAD)
   Cube [Hiệu suất cầu thủ]. AVG của MDX bỏ qua ô rỗng, giống AVG trên các mùa có dữ liệu của SQL.
-------------------------------------------------------------------------------------------------
WITH
  MEMBER [Measures].[Bàn thắng lũy kế] AS
    SUM({[Mùa giải].[Mùa giải].[Mùa giải].MEMBERS.ITEM(0) : [Mùa giải].[Mùa giải].CURRENTMEMBER},
        [Measures].[Bàn thắng cầu thủ])
  MEMBER [Measures].[TB trượt 3 mùa] AS
    AVG(LASTPERIODS(3, [Mùa giải].[Mùa giải].CURRENTMEMBER), [Measures].[Bàn thắng cầu thủ]), FORMAT_STRING = "0.00"
  MEMBER [Measures].[Bàn mùa trước] AS ([Measures].[Bàn thắng cầu thủ], [Mùa giải].[Mùa giải].CURRENTMEMBER.PREVMEMBER)
  MEMBER [Measures].[Bàn mùa sau]   AS ([Measures].[Bàn thắng cầu thủ], [Mùa giải].[Mùa giải].CURRENTMEMBER.NEXTMEMBER)
  MEMBER [Measures].[Tăng trưởng] AS
    IIF(ISEMPTY([Measures].[Bàn mùa trước]) OR [Measures].[Bàn mùa trước] = 0, NULL,
        ([Measures].[Bàn thắng cầu thủ] - [Measures].[Bàn mùa trước]) / [Measures].[Bàn mùa trước]),
    FORMAT_STRING = "0.00%"
  MEMBER [Measures].[Tỉ trọng sự nghiệp] AS
    [Measures].[Bàn thắng cầu thủ] / ([Measures].[Bàn thắng cầu thủ], [Mùa giải].[Mùa giải].[All]),
    FORMAT_STRING = "0.00%"
SELECT
  {[Measures].[Bàn thắng cầu thủ], [Measures].[Kiến tạo], [Measures].[Số phút], [Measures].[Bàn thắng lũy kế],
   [Measures].[TB trượt 3 mùa], [Measures].[Bàn mùa trước], [Measures].[Bàn mùa sau], [Measures].[Tăng trưởng],
   [Measures].[Tỉ trọng sự nghiệp]} ON COLUMNS,
  NONEMPTY([Mùa giải].[Mùa giải].[Mùa giải].MEMBERS, [Measures].[Số phút]) ON ROWS
FROM [Hiệu suất cầu thủ]
WHERE ([Cầu thủ].[Cầu thủ].[Mohamed Salah]);
------------------------------------------------------------------------------------------------- */

-- [9.3] TRUY VẤN T-SQL (NTILE(4) CHIA CLB THÀNH 4 NHÓM CHI TIÊU RÒNG; RANK XẾP HẠNG; TỈ TRỌNG BẰNG SUM() OVER ())
--       CLB được xét: có chi mua hoặc thu bán > 0 trong mùa 2024/25.
WITH Mua AS (
    SELECT f.to_club_key AS club_key, SUM(f.transfer_fee_eur) AS chi_mua
    FROM dbo.fact_transfer f JOIN dbo.dim_season s ON s.season_key = f.season_key
    WHERE s.season_label = '2024/25' GROUP BY f.to_club_key
),
Ban AS (
    SELECT f.from_club_key AS club_key, SUM(f.transfer_fee_eur) AS thu_ban
    FROM dbo.fact_transfer f JOIN dbo.dim_season s ON s.season_key = f.season_key
    WHERE s.season_label = '2024/25' GROUP BY f.from_club_key
),
Rong AS (
    SELECT COALESCE(m.club_key, b.club_key) AS club_key,
           ISNULL(m.chi_mua, 0) AS chi_mua, ISNULL(b.thu_ban, 0) AS thu_ban,
           ISNULL(m.chi_mua, 0) - ISNULL(b.thu_ban, 0) AS chi_tieu_rong
    FROM Mua m FULL OUTER JOIN Ban b ON b.club_key = m.club_key
    WHERE COALESCE(m.club_key, b.club_key) > 0   -- bỏ -1 Không rõ, -2 Không thuộc CLB nào
      AND (ISNULL(m.chi_mua, 0) > 0 OR ISNULL(b.thu_ban, 0) > 0)
),
Nhom AS (
    SELECT r.*, c.club_name,
           RANK()   OVER (ORDER BY r.chi_tieu_rong DESC) AS hang,
           NTILE(4) OVER (ORDER BY r.chi_tieu_rong DESC, r.club_key) AS nhom_chi_tieu,
           COUNT(*) OVER () AS so_clb_xet
    FROM Rong r JOIN dbo.dim_club c ON c.club_key = r.club_key
)
SELECT TOP 10
    hang, nhom_chi_tieu, club_name,
    ROUND(chi_mua / 1000000.0, 2)       AS chi_mua_trieu_eur,
    ROUND(thu_ban / 1000000.0, 2)       AS thu_ban_trieu_eur,
    ROUND(chi_tieu_rong / 1000000.0, 2) AS chi_tieu_rong_trieu_eur,
    so_clb_xet
FROM Nhom
ORDER BY hang, club_key;
GO

-- [9.4] TÓM TẮT THEO NHÓM NTILE: MỖI NHÓM CHIẾM BAO NHIÊU % TỔNG CHI MUA
WITH Mua AS (
    SELECT f.to_club_key AS club_key, SUM(f.transfer_fee_eur) AS chi_mua
    FROM dbo.fact_transfer f JOIN dbo.dim_season s ON s.season_key = f.season_key
    WHERE s.season_label = '2024/25' GROUP BY f.to_club_key
),
Ban AS (
    SELECT f.from_club_key AS club_key, SUM(f.transfer_fee_eur) AS thu_ban
    FROM dbo.fact_transfer f JOIN dbo.dim_season s ON s.season_key = f.season_key
    WHERE s.season_label = '2024/25' GROUP BY f.from_club_key
),
Rong AS (
    SELECT COALESCE(m.club_key, b.club_key) AS club_key,
           ISNULL(m.chi_mua, 0) AS chi_mua, ISNULL(m.chi_mua, 0) - ISNULL(b.thu_ban, 0) AS chi_tieu_rong
    FROM Mua m FULL OUTER JOIN Ban b ON b.club_key = m.club_key
    WHERE COALESCE(m.club_key, b.club_key) > 0   -- bỏ -1 Không rõ, -2 Không thuộc CLB nào
      AND (ISNULL(m.chi_mua, 0) > 0 OR ISNULL(b.thu_ban, 0) > 0)
),
Nhom AS (
    SELECT *, NTILE(4) OVER (ORDER BY chi_tieu_rong DESC, club_key) AS nhom_chi_tieu FROM Rong
)
SELECT nhom_chi_tieu,
       COUNT(*)                                                         AS so_clb,
       ROUND(SUM(chi_tieu_rong) / 1000000.0, 2)                         AS chi_tieu_rong_trieu_eur,
       ROUND(100.0 * SUM(chi_mua) / NULLIF(SUM(SUM(chi_mua)) OVER (), 0), 2) AS ti_trong_chi_mua_pct
FROM Nhom
GROUP BY nhom_chi_tieu
ORDER BY nhom_chi_tieu;
GO

/* [9.5] TRUY VẤN MDX TƯƠNG ỨNG [9.3] (WITH SET + ORDER + RANK; NHÓM TÍNH GIỐNG NTILE(4))
   Cube [Thị trường cầu thủ], xem theo [CLB đến]. NTILE(4) với n CLB: n MOD 4 nhóm đầu có (n \ 4) + 1 CLB, các nhóm sau có n \ 4 CLB.
-------------------------------------------------------------------------------------------------
WITH
  SET [CLB xét] AS
    ORDER(
      FILTER(EXCEPT([CLB đến].[CLB].[CLB].MEMBERS, {[CLB đến].[CLB].&[-1], [CLB đến].[CLB].&[-2]}),
             [Measures].[Chi mua] > 0 OR [Measures].[Thu bán] > 0),
      [Measures].[Chi tiêu ròng], BDESC)
  MEMBER [Measures].[Hạng] AS RANK([CLB đến].[CLB].CURRENTMEMBER, [CLB xét], [Measures].[Chi tiêu ròng])
  MEMBER [Measures].[Số CLB xét] AS [CLB xét].COUNT
  MEMBER [Measures].[Vị trí trong tập] AS RANK([CLB đến].[CLB].CURRENTMEMBER, [CLB xét])
  MEMBER [Measures].[Cỡ nhóm] AS INT([Measures].[Số CLB xét] / 4)                               -- n \ 4
  MEMBER [Measures].[Số nhóm dư] AS [Measures].[Số CLB xét] - 4 * [Measures].[Cỡ nhóm]            -- n MOD 4 (MDX không có MOD)
  MEMBER [Measures].[Nhóm chi tiêu] AS
    IIF([Measures].[Vị trí trong tập] <= [Measures].[Số nhóm dư] * ([Measures].[Cỡ nhóm] + 1),
        INT(([Measures].[Vị trí trong tập] - 1) / ([Measures].[Cỡ nhóm] + 1)) + 1,
        [Measures].[Số nhóm dư]
          + INT(([Measures].[Vị trí trong tập] - 1 - [Measures].[Số nhóm dư] * ([Measures].[Cỡ nhóm] + 1))
                / [Measures].[Cỡ nhóm]) + 1)
  MEMBER [Measures].[Chi mua (triệu €)] AS [Measures].[Chi mua] / 1000000, FORMAT_STRING = "#,##0.00"
  MEMBER [Measures].[Thu bán (triệu €)] AS [Measures].[Thu bán] / 1000000, FORMAT_STRING = "#,##0.00"
  MEMBER [Measures].[Chi tiêu ròng (triệu €)] AS [Measures].[Chi tiêu ròng] / 1000000, FORMAT_STRING = "#,##0.00"
SELECT
  {[Measures].[Hạng], [Measures].[Nhóm chi tiêu], [Measures].[Chi mua (triệu €)], [Measures].[Thu bán (triệu €)],
   [Measures].[Chi tiêu ròng (triệu €)], [Measures].[Số CLB xét]} ON COLUMNS,
  HEAD([CLB xét], 10) ON ROWS
FROM [Thị trường cầu thủ]
WHERE ([Mùa giải].[Mùa giải].[2024/25]);
------------------------------------------------------------------------------------------------- */


/* ==============================================================================================
   CHỦ ĐỀ 10: VẬT HÓA BẢNG XẾP HẠNG CLB THEO MÙA (MATERIALIZED VIEW = INDEXED VIEW TRONG SQL SERVER)
   Câu hỏi kinh doanh:
   "Bảng xếp hạng (điểm, thắng, hiệu số) theo CLB × mùa được hỏi lặp lại rất nhiều lần.
    Có thể tính sẵn một lần rồi đọc lại thay vì quét ~360 nghìn dòng fact mỗi lần không?"
   Ghi chú:
   - SQL Server không có lệnh CREATE MATERIALIZED VIEW; tương đương là view WITH SCHEMABINDING
     + UNIQUE CLUSTERED INDEX. Kết quả được lưu thật và SQL Server tự cập nhật khi SSIS nạp thêm fact.
   - Điều kiện: đủ các SET ở dưới, tên bảng ghi đủ schema, có COUNT_BIG(*), SUM không được trên biểu thức nullable.
   - Lưu SUM và COUNT (không lưu tỉ lệ) để tổng hợp lên mức cao hơn vẫn tính đúng tỉ lệ (điểm mỗi trận, tỉ lệ thắng).
   - Cube MOLAP của SSAS cũng là một dạng vật hóa: aggregation được tính sẵn khi Process.
   ============================================================================================== */

-- [10.1] TẠO MATERIALIZED VIEW (CHẠY MỘT LẦN)
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
GO
IF OBJECT_ID(N'dbo.mv_club_season_standing', N'V') IS NOT NULL
    DROP VIEW dbo.mv_club_season_standing;
GO
CREATE VIEW dbo.mv_club_season_standing
WITH SCHEMABINDING
AS
SELECT f.season_key,
       f.club_key,
       COUNT_BIG(*)                          AS so_tran,
       SUM(ISNULL(f.points, 0))              AS diem,
       SUM(ISNULL(f.is_win, 0))              AS thang,
       SUM(ISNULL(f.is_draw, 0))             AS hoa,
       SUM(ISNULL(f.is_loss, 0))             AS thua,
       SUM(ISNULL(f.goals_for, 0))           AS ban_thang,
       SUM(ISNULL(f.goals_against, 0))       AS ban_thua
FROM dbo.fact_team_match AS f
GROUP BY f.season_key, f.club_key;
GO
CREATE UNIQUE CLUSTERED INDEX ix_mv_club_season_standing
    ON dbo.mv_club_season_standing (season_key, club_key);
GO

-- [10.2] ĐỌC TỪ KẾT QUẢ ĐÃ VẬT HÓA: TOP 10 CLB MÙA 2024/25 (NOEXPAND = ĐỌC THẲNG INDEX CỦA VIEW)
--        Điểm mỗi trận và tỉ lệ thắng tính lại từ SUM / COUNT đã lưu, không lấy trung bình các tỉ lệ.
SELECT TOP 10
    RANK() OVER (ORDER BY v.diem DESC, v.ban_thang - v.ban_thua DESC) AS hang,
    c.club_name, v.so_tran, v.thang, v.hoa, v.thua, v.diem,
    v.ban_thang - v.ban_thua                                   AS hieu_so,
    ROUND(1.0 * v.diem / NULLIF(v.so_tran, 0), 2)              AS diem_moi_tran,
    ROUND(100.0 * v.thang / NULLIF(v.so_tran, 0), 2)           AS ti_le_thang_pct
FROM dbo.mv_club_season_standing AS v WITH (NOEXPAND)
JOIN dbo.dim_club c   ON c.club_key = v.club_key
JOIN dbo.dim_season s ON s.season_key = v.season_key
WHERE s.season_label = '2024/25'
ORDER BY hang, c.club_name;
GO

-- [10.3] TỔNG HỢP LÊN MỨC CAO HƠN TỪ VIEW (QUERY REWRITE THỦ CÔNG): TỈ LỆ THẮNG THEO MÙA CỦA TOÀN BỘ CLB
--        Cộng các SUM và COUNT đã vật hóa rồi mới chia. Kết quả phải trùng với tính thẳng trên fact.
SELECT s.season_label,
       SUM(v.so_tran)                                               AS so_tran,
       ROUND(100.0 * SUM(v.thang) / NULLIF(SUM(v.so_tran), 0), 2)   AS ti_le_thang_pct,
       ROUND(1.0 * SUM(v.diem) / NULLIF(SUM(v.so_tran), 0), 3)      AS diem_moi_tran
FROM dbo.mv_club_season_standing AS v WITH (NOEXPAND)
JOIN dbo.dim_season s ON s.season_key = v.season_key
WHERE s.season_label IN ('2022/23', '2023/24', '2024/25')
GROUP BY s.season_label
ORDER BY s.season_label;
GO

/* [10.4] TRUY VẤN MDX TƯƠNG ỨNG [10.2] (CUBE MOLAP ĐỌC AGGREGATION ĐÃ TÍNH SẴN)
   Cube [Hiệu suất đội bóng]. Top 10 CLB theo điểm, hòa điểm thì xét hiệu số.
-------------------------------------------------------------------------------------------------
WITH
  MEMBER [Measures].[Điểm mỗi trận] AS IIF([Measures].[Số trận] = 0, NULL, [Measures].[Điểm] / [Measures].[Số trận]),
    FORMAT_STRING = "0.00"
  MEMBER [Measures].[Khóa xếp hạng] AS [Measures].[Điểm] * 1000 + [Measures].[Hiệu số]
SELECT
  {[Measures].[Số trận], [Measures].[Thắng], [Measures].[Hòa], [Measures].[Thua], [Measures].[Điểm],
   [Measures].[Hiệu số], [Measures].[Điểm mỗi trận], [Measures].[Tỉ lệ thắng]} ON COLUMNS,
  TOPCOUNT(NONEMPTY([CLB].[CLB].[CLB].MEMBERS, [Measures].[Số trận]), 10, [Measures].[Khóa xếp hạng]) ON ROWS
FROM [Hiệu suất đội bóng]
WHERE ([Mùa giải].[Mùa giải].[2024/25]);
------------------------------------------------------------------------------------------------- */


/* ==============================================================================================
   CHỦ ĐỀ 11: PHÂN TÍCH KỶ LUẬT THI ĐẤU & CÔNG TÁC TRỌNG TÀI (CUBE [KỶ LUẬT VÀ TRỌNG TÀI])
   Câu hỏi kinh doanh:
   "Trọng tài nào rút thẻ nghiêm khắc nhất mỗi trận? Cơ cấu thẻ phạt theo vị trí thi đấu ra sao?
    CLB nào có điểm trừ kỷ luật Fair-play cao nhất (chơi bạo lực nhất) ở Ngoại hạng Anh mùa 2024/25?"
   ============================================================================================== */

-- [11.1] TRUY VẤN T-SQL: TOP 10 TRỌNG TÀI RÚT THẺ NGHIÊM KHẮC NHẤT (TỐI THIỂU 50 TRẬN)
SELECT TOP 10 
    m.referee, 
    COUNT(DISTINCT a.match_key) AS matches, 
    SUM(a.yellow_cards) AS yellows, 
    SUM(a.red_cards) AS reds,
    SUM(a.yellow_cards) + SUM(a.red_cards) AS total_cards,
    ROUND(CAST(SUM(a.yellow_cards) + SUM(a.red_cards) AS FLOAT) / COUNT(DISTINCT a.match_key), 2) AS cards_per_match
FROM dbo.fact_player_appearance a
JOIN dbo.dim_match m ON a.match_key = m.match_key
WHERE m.referee <> N'Không xác định'
GROUP BY m.referee
HAVING COUNT(DISTINCT a.match_key) >= 50
ORDER BY cards_per_match DESC;
GO

/* [11.2] TRUY VẤN MDX TƯƠNG ỨNG [11.1] TRÊN CUBE [Kỷ luật và Trọng tài]
-------------------------------------------------------------------------------------------------
SELECT 
    {[Measures].[Số trận đấu], [Measures].[Thẻ vàng], [Measures].[Thẻ đỏ], [Measures].[Thẻ mỗi trận]} ON COLUMNS,
    TOPCOUNT(
        FILTER(
            [Trận đấu].[Trọng tài].[Trọng tài].MEMBERS,
            [Trận đấu].[Trọng tài].CURRENTMEMBER.NAME <> "Không xác định" 
            AND [Measures].[Số trận đấu] >= 50
        ),
        10,
        [Measures].[Thẻ mỗi trận]
    ) ON ROWS
FROM [Kỷ luật và Trọng tài];
------------------------------------------------------------------------------------------------- */

-- [11.3] TRUY VẤN T-SQL: CƠ CẤU THẺ PHẠT PHÂN BỔ THEO VỊ TRÍ THI ĐẤU TRÊN SÂN
SELECT 
    p.position, 
    SUM(a.yellow_cards) AS yellows, 
    SUM(a.red_cards) AS reds,
    SUM(a.yellow_cards) + SUM(a.red_cards) AS total_cards,
    ROUND(100.0 * (SUM(a.yellow_cards) + SUM(a.red_cards)) / SUM(SUM(a.yellow_cards) + SUM(a.red_cards)) OVER(), 2) as pct
FROM dbo.fact_player_appearance a
JOIN dbo.dim_player p ON a.player_key = p.player_key
WHERE p.position NOT IN (N'Không xác định', 'Missing')
GROUP BY p.position
ORDER BY SUM(a.yellow_cards) + SUM(a.red_cards) DESC;
GO

/* [11.4] TRUY VẤN MDX TƯƠNG ỨNG [11.3] TRÊN CUBE [Kỷ luật và Trọng tài]
-------------------------------------------------------------------------------------------------
WITH 
MEMBER [Measures].[Tỉ trọng thẻ] AS
    [Measures].[Tổng thẻ phạt] / ([Measures].[Tổng thẻ phạt], [Cầu thủ].[Vị trí].[All]),
    FORMAT_STRING = "0.0%"
SELECT 
    {[Measures].[Thẻ vàng], [Measures].[Thẻ đỏ], [Measures].[Tổng thẻ phạt], [Measures].[Tỉ trọng thẻ]} ON COLUMNS,
    FILTER(
        [Cầu thủ].[Vị trí].[Vị trí].MEMBERS,
        NOT ([Cầu thủ].[Vị trí].CURRENTMEMBER.NAME = "Không xác định"
             OR [Cầu thủ].[Vị trí].CURRENTMEMBER.NAME = "Missing")
    ) ON ROWS
FROM [Kỷ luật và Trọng tài];
------------------------------------------------------------------------------------------------- */

-- [11.5] TRUY VẤN T-SQL: ĐIỂM TRỪ KỶ LUẬT FAIR-PLAY CLB (PREMIER LEAGUE 2024/25)
SELECT TOP 5 
    c.club_name, 
    SUM(a.yellow_cards) AS yellows, 
    SUM(a.red_cards) AS reds,
    SUM(a.yellow_cards) + SUM(a.red_cards) AS total_cards,
    (SUM(a.yellow_cards) * 1) + (SUM(a.red_cards) * 3) AS discipline_points
FROM dbo.fact_player_appearance a
JOIN dbo.dim_club c ON a.club_key = c.club_key
JOIN dbo.dim_competition k ON a.competition_key = k.competition_key
JOIN dbo.dim_season s ON a.season_key = s.season_key
WHERE k.competition_id = 'GB1' AND s.season_label = '2024/25'
GROUP BY c.club_name
ORDER BY discipline_points DESC;
GO

/* [11.6] TRUY VẤN MDX TƯƠNG ỨNG [11.5] TRÊN CUBE [Kỷ luật và Trọng tài]
-------------------------------------------------------------------------------------------------
SELECT 
    {[Measures].[Thẻ vàng], [Measures].[Thẻ đỏ], [Measures].[Tổng thẻ phạt], [Measures].[Điểm kỷ luật Fair Play]} ON COLUMNS,
    TOPCOUNT(
        [CLB].[CLB].[CLB].MEMBERS,
        5,
        [Measures].[Điểm kỷ luật Fair Play]
    ) ON ROWS
FROM [Kỷ luật và Trọng tài]
WHERE (
    [Giải đấu].[Mã giải].[GB1],
    [Mùa giải].[Mùa giải].[2024/25]
);
------------------------------------------------------------------------------------------------- */
