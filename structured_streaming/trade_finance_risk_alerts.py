from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col,
    from_json,
    when,
    concat_ws,
    lit,
)
from pyspark.sql.types import (
    StructType,
    StructField,
    StringType,
    DoubleType,
    IntegerType,
)


# ---------------------------------------------------------
# 1. Spark Session
# ---------------------------------------------------------
spark = (
    SparkSession.builder
    .appName("TradeFinanceRealTimeRiskAlerts")
    .getOrCreate()
)

spark.sparkContext.setLogLevel("WARN")


# ---------------------------------------------------------
# 2. JSON Schemas
# ---------------------------------------------------------
payload_schema = StructType([
    StructField("transaction_id", StringType(), True),
    StructField("product_type", StringType(), True),
    StructField("applicant_country", StringType(), True),
    StructField("beneficiary_country", StringType(), True),
    StructField("currency", StringType(), True),
    StructField("amount", DoubleType(), True),
    StructField("customer_risk_rating", StringType(), True),
    StructField("discrepancy_flag", IntegerType(), True),
    StructField("delay_flag", IntegerType(), True),
    StructField("result", StringType(), True),
    StructField("risk_rating", StringType(), True),
])

event_schema = StructType([
    StructField("event_id", StringType(), True),
    StructField("event_type", StringType(), True),
    StructField("event_time", StringType(), True),
    StructField("source", StringType(), True),
    StructField("aggregate_type", StringType(), True),
    StructField("aggregate_id", StringType(), True),
    StructField("transaction_id", StringType(), True),
    StructField("schema_version", StringType(), True),
    StructField("payload", payload_schema, True),
])


# ---------------------------------------------------------
# 3. Kafka Streaming Source
# ---------------------------------------------------------
kafka_stream = (
    spark.readStream
    .format("kafka")
    .option("kafka.bootstrap.servers", "kafka:9092")
    .option(
        "subscribePattern",
        r"tf\.(lc|guarantee|collection|payment|document|shipment|compliance|sanctions|limit)\.events"
    )
    .option("startingOffsets", "earliest")
    .option("maxOffsetsPerTrigger", "500")
    .option("failOnDataLoss", "false")
    .load()
)


# ---------------------------------------------------------
# 4. Parse JSON
# ---------------------------------------------------------
parsed_events = (
    kafka_stream
    .selectExpr(
        "topic",
        "CAST(value AS STRING) AS json_value"
    )
    .withColumn(
        "event",
        from_json(col("json_value"), event_schema)
    )
    .filter(
        col("event").isNotNull()
        & col("event.transaction_id").isNotNull()
    )
)


# ---------------------------------------------------------
# 5. Extract Trade Finance Fields
# ---------------------------------------------------------
transactions = (
    parsed_events
    .select(
        col("event.transaction_id").alias("transaction_id"),
        col("event.event_type").alias("event_type"),
        col("event.payload.product_type").alias("product_type"),
        col("event.payload.applicant_country").alias("applicant_country"),
        col("event.payload.beneficiary_country").alias("beneficiary_country"),
        col("event.payload.currency").alias("currency"),
        col("event.payload.amount").alias("amount"),
        col("event.payload.customer_risk_rating")
            .alias("customer_risk_rating"),
        col("event.payload.discrepancy_flag")
            .alias("discrepancy_flag"),
        col("event.payload.delay_flag")
            .alias("delay_flag"),
    )
    .filter(
        col("transaction_id").startswith("TF-")
        & col("amount").isNotNull()
    )
    .dropDuplicates(["transaction_id"])
)


# ---------------------------------------------------------
# 6. Real-Time Risk Score
# ---------------------------------------------------------
risk_scored = (
    transactions

    .withColumn(
        "risk_score",
        when(col("customer_risk_rating") == "HIGH", 3).otherwise(0)
        + when(col("discrepancy_flag") == 1, 2).otherwise(0)
        + when(col("delay_flag") == 1, 2).otherwise(0)
        + when(col("amount") >= 1000000, 2).otherwise(0)
    )

    .withColumn(
        "risk_level",
        when(col("risk_score") >= 5, "HIGH")
        .when(col("risk_score") >= 3, "MEDIUM")
        .otherwise("LOW")
    )
)


# ---------------------------------------------------------
# 7. Human-Readable Risk Reason
# ---------------------------------------------------------
risk_with_reason = (
    risk_scored
    .withColumn(
        "risk_reason",
        concat_ws(
            "; ",
            when(
                col("customer_risk_rating") == "HIGH",
                lit("High-risk customer")
            ),
            when(
                col("discrepancy_flag") == 1,
                lit("Document discrepancy")
            ),
            when(
                col("delay_flag") == 1,
                lit("Processing delay")
            ),
            when(
                col("amount") >= 1000000,
                lit("Large transaction >= 1M")
            ),
        )
    )
)


# ---------------------------------------------------------
# 8. HIGH-RISK Alerts Only
# ---------------------------------------------------------
high_risk_alerts = (
    risk_with_reason
    .filter(col("risk_level") == "HIGH")
    .select(
        "transaction_id",
        "product_type",
        "beneficiary_country",
        "currency",
        "amount",
        "risk_score",
        "risk_level",
        "risk_reason",
    )
)


print("=" * 92)
print("REAL-TIME TRADE FINANCE RISK ALERTS")
print("Streaming Rule-Based Risk Detection")
print("=" * 92)


query = (
    high_risk_alerts.writeStream
    .format("console")
    .outputMode("append")
    .option("truncate", "false")
    .option("numRows", "15")
    .start()
)


query.awaitTermination()