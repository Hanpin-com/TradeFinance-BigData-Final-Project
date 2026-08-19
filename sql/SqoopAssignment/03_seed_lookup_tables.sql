USE [LoblawRetailOperations];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRANSACTION;

INSERT INTO retail.ProductCategories (category)
SELECT source.category
FROM
(
    VALUES
        (N'Bakery'),
        (N'Dairy'),
        (N'Frozen'),
        (N'Grocery'),
        (N'Household'),
        (N'Meat'),
        (N'Personal Care'),
        (N'Produce')
) AS source(category)
WHERE NOT EXISTS
(
    SELECT 1
    FROM retail.ProductCategories target
    WHERE target.category = source.category
);

INSERT INTO retail.Provinces (province)
SELECT source.province
FROM
(
    VALUES
        (N'Alberta'),
        (N'Ontario')
) AS source(province)
WHERE NOT EXISTS
(
    SELECT 1
    FROM retail.Provinces target
    WHERE target.province = source.province
);

INSERT INTO retail.StoreRegions (store_region)
SELECT source.store_region
FROM
(
    VALUES
        (N'Central'),
        (N'Eastern'),
        (N'Western')
) AS source(store_region)
WHERE NOT EXISTS
(
    SELECT 1
    FROM retail.StoreRegions target
    WHERE target.store_region = source.store_region
);

INSERT INTO retail.PaymentTypes (payment_type)
SELECT source.payment_type
FROM
(
    VALUES
        (N'Cash'),
        (N'Credit'),
        (N'Debit'),
        (N'Mobile')
) AS source(payment_type)
WHERE NOT EXISTS
(
    SELECT 1
    FROM retail.PaymentTypes target
    WHERE target.payment_type = source.payment_type
);

COMMIT TRANSACTION;
GO

/* Import data_dictionary.csv */

DROP TABLE IF EXISTS retail._StageDataDictionary;
GO

CREATE TABLE retail._StageDataDictionary
(
    field_name       NVARCHAR(4000) NULL,
    generated_dtype  NVARCHAR(4000) NULL,
    dataset          NVARCHAR(4000) NULL
);
GO

BULK INSERT retail._StageDataDictionary
FROM '/data/data_dictionary.csv'
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

DELETE FROM retail.SourceDataDictionary;
GO

INSERT INTO retail.SourceDataDictionary
(
    field_name,
    generated_dtype,
    dataset
)
SELECT
    LTRIM(RTRIM(REPLACE(field_name, CHAR(13), N''))),
    LTRIM(RTRIM(REPLACE(generated_dtype, CHAR(13), N''))),
    LTRIM(RTRIM(REPLACE(dataset, CHAR(13), N'')))
FROM retail._StageDataDictionary;
GO

DROP TABLE retail._StageDataDictionary;
GO

/* Preserve malformed_retail_events.csv in the quarantine table.
   These rows are intentionally NOT loaded into retail.RetailEvents. */

DROP TABLE IF EXISTS retail._StageMalformedRetailEvents;
GO

CREATE TABLE retail._StageMalformedRetailEvents
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

BULK INSERT retail._StageMalformedRetailEvents
FROM '/data/malformed_retail_events.csv'
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

DELETE FROM retail.RejectedRetailEvents;
GO

INSERT INTO retail.RejectedRetailEvents
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
    loyalty_flag,
    rejection_reason
)
SELECT
    NULLIF(LTRIM(RTRIM(REPLACE(event_id, CHAR(13), N''))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(transaction_id, CHAR(13), N''))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(store_id, CHAR(13), N''))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(store_city, CHAR(13), N''))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(province, CHAR(13), N''))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(store_region, CHAR(13), N''))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(event_timestamp, CHAR(13), N''))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(product_id, CHAR(13), N''))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(product_name, CHAR(13), N''))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(category, CHAR(13), N''))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(quantity, CHAR(13), N''))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(unit_price, CHAR(13), N''))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(discount_amount, CHAR(13), N''))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(final_price, CHAR(13), N''))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(promotion_flag, CHAR(13), N''))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(promotion_id, CHAR(13), N''))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(payment_type, CHAR(13), N''))), N''),
    NULLIF(LTRIM(RTRIM(REPLACE(loyalty_flag, CHAR(13), N''))), N''),
    COALESCE
    (
        NULLIF
        (
            CONCAT_WS
            (
                N'; ',
                CASE
                    WHEN NULLIF(LTRIM(RTRIM(transaction_id)), N'') IS NULL
                    THEN N'Missing transaction_id'
                END,
                CASE
                    WHEN TRY_CONVERT(DATETIME2(0), event_timestamp) IS NULL
                    THEN N'Invalid event_timestamp'
                END,
                CASE
                    WHEN TRY_CONVERT(INT, quantity) IS NULL
                      OR TRY_CONVERT(INT, quantity) <= 0
                    THEN N'Invalid quantity'
                END,
                CASE
                    WHEN TRY_CONVERT(DECIMAL(12,2), unit_price) IS NULL
                      OR TRY_CONVERT(DECIMAL(12,2), unit_price) <= 0
                    THEN N'Invalid unit_price'
                END,
                CASE
                    WHEN TRY_CONVERT(DECIMAL(12,2), final_price) IS NULL
                      OR TRY_CONVERT(DECIMAL(12,2), final_price) < 0
                    THEN N'Invalid final_price'
                END
            ),
            N''
        ),
        N'Failed source-data validation'
    )
FROM retail._StageMalformedRetailEvents;
GO

DROP TABLE retail._StageMalformedRetailEvents;
GO
