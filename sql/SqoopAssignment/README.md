Updated for Dockerized SQL Server.

Expected docker-compose mounts:

  - ./data:/data:ro
  - ./sqlserver/init:/docker-entrypoint-initdb.d:ro

All BULK INSERT/OpenRowset paths must reference:

/data/products.csv
/data/stores.csv
/data/promotions.csv
/data/retail_events.csv
/data/data_dictionary.csv
/data/malformed_retail_events.csv
