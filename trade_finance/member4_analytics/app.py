import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import IsolationForest, RandomForestClassifier, RandomForestRegressor
from sklearn.metrics import (
    accuracy_score,
    f1_score,
    mean_absolute_error,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import train_test_split
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder
from statsmodels.tsa.holtwinters import ExponentialSmoothing

RANDOM_STATE = 42


def log(message: str) -> None:
    print(f"[Member 4] {message}", flush=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run Member 4 ML analytics and create Power BI-ready outputs."
    )
    parser.add_argument(
        "--input",
        default="data/trade-finance/transactions.json",
        help="Path to transactions.json",
    )
    parser.add_argument(
        "--output",
        default="data/trade-finance/member4-output",
        help="Directory for generated CSV/JSON outputs",
    )
    return parser.parse_args()


def load_transactions(path: Path) -> pd.DataFrame:
    if not path.exists():
        raise FileNotFoundError(f"Input file not found: {path}")

    with path.open("r", encoding="utf-8") as handle:
        raw = json.load(handle)

    if not isinstance(raw, list) or not raw:
        raise ValueError("Expected transactions.json to contain a non-empty JSON list.")

    df = pd.DataFrame(raw)
    required = {
        "transaction_id",
        "product_type",
        "beneficiary_country",
        "currency",
        "amount",
        "issue_date",
        "goods_category",
        "amendment_count",
        "document_count",
        "processing_days",
        "discrepancy_flag",
        "delay_flag",
        "counterparty_relationship_years",
        "customer_risk_rating",
    }
    missing = sorted(required - set(df.columns))
    if missing:
        raise ValueError(f"Missing required columns: {', '.join(missing)}")

    numeric_cols = [
        "amount",
        "amendment_count",
        "document_count",
        "processing_days",
        "discrepancy_flag",
        "delay_flag",
        "counterparty_relationship_years",
    ]
    for col in numeric_cols:
        df[col] = pd.to_numeric(df[col], errors="coerce")

    if df[numeric_cols].isna().any().any():
        bad = df[numeric_cols].isna().sum()
        bad = bad[bad > 0].to_dict()
        raise ValueError(f"Invalid numeric values detected: {bad}")

    df["issue_date"] = pd.to_datetime(df["issue_date"], errors="coerce")
    if df["issue_date"].isna().any():
        raise ValueError("One or more issue_date values are invalid.")

    if df["transaction_id"].duplicated().any():
        raise ValueError("Duplicate transaction_id values were found.")

    return df


def feature_frame(df: pd.DataFrame) -> tuple[pd.DataFrame, list[str], list[str]]:
    x = df.copy()
    x["log_amount"] = np.log1p(x["amount"].clip(lower=0))

    numeric = [
        "log_amount",
        "amendment_count",
        "document_count",
        "counterparty_relationship_years",
    ]
    categorical = [
        "product_type",
        "beneficiary_country",
        "currency",
        "goods_category",
        "customer_risk_rating",
    ]
    return x[numeric + categorical], numeric, categorical


def build_preprocessor(numeric: list[str], categorical: list[str]) -> ColumnTransformer:
    return ColumnTransformer(
        transformers=[
            ("numeric", "passthrough", numeric),
            ("categorical", OneHotEncoder(handle_unknown="ignore"), categorical),
        ]
    )


def best_f1_threshold(y_true: pd.Series, probabilities: np.ndarray) -> float:
    best_threshold = 0.50
    best_score = -1.0
    for threshold in np.arange(0.20, 0.81, 0.02):
        pred = (probabilities >= threshold).astype(int)
        score = f1_score(y_true, pred, zero_division=0)
        if score > best_score:
            best_score = score
            best_threshold = float(threshold)
    return best_threshold


def split_train_validation_test(
    x: pd.DataFrame, y: pd.Series
) -> tuple[pd.DataFrame, pd.DataFrame, pd.DataFrame, pd.Series, pd.Series, pd.Series]:
    x_train, x_temp, y_train, y_temp = train_test_split(
        x,
        y,
        test_size=0.40,
        random_state=RANDOM_STATE,
        stratify=y,
    )
    x_validation, x_test, y_validation, y_test = train_test_split(
        x_temp,
        y_temp,
        test_size=0.50,
        random_state=RANDOM_STATE,
        stratify=y_temp,
    )
    return x_train, x_validation, x_test, y_train, y_validation, y_test


def classifier_metrics(y_true: pd.Series, pred: np.ndarray, prob: np.ndarray) -> dict:
    result = {
        "accuracy": round(float(accuracy_score(y_true, pred)), 4),
        "precision": round(float(precision_score(y_true, pred, zero_division=0)), 4),
        "recall": round(float(recall_score(y_true, pred, zero_division=0)), 4),
        "f1": round(float(f1_score(y_true, pred, zero_division=0)), 4),
    }
    try:
        result["roc_auc"] = round(float(roc_auc_score(y_true, prob)), 4)
    except ValueError:
        result["roc_auc"] = None
    return result


def run_anomaly_model(df: pd.DataFrame) -> tuple[np.ndarray, np.ndarray]:
    x = pd.DataFrame(
        {
            "log_amount": np.log1p(df["amount"].clip(lower=0)),
            "amendment_count": df["amendment_count"],
            "document_count": df["document_count"],
            "relationship_years": df["counterparty_relationship_years"],
        }
    )

    model = IsolationForest(
        n_estimators=250,
        contamination=0.05,
        random_state=RANDOM_STATE,
    )
    model.fit(x)
    scores = -model.score_samples(x)
    cutoff = float(np.quantile(scores, 0.95))
    classes = np.where(scores >= cutoff, "HIGH", "NORMAL")
    return scores, classes


def run_discrepancy_model(df: pd.DataFrame) -> tuple[np.ndarray, dict]:
    x, numeric, categorical = feature_frame(df)
    y = df["discrepancy_flag"].astype(int)

    x_train, x_validation, x_test, y_train, y_validation, y_test = (
        split_train_validation_test(x, y)
    )

    model = Pipeline(
        steps=[
            ("prep", build_preprocessor(numeric, categorical)),
            (
                "model",
                RandomForestClassifier(
                    n_estimators=300,
                    min_samples_leaf=3,
                    class_weight="balanced_subsample",
                    random_state=RANDOM_STATE,
                    n_jobs=-1,
                ),
            ),
        ]
    )
    model.fit(x_train, y_train)

    validation_prob = model.predict_proba(x_validation)[:, 1]
    threshold = best_f1_threshold(y_validation, validation_prob)

    test_prob = model.predict_proba(x_test)[:, 1]
    test_pred = (test_prob >= threshold).astype(int)
    metrics = classifier_metrics(y_test, test_pred, test_prob)
    metrics["decision_threshold"] = round(threshold, 2)
    metrics["test_rows"] = int(len(y_test))

    all_prob = model.predict_proba(x)[:, 1]
    return all_prob, metrics


def run_delay_models(df: pd.DataFrame) -> tuple[np.ndarray, np.ndarray, dict]:
    x, numeric, categorical = feature_frame(df)
    y_class = df["delay_flag"].astype(int)
    y_days = df["processing_days"].astype(float)

    indices = np.arange(len(df))
    train_idx, test_idx = train_test_split(
        indices,
        test_size=0.25,
        random_state=RANDOM_STATE,
        stratify=y_class,
    )

    classifier = Pipeline(
        steps=[
            ("prep", build_preprocessor(numeric, categorical)),
            (
                "model",
                RandomForestClassifier(
                    n_estimators=300,
                    min_samples_leaf=3,
                    class_weight="balanced_subsample",
                    random_state=RANDOM_STATE,
                    n_jobs=-1,
                ),
            ),
        ]
    )
    classifier.fit(x.iloc[train_idx], y_class.iloc[train_idx])

    test_prob = classifier.predict_proba(x.iloc[test_idx])[:, 1]
    test_pred = (test_prob >= 0.50).astype(int)
    metrics = classifier_metrics(y_class.iloc[test_idx], test_pred, test_prob)
    metrics["classification_test_rows"] = int(len(test_idx))

    regressor = Pipeline(
        steps=[
            ("prep", build_preprocessor(numeric, categorical)),
            (
                "model",
                RandomForestRegressor(
                    n_estimators=300,
                    min_samples_leaf=3,
                    random_state=RANDOM_STATE,
                    n_jobs=-1,
                ),
            ),
        ]
    )
    regressor.fit(x.iloc[train_idx], y_days.iloc[train_idx])
    test_days = regressor.predict(x.iloc[test_idx])
    metrics["processing_days_mae"] = round(
        float(mean_absolute_error(y_days.iloc[test_idx], test_days)), 4
    )

    all_prob = classifier.predict_proba(x)[:, 1]
    all_days = regressor.predict(x)
    return all_prob, all_days, metrics


def run_forecast(df: pd.DataFrame) -> pd.DataFrame:
    monthly = (
        df.set_index("issue_date")
        .resample("MS")
        .size()
        .rename("actual_transactions")
        .astype(float)
    )
    monthly = monthly.asfreq("MS", fill_value=0.0)

    if len(monthly) < 6:
        raise ValueError("At least 6 months of dated transactions are required for forecasting.")

    model = ExponentialSmoothing(
        monthly,
        trend="add",
        seasonal=None,
        initialization_method="estimated",
    ).fit(optimized=True)

    forecast = model.forecast(3)
    result = pd.DataFrame(
        {
            "forecast_month": forecast.index.strftime("%Y-%m"),
            "predicted_transactions": np.maximum(0, forecast.values).round(2),
        }
    )
    return result


def create_powerbi_output(
    df: pd.DataFrame,
    anomaly_scores: np.ndarray,
    anomaly_classes: np.ndarray,
    discrepancy_prob: np.ndarray,
    delay_prob: np.ndarray,
    expected_days: np.ndarray,
) -> pd.DataFrame:
    out = df.copy()
    out["issue_date"] = out["issue_date"].dt.strftime("%Y-%m-%d")
    out["anomaly_score"] = np.round(anomaly_scores, 6)
    out["anomaly_class"] = anomaly_classes
    out["discrepancy_probability"] = np.round(discrepancy_prob, 6)
    out["delay_probability"] = np.round(delay_prob, 6)
    out["predicted_processing_days"] = np.round(expected_days, 2)

    # Convert anomaly score to a 0-1 percentile so different model scores can be combined.
    anomaly_percentile = pd.Series(anomaly_scores).rank(pct=True).to_numpy()
    customer_risk = (
        out["customer_risk_rating"]
        .map({"LOW": 0.0, "MEDIUM": 0.5, "HIGH": 1.0})
        .fillna(0.5)
        .to_numpy()
    )

    overall = (
        0.25 * anomaly_percentile
        + 0.30 * discrepancy_prob
        + 0.35 * delay_prob
        + 0.10 * customer_risk
    )
    out["overall_risk_score"] = np.round(overall * 100.0, 2)
    out["overall_risk_level"] = np.select(
        [out["overall_risk_score"] >= 65, out["overall_risk_score"] >= 40],
        ["HIGH", "MEDIUM"],
        default="LOW",
    )
    return out


def main() -> None:
    args = parse_args()
    input_path = Path(args.input)
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)

    log(f"Loading dataset: {input_path}")
    df = load_transactions(input_path)
    log(f"Dataset validated successfully: {len(df):,} transactions")

    log("1/4 Training Isolation Forest anomaly model...")
    anomaly_scores, anomaly_classes = run_anomaly_model(df)
    anomaly_count = int((anomaly_classes == "HIGH").sum())
    log(f"Anomaly model complete: {anomaly_count:,} HIGH anomalies")

    log("2/4 Training Random Forest discrepancy model...")
    discrepancy_prob, discrepancy_metrics = run_discrepancy_model(df)
    log(
        "Discrepancy model complete: "
        f"F1={discrepancy_metrics['f1']:.4f}, "
        f"ROC-AUC={discrepancy_metrics['roc_auc']:.4f}, "
        f"threshold={discrepancy_metrics['decision_threshold']:.2f}"
    )

    log("3/4 Training processing-delay classification/regression models...")
    delay_prob, expected_days, delay_metrics = run_delay_models(df)
    log(
        "Delay models complete: "
        f"F1={delay_metrics['f1']:.4f}, "
        f"MAE={delay_metrics['processing_days_mae']:.2f} days"
    )

    log("4/4 Training 3-month transaction-volume forecast...")
    forecast = run_forecast(df)
    log("Forecast model complete")

    powerbi = create_powerbi_output(
        df,
        anomaly_scores,
        anomaly_classes,
        discrepancy_prob,
        delay_prob,
        expected_days,
    )

    powerbi_path = output_dir / "powerbi_trade_finance_ml.csv"
    forecast_path = output_dir / "trade_volume_forecast.csv"
    metrics_path = output_dir / "model_metrics.json"
    summary_path = output_dir / "model_summary.txt"

    powerbi.to_csv(powerbi_path, index=False)
    forecast.to_csv(forecast_path, index=False)

    metrics = {
        "dataset_rows": int(len(df)),
        "anomaly_high_count": anomaly_count,
        "anomaly_high_pct": round(100.0 * anomaly_count / len(df), 2),
        "discrepancy_model": discrepancy_metrics,
        "delay_model": delay_metrics,
        "powerbi_high_risk_count": int((powerbi["overall_risk_level"] == "HIGH").sum()),
        "powerbi_medium_risk_count": int((powerbi["overall_risk_level"] == "MEDIUM").sum()),
        "powerbi_low_risk_count": int((powerbi["overall_risk_level"] == "LOW").sum()),
        "forecast": forecast.to_dict(orient="records"),
    }
    metrics_path.write_text(json.dumps(metrics, indent=2), encoding="utf-8")

    lines = [
        "MEMBER 4 - MACHINE LEARNING SUMMARY",
        "===================================",
        f"Transactions analyzed: {len(df):,}",
        f"High anomalies: {anomaly_count:,} ({metrics['anomaly_high_pct']:.2f}%)",
        "",
        "Document discrepancy model (held-out test set):",
        f"  Accuracy : {discrepancy_metrics['accuracy']:.4f}",
        f"  Precision: {discrepancy_metrics['precision']:.4f}",
        f"  Recall   : {discrepancy_metrics['recall']:.4f}",
        f"  F1       : {discrepancy_metrics['f1']:.4f}",
        f"  ROC-AUC  : {discrepancy_metrics['roc_auc']:.4f}",
        f"  Threshold: {discrepancy_metrics['decision_threshold']:.2f}",
        "",
        "Processing-delay model (held-out test set):",
        f"  Accuracy : {delay_metrics['accuracy']:.4f}",
        f"  Precision: {delay_metrics['precision']:.4f}",
        f"  Recall   : {delay_metrics['recall']:.4f}",
        f"  F1       : {delay_metrics['f1']:.4f}",
        f"  ROC-AUC  : {delay_metrics['roc_auc']:.4f}",
        f"  Processing-days MAE: {delay_metrics['processing_days_mae']:.2f} days",
        "",
        "Power BI management risk distribution:",
        f"  HIGH  : {metrics['powerbi_high_risk_count']:,}",
        f"  MEDIUM: {metrics['powerbi_medium_risk_count']:,}",
        f"  LOW   : {metrics['powerbi_low_risk_count']:,}",
        "",
        "3-month transaction-volume forecast:",
    ]
    for row in metrics["forecast"]:
        lines.append(
            f"  {row['forecast_month']}: {row['predicted_transactions']:.2f} transactions"
        )
    summary_path.write_text("\n".join(lines) + "\n", encoding="utf-8")

    log("All Member 4 outputs created successfully:")
    log(f"  {powerbi_path}")
    log(f"  {forecast_path}")
    log(f"  {metrics_path}")
    log(f"  {summary_path}")
    log("MEMBER 4 PIPELINE SUCCESS")


if __name__ == "__main__":
    main()
