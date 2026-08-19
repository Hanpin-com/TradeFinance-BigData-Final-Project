USE [LoblawRetailOperations];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DROP TABLE IF EXISTS retail._StageRetailEvents;
GO

CREATE TABLE retail._StageRetailEvents
(
    event_id          NVARCHAR(4000) NULL,
    transaction_id    NVARCHAR(4000) NULL,
    store_id          NVARCHAR(4000) NULL,
    store_city        NVARCHAR(4000) NULL,
    province          NVARCHAR(4000) NULL,
    store_region      NVARCHAR(4000) NULL,
    event_timestamp   NVARCHAR(4000) NULL,
    product_id        NVARCHAR(4000) NULL,
    product_name      NVARCHAR(4000) NULL,
    category          NVARCHAR(4000) NULL,
    quantity          NVARCHAR(4000) NULL,
    unit_price        NVARCHAR(4000) NULL,
    discount_amount   NVARCHAR(4000) NULL,
    final_price       NVARCHAR(4000) NULL,
    promotion_flag    NVARCHAR(4000) NULL,
    promotion_id      NVARCHAR(4000) NULL,
    payment_type      NVARCHAR(4000) NULL,
    loyalty_flag      NVARCHAR(4000) NULL
);
GO

BULK INSERT retail._StageRetailEvents
FROM '/data/retail_events.csv'
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
    FROM retail._StageRetailEvents
    WHERE NULLIF(LTRIM(RTRIM(event_id)), N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(transaction_id)), N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(store_id)), N'') IS NULL
       OR TRY_CONVERT(DATETIME2(0), event_timestamp) IS NULL
       OR NULLIF(LTRIM(RTRIM(product_id)), N'') IS NULL
       OR TRY_CONVERT(SMALLINT, quantity) IS NULL
       OR TRY_CONVERT(SMALLINT, quantity) <= 0
       OR TRY_CONVERT(DECIMAL(12,2), unit_price) IS NULL
       OR TRY_CONVERT(DECIMAL(12,2), unit_price) <= 0
       OR TRY_CONVERT(DECIMAL(12,2), discount_amount) IS NULL
       OR TRY_CONVERT(DECIMAL(12,2), discount_amount) < 0
       OR TRY_CONVERT(DECIMAL(12,2), final_price) IS NULL
       OR TRY_CONVERT(DECIMAL(12,2), final_price) < 0
       OR LTRIM(RTRIM(promotion_flag)) NOT IN (N'Y', N'N')
       OR LTRIM(RTRIM(REPLACE(loyalty_flag, CHAR(13), N''))) NOT IN (N'Y', N'N')
       OR
       (
           LTRIM(RTRIM(promotion_flag)) = N'Y'
           AND NULLIF(LTRIM(RTRIM(promotion_id)), N'') IS NULL
       )
       OR
       (
           LTRIM(RTRIM(promotion_flag)) = N'N'
           AND NULLIF(LTRIM(RTRIM(promotion_id)), N'') IS NOT NULL
       )
)
BEGIN
    THROW 50004, 'retail_events.csv contains invalid required values.', 1;
END;
GO

INSERT INTO retail.RetailEvents
(
    event_id,
    transaction_id,
    store_id,
    store_city,
    province,
    store_region,
    event_timestamp,
    product_id,
    product_name,
    category,
    quantity,
    unit_price,
    discount_amount,
    final_price,
    promotion_flag,
    promotion_id,
    payment_type,
    loyalty_flag
)
SELECT
    CONVERT(VARCHAR(12), LTRIM(RTRIM(REPLACE(event_id, CHAR(13), N'')))),
    CONVERT(VARCHAR(11), LTRIM(RTRIM(REPLACE(transaction_id, CHAR(13), N'')))),
    CONVERT(VARCHAR(10), LTRIM(RTRIM(REPLACE(store_id, CHAR(13), N'')))),
    CONVERT(NVARCHAR(100), LTRIM(RTRIM(REPLACE(store_city, CHAR(13), N'')))),
    CONVERT(NVARCHAR(30), LTRIM(RTRIM(REPLACE(province, CHAR(13), N'')))),
    CONVERT(NVARCHAR(30), LTRIM(RTRIM(REPLACE(store_region, CHAR(13), N'')))),
    CONVERT(DATETIME2(0), event_timestamp),
    CONVERT(VARCHAR(4), LTRIM(RTRIM(REPLACE(product_id, CHAR(13), N'')))),
    CONVERT(NVARCHAR(100), LTRIM(RTRIM(REPLACE(product_name, CHAR(13), N'')))),
    CONVERT(NVARCHAR(30), LTRIM(RTRIM(REPLACE(category, CHAR(13), N'')))),
    CONVERT(SMALLINT, quantity),
    CONVERT(DECIMAL(12,2), unit_price),
    CONVERT(DECIMAL(12,2), discount_amount),
    CONVERT(DECIMAL(12,2), final_price),
    CONVERT(CHAR(1), LTRIM(RTRIM(promotion_flag))),
    CONVERT(VARCHAR(5), NULLIF(LTRIM(RTRIM(promotion_id)), N'')),
    CONVERT(NVARCHAR(20), LTRIM(RTRIM(REPLACE(payment_type, CHAR(13), N'')))),
    CONVERT(CHAR(1), LTRIM(RTRIM(REPLACE(loyalty_flag, CHAR(13), N''))))
FROM retail._StageRetailEvents;
GO

DROP TABLE retail._StageRetailEvents;
GO
