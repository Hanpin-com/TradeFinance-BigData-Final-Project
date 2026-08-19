USE [LoblawRetailOperations];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

DROP TABLE IF EXISTS retail._StageStores;
GO

CREATE TABLE retail._StageStores
(
    store_id      NVARCHAR(4000) NULL,
    store_city    NVARCHAR(4000) NULL,
    province      NVARCHAR(4000) NULL,
    store_region  NVARCHAR(4000) NULL
);
GO

BULK INSERT retail._StageStores
FROM '/data/stores.csv'
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
    FROM retail._StageStores
    WHERE NULLIF(LTRIM(RTRIM(store_id)), N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(store_city)), N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(province)), N'') IS NULL
       OR NULLIF(LTRIM(RTRIM(REPLACE(store_region, CHAR(13), N''))), N'') IS NULL
)
BEGIN
    THROW 50002, 'stores.csv contains invalid required values.', 1;
END;
GO

INSERT INTO retail.Stores
(
    store_id,
    store_city,
    province,
    store_region
)
SELECT
    CONVERT(VARCHAR(10), LTRIM(RTRIM(REPLACE(store_id, CHAR(13), N'')))),
    CONVERT(NVARCHAR(100), LTRIM(RTRIM(REPLACE(store_city, CHAR(13), N'')))),
    CONVERT(NVARCHAR(30), LTRIM(RTRIM(REPLACE(province, CHAR(13), N'')))),
    CONVERT(NVARCHAR(30), LTRIM(RTRIM(REPLACE(store_region, CHAR(13), N''))))
FROM retail._StageStores;
GO

DROP TABLE retail._StageStores;
GO
