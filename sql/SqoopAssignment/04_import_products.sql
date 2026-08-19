USE [LoblawRetailOperations];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DROP TABLE IF EXISTS retail._StageProducts;
GO

CREATE TABLE retail._StageProducts
(
    product_id       NVARCHAR(4000) NULL,
    product_name     NVARCHAR(4000) NULL,
    category         NVARCHAR(4000) NULL,
    base_unit_price  NVARCHAR(4000) NULL
);
GO

BULK INSERT retail._StageProducts
FROM '/data/products.csv'
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
    FROM retail._StageProducts
    WHERE NULLIF(LTRIM(RTRIM(product_id)), N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(product_name)), N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(category)), N'') IS NULL
       OR TRY_CONVERT(DECIMAL(12,2), REPLACE(base_unit_price, CHAR(13), N'')) IS NULL
       OR TRY_CONVERT(DECIMAL(12,2), REPLACE(base_unit_price, CHAR(13), N'')) <= 0
)
BEGIN
    THROW 50001, 'products.csv contains invalid required values.', 1;
END;
GO

INSERT INTO retail.Products
(
    product_id,
    product_name,
    category,
    base_unit_price
)
SELECT
    CONVERT(VARCHAR(4), LTRIM(RTRIM(REPLACE(product_id, CHAR(13), N'')))),
    CONVERT(NVARCHAR(100), LTRIM(RTRIM(REPLACE(product_name, CHAR(13), N'')))),
    CONVERT(NVARCHAR(30), LTRIM(RTRIM(REPLACE(category, CHAR(13), N'')))),
    CONVERT(DECIMAL(12,2), REPLACE(base_unit_price, CHAR(13), N''))
FROM retail._StageProducts;
GO

DROP TABLE retail._StageProducts;
GO
