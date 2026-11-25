-- Phần 3 – Cube "Thị trường cầu thủ": SQL đối chiếu cho 6 câu hỏi nghiệp vụ và KPI.
-- Mỗi khối: câu SQL trên kho (đáp án) + câu MDX tương ứng trên cube (chạy trong SSMS → Analysis Services → New MDX Query).
-- Kết quả cube phải bằng kết quả SQL.
USE football_dwh_dw;
GO

-- Q1. Giá trị đội hình mỗi CLB năm 2024 = tổng giá trị lần định giá CUỐI trong năm của từng cầu thủ tại CLB đó
--     Kết quả đã kiểm tra: Man City 1.292.200.000; Arsenal 1.270.500.000; Real Madrid 1.262.000.000
WITH v AS (
    SELECT f.club_key, f.player_key, f.market_value_eur,
           ROW_NUMBER() OVER (PARTITION BY f.club_key, f.player_key ORDER BY f.date_key DESC) AS rn
    FROM dbo.fact_player_valuation f
    WHERE f.date_key BETWEEN 20240101 AND 20241231)
SELECT TOP 5 c.club_name, SUM(v.market_value_eur) AS gia_tri_doi_hinh
FROM v JOIN dbo.dim_club c ON c.club_key = v.club_key
WHERE v.rn = 1
GROUP BY c.club_key, c.club_name
ORDER BY gia_tri_doi_hinh DESC;
/* MDX:
SELECT {[Measures].[Giá trị đội hình]} ON 0,
       TOPCOUNT([CLB].[CLB].[CLB].MEMBERS, 5, [Measures].[Giá trị đội hình]) ON 1
FROM [Thị trường cầu thủ]
WHERE ([Ngày].[Năm - Quý - Tháng - Ngày].[Năm].&[2024])
*/

-- Q2. Cầu thủ tăng giá mạnh nhất năm 2024
--     Kết quả đã kiểm tra: Lamine Yamal +120.000.000; Cole Palmer +85.000.000; Pau Cubarsí +68.500.000
SELECT TOP 5 p.full_name, SUM(f.value_change_eur) AS muc_tang_gia
FROM dbo.fact_player_valuation f JOIN dbo.dim_player p ON p.player_key = f.player_key
WHERE f.date_key BETWEEN 20240101 AND 20241231
GROUP BY p.player_key, p.full_name
ORDER BY muc_tang_gia DESC;
/* MDX:
SELECT {[Measures].[Tăng giảm giá trị]} ON 0,
       TOPCOUNT([Cầu thủ].[Cầu thủ].[Cầu thủ].MEMBERS, 5, [Measures].[Tăng giảm giá trị]) ON 1
FROM [Thị trường cầu thủ]
WHERE ([Ngày].[Năm - Quý - Tháng - Ngày].[Năm].&[2024])
*/

-- Q3. Giá trị đạt đỉnh ở độ tuổi nào, theo vị trí (giá trị trung bình mỗi lần định giá)
--     Kết quả đã kiểm tra: Attack đạt đỉnh ở nhóm 25-28 với 3.859.289; tuổi TB lúc định giá của Attack 24,5
SELECT p.position,
       CASE WHEN f.age_at_valuation IS NULL THEN N'Không rõ' WHEN f.age_at_valuation < 18 THEN N'Dưới 18'
            WHEN f.age_at_valuation <= 21 THEN N'18-21' WHEN f.age_at_valuation <= 24 THEN N'22-24'
            WHEN f.age_at_valuation <= 28 THEN N'25-28' WHEN f.age_at_valuation <= 31 THEN N'29-31' ELSE N'32+' END AS nhom_tuoi,
       AVG(CAST(f.market_value_eur AS float)) AS gia_tri_trung_binh
FROM dbo.fact_player_valuation f JOIN dbo.dim_player p ON p.player_key = f.player_key
GROUP BY p.position,
         CASE WHEN f.age_at_valuation IS NULL THEN N'Không rõ' WHEN f.age_at_valuation < 18 THEN N'Dưới 18'
              WHEN f.age_at_valuation <= 21 THEN N'18-21' WHEN f.age_at_valuation <= 24 THEN N'22-24'
              WHEN f.age_at_valuation <= 28 THEN N'25-28' WHEN f.age_at_valuation <= 31 THEN N'29-31' ELSE N'32+' END
ORDER BY p.position, nhom_tuoi;
SELECT p.position, AVG(CAST(f.age_at_valuation AS float)) AS tuoi_tb_luc_dinh_gia
FROM dbo.fact_player_valuation f JOIN dbo.dim_player p ON p.player_key = f.player_key
GROUP BY p.position;
/* MDX:
SELECT NON EMPTY [Cầu thủ].[Vị trí].[Vị trí].MEMBERS ON 0,
       NON EMPTY [Tuổi].[Nhóm tuổi].[Nhóm tuổi].MEMBERS ON 1
FROM [Thị trường cầu thủ]
WHERE ([Measures].[Giá trị trung bình])
*/

-- Q4. CLB chi tiêu ròng nhiều nhất mùa 2024/25 (chi mua − thu bán)
--     Kết quả đã kiểm tra: Brighton chi 281.450.000, thu 50.740.000, ròng 230.710.000
SELECT TOP 5 c.club_name,
       SUM(CASE WHEN t.to_club_key   = c.club_key THEN ISNULL(t.transfer_fee_eur, 0) ELSE 0 END) AS chi_mua,
       SUM(CASE WHEN t.from_club_key = c.club_key THEN ISNULL(t.transfer_fee_eur, 0) ELSE 0 END) AS thu_ban,
       SUM(CASE WHEN t.to_club_key   = c.club_key THEN ISNULL(t.transfer_fee_eur, 0) ELSE 0 END)
     - SUM(CASE WHEN t.from_club_key = c.club_key THEN ISNULL(t.transfer_fee_eur, 0) ELSE 0 END) AS chi_tieu_rong
FROM dbo.fact_transfer t
JOIN dbo.dim_club c   ON c.club_key IN (t.to_club_key, t.from_club_key)
JOIN dbo.dim_season s ON s.season_key = t.season_key
WHERE s.season_label = '2024/25'
GROUP BY c.club_key, c.club_name
ORDER BY chi_tieu_rong DESC;
/* MDX (xem với CLB đến trên trục):
SELECT {[Measures].[Chi mua], [Measures].[Thu bán], [Measures].[Chi tiêu ròng]} ON 0,
       TOPCOUNT([CLB đến].[CLB].[CLB].MEMBERS, 5, [Measures].[Chi tiêu ròng]) ON 1
FROM [Thị trường cầu thủ]
WHERE ([Mùa giải].[Mùa giải].[2024/25])
*/

-- Q5. CLB mua đắt hay rẻ so với giá trị thị trường (phí TB chỉ tính vụ có phí > 0)
--     Kết quả đã kiểm tra: Chelsea phí TB 31.969.681, phí chênh TB −4.749.028 (283 thương vụ có phí chênh)
SELECT TOP 5 c.club_name,
       AVG(CASE WHEN t.transfer_fee_eur > 0 THEN CAST(t.transfer_fee_eur AS float) END) AS phi_trung_binh,
       AVG(CAST(t.fee_premium_eur AS float))  AS phi_chenh_trung_binh,
       COUNT(t.fee_premium_eur)               AS so_thuong_vu_co_phi_chenh
FROM dbo.fact_transfer t JOIN dbo.dim_club c ON c.club_key = t.to_club_key
GROUP BY c.club_key, c.club_name
ORDER BY so_thuong_vu_co_phi_chenh DESC;
/* MDX:
SELECT {[Measures].[Phí trung bình], [Measures].[Phí chênh trung bình], [Measures].[_Số vụ tính được chênh lệch]} ON 0,
       TOPCOUNT([CLB đến].[CLB].[CLB].MEMBERS, 5, [Measures].[_Số vụ tính được chênh lệch]) ON 1
FROM [Thị trường cầu thủ]
*/

-- Q6. Tỉ lệ thương vụ miễn phí / cho mượn, tỉ lệ đội trẻ, tuổi TB cầu thủ chuyên nghiệp theo mùa
--     Kết quả đã kiểm tra (2024/25): 16.686 thương vụ, miễn phí 58,5%, đội trẻ 6,6%, tuổi TB chuyên nghiệp 24,0
SELECT s.season_label,
       COUNT(*) AS so_thuong_vu,
       AVG(CASE WHEN t.transfer_type_key = 2 THEN 1.0 ELSE 0 END) AS ti_le_mien_phi,
       SUM(CASE WHEN t.is_youth_transfer = 1 THEN 1.0 ELSE 0 END)
         / NULLIF(SUM(CASE WHEN t.is_youth_transfer IS NOT NULL THEN 1 ELSE 0 END), 0) AS ti_le_doi_tre,
       AVG(CASE WHEN t.is_youth_transfer = 0 THEN CAST(t.age_at_transfer AS float) END) AS tuoi_tb_chuyen_nghiep
FROM dbo.fact_transfer t JOIN dbo.dim_season s ON s.season_key = t.season_key
WHERE s.season_label IN ('2022/23', '2023/24', '2024/25')
GROUP BY s.season_label
ORDER BY s.season_label;
/* MDX:
SELECT {[Measures].[Số thương vụ], [Measures].[Tỉ lệ miễn phí hoặc cho mượn], [Measures].[Tỉ lệ vụ U18],
        [Measures].[Tuổi TB cầu thủ từ 18 tuổi]} ON 0,
       {[Mùa giải].[Mùa giải].[2022/23], [Mùa giải].[Mùa giải].[2023/24], [Mùa giải].[Mùa giải].[2024/25]} ON 1
FROM [Thị trường cầu thủ]
*/

-- KPI. Chi tiêu ròng so với ngân sách 100 triệu € (mùa 2024/25)
--     Kết quả đã kiểm tra: Man City ròng 106.300.000 → vàng (0); Chelsea 57.800.000 → xanh (1); cả hai giảm so với mùa trước (−1)
/* MDX:
SELECT {KPIValue("Chi tiêu ròng so với ngân sách"), KPIGoal("Chi tiêu ròng so với ngân sách"),
        KPIStatus("Chi tiêu ròng so với ngân sách"), KPITrend("Chi tiêu ròng so với ngân sách")} ON 0,
       {[CLB đến].[CLB].[Chelsea FC], [CLB đến].[CLB].[Manchester City]} ON 1
FROM [Thị trường cầu thủ]
WHERE ([Mùa giải].[Mùa giải].[2024/25])
*/
