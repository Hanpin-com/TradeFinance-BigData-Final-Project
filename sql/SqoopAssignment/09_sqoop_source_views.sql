USE [LoblawRetailOperations];
GO

CREATE OR ALTER VIEW retail.vProducts
AS
SELECT
    product_id,
    product_name,
    category,
    base_unit_price
FROM retail.Products;
GO

CREATE OR ALTER VIEW retail.vStores
AS
SELECT
    store_id,
    store_city,
    province,
    store_region
FROM retail.Stores;
GO

CREATE OR ALTER VIEW retail.vPromotions
AS
SELECT
    promotion_id,
    product_id,
    promotion_name,
    start_date,
    end_date,
    discount_rate
FROM retail.Promotions;
GO

CREATE OR ALTER VIEW retail.vRetailEvents
AS
SELECT
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
FROM retail.RetailEvents;
GO

CREATE OR ALTER VIEW retail.vTransactionSummary
AS
SELECT
    transaction_id,
    store_id,
    MIN(event_timestamp) AS transaction_timestamp,
    COUNT_BIG(*) AS product_line_count,
    SUM(CONVERT(BIGINT, quantity)) AS total_quantity,
    SUM(final_price) AS transaction_value,
    MAX(payment_type) AS payment_type,
    MAX(loyalty_flag) AS loyalty_flag
FROM retail.RetailEvents
GROUP BY
    transaction_id,
    store_id;
GO

CREATE OR ALTER VIEW retail.vStoreSalesSummary
AS
SELECT
    store_id,
    store_city,
    province,
    store_region,
    COUNT_BIG(*) AS product_sale_events,
    COUNT(DISTINCT transaction_id) AS transaction_count,
    SUM(CONVERT(BIGINT, quantity)) AS units_sold,
    SUM(final_price) AS total_sales
FROM retail.RetailEvents
GROUP BY
    store_id,
    store_city,
    province,
    store_region;
GO
