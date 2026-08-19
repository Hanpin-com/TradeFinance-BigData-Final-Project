IF DB_ID(N'LoblawRetailOperations') IS NULL
BEGIN
    EXEC(N'CREATE DATABASE [LoblawRetailOperations]');
END;
GO
