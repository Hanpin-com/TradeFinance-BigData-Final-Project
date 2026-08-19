import os
import time
import json
import socket
from datetime import datetime, timezone

import numpy as np
import pandas as pd
from sklearn.ensemble import IsolationForest, RandomForestClassifier, RandomForestRegressor
from sklearn.metrics import precision_score, recall_score, f1_score, mean_absolute_error
from sklearn.model_selection import train_test_split
from statsmodels.tsa.holtwinters import ExponentialSmoothing
from confluent_kafka import Producer
from thrift.transport.TTransport import TTransportException

from trade_finance.common.config import KAFKA_BOOTSTRAP, TOPICS
from trade_finance.common.hbase_schema import connect, ensure_schema


INTERVAL = int(os.getenv("ML_RUN_INTERVAL_SECONDS", "60"))
MIN_ROWS = int(os.getenv("MIN_TRAINING_ROWS", "100"))
PUBLISH = os.getenv("PUBLISH_ML_EVENTS", "true").lower() == "true"
HBASE_RETRIES = int(os.getenv("ML_HBASE_RETRIES", "3"))
HBASE_RETRY_DELAY_SECONDS = int(os.getenv("ML_HBASE_RETRY_DELAY_SECONDS", "5"))

producer = (
    Producer(
        {
            "bootstrap.servers": KAFKA_BOOTSTRAP,
            "client.id": "tf-ml-worker",
        }
    )
    if PUBLISH
    else None
)


def log(message):
    print(
        f"[{datetime.now(timezone.utc).isoformat(timespec='seconds')}] {message}",
        flush=True,
    )


def dec(v, default=""):
    if v is None:
        return default
    return v.decode() if isinstance(v, bytes) else str(v)


def is_transport_error(exc):
    return isinstance(
        exc,
        (
            TTransportException,
            BrokenPipeError,
            ConnectionResetError,
            ConnectionAbortedError,
            ConnectionRefusedError,
            TimeoutError,
            socket.timeout,
            OSError,
            EOFError,
        ),
    )


def close_hbase(conn):
    if conn is None:
        return
    try:
        conn.close()
    except Exception:
        pass


def open_hbase():
    log("Connecting to HBase...")
    conn = connect()
    log("HBase connection established.")
    ensure_schema(conn)
    log("HBase schema verified.")
    return conn


def load_df(table):
    rows = []

    for key, d in table.scan():
        try:
            rows.append({
                "transaction_id": dec(key),
                "amount": float(dec(d.get(b"financial:amount"), "0")),
                "amendment_count": int(float(dec(d.get(b"metrics:amendment_count"), "0"))),
                "document_count": int(float(dec(d.get(b"metrics:document_count"), "0"))),
                "processing_days": int(float(dec(d.get(b"metrics:processing_days"), "0"))),
                "relationship_years": int(
                    float(dec(d.get(b"metrics:counterparty_relationship_years"), "0"))
                ),
                "discrepancy_flag": int(float(dec(d.get(b"metrics:discrepancy_flag"), "0"))),
                "delay_flag": int(float(dec(d.get(b"metrics:delay_flag"), "0"))),
                "product_type": dec(d.get(b"instrument:product_type")),
                "issue_date": dec(d.get(b"instrument:issue_date")),
            })
        except Exception as exc:
            log(f"Skipping malformed HBase row {dec(key)}: {exc}")

    return pd.DataFrame(rows)


def emit(topic, tid, payload):
    if producer:
        producer.produce(
            topic,
            key=tid,
            value=json.dumps(payload, separators=(",", ":")),
        )
        producer.poll(0)


def store(out, tid, model, version, values, metrics=None):
    key = f"{tid}#{model}#{version}"

    data = {
        b"model:name": model.encode(),
        b"model:version": version.encode(),
        b"audit:prediction_timestamp": datetime.now(timezone.utc).isoformat().encode(),
    }

    for k, v in values.items():
        data[f"prediction:{k}".encode()] = str(v).encode()

    for k, v in (metrics or {}).items():
        data[f"evaluation:{k}".encode()] = str(v).encode()

    out.put(key.encode(), data)


def run_models(conn):
    src = conn.table("trade_transactions")
    out = conn.table("trade_ml_results")

    log("Loading Trade Finance transactions from HBase...")
    df = load_df(src)

    if len(df) < MIN_ROWS:
        log(f"ML waiting: {len(df)}/{MIN_ROWS} rows")
        return

    log(f"Training ML pipeline with {len(df)} transactions.")

    X = pd.DataFrame({
        "log_amount": np.log1p(df["amount"].clip(lower=0)),
        "amendment_count": df["amendment_count"],
        "document_count": df["document_count"],
        "relationship_years": df["relationship_years"],
    }).fillna(0)

    # 1) anomaly detection
    log("Training transaction anomaly model...")

    iso = IsolationForest(
        contamination=0.05,
        random_state=42,
    ).fit(X)

    anomaly = -iso.score_samples(X)
    q95 = float(np.quantile(anomaly, 0.95))

    for tid, score in zip(df["transaction_id"], anomaly):
        cls = "HIGH" if score >= q95 else "NORMAL"

        store(
            out,
            tid,
            "transaction_anomaly",
            "1.0",
            {
                "score": round(float(score), 6),
                "class": cls,
            },
        )

        emit(
            TOPICS["anomaly"],
            tid,
            {
                "transaction_id": tid,
                "anomaly_score": float(score),
                "class": cls,
                "model_version": "1.0",
            },
        )

    log("Transaction anomaly model completed.")

    # 2) discrepancy classifier
    y = df["discrepancy_flag"]

    if y.nunique() > 1:
        log("Training document discrepancy model...")

        Xtr, Xte, ytr, yte = train_test_split(
            X,
            y,
            test_size=0.25,
            random_state=42,
            stratify=y,
        )

        model = RandomForestClassifier(
            n_estimators=150,
            random_state=42,
            class_weight="balanced",
        ).fit(Xtr, ytr)

        pred = model.predict(Xte)

        metrics = {
            "precision": precision_score(yte, pred, zero_division=0),
            "recall": recall_score(yte, pred, zero_division=0),
            "f1": f1_score(yte, pred, zero_division=0),
        }

        probs = model.predict_proba(X)[:, 1]

        for tid, probability in zip(df["transaction_id"], probs):
            risk_class = (
                "HIGH"
                if probability >= 0.65
                else "MEDIUM"
                if probability >= 0.35
                else "LOW"
            )

            store(
                out,
                tid,
                "document_discrepancy",
                "1.0",
                {
                    "probability": round(float(probability), 6),
                    "class": risk_class,
                },
                metrics,
            )

            emit(
                TOPICS["discrepancy"],
                tid,
                {
                    "transaction_id": tid,
                    "probability": float(probability),
                    "model_version": "1.0",
                },
            )

        log(
            "Document discrepancy model completed. "
            f"precision={metrics['precision']:.4f}, "
            f"recall={metrics['recall']:.4f}, "
            f"f1={metrics['f1']:.4f}"
        )

    # 3) delay classifier + expected processing days regression
    yd = df["delay_flag"]
    yr = df["processing_days"]

    if yd.nunique() > 1:
        log("Training processing-delay models...")

        classifier = RandomForestClassifier(
            n_estimators=150,
            random_state=42,
            class_weight="balanced",
        ).fit(X, yd)

        regressor = RandomForestRegressor(
            n_estimators=150,
            random_state=42,
        ).fit(X, yr)

        probs = classifier.predict_proba(X)[:, 1]
        expected_days = regressor.predict(X)

        mae = mean_absolute_error(yr, expected_days)

        for tid, probability, days in zip(
            df["transaction_id"],
            probs,
            expected_days,
        ):
            store(
                out,
                tid,
                "processing_delay",
                "1.0",
                {
                    "probability": round(float(probability), 6),
                    "expected_days": round(float(days), 2),
                },
                {
                    "mae_days": round(float(mae), 4),
                },
            )

            emit(
                TOPICS["delay"],
                tid,
                {
                    "transaction_id": tid,
                    "delay_probability": float(probability),
                    "expected_days": float(days),
                    "model_version": "1.0",
                },
            )

        log(
            "Processing-delay models completed. "
            f"mae_days={mae:.4f}"
        )

    # 4) monthly trade-volume forecast
    dated = df.copy()
    dated["issue_date"] = pd.to_datetime(
        dated["issue_date"],
        errors="coerce",
    )

    series = (
        dated.dropna(subset=["issue_date"])
        .set_index("issue_date")
        .resample("MS")
        .size()
    )

    if len(series) >= 6:
        log("Training trade-volume forecast model...")

        model = ExponentialSmoothing(
            series.astype(float),
            trend="add",
            seasonal=None,
            initialization_method="estimated",
        ).fit(optimized=True)

        forecast = model.forecast(3)

        for dt, value in forecast.items():
            tid = f"FORECAST#{dt.strftime('%Y-%m')}"

            store(
                out,
                tid,
                "trade_volume_forecast",
                "1.0",
                {
                    "forecast_month": dt.strftime("%Y-%m"),
                    "predicted_transactions": max(
                        0,
                        round(float(value), 2),
                    ),
                },
            )

            emit(
                TOPICS["forecast"],
                tid,
                {
                    "forecast_month": dt.strftime("%Y-%m"),
                    "predicted_transactions": max(0, float(value)),
                    "model_version": "1.0",
                },
            )

        log("Trade-volume forecast completed.")

    if producer:
        producer.flush()

    log(f"ML pipeline completed for {len(df)} transactions.")


def run_cycle():
    conn = None

    try:
        conn = open_hbase()
        run_models(conn)

    finally:
        close_hbase(conn)
        log("HBase connection closed for completed ML cycle.")


log(
    f"Trade Finance ML worker starting. "
    f"interval={INTERVAL}s, "
    f"minimum_rows={MIN_ROWS}, "
    f"publish={PUBLISH}"
)

while True:
    cycle_succeeded = False

    for attempt in range(1, HBASE_RETRIES + 1):
        try:
            log(
                f"Starting ML cycle "
                f"(attempt {attempt}/{HBASE_RETRIES})."
            )

            run_cycle()
            cycle_succeeded = True
            break

        except Exception as exc:
            if is_transport_error(exc):
                log(
                    f"HBase transport failure during ML cycle: "
                    f"{type(exc).__name__}: {exc}"
                )

                if attempt < HBASE_RETRIES:
                    log(
                        f"Retrying ML cycle with a fresh HBase "
                        f"connection in {HBASE_RETRY_DELAY_SECONDS}s."
                    )
                    time.sleep(HBASE_RETRY_DELAY_SECONDS)
                    continue

            log(
                f"ML pipeline error: "
                f"{type(exc).__name__}: {exc}"
            )
            break

    if not cycle_succeeded:
        log(
            "ML cycle did not complete successfully. "
            "The next scheduled cycle will retry with a new "
            "HBase connection."
        )

    log(f"Sleeping {INTERVAL}s before next ML cycle.")
    time.sleep(INTERVAL)