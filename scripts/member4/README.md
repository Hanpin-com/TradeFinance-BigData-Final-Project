# Member 4 - ML + Power BI Quick Run

This folder contains the safe test/run command for Member 4.

## What it creates

Running the script produces these files under `data/trade-finance/member4-output/`:

- `powerbi_trade_finance_ml.csv` - transaction-level ML and risk fields for Power BI
- `trade_volume_forecast.csv` - three-month transaction-volume forecast
- `model_metrics.json` - machine-readable evaluation results
- `model_summary.txt` - short results summary for screenshots/presentation

## Run on Windows

From the repository root:

```bat
scripts\member4\run-member4.bat
```

Or from PowerShell:

```powershell
.\scripts\member4\run-member4.bat
```

The final terminal line should include:

```text
[Member 4] MEMBER 4 PIPELINE SUCCESS
```

## Evidence to capture

1. Terminal showing `Dataset validated successfully: 5,000 transactions`.
2. Terminal showing all four model steps and `MEMBER 4 PIPELINE SUCCESS`.
3. `model_summary.txt` showing held-out test metrics.
4. Power BI dashboard after importing `powerbi_trade_finance_ml.csv`.
5. Forecast visual using `trade_volume_forecast.csv`.

## Important interpretation

The risk output is a management decision-support score for the course project. It is not a production fraud or credit-decision system.
