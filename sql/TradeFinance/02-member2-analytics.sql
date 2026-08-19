USE trade_finance;

-- 1. Portfolio totals by product
SELECT product_type,
       transaction_count,
       ROUND(total_value_cad,2) AS total_value_cad,
       ROUND(avg_transaction_value_cad,2) AS avg_transaction_value_cad
FROM tf_product_performance
ORDER BY total_value_cad DESC;

-- 2. Highest country exposures
SELECT beneficiary_country,
       transaction_count,
       ROUND(exposure_value_cad,2) AS exposure_value_cad,
       ROUND(discrepancy_rate * 100,2) AS discrepancy_rate_pct
FROM tf_country_exposure
ORDER BY exposure_value_cad DESC
LIMIT 10;

-- 3. Busiest trade corridors
SELECT applicant_country,
       beneficiary_country,
       transaction_count,
       ROUND(total_value_cad,2) AS total_value_cad,
       ROUND(avg_processing_days,2) AS avg_processing_days
FROM tf_corridor_performance
ORDER BY transaction_count DESC
LIMIT 10;

-- 4. SLA performance by product
SELECT product_type,
       transaction_count,
       within_sla,
       sla_breaches,
       ROUND(100.0 * within_sla / transaction_count,2) AS within_sla_pct,
       ROUND(avg_processing_days,2) AS avg_processing_days
FROM tf_sla_performance
ORDER BY within_sla_pct ASC;

-- 5. Risk concentration
SELECT customer_risk_rating,
       product_type,
       COUNT(*) AS transaction_count,
       ROUND(SUM(amount_cad),2) AS exposure_value_cad,
       ROUND(AVG(discrepancy_flag) * 100,2) AS discrepancy_rate_pct,
       ROUND(AVG(delay_flag) * 100,2) AS delay_rate_pct
FROM tf_transactions_valued
GROUP BY customer_risk_rating,product_type
ORDER BY exposure_value_cad DESC;

-- 6. Historical annual trend
SELECT issue_year,
       product_type,
       transaction_count,
       ROUND(total_value_cad,2) AS total_value_cad,
       ROUND(avg_transaction_value_cad,2) AS avg_transaction_value_cad
FROM tf_annual_growth
ORDER BY issue_year,product_type;

-- 7. Exact transaction lookup through the Hive-to-HBase external table
SELECT transaction_id,
       product_type,
       status,
       currency,
       amount,
       applicant_id,
       beneficiary_id
FROM trade_transactions_hbase
WHERE transaction_id = 'TF-2026-0000001';
