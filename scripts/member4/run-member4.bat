@echo off
setlocal
cd /d "%~dp0\..\.."

echo ============================================================
echo Member 4 - Machine Learning and Power BI Preparation
echo ============================================================
echo.

echo [1/2] Building Trade Finance Python image...
docker compose build tf-data-generator
if errorlevel 1 goto :error

echo.
echo [2/2] Running Member 4 analytics...
docker compose run --rm --no-deps tf-data-generator python -m trade_finance.member4_analytics.app --input /data/trade-finance/transactions.json --output /data/trade-finance/member4-output
if errorlevel 1 goto :error

echo.
echo ============================================================
echo MEMBER 4 RUN COMPLETED SUCCESSFULLY
echo Outputs: data\trade-finance\member4-output
echo ============================================================
echo.
echo Open model_summary.txt for the presentation metrics.
echo Import powerbi_trade_finance_ml.csv into Power BI Desktop.
exit /b 0

:error
echo.
echo ============================================================
echo MEMBER 4 RUN FAILED - send the error above for troubleshooting.
echo ============================================================
exit /b 1
