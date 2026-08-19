# Trade Finance Real-Time Streaming and Risk Monitoring

**Project:** Trade Finance Intelligence and Risk Management  
**Role:** Member 3 – Real-Time Big Data Engineering  
**Developed by:** Han-Pin, Hung  

---

## Overview

This module implements the **real-time Big Data Engineering component** of the Trade Finance Intelligence and Risk Management platform.

The solution uses **Apache Kafka** and **Apache Spark Structured Streaming** to process Trade Finance lifecycle events, perform real-time business analytics, and generate rule-based risk alerts.

The main responsibilities of this module are:

- Kafka event ingestion
- Spark Structured Streaming
- JSON parsing and validation
- Multi-topic Trade Finance event processing
- Real-time transaction analytics
- Transaction deduplication
- Currency exposure monitoring
- Real-time risk scoring
- High-risk transaction alerts

---

## Real-Time Data Pipeline

```text
Trade Finance Data Generator
        |
        v
Kafka Event Producer
        |
        v
Multiple Kafka Topics
        |
        v
Spark Structured Streaming
        |
        +--------------------------+
        |                          |
        v                          v
Structured Event Processing   Real-Time Analytics
                                   |
                                   v
                            Risk Scoring Engine
                                   |
                                   v
                            HIGH-RISK ALERTS
```

---

## Module Structure

```text
structured_streaming/
├── trade_finance_streaming.py
├── trade_finance_analytics.py
├── trade_finance_risk_alerts.py
└── README.md
```

---

# 1. Kafka Ingestion and Structured Streaming

## File

```text
trade_finance_streaming.py
```

This application consumes Trade Finance lifecycle events from Kafka using **Spark Structured Streaming**.

### Main Functions

- Connects Spark Structured Streaming to Kafka
- Subscribes to multiple Trade Finance Kafka topics
- Converts Kafka binary values into JSON strings
- Parses JSON using a defined Spark schema
- Performs basic record validation
- Extracts important business fields
- Displays structured Trade Finance events in real time

### Business Fields Extracted

Examples include:

- Transaction ID
- Event type
- Product type
- Applicant country
- Beneficiary country
- Currency
- Transaction amount
- Customer risk rating
- Discrepancy flag
- Delay flag

---

## Kafka Topics

The streaming application processes the following Trade Finance topics:

```text
tf.lc.events
tf.guarantee.events
tf.collection.events
tf.payment.events
tf.document.events
tf.shipment.events
tf.compliance.events
tf.sanctions.events
tf.limit.events
tf.fx.events
```

Machine Learning result topics are handled separately and are not part of this Member 3 streaming pipeline.

---

# 2. Real-Time Trade Finance Analytics

## File

```text
trade_finance_analytics.py
```

The analytics application transforms incoming Trade Finance events into real-time business KPIs.

A single Trade Finance transaction can generate multiple lifecycle events.

For example:

```text
LC_APPLICATION_RECEIVED
        |
LIMIT_CHECK_COMPLETED
        |
COMPLIANCE_SCREENING_COMPLETED
        |
SANCTIONS_SCREENING_COMPLETED
        |
LC_ISSUED
        |
PAYMENT_AUTHORIZED
```

These events may contain the same transaction amount.

Therefore, the application removes duplicate lifecycle records using:

```text
transaction_id
```

before calculating transaction-level KPIs.

This prevents the same financial transaction from being counted multiple times.

---

## Real-Time KPIs

The application calculates:

- Unique transaction count
- Total transaction value
- Average transaction value
- High-risk transaction count
- Discrepancy transaction count
- Delayed transaction count

---

## Currency Exposure Monitoring

Trade Finance transactions can use different currencies, including:

```text
CAD
CNY
EUR
GBP
JPY
USD
```

Transaction values are therefore analyzed separately by currency.

This avoids incorrectly combining values from different currencies into one financial total.

Example output:

```text
+--------+-------------------+-----------+---------------------+----------------------+------------------------+--------------------+
|currency|unique_transactions|total_value|avg_transaction_value|high_risk_transactions|discrepancy_transactions|delayed_transactions|
+--------+-------------------+-----------+---------------------+----------------------+------------------------+--------------------+
|CAD     |...                |...        |...                  |...                   |...                     |...                 |
|CNY     |...                |...        |...                  |...                   |...                     |...                 |
|EUR     |...                |...        |...                  |...                   |...                     |...                 |
|GBP     |...                |...        |...                  |...                   |...                     |...                 |
|JPY     |...                |...        |...                  |...                   |...                     |...                 |
|USD     |...                |...        |...                  |...                   |...                     |...                 |
+--------+-------------------+-----------+---------------------+----------------------+------------------------+--------------------+
```

---

# 3. Real-Time Risk Detection and Alerts

## File

```text
trade_finance_risk_alerts.py
```

This application implements a transparent **rule-based risk detection engine**.

It evaluates incoming Trade Finance transactions and assigns a risk score based on transaction characteristics.

---

## Risk Scoring Rules

| Risk Factor | Score |
|---|---:|
| High-risk customer | +3 |
| Document discrepancy | +2 |
| Processing delay | +2 |
| Transaction amount >= 1,000,000 | +2 |

---

## Risk Classification

| Risk Score | Risk Level |
|---:|---|
| 0–2 | LOW |
| 3–4 | MEDIUM |
| 5+ | HIGH |

Only transactions classified as:

```text
HIGH
```

are displayed in the real-time alert stream.

---

## Risk Alert Fields

Each alert contains:

- Transaction ID
- Product type
- Beneficiary country
- Currency
- Transaction amount
- Risk score
- Risk level
- Human-readable risk reason

Example:

```text
Transaction ID: TF-2026-0004593
Product Type: EXPORT_LC
Currency: EUR
Risk Score: 9
Risk Level: HIGH

Risk Reason:
High-risk customer;
Document discrepancy;
Processing delay;
Large transaction >= 1M
```

This allows risk analysts to understand not only that a transaction is high risk, but also **why the alert was generated**.

---

# Technologies

This module uses:

- Apache Kafka
- Apache Spark 3.5.0
- Spark Structured Streaming
- PySpark
- Python
- Docker
- HDFS
- YARN

Kafka integration package:

```text
org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.0
```

---

# How to Run

Run all commands from the project root directory.

---

## Step 1 – Start the Big Data Environment

```bash
docker compose up -d
```

Check service status:

```bash
docker compose ps
```

Required services should be running, including:

```text
Kafka
Spark Master
Spark Worker
HDFS NameNode
HDFS DataNode
YARN ResourceManager
YARN NodeManager
Hive
HBase
ZooKeeper
```

---

## Step 2 – Generate Trade Finance Data

```bash
docker compose up tf-data-generator
```

The generator creates Trade Finance transactions and lifecycle events.

The project dataset contains thousands of transactions and tens of thousands of lifecycle events.

---

## Step 3 – Publish Trade Finance Events to Kafka

```bash
docker compose up tf-event-producer
```

Successful execution should report that Trade Finance events were published to Kafka.

Kafka topics can be checked using:

```bash
docker exec kafka \
  /opt/kafka/bin/kafka-topics.sh \
  --bootstrap-server kafka:9092 \
  --list
```

---

# Prepare Spark Applications

Create the Member 3 application directory inside the Spark Master container:

```bash
docker exec spark-master mkdir -p /opt/member3
```

Copy the Structured Streaming application:

```bash
docker cp \
  structured_streaming/trade_finance_streaming.py \
  spark-master:/opt/member3/trade_finance_streaming.py
```

Copy the analytics application:

```bash
docker cp \
  structured_streaming/trade_finance_analytics.py \
  spark-master:/opt/member3/trade_finance_analytics.py
```

Copy the risk alert application:

```bash
docker cp \
  structured_streaming/trade_finance_risk_alerts.py \
  spark-master:/opt/member3/trade_finance_risk_alerts.py
```

Verify the files:

```bash
docker exec spark-master ls -lh /opt/member3/
```

Expected files:

```text
trade_finance_streaming.py
trade_finance_analytics.py
trade_finance_risk_alerts.py
```

---

# Run Application 1 – Kafka to Spark Structured Streaming

Before execution, confirm that another Trade Finance Spark job is not already running:

```bash
docker exec spark-master sh -lc \
'ps -ef | grep -E "trade_finance|spark-submit|pyspark" | grep -v grep'
```

If no process is displayed, run:

```bash
docker exec spark-master sh -lc '
timeout 60s /opt/spark/bin/spark-submit \
  --master spark://spark-master:7077 \
  --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.0 \
  /opt/member3/trade_finance_streaming.py
'
```

Expected output includes:

```text
TRADE FINANCE STRUCTURED STREAMING STARTED

Kafka -> Spark Structured Streaming -> JSON Parsing

Batch: 0
```

followed by structured Trade Finance event records.

---

# Run Application 2 – Real-Time Analytics

Confirm again that no previous Trade Finance Spark application is using the worker:

```bash
docker exec spark-master sh -lc \
'ps -ef | grep -E "trade_finance|spark-submit|pyspark" | grep -v grep'
```

Then run:

```bash
docker exec spark-master sh -lc '
timeout 60s /opt/spark/bin/spark-submit \
  --master spark://spark-master:7077 \
  --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.0 \
  /opt/member3/trade_finance_analytics.py
'
```

Expected output:

```text
REAL-TIME TRADE FINANCE ANALYTICS

Unique Transaction & Currency Exposure Monitoring
```

followed by continuously updated currency-level KPIs.

---

# Run Application 3 – Real-Time Risk Alerts

Check that no previous Trade Finance Spark application is running:

```bash
docker exec spark-master sh -lc \
'ps -ef | grep -E "trade_finance|spark-submit|pyspark" | grep -v grep'
```

Then run:

```bash
docker exec spark-master sh -lc '
timeout 60s /opt/spark/bin/spark-submit \
  --master spark://spark-master:7077 \
  --packages org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.0 \
  /opt/member3/trade_finance_risk_alerts.py
'
```

Expected output:

```text
REAL-TIME TRADE FINANCE RISK ALERTS

Streaming Rule-Based Risk Detection
```

followed by HIGH-risk transaction alerts.

---

# Spark Resource Note

The current development environment uses a limited Spark worker.

Only one major Trade Finance Structured Streaming application should be executed at a time.

Before starting another application, use:

```bash
docker exec spark-master sh -lc \
'ps -ef | grep -E "trade_finance|spark-submit|pyspark" | grep -v grep'
```

If an old Trade Finance application remains active, it may consume all Spark Worker resources and cause:

```text
Initial job has not accepted any resources
```

A remaining Trade Finance application can be terminated using:

```bash
docker exec spark-master sh -lc \
"pkill -TERM -f 'trade_finance_(streaming|analytics|risk_alerts)\.py' || true"
```

Then verify again that no process remains.

---

# Timeout Behaviour

The demonstration commands use:

```text
timeout 60s
```

because Spark Structured Streaming applications are designed to run continuously.

For the project demonstration, the timeout automatically stops the application after approximately 60 seconds.

When the timeout terminates a running micro-batch, Spark may display a shutdown-related message such as:

```text
Cannot call methods on a stopped SparkContext
```

This can occur because the demonstration timeout stops the Spark context while the continuous streaming query is still active.

Successful batches generated before the timeout remain valid demonstration results.

---

# Demonstration Flow

For the final demonstration, the recommended sequence is:

```text
1. Verify Docker services
        ↓
2. Generate Trade Finance data
        ↓
3. Publish events to Kafka
        ↓
4. Demonstrate Kafka topics
        ↓
5. Run Spark Structured Streaming
        ↓
6. Demonstrate real-time analytics
        ↓
7. Demonstrate high-risk alerts
```

The demonstration shows the complete real-time flow:

```text
Trade Finance Events
        ↓
Kafka
        ↓
Spark Structured Streaming
        ↓
JSON Parsing & Validation
        ↓
Transaction-Level Processing
        ↓
Real-Time Analytics
        ↓
Risk Scoring
        ↓
High-Risk Alerts
```

---

# Key Design Decisions

## Transaction Deduplication

Trade Finance transactions generate multiple lifecycle events.

Using the same transaction amount from every event would overstate transaction value.

Therefore:

```text
transaction_id
```

is used to identify unique transactions before transaction-level analytics are calculated.

---

## Currency-Level Analysis

Transaction values in:

```text
CAD
CNY
EUR
GBP
JPY
USD
```

are not directly added together.

The analytics pipeline groups transactions by currency to provide more meaningful exposure monitoring.

---

## Rule-Based Risk Engine

Risk detection is intentionally transparent.

The risk engine allows users to see:

```text
Risk Score
+
Risk Level
+
Risk Reason
```

for each high-risk transaction.

This module focuses on real-time engineering and rule-based monitoring.

Machine Learning-based predictive analysis is handled separately by the project intelligence and decision-support component.

---

# Project Evidence

The Member 3 implementation demonstrates:

1. Kafka successfully receiving Trade Finance lifecycle events
2. Spark Structured Streaming consuming multiple Kafka topics
3. Real-time transaction and currency analytics
4. Real-time rule-based risk detection and HIGH-risk alerts

The main demonstration evidence includes:

```text
01_Kafka_Ingestion
02_Spark_Structured_Streaming
03_Real_Time_Trade_Finance_Analytics
04_Real_Time_Risk_Alerts
```

---

# Member 3 Contribution

**Name:** Han-Pin Hung  
**Role:** Real-Time Big Data Engineering  

### Main Contributions

- Stabilized Spark-related Big Data infrastructure dependencies
- Integrated Kafka with Spark Structured Streaming
- Implemented multi-topic Trade Finance event ingestion
- Implemented JSON schema parsing and basic validation
- Extracted transaction-level business fields
- Implemented transaction deduplication
- Developed real-time Trade Finance currency analytics
- Developed real-time risk scoring logic
- Implemented HIGH-risk transaction alerts
- Added reproducible execution and demonstration documentation

---

## Summary

The Member 3 module provides the real-time processing layer of the Trade Finance Intelligence and Risk Management platform.

It transforms raw Trade Finance lifecycle events into:

```text
Structured Events
        ↓
Business KPIs
        ↓
Risk Scores
        ↓
Actionable High-Risk Alerts
```

This demonstrates how Kafka and Spark Structured Streaming can support real-time financial transaction monitoring and risk management in a Trade Finance environment.

---

**Developed by Han-Pin Hung**  
**Member 3 – Real-Time Big Data Engineering**