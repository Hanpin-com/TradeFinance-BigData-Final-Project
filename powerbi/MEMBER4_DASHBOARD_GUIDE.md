# Member 4 Power BI Dashboard Guide

## Files to import

Use **Home -> Get data -> Text/CSV** and import:

1. `data/trade-finance/member4-output/powerbi_trade_finance_ml.csv`
2. `data/trade-finance/member4-output/trade_volume_forecast.csv`

## Recommended one-page dashboard

### KPI cards
- Total Transactions: Count of `transaction_id`
- Total Exposure: Sum of `amount`
- High-Risk Transactions: Count where `overall_risk_level = HIGH`
- High Anomalies: Count where `anomaly_class = HIGH`

### Visuals
- Donut chart: `overall_risk_level` by transaction count
- Bar chart: Sum of `amount` by `beneficiary_country`
- Column chart: Transaction count by `product_type`
- Bar chart: Average `overall_risk_score` by `customer_risk_rating`
- Table: `transaction_id`, `amount`, `beneficiary_country`, `overall_risk_score`, `overall_risk_level`, `anomaly_class`
- Line/column chart from forecast file: `forecast_month` vs `predicted_transactions`

### Slicers
- `product_type`
- `beneficiary_country`
- `customer_risk_rating`
- `overall_risk_level`

## Suggested title

**Trade Finance Risk Intelligence & Management Dashboard**

## Presentation message

The dashboard combines anomaly detection, discrepancy risk, processing-delay risk, and customer risk into an explainable management risk score. Managers can use the dashboard to prioritize high-risk transactions, identify exposure concentrations, and monitor expected transaction volume.
