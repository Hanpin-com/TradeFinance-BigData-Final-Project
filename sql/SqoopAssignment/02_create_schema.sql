USE [LoblawRetailOperations];
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.schemas
    WHERE name = N'retail'
)
BEGIN
    EXEC(N'CREATE SCHEMA [retail]');
END;
GO

/* Lookup tables */

IF OBJECT_ID(N'retail.ProductCategories', N'U') IS NULL
BEGIN
    CREATE TABLE retail.ProductCategories
    (
        category NVARCHAR(30) NOT NULL,
        CONSTRAINT PK_ProductCategories PRIMARY KEY (category)
    );
END;
GO

IF OBJECT_ID(N'retail.Provinces', N'U') IS NULL
BEGIN
    CREATE TABLE retail.Provinces
    (
        province NVARCHAR(30) NOT NULL,
        CONSTRAINT PK_Provinces PRIMARY KEY (province)
    );
END;
GO

IF OBJECT_ID(N'retail.StoreRegions', N'U') IS NULL
BEGIN
    CREATE TABLE retail.StoreRegions
    (
        store_region NVARCHAR(30) NOT NULL,
        CONSTRAINT PK_StoreRegions PRIMARY KEY (store_region)
    );
END;
GO

IF OBJECT_ID(N'retail.PaymentTypes', N'U') IS NULL
BEGIN
    CREATE TABLE retail.PaymentTypes
    (
        payment_type NVARCHAR(20) NOT NULL,
        CONSTRAINT PK_PaymentTypes PRIMARY KEY (payment_type)
    );
END;
GO

/* Main source tables */

IF OBJECT_ID(N'retail.Products', N'U') IS NULL
BEGIN
    CREATE TABLE retail.Products
    (
        product_id       VARCHAR(4)     NOT NULL,
        product_name     NVARCHAR(100)  NOT NULL,
        category         NVARCHAR(30)   NOT NULL,
        base_unit_price  DECIMAL(12,2)  NOT NULL,

        CONSTRAINT PK_Products
            PRIMARY KEY (product_id),

        CONSTRAINT FK_Products_ProductCategories
            FOREIGN KEY (category)
            REFERENCES retail.ProductCategories(category),

        CONSTRAINT CK_Products_BaseUnitPrice
            CHECK (base_unit_price > 0)
    );
END;
GO

IF OBJECT_ID(N'retail.Stores', N'U') IS NULL
BEGIN
    CREATE TABLE retail.Stores
    (
        store_id      VARCHAR(10)    NOT NULL,
        store_city    NVARCHAR(100)  NOT NULL,
        province      NVARCHAR(30)   NOT NULL,
        store_region  NVARCHAR(30)   NOT NULL,

        CONSTRAINT PK_Stores
            PRIMARY KEY (store_id),

        CONSTRAINT FK_Stores_Provinces
            FOREIGN KEY (province)
            REFERENCES retail.Provinces(province),

        CONSTRAINT FK_Stores_StoreRegions
            FOREIGN KEY (store_region)
            REFERENCES retail.StoreRegions(store_region)
    );
END;
GO

IF OBJECT_ID(N'retail.Promotions', N'U') IS NULL
BEGIN
    CREATE TABLE retail.Promotions
    (
        promotion_id    VARCHAR(5)     NOT NULL,
        product_id      VARCHAR(4)     NOT NULL,
        promotion_name  NVARCHAR(100)  NOT NULL,
        start_date      DATE           NOT NULL,
        end_date        DATE           NOT NULL,
        discount_rate   DECIMAL(6,4)   NOT NULL,

        CONSTRAINT PK_Promotions
            PRIMARY KEY (promotion_id),

        CONSTRAINT FK_Promotions_Products
            FOREIGN KEY (product_id)
            REFERENCES retail.Products(product_id),

        CONSTRAINT CK_Promotions_DateRange
            CHECK (end_date >= start_date),

        CONSTRAINT CK_Promotions_DiscountRate
            CHECK (discount_rate > 0 AND discount_rate <= 1)
    );
END;
GO

IF OBJECT_ID(N'retail.RetailEvents', N'U') IS NULL
BEGIN
    CREATE TABLE retail.RetailEvents
    (
        event_id         VARCHAR(12)    NOT NULL,
        transaction_id   VARCHAR(11)    NOT NULL,
        store_id         VARCHAR(10)    NOT NULL,
        store_city       NVARCHAR(100)  NOT NULL,
        province         NVARCHAR(30)   NOT NULL,
        store_region     NVARCHAR(30)   NOT NULL,
        event_timestamp  DATETIME2(0)   NOT NULL,
        product_id       VARCHAR(4)     NOT NULL,
        product_name     NVARCHAR(100)  NOT NULL,
        category         NVARCHAR(30)   NOT NULL,
        quantity         SMALLINT       NOT NULL,
        unit_price       DECIMAL(12,2)  NOT NULL,
        discount_amount  DECIMAL(12,2)  NOT NULL,
        final_price      DECIMAL(12,2)  NOT NULL,
        promotion_flag   CHAR(1)        NOT NULL,
        promotion_id     VARCHAR(5)     NULL,
        payment_type     NVARCHAR(20)   NOT NULL,
        loyalty_flag     CHAR(1)        NOT NULL,

        CONSTRAINT PK_RetailEvents
            PRIMARY KEY (event_id),

        CONSTRAINT FK_RetailEvents_Stores
            FOREIGN KEY (store_id)
            REFERENCES retail.Stores(store_id),

        CONSTRAINT FK_RetailEvents_Products
            FOREIGN KEY (product_id)
            REFERENCES retail.Products(product_id),

        CONSTRAINT FK_RetailEvents_Promotions
            FOREIGN KEY (promotion_id)
            REFERENCES retail.Promotions(promotion_id),

        CONSTRAINT FK_RetailEvents_ProductCategories
            FOREIGN KEY (category)
            REFERENCES retail.ProductCategories(category),

        CONSTRAINT FK_RetailEvents_Provinces
            FOREIGN KEY (province)
            REFERENCES retail.Provinces(province),

        CONSTRAINT FK_RetailEvents_StoreRegions
            FOREIGN KEY (store_region)
            REFERENCES retail.StoreRegions(store_region),

        CONSTRAINT FK_RetailEvents_PaymentTypes
            FOREIGN KEY (payment_type)
            REFERENCES retail.PaymentTypes(payment_type),

        CONSTRAINT CK_RetailEvents_Quantity
            CHECK (quantity > 0),

        CONSTRAINT CK_RetailEvents_UnitPrice
            CHECK (unit_price > 0),

        CONSTRAINT CK_RetailEvents_DiscountAmount
            CHECK (discount_amount >= 0),

        CONSTRAINT CK_RetailEvents_FinalPrice
            CHECK (final_price >= 0),

        CONSTRAINT CK_RetailEvents_PromotionFlag
            CHECK (promotion_flag IN ('Y', 'N')),

        CONSTRAINT CK_RetailEvents_LoyaltyFlag
            CHECK (loyalty_flag IN ('Y', 'N')),

        CONSTRAINT CK_RetailEvents_PromotionReference
            CHECK
            (
                (promotion_flag = 'N' AND promotion_id IS NULL)
                OR
                (promotion_flag = 'Y' AND promotion_id IS NOT NULL)
            )
    );
END;
GO

/* Metadata from data_dictionary.csv */

IF OBJECT_ID(N'retail.SourceDataDictionary', N'U') IS NULL
BEGIN
    CREATE TABLE retail.SourceDataDictionary
    (
        field_name       NVARCHAR(100) NOT NULL,
        generated_dtype  NVARCHAR(100) NOT NULL,
        dataset          NVARCHAR(255) NOT NULL,

        CONSTRAINT PK_SourceDataDictionary
            PRIMARY KEY (dataset, field_name)
    );
END;
GO

/* Raw quarantine table for intentionally malformed source rows */

IF OBJECT_ID(N'retail.RejectedRetailEvents', N'U') IS NULL
BEGIN
    CREATE TABLE retail.RejectedRetailEvents
    (
        rejected_id       INT IDENTITY(1,1) NOT NULL,
        event_id           NVARCHAR(100) NULL,
        transaction_id     NVARCHAR(100) NULL,
        store_id           NVARCHAR(100) NULL,
        store_city         NVARCHAR(100) NULL,
        province           NVARCHAR(100) NULL,
        store_region       NVARCHAR(100) NULL,
        event_timestamp    NVARCHAR(100) NULL,
        product_id         NVARCHAR(100) NULL,
        product_name       NVARCHAR(200) NULL,
        category           NVARCHAR(100) NULL,
        quantity           NVARCHAR(100) NULL,
        unit_price         NVARCHAR(100) NULL,
        discount_amount    NVARCHAR(100) NULL,
        final_price        NVARCHAR(100) NULL,
        promotion_flag     NVARCHAR(100) NULL,
        promotion_id       NVARCHAR(100) NULL,
        payment_type       NVARCHAR(100) NULL,
        loyalty_flag       NVARCHAR(100) NULL,
        rejection_reason   NVARCHAR(1000) NOT NULL,
        rejected_at        DATETIME2(0) NOT NULL
            CONSTRAINT DF_RejectedRetailEvents_RejectedAt DEFAULT SYSUTCDATETIME(),

        CONSTRAINT PK_RejectedRetailEvents
            PRIMARY KEY (rejected_id)
    );
END;
GO

/* Useful indexes for Sqoop and analytical queries */

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'retail.RetailEvents')
      AND name = N'IX_RetailEvents_Transaction'
)
BEGIN
    CREATE INDEX IX_RetailEvents_Transaction
        ON retail.RetailEvents(transaction_id);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'retail.RetailEvents')
      AND name = N'IX_RetailEvents_Timestamp'
)
BEGIN
    CREATE INDEX IX_RetailEvents_Timestamp
        ON retail.RetailEvents(event_timestamp);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'retail.RetailEvents')
      AND name = N'IX_RetailEvents_Store'
)
BEGIN
    CREATE INDEX IX_RetailEvents_Store
        ON retail.RetailEvents(store_id);
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE object_id = OBJECT_ID(N'retail.RetailEvents')
      AND name = N'IX_RetailEvents_Product'
)
BEGIN
    CREATE INDEX IX_RetailEvents_Product
        ON retail.RetailEvents(product_id);
END;
GO
