-- Tao 2 database va cac bang stg_raw_* ma Main_ETL_Master.dtsx can (cot lay tu metadata cua OLE DB Destination).
-- Chay 1 lan truoc khi mo/chay package SSIS. Chay lai se xoa va tao lai bang stg_raw_*.

IF DB_ID(N'football_dwh_staging') IS NULL CREATE DATABASE football_dwh_staging;
GO
IF DB_ID(N'football_dwh_dw') IS NULL CREATE DATABASE football_dwh_dw;
GO

USE football_dwh_staging;
GO

DROP TABLE IF EXISTS [dbo].[stg_raw_appearances];
CREATE TABLE [dbo].[stg_raw_appearances] (
    [appearance_id] NVARCHAR(MAX) NULL,
    [game_id] NVARCHAR(MAX) NULL,
    [player_id] NVARCHAR(MAX) NULL,
    [player_club_id] NVARCHAR(MAX) NULL,
    [player_current_club_id] NVARCHAR(MAX) NULL,
    [date] NVARCHAR(MAX) NULL,
    [player_name] NVARCHAR(MAX) NULL,
    [competition_id] NVARCHAR(MAX) NULL,
    [yellow_cards] NVARCHAR(MAX) NULL,
    [red_cards] NVARCHAR(MAX) NULL,
    [goals] NVARCHAR(MAX) NULL,
    [assists] NVARCHAR(MAX) NULL,
    [minutes_played] NVARCHAR(MAX) NULL,
    [batch_id] NVARCHAR(MAX) NULL,
    [loaded_at] DATETIME NULL,
    [source_file] NVARCHAR(MAX) NULL
);
GO

DROP TABLE IF EXISTS [dbo].[stg_raw_clubs];
CREATE TABLE [dbo].[stg_raw_clubs] (
    [club_id] NVARCHAR(MAX) NULL,
    [club_code] NVARCHAR(MAX) NULL,
    [name] NVARCHAR(MAX) NULL,
    [domestic_competition_id] NVARCHAR(MAX) NULL,
    [total_market_value] NVARCHAR(MAX) NULL,
    [squad_size] NVARCHAR(MAX) NULL,
    [average_age] NVARCHAR(MAX) NULL,
    [foreigners_number] NVARCHAR(MAX) NULL,
    [foreigners_percentage] NVARCHAR(MAX) NULL,
    [national_team_players] NVARCHAR(MAX) NULL,
    [stadium_name] NVARCHAR(MAX) NULL,
    [stadium_seats] NVARCHAR(MAX) NULL,
    [net_transfer_record] NVARCHAR(MAX) NULL,
    [coach_name] NVARCHAR(MAX) NULL,
    [last_season] NVARCHAR(MAX) NULL,
    [filename] NVARCHAR(MAX) NULL,
    [url] NVARCHAR(MAX) NULL,
    [batch_id] NVARCHAR(MAX) NULL,
    [loaded_at] DATETIME NULL,
    [source_file] NVARCHAR(MAX) NULL
);
GO

DROP TABLE IF EXISTS [dbo].[stg_raw_club_games];
CREATE TABLE [dbo].[stg_raw_club_games] (
    [game_id] NVARCHAR(MAX) NULL,
    [club_id] NVARCHAR(MAX) NULL,
    [own_goals] NVARCHAR(MAX) NULL,
    [own_position] NVARCHAR(MAX) NULL,
    [own_manager_name] NVARCHAR(MAX) NULL,
    [opponent_id] NVARCHAR(MAX) NULL,
    [opponent_goals] NVARCHAR(MAX) NULL,
    [opponent_position] NVARCHAR(MAX) NULL,
    [opponent_manager_name] NVARCHAR(MAX) NULL,
    [hosting] NVARCHAR(MAX) NULL,
    [is_win] NVARCHAR(MAX) NULL,
    [batch_id] NVARCHAR(MAX) NULL,
    [loaded_at] DATETIME NULL,
    [source_file] NVARCHAR(MAX) NULL
);
GO

DROP TABLE IF EXISTS [dbo].[stg_raw_competitions];
CREATE TABLE [dbo].[stg_raw_competitions] (
    [competition_id] NVARCHAR(MAX) NULL,
    [competition_code] NVARCHAR(MAX) NULL,
    [name] NVARCHAR(MAX) NULL,
    [sub_type] NVARCHAR(MAX) NULL,
    [type] NVARCHAR(MAX) NULL,
    [country_id] NVARCHAR(MAX) NULL,
    [country_name] NVARCHAR(MAX) NULL,
    [domestic_league_code] NVARCHAR(MAX) NULL,
    [confederation] NVARCHAR(MAX) NULL,
    [total_clubs] NVARCHAR(MAX) NULL,
    [url] NVARCHAR(MAX) NULL,
    [batch_id] NVARCHAR(MAX) NULL,
    [loaded_at] DATETIME NULL,
    [source_file] NVARCHAR(MAX) NULL
);
GO

DROP TABLE IF EXISTS [dbo].[stg_raw_countries];
CREATE TABLE [dbo].[stg_raw_countries] (
    [country_id] NVARCHAR(MAX) NULL,
    [country_name] NVARCHAR(MAX) NULL,
    [country_code] NVARCHAR(MAX) NULL,
    [confederation] NVARCHAR(MAX) NULL,
    [total_clubs] NVARCHAR(MAX) NULL,
    [total_players] NVARCHAR(MAX) NULL,
    [average_age] NVARCHAR(MAX) NULL,
    [url] NVARCHAR(MAX) NULL,
    [batch_id] NVARCHAR(MAX) NULL,
    [loaded_at] DATETIME NULL,
    [source_file] NVARCHAR(MAX) NULL
);
GO

DROP TABLE IF EXISTS [dbo].[stg_raw_games];
CREATE TABLE [dbo].[stg_raw_games] (
    [game_id] NVARCHAR(MAX) NULL,
    [competition_id] NVARCHAR(MAX) NULL,
    [season] NVARCHAR(MAX) NULL,
    [round] NVARCHAR(MAX) NULL,
    [date] NVARCHAR(MAX) NULL,
    [home_club_id] NVARCHAR(MAX) NULL,
    [away_club_id] NVARCHAR(MAX) NULL,
    [home_club_goals] NVARCHAR(MAX) NULL,
    [away_club_goals] NVARCHAR(MAX) NULL,
    [home_club_position] NVARCHAR(MAX) NULL,
    [away_club_position] NVARCHAR(MAX) NULL,
    [home_club_manager_name] NVARCHAR(MAX) NULL,
    [away_club_manager_name] NVARCHAR(MAX) NULL,
    [stadium] NVARCHAR(MAX) NULL,
    [attendance] NVARCHAR(MAX) NULL,
    [referee] NVARCHAR(MAX) NULL,
    [url] NVARCHAR(MAX) NULL,
    [home_club_formation] NVARCHAR(MAX) NULL,
    [away_club_formation] NVARCHAR(MAX) NULL,
    [home_club_name] NVARCHAR(MAX) NULL,
    [away_club_name] NVARCHAR(MAX) NULL,
    [aggregate] NVARCHAR(MAX) NULL,
    [competition_type] NVARCHAR(MAX) NULL,
    [batch_id] NVARCHAR(MAX) NULL,
    [loaded_at] DATETIME NULL,
    [source_file] NVARCHAR(MAX) NULL
);
GO

DROP TABLE IF EXISTS [dbo].[stg_raw_national_teams];
CREATE TABLE [dbo].[stg_raw_national_teams] (
    [national_team_id] NVARCHAR(MAX) NULL,
    [name] NVARCHAR(MAX) NULL,
    [team_code] NVARCHAR(MAX) NULL,
    [country_id] NVARCHAR(MAX) NULL,
    [country_name] NVARCHAR(MAX) NULL,
    [country_code] NVARCHAR(MAX) NULL,
    [confederation] NVARCHAR(MAX) NULL,
    [team_image_url] NVARCHAR(MAX) NULL,
    [squad_size] NVARCHAR(MAX) NULL,
    [average_age] NVARCHAR(MAX) NULL,
    [foreigners_number] NVARCHAR(MAX) NULL,
    [foreigners_percentage] NVARCHAR(MAX) NULL,
    [total_market_value] NVARCHAR(MAX) NULL,
    [coach_name] NVARCHAR(MAX) NULL,
    [fifa_ranking] NVARCHAR(MAX) NULL,
    [last_season] NVARCHAR(MAX) NULL,
    [url] NVARCHAR(MAX) NULL,
    [batch_id] NVARCHAR(MAX) NULL,
    [loaded_at] DATETIME NULL,
    [source_file] NVARCHAR(MAX) NULL
);
GO

DROP TABLE IF EXISTS [dbo].[stg_raw_players];
CREATE TABLE [dbo].[stg_raw_players] (
    [player_id] NVARCHAR(MAX) NULL,
    [first_name] NVARCHAR(MAX) NULL,
    [last_name] NVARCHAR(MAX) NULL,
    [name] NVARCHAR(MAX) NULL,
    [last_season] NVARCHAR(MAX) NULL,
    [current_club_id] NVARCHAR(MAX) NULL,
    [player_code] NVARCHAR(MAX) NULL,
    [country_of_birth] NVARCHAR(MAX) NULL,
    [city_of_birth] NVARCHAR(MAX) NULL,
    [country_of_citizenship] NVARCHAR(MAX) NULL,
    [date_of_birth] NVARCHAR(MAX) NULL,
    [sub_position] NVARCHAR(MAX) NULL,
    [position] NVARCHAR(MAX) NULL,
    [foot] NVARCHAR(MAX) NULL,
    [height_in_cm] NVARCHAR(MAX) NULL,
    [contract_expiration_date] NVARCHAR(MAX) NULL,
    [agent_name] NVARCHAR(MAX) NULL,
    [image_url] NVARCHAR(MAX) NULL,
    [international_caps] NVARCHAR(MAX) NULL,
    [international_goals] NVARCHAR(MAX) NULL,
    [current_national_team_id] NVARCHAR(MAX) NULL,
    [url] NVARCHAR(MAX) NULL,
    [current_club_domestic_competition_id] NVARCHAR(MAX) NULL,
    [current_club_name] NVARCHAR(MAX) NULL,
    [market_value_in_eur] NVARCHAR(MAX) NULL,
    [highest_market_value_in_eur] NVARCHAR(MAX) NULL,
    [batch_id] NVARCHAR(MAX) NULL,
    [loaded_at] DATETIME NULL,
    [source_file] NVARCHAR(MAX) NULL
);
GO

DROP TABLE IF EXISTS [dbo].[stg_raw_player_valuations];
CREATE TABLE [dbo].[stg_raw_player_valuations] (
    [player_id] NVARCHAR(MAX) NULL,
    [date] NVARCHAR(MAX) NULL,
    [market_value_in_eur] NVARCHAR(MAX) NULL,
    [current_club_name] NVARCHAR(MAX) NULL,
    [current_club_id] NVARCHAR(MAX) NULL,
    [player_club_domestic_competition_id] NVARCHAR(MAX) NULL,
    [batch_id] NVARCHAR(MAX) NULL,
    [loaded_at] DATETIME NULL,
    [source_file] NVARCHAR(MAX) NULL
);
GO

DROP TABLE IF EXISTS [dbo].[stg_raw_transfers];
CREATE TABLE [dbo].[stg_raw_transfers] (
    [player_id] NVARCHAR(MAX) NULL,
    [transfer_date] NVARCHAR(MAX) NULL,
    [transfer_season] NVARCHAR(MAX) NULL,
    [from_club_id] NVARCHAR(MAX) NULL,
    [to_club_id] NVARCHAR(MAX) NULL,
    [from_club_name] NVARCHAR(MAX) NULL,
    [to_club_name] NVARCHAR(MAX) NULL,
    [transfer_fee] NVARCHAR(MAX) NULL,
    [market_value_in_eur] NVARCHAR(MAX) NULL,
    [player_name] NVARCHAR(MAX) NULL,
    [batch_id] NVARCHAR(MAX) NULL,
    [loaded_at] DATETIME NULL,
    [source_file] NVARCHAR(MAX) NULL
);
GO

-- ============================================================
-- Bang ghi dong loi (reject) cua cac data flow nap fact
-- ============================================================
DROP TABLE IF EXISTS dbo.etl_reject;
CREATE TABLE dbo.etl_reject (
    reject_id               BIGINT IDENTITY(1,1) PRIMARY KEY,
    batch_id                NVARCHAR(30)   NULL,
    source_table            NVARCHAR(100)  NOT NULL,      -- vd: stg_raw_appearances
    natural_key             NVARCHAR(200)  NULL,          -- vd: appearance_id
    reason                  NVARCHAR(200)  NOT NULL,      -- vd: minutes_played ngoài 0-130
    rejected_at             DATETIME       NOT NULL DEFAULT GETDATE()
);
GO
