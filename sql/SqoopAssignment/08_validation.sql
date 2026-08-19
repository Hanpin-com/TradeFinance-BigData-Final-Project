USE [LoblawRetailOperations];
GO

SET NOCOUNT ON;
GO

SELECT N'ProductCategories' AS table_name, COUNT_BIG(*) AS record_count
FROM retail.ProductCategories
UNION ALL
SELECT N'Provinces', COUNT_BIG(*)
FROM retail.Provinces
UNION ALL
SELECT N'StoreRegions', COUNT_BIG(*)
FROM retail.StoreRegions
UNION ALL
SELECT N'PaymentTypes', COUNT_BIG(*)
FROM retail.PaymentTypes
UNION ALL
SELECT N'Products', COUNT_BIG(*)
FROM retail.Products
UNION ALL
SELECT N'Stores', COUNT_BIG(*)
FROM retail.Stores
UNION ALL
SELECT N'Promotions', COUNT_BIG(*)
FROM retail.Promotions
UNION ALL
SELECT N'RetailEvents', COUNT_BIG(*)
FROM retail.RetailEvents
UNION ALL
SELECT N'SourceDataDictionary', COUNT_BIG(*)
FROM retail.SourceDataDictionary
UNION ALL
SELECT N'RejectedRetailEvents', COUNT_BIG(*)
FROM retail.RejectedRetailEvents;
GO

IF (SELECT COUNT_BIG(*) FROM retail.Products) <> 45
    THROW 51001, 'Validation failed: retail.Products must contain 45 rows.', 1;

IF (SELECT COUNT_BIG(*) FROM retail.Stores) <> 12
    THROW 51002, 'Validation failed: retail.Stores must contain 12 rows.', 1;

IF (SELECT COUNT_BIG(*) FROM retail.Promotions) <> 8
    THROW 51003, 'Validation failed: retail.Promotions must contain 8 rows.', 1;

IF (SELECT COUNT_BIG(*) FROM retail.RetailEvents) <> 38143
    THROW 51004, 'Validation failed: retail.RetailEvents must contain 38,143 rows.', 1;

IF (SELECT COUNT_BIG(*) FROM retail.SourceDataDictionary) <> 18
    THROW 51005, 'Validation failed: retail.SourceDataDictionary must contain 18 rows.', 1;

IF (SELECT COUNT_BIG(*) FROM retail.RejectedRetailEvents) <> 2
    THROW 51006, 'Validation failed: retail.RejectedRetailEvents must contain 2 rows.', 1;
GO

IF EXISTS
(
    SELECT 1
    FROM retail.RetailEvents event_row
    LEFT JOIN retail.Products product
        ON product.product_id = event_row.product_id
    WHERE product.product_id IS NULL
)
    THROW 51007, 'Validation failed: retail events contain unknown products.', 1;

IF EXISTS
(
    SELECT 1
    FROM retail.RetailEvents event_row
    LEFT JOIN retail.Stores store_row
        ON store_row.store_id = event_row.store_id
    WHERE store_row.store_id IS NULL
)
    THROW 51008, 'Validation failed: retail events contain unknown stores.', 1;

IF EXISTS
(
    SELECT 1
    FROM retail.RetailEvents event_row
    LEFT JOIN retail.Promotions promotion
        ON promotion.promotion_id = event_row.promotion_id
    WHERE event_row.promotion_id IS NOT NULL
      AND promotion.promotion_id IS NULL
)
    THROW 51009, 'Validation failed: retail events contain unknown promotions.', 1;
GO

SELECT
    COUNT_BIG(*) AS product_sale_events,
    COUNT(DISTINCT transaction_id) AS transactions,
    MIN(event_timestamp) AS first_event,
    MAX(event_timestamp) AS last_event,
    SUM(final_price) AS total_sales
FROM retail.RetailEvents;
GO

SELECT TOP (5)
    *
FROM retail.RetailEvents
ORDER BY event_timestamp, event_id;
GO

PRINT 'All LoblawRetailOperations validation checks passed.';
GO
