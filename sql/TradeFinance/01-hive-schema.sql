CREATE DATABASE IF NOT EXISTS trade_finance;
USE trade_finance;

CREATE EXTERNAL TABLE IF NOT EXISTS trade_transactions_hbase (
  transaction_id STRING,
  product_type STRING,
  status STRING,
  issue_date STRING,
  expiry_date STRING,
  currency STRING,
  amount DOUBLE,
  applicant_id STRING,
  beneficiary_id STRING,
  applicant_country STRING,
  beneficiary_country STRING,
  goods_category STRING,
  amendment_count INT,
  document_count INT,
  processing_days INT,
  discrepancy_flag INT,
  delay_flag INT
)
STORED BY 'org.apache.hadoop.hive.hbase.HBaseStorageHandler'
WITH SERDEPROPERTIES (
 "hbase.columns.mapping"=":key,instrument:product_type,instrument:status,instrument:issue_date,instrument:expiry_date,financial:currency,financial:amount,parties:applicant_id,parties:beneficiary_id,geography:applicant_country,geography:beneficiary_country,trade:goods_category,metrics:amendment_count,metrics:document_count,metrics:processing_days,metrics:discrepancy_flag,metrics:delay_flag"
)
TBLPROPERTIES ("hbase.table.name"="trade_transactions");

CREATE EXTERNAL TABLE IF NOT EXISTS trade_ml_results_hbase (
  result_key STRING,
  model_name STRING,
  model_version STRING,
  anomaly_score DOUBLE,
  risk_class STRING,
  probability DOUBLE,
  expected_days DOUBLE,
  forecast_month STRING,
  predicted_transactions DOUBLE,
  prediction_timestamp STRING
)
STORED BY 'org.apache.hadoop.hive.hbase.HBaseStorageHandler'
WITH SERDEPROPERTIES (
 "hbase.columns.mapping"=":key,model:name,model:version,prediction:score,prediction:class,prediction:probability,prediction:expected_days,prediction:forecast_month,prediction:predicted_transactions,audit:prediction_timestamp"
)
TBLPROPERTIES ("hbase.table.name"="trade_ml_results");

CREATE OR REPLACE VIEW tf_trade_portfolio AS
SELECT product_type,status,currency,applicant_country,beneficiary_country,
       COUNT(*) AS transaction_count,
       SUM(amount) AS total_value,
       AVG(amount) AS avg_transaction_value,
       AVG(processing_days) AS avg_processing_days,
       AVG(discrepancy_flag) AS discrepancy_rate,
       AVG(delay_flag) AS delay_rate
FROM trade_transactions_hbase
GROUP BY product_type,status,currency,applicant_country,beneficiary_country;

CREATE OR REPLACE VIEW tf_corridor_performance AS
SELECT applicant_country,beneficiary_country,
       COUNT(*) AS transaction_count,
       SUM(amount) AS total_value,
       AVG(amount) AS avg_transaction_value,
       AVG(processing_days) AS avg_processing_days,
       AVG(discrepancy_flag) AS discrepancy_rate,
       AVG(delay_flag) AS delay_rate
FROM trade_transactions_hbase
GROUP BY applicant_country,beneficiary_country;

CREATE OR REPLACE VIEW tf_documentary_operations AS
SELECT product_type,
       COUNT(*) AS transaction_count,
       SUM(document_count) AS document_count,
       AVG(discrepancy_flag) AS discrepancy_rate,
       AVG(processing_days) AS avg_processing_days
FROM trade_transactions_hbase
GROUP BY product_type;

CREATE OR REPLACE VIEW tf_sla_performance AS
SELECT product_type,
       COUNT(*) AS transaction_count,
       SUM(CASE WHEN processing_days <= 10 THEN 1 ELSE 0 END) AS within_sla,
       SUM(CASE WHEN processing_days > 10 THEN 1 ELSE 0 END) AS sla_breaches,
       AVG(processing_days) AS avg_processing_days
FROM trade_transactions_hbase
GROUP BY product_type;

CREATE OR REPLACE VIEW tf_risk_summary AS
SELECT applicant_country,beneficiary_country,product_type,
       COUNT(*) AS transaction_count,
       SUM(amount) AS exposure_value,
       AVG(discrepancy_flag) AS discrepancy_rate,
       AVG(delay_flag) AS delay_rate
FROM trade_transactions_hbase
GROUP BY applicant_country,beneficiary_country,product_type;
