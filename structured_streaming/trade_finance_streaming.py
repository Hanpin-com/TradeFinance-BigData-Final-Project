from pyspark.sql import SparkSession
from pyspark.sql.functions import col, from_json
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
    .appName("TradeFinanceRealTimeStreaming")
    .getOrCreate()
)

spark.sparkContext.setLogLevel("WARN")


# ---------------------------------------------------------
# 2. Trade Finance Payload Schema
# ---------------------------------------------------------
payload_schema = StructType([
    StructField("transaction_id", StringType(), True),
    StructField("product_type", StringType(), True),
    StructField("applicant_id", StringType(), True),
    StructField("beneficiary_id", StringType(), True),
    StructField("applicant_country", StringType(), True),
    StructField("beneficiary_country", StringType(), True),
    StructField("currency", StringType(), True),
    StructField("amount", DoubleType(), True),
    StructField("issue_date", StringType(), True),
    StructField("expiry_date", StringType(), True),
    StructField("status", StringType(), True),
    StructField("goods_category", StringType(), True),
    StructField("amendment_count", IntegerType(), True),
    StructField("document_count", IntegerType(), True),
    StructField("processing_days", IntegerType(), True),
    StructField("discrepancy_flag", IntegerType(), True),
    StructField("delay_flag", IntegerType(), True),
    StructField("counterparty_relationship_years", IntegerType(), True),
    StructField("customer_risk_rating", StringType(), True),

    # Compliance-specific optional fields
    StructField("result", StringType(), True),
    StructField("risk_rating", StringType(), True),
])


# ---------------------------------------------------------
# 3. Event Envelope Schema
# ---------------------------------------------------------
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
# 4. Read Real-Time Events from Kafka
# ---------------------------------------------------------
kafka_stream = (
    spark.readStream
    .format("kafka")
    .option("kafka.bootstrap.servers", "kafka:9092")
    .option(
        "subscribePattern",
        r"tf\.(lc|guarantee|collection|payment|document|shipment|compliance|sanctions|limit|fx)\.events"
    )
    .option("startingOffsets", "earliest")
    .option("maxOffsetsPerTrigger", "20")
    .option("failOnDataLoss", "false")
    .load()
)


# ---------------------------------------------------------
# 5. Convert Kafka Binary Value to JSON String
# ---------------------------------------------------------
raw_events = kafka_stream.selectExpr(
    "topic",
    "partition",
    "offset",
    "timestamp AS kafka_timestamp",
    "CAST(key AS STRING) AS kafka_key",
    "CAST(value AS STRING) AS json_value"
)


# ---------------------------------------------------------
# 6. Parse JSON
# ---------------------------------------------------------
parsed_events = (
    raw_events
    .withColumn(
        "event",
        from_json(col("json_value"), event_schema)
    )
)


# ---------------------------------------------------------
# 7. Basic Validation
# ---------------------------------------------------------
valid_events = parsed_events.filter(
    col("event").isNotNull()
    & col("event.event_id").isNotNull()
    & col("event.transaction_id").isNotNull()
)


# ---------------------------------------------------------
# 8. Flatten Important Business Fields
# ---------------------------------------------------------
trade_events = valid_events.select(
    col("topic"),
    col("event.event_id").alias("event_id"),
    col("event.event_type").alias("event_type"),
    col("event.event_time").alias("event_time"),
    col("event.transaction_id").alias("transaction_id"),

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
        .alias("delay_flag")
)


# ---------------------------------------------------------
# 9. Development Console Output
# ---------------------------------------------------------
query = (
    trade_events.writeStream
    .format("console")
    .outputMode("append")
    .option("truncate", "false")
    .option("numRows", "20")
    .start()
)


print("=" * 70)
print("TRADE FINANCE STRUCTURED STREAMING STARTED")
print("Kafka -> Spark Structured Streaming -> JSON Parsing")
print("=" * 70)


query.awaitTermination()