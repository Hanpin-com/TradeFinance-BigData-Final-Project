CREATE DATABASE IF NOT EXISTS trade_finance;
USE trade_finance;

-- This is an EXTERNAL table, so replacing Hive metadata does not delete HBase data.
DROP TABLE IF EXISTS trade_transactions_hbase;

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
  delay_flag INT,
  customer_risk_rating STRING
)
STORED BY 'org.apache.hadoop.hive.hbase.HBaseStorageHandler'
WITH SERDEPROPERTIES (
 "hbase.columns.mapping"=":key,instrument:product_type,instrument:status,instrument:issue_date,instrument:expiry_date,financial:currency,financial:amount,parties:applicant_id,parties:beneficiary_id,geography:applicant_country,geography:beneficiary_country,trade:goods_category,metrics:amendment_count,metrics:document_count,metrics:processing_days,metrics:discrepancy_flag,metrics:delay_flag,risk:customer_risk_rating"
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

-- Fixed synthetic rates make every portfolio exposure comparable in CAD.
-- Each rate represents the CAD value of one unit of the original currency.
CREATE OR REPLACE VIEW tf_transactions_valued AS
SELECT transaction_id,
       product_type,
       status,
       issue_date,
       expiry_date,
       SUBSTR(issue_date,1,4) AS issue_year,
       currency,
       amount AS amount_original,
       CASE currency
         WHEN 'CAD' THEN 1.0000
         WHEN 'USD' THEN 1.3600
         WHEN 'EUR' THEN 1.4800
         WHEN 'GBP' THEN 1.7300
         WHEN 'JPY' THEN 0.0092
         WHEN 'CNY' THEN 0.1900
         ELSE NULL
       END AS exchange_rate_to_cad,
       amount * CASE currency
         WHEN 'CAD' THEN 1.0000
         WHEN 'USD' THEN 1.3600
         WHEN 'EUR' THEN 1.4800
         WHEN 'GBP' THEN 1.7300
         WHEN 'JPY' THEN 0.0092
         WHEN 'CNY' THEN 0.1900
         ELSE NULL
       END AS amount_cad,
       applicant_id,
       beneficiary_id,
       applicant_country,
       beneficiary_country,
       goods_category,
       amendment_count,
       document_count,
       processing_days,
       discrepancy_flag,
       delay_flag,
       customer_risk_rating
FROM trade_transactions_hbase;

CREATE OR REPLACE VIEW tf_trade_portfolio AS
SELECT product_type,
       status,
       applicant_country,
       beneficiary_country,
       COUNT(*) AS transaction_count,
       SUM(amount_cad) AS total_value_cad,
       AVG(amount_cad) AS avg_transaction_value_cad,
       AVG(processing_days) AS avg_processing_days,
       AVG(discrepancy_flag) AS discrepancy_rate,
       AVG(delay_flag) AS delay_rate
FROM tf_transactions_valued
GROUP BY product_type,status,applicant_country,beneficiary_country;

CREATE OR REPLACE VIEW tf_product_performance AS
SELECT product_type,
       COUNT(*) AS transaction_count,
       SUM(amount_cad) AS total_value_cad,
       AVG(amount_cad) AS avg_transaction_value_cad,
       AVG(processing_days) AS avg_processing_days,
       AVG(discrepancy_flag) AS discrepancy_rate,
       AVG(delay_flag) AS delay_rate
FROM tf_transactions_valued
GROUP BY product_type;

CREATE OR REPLACE VIEW tf_country_exposure AS
SELECT beneficiary_country,
       COUNT(*) AS transaction_count,
       SUM(amount_cad) AS exposure_value_cad,
       AVG(amount_cad) AS avg_transaction_value_cad,
       AVG(discrepancy_flag) AS discrepancy_rate,
       AVG(delay_flag) AS delay_rate
FROM tf_transactions_valued
GROUP BY beneficiary_country;

CREATE OR REPLACE VIEW tf_corridor_performance AS
SELECT applicant_country,
       beneficiary_country,
       COUNT(*) AS transaction_count,
       SUM(amount_cad) AS total_value_cad,
       AVG(amount_cad) AS avg_transaction_value_cad,
       AVG(processing_days) AS avg_processing_days,
       AVG(discrepancy_flag) AS discrepancy_rate,
       AVG(delay_flag) AS delay_rate
FROM tf_transactions_valued
GROUP BY applicant_country,beneficiary_country;

CREATE OR REPLACE VIEW tf_documentary_operations AS
SELECT product_type,
       COUNT(*) AS transaction_count,
       SUM(document_count) AS document_count,
       AVG(amendment_count) AS avg_amendment_count,
       AVG(discrepancy_flag) AS discrepancy_rate,
       AVG(processing_days) AS avg_processing_days
FROM tf_transactions_valued
GROUP BY product_type;

CREATE OR REPLACE VIEW tf_sla_performance AS
SELECT product_type,
       COUNT(*) AS transaction_count,
       SUM(CASE WHEN processing_days <= 10 THEN 1 ELSE 0 END) AS within_sla,
       SUM(CASE WHEN processing_days > 10 THEN 1 ELSE 0 END) AS sla_breaches,
       AVG(processing_days) AS avg_processing_days
FROM tf_transactions_valued
GROUP BY product_type;

CREATE OR REPLACE VIEW tf_risk_summary AS
SELECT applicant_country,
       beneficiary_country,
       product_type,
       customer_risk_rating,
       COUNT(*) AS transaction_count,
       SUM(amount_cad) AS exposure_value_cad,
       AVG(discrepancy_flag) AS discrepancy_rate,
       AVG(delay_flag) AS delay_rate
FROM tf_transactions_valued
GROUP BY applicant_country,beneficiary_country,product_type,customer_risk_rating;

CREATE OR REPLACE VIEW tf_annual_growth AS
SELECT issue_year,
       product_type,
       COUNT(*) AS transaction_count,
       SUM(amount_cad) AS total_value_cad,
       AVG(amount_cad) AS avg_transaction_value_cad
FROM tf_transactions_valued
GROUP BY issue_year,product_type;
