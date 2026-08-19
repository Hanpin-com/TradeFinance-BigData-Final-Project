USE [LoblawRetailOperations];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DROP TABLE IF EXISTS retail._StagePromotions;
GO

CREATE TABLE retail._StagePromotions
(
    promotion_id    NVARCHAR(4000) NULL,
    product_id      NVARCHAR(4000) NULL,
    promotion_name  NVARCHAR(4000) NULL,
    start_date      NVARCHAR(4000) NULL,
    end_date        NVARCHAR(4000) NULL,
    discount_rate   NVARCHAR(4000) NULL
);
GO

BULK INSERT retail._StagePromotions
FROM '/data/promotions.csv'
WITH
(
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDQUOTE = '"',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
GO

IF EXISTS
(
    SELECT 1
    FROM retail._StagePromotions
    WHERE NULLIF(LTRIM(RTRIM(promotion_id)), N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(product_id)), N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(promotion_name)), N'') IS NULL
       OR TRY_CONVERT(DATE, start_date) IS NULL
       OR TRY_CONVERT(DATE, end_date) IS NULL
       OR TRY_CONVERT(DATE, end_date) < TRY_CONVERT(DATE, start_date)
       OR TRY_CONVERT(DECIMAL(6,4), REPLACE(discount_rate, CHAR(13), N'')) IS NULL
       OR TRY_CONVERT(DECIMAL(6,4), REPLACE(discount_rate, CHAR(13), N'')) <= 0
       OR TRY_CONVERT(DECIMAL(6,4), REPLACE(discount_rate, CHAR(13), N'')) > 1
)
BEGIN
    THROW 50003, 'promotions.csv contains invalid required values.', 1;
END;
GO

INSERT INTO retail.Promotions
(
    promotion_id,
    product_id,
    promotion_name,
    start_date,
    end_date,
    discount_rate
)
SELECT
    CONVERT(VARCHAR(5), LTRIM(RTRIM(REPLACE(promotion_id, CHAR(13), N'')))),
    CONVERT(VARCHAR(4), LTRIM(RTRIM(REPLACE(product_id, CHAR(13), N'')))),
    CONVERT(NVARCHAR(100), LTRIM(RTRIM(REPLACE(promotion_name, CHAR(13), N'')))),
    CONVERT(DATE, start_date),
    CONVERT(DATE, end_date),
    CONVERT(DECIMAL(6,4), REPLACE(discount_rate, CHAR(13), N''))
FROM retail._StagePromotions;
GO

DROP TABLE retail._StagePromotions;
GO
