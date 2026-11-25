USE football_dwh_dw;
GO

/* =========================================================================
   BỘ CÂU HỎI ĐỐI CHIẾU SSAS - PHẦN 1: HIỆU SUẤT ĐỘI BÓNG & HLV
   Lưu ý: 
   - Thay đổi 'GB1' thành mã giải khác (như ES1, IT1) nếu cần.
   - Thay đổi '2023/24' thành mùa giải bạn muốn kiểm tra.
   - Luôn có điều kiện c.club_key <> -1 để loại dòng "Không xác định".
========================================================================= */

-- -------------------------------------------------------------------------
-- Q1: Bảng xếp hạng các câu lạc bộ cuối mùa giải
-- Ý nghĩa: Tạo bảng xếp hạng chuẩn xác dựa trên Tổng điểm, Hiệu số, Bàn thắng.
-- Kỹ thuật: Dùng Window Function RANK() để xếp hạng tự động dựa trên 3 tiêu chí.
-- -------------------------------------------------------------------------
SELECT 
    c.club_name AS [Câu lạc bộ],
    COUNT(f.match_key) AS [Số trận],
    SUM(f.is_win) AS [Thắng],
    SUM(f.is_draw) AS [Hòa],
    SUM(f.is_loss) AS [Thua],
    SUM(f.goals_for) AS [Bàn thắng],
    SUM(f.goals_against) AS [Bàn thua],
    SUM(f.goal_difference) AS [Hiệu số],
    SUM(f.points) AS [Tổng điểm],
    RANK() OVER (ORDER BY SUM(f.points) DESC, SUM(f.goal_difference) DESC, SUM(f.goals_for) DESC) AS [Thứ hạng]
FROM fact_team_match f
JOIN dim_club c ON f.club_key = c.club_key
JOIN dim_competition k ON f.competition_key = k.competition_key
JOIN dim_season s ON f.season_key = s.season_key
WHERE k.competition_id = 'GB1' 
  AND s.season_label = '2015/16' 
  AND c.club_key <> -1
GROUP BY c.club_name
ORDER BY [Tổng điểm] DESC, [Hiệu số] DESC;
GO

-- -------------------------------------------------------------------------
-- Q2: Top câu lạc bộ có số trận thắng nhiều nhất
-- Ý nghĩa: Tìm ra đội bóng giành nhiều chiến thắng nhất.
-- Kỹ thuật: Ép kiểu CAST sang FLOAT/DECIMAL để tính tỷ lệ phần trăm chính xác, 
-- tránh lỗi chia số nguyên (integer division) trong SQL.
-- -------------------------------------------------------------------------
SELECT TOP 10
    c.club_name AS [Câu lạc bộ],
    COUNT(f.match_key) AS [Số trận đã đấu],
    SUM(f.is_win) AS [Tổng số trận thắng],
    CAST(SUM(f.is_win) * 100.0 / COUNT(f.match_key) AS DECIMAL(5,2)) AS [Tỷ lệ thắng (%)]
FROM fact_team_match f
JOIN dim_club c ON f.club_key = c.club_key
JOIN dim_season s ON f.season_key = s.season_key
WHERE s.season_label = '2015/16' 
  AND c.club_key <> -1
GROUP BY c.club_name
ORDER BY [Tổng số trận thắng] DESC, [Tỷ lệ thắng (%)] DESC;
GO

-- -------------------------------------------------------------------------
-- Q3: Câu lạc bộ nào có hiệu suất tấn công tốt nhất?
-- Ý nghĩa: Đo lường sức mạnh hàng công (tổng bàn thắng, số bàn trung bình).
-- Kỹ thuật: Dùng SUM kết hợp CASE WHEN để đếm rẽ nhánh số trận ghi từ 3 bàn trở lên.
-- -------------------------------------------------------------------------
SELECT TOP 10
    c.club_name AS [Câu lạc bộ],
    COUNT(f.match_key) AS [Số trận],
    SUM(f.goals_for) AS [Tổng bàn thắng],
    CAST(SUM(f.goals_for) AS FLOAT) / COUNT(f.match_key) AS [Bàn thắng mỗi trận],
    SUM(CASE WHEN f.goals_for >= 3 THEN 1 ELSE 0 END) AS [Số trận ghi >= 3 bàn]
FROM fact_team_match f
JOIN dim_club c ON f.club_key = c.club_key
JOIN dim_season s ON f.season_key = s.season_key
WHERE s.season_label = '2015/16'
  AND c.club_key <> -1
GROUP BY c.club_name
ORDER BY [Tổng bàn thắng] DESC, [Bàn thắng mỗi trận] DESC;
GO

-- -------------------------------------------------------------------------
-- Q4: Câu lạc bộ nào có khả năng phòng ngự tốt nhất?
-- Ý nghĩa: Đánh giá sự vững chắc của hàng thủ qua tỷ lệ sạch lưới.
-- Kỹ thuật: Sử dụng trực tiếp cờ is_clean_sheet đã được SSIS tính toán sẵn.
-- -------------------------------------------------------------------------
SELECT TOP 10
    c.club_name AS [Câu lạc bộ],
    COUNT(f.match_key) AS [Số trận],
    SUM(f.goals_against) AS [Tổng bàn thua],
    CAST(SUM(f.goals_against) AS FLOAT) / COUNT(f.match_key) AS [Bàn thua mỗi trận],
    SUM(f.is_clean_sheet) AS [Số trận sạch lưới],
    CAST(SUM(f.is_clean_sheet) * 100.0 / COUNT(f.match_key) AS DECIMAL(5,2)) AS [Tỷ lệ sạch lưới (%)]
FROM fact_team_match f
JOIN dim_club c ON f.club_key = c.club_key
JOIN dim_season s ON f.season_key = s.season_key
WHERE s.season_label = '2015/16'
  AND c.club_key <> -1
GROUP BY c.club_name
ORDER BY [Tỷ lệ sạch lưới (%)] DESC, [Tổng bàn thua] ASC;
GO

-- -------------------------------------------------------------------------
-- Q5: Lợi thế sân nhà ảnh hưởng đến kết quả thi đấu như thế nào?
-- Ý nghĩa: So sánh chéo hiệu suất khi đá sân nhà so với khi đá sân khách.
-- Kỹ thuật: Dùng CASE WHEN kết hợp NULLIF để tránh lỗi chia cho 0 nếu 
-- có đội chưa đá trận sân khách/sân nhà nào.
-- -------------------------------------------------------------------------
SELECT 
    c.club_name AS [Câu lạc bộ],
    -- Chỉ số Sân nhà
    SUM(CASE WHEN f.is_home = 1 THEN 1 ELSE 0 END) AS [Trận sân nhà],
    CAST(SUM(CASE WHEN f.is_home = 1 AND f.is_win = 1 THEN 1 ELSE 0 END) * 100.0 / NULLIF(SUM(CASE WHEN f.is_home = 1 THEN 1 ELSE 0 END), 0) AS DECIMAL(5,2)) AS [Tỷ lệ thắng sân nhà (%)],
    CAST(SUM(CASE WHEN f.is_home = 1 THEN f.points ELSE 0 END) AS FLOAT) / NULLIF(SUM(CASE WHEN f.is_home = 1 THEN 1 ELSE 0 END), 0) AS [Điểm TB sân nhà],
    SUM(CASE WHEN f.is_home = 1 THEN f.goal_difference ELSE 0 END) AS [Hiệu số sân nhà],
    -- Chỉ số Sân khách
    SUM(CASE WHEN f.is_home = 0 THEN 1 ELSE 0 END) AS [Trận sân khách],
    CAST(SUM(CASE WHEN f.is_home = 0 AND f.is_win = 1 THEN 1 ELSE 0 END) * 100.0 / NULLIF(SUM(CASE WHEN f.is_home = 0 THEN 1 ELSE 0 END), 0) AS DECIMAL(5,2)) AS [Tỷ lệ thắng sân khách (%)],
    CAST(SUM(CASE WHEN f.is_home = 0 THEN f.points ELSE 0 END) AS FLOAT) / NULLIF(SUM(CASE WHEN f.is_home = 0 THEN 1 ELSE 0 END), 0) AS [Điểm TB sân khách],
    SUM(CASE WHEN f.is_home = 0 THEN f.goal_difference ELSE 0 END) AS [Hiệu số sân khách]
FROM fact_team_match f
JOIN dim_club c ON f.club_key = c.club_key
JOIN dim_season s ON f.season_key = s.season_key
WHERE s.season_label = '2015/16' AND c.club_key <> -1
GROUP BY c.club_name
ORDER BY [Điểm TB sân nhà] DESC;
GO

-- -------------------------------------------------------------------------
-- Q6: Phong độ của các câu lạc bộ thay đổi ra sao qua các mùa giải?
-- Ý nghĩa: Theo dõi biến động hiệu suất của một CLB cụ thể qua từng năm.
-- Kỹ thuật: Dùng CTE kết hợp hàm LAG() để lấy số liệu của mùa giải trước (YoY), 
-- từ đó tính ra mức độ cải thiện hay sa sút.
-- -------------------------------------------------------------------------
WITH TeamForm AS (
    SELECT 
        s.season_label AS [Mùa giải],
        s.season_start_year,
        COUNT(f.match_key) AS [Số trận],
        CAST(SUM(f.points) AS FLOAT) / COUNT(f.match_key) AS [Điểm mỗi trận],
        CAST(SUM(f.is_win) * 100.0 / COUNT(f.match_key) AS DECIMAL(5,2)) AS [Tỷ lệ thắng (%)],
        SUM(f.goal_difference) AS [Hiệu số],
        MAX(f.league_position) AS [Thứ hạng cuối mùa]
    FROM fact_team_match f
    JOIN dim_club c ON f.club_key = c.club_key
    JOIN dim_season s ON f.season_key = s.season_key
    WHERE c.club_name = 'Arsenal FC' -- Điền CLB muốn phân tích xu hướng
    GROUP BY s.season_label, s.season_start_year
)
SELECT 
    [Mùa giải],
    [Điểm mỗi trận],
    [Tỷ lệ thắng (%)],
    [Hiệu số],
    CAST([Điểm mỗi trận] - LAG([Điểm mỗi trận], 1) OVER (ORDER BY season_start_year) AS DECIMAL(5,2)) AS [Biến động Điểm TB (YoY)]
FROM TeamForm
ORDER BY season_start_year DESC;
GO

-- -------------------------------------------------------------------------
-- Q7: Thành tích thi đấu khác nhau như thế nào giữa các huấn luyện viên?
-- Ý nghĩa: Đánh giá xem HLV nào mang lại thành công lớn nhất cho 1 CLB.
-- Kỹ thuật: Nhóm theo tên HLV và lọc các HLV có từ 10 trận trở lên để bỏ 
-- qua các HLV tạm quyền (caretaker manager).
-- -------------------------------------------------------------------------
SELECT 
    c.club_name AS [Câu lạc bộ],
    m.manager_name AS [Huấn luyện viên],
    COUNT(f.match_key) AS [Số trận phụ trách],
    SUM(f.is_win) AS [Thắng],
    CAST(SUM(f.is_win) * 100.0 / COUNT(f.match_key) AS DECIMAL(5,2)) AS [Tỷ lệ thắng (%)],
    CAST(SUM(f.points) AS FLOAT) / COUNT(f.match_key) AS [Điểm TB mỗi trận],
    SUM(f.goal_difference) AS [Hiệu số bàn thắng]
FROM fact_team_match f
JOIN dim_manager m ON f.manager_key = m.manager_key
JOIN dim_club c ON f.club_key = c.club_key
WHERE c.club_name = 'Chelsea FC' -- Lọc CLB muốn xem lịch sử HLV
  AND m.manager_key <> -1
GROUP BY c.club_name, m.manager_name
HAVING COUNT(f.match_key) >= 10
ORDER BY [Điểm TB mỗi trận] DESC;
GO

-- -------------------------------------------------------------------------
-- Q8: Những câu lạc bộ nào có thành tích tốt trước các đối thủ mạnh?
-- Ý nghĩa: Đánh giá bản lĩnh đại chiến (Big Match) của các đội bóng.
-- Kỹ thuật: JOIN bảng Dim_Club 2 lần (Role-playing dimension) thông qua 
-- opponent_club_key để lấy ra tên đội đối thủ.
-- -------------------------------------------------------------------------
SELECT 
    c.club_name AS [Câu lạc bộ],
    COUNT(f.match_key) AS [Số trận đối đầu Big 6],
    SUM(f.is_win) AS [Thắng],
    SUM(f.is_draw) AS [Hòa],
    SUM(f.is_loss) AS [Thua],
    CAST(SUM(f.points) AS FLOAT) / COUNT(f.match_key) AS [Điểm TB mỗi trận],
    SUM(f.goals_for) AS [Bàn thắng],
    SUM(f.goals_against) AS [Bàn thua]
FROM fact_team_match f
JOIN dim_club c ON f.club_key = c.club_key
JOIN dim_club opp ON f.opponent_club_key = opp.club_key
JOIN dim_season s ON f.season_key = s.season_key
WHERE s.season_label = '2015/16'
  -- Xác định nhóm đối thủ mạnh (Big 6 Premier League làm ví dụ)
  AND opp.club_name IN ('Manchester City', 'Arsenal FC', 'Liverpool FC', 'Chelsea FC', 'Manchester United', 'Tottenham Hotspur')
  -- Loại bỏ chính các đội Big 6 để xem các đội khác đá với Big 6 thế nào
  AND c.club_name NOT IN ('Manchester City', 'Arsenal FC', 'Liverpool FC', 'Chelsea FC', 'Manchester United', 'Tottenham Hotspur')
GROUP BY c.club_name
ORDER BY [Điểm TB mỗi trận] DESC;
GO