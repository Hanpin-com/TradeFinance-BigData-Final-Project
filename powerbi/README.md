# Power BI Desktop Integration

Power BI Desktop remains on the Windows host. It is not containerized.

## Analytical source
HiveServer2 is exposed by the existing `hive-server` container on host port `10000`.

Recommended Power BI datasets:
- `trade_finance.tf_trade_portfolio`
- `trade_finance.tf_corridor_performance`
- `trade_finance.tf_documentary_operations`
- `trade_finance.tf_sla_performance`
- `trade_finance.tf_risk_summary`

## Recommended dashboards
1. Executive Trade Finance Overview
2. Portfolio and Product Performance
3. Geographic / Trade Corridor Risk
4. Documentary Operations
5. SLA and Processing Performance
6. Predictive Analytics (anomaly, discrepancy, delay, forecast)

The exact ODBC driver/DSN depends on the Windows Hive driver installed on the workstation.
