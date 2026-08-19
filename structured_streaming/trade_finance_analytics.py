from pyspark.sql import SparkSession
from pyspark.sql.functions import (
    col,
    from_json,
    count,
    sum as spark_sum,
    avg,
    when,
    round as spark_round,
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
    .appName("TradeFinanceRealTimeAnalytics")
    .getOrCreate()
)

spark.sparkContext.setLogLevel("WARN")


# ---------------------------------------------------------
# 2. Trade Finance JSON Schema
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
# 3. Read Trade Finance Events from Kafka
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
    .option("maxOffsetsPerTrigger", "1000")
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
        "timestamp AS kafka_timestamp",
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
# 5. Extract Business Fields
# ---------------------------------------------------------
trade_events = parsed_events.select(
    col("event.transaction_id").alias("transaction_id"),
    col("event.payload.product_type").alias("product_type"),
    col("event.payload.currency").alias("currency"),
    col("event.payload.amount").alias("amount"),
    col("event.payload.customer_risk_rating")
        .alias("customer_risk_rating"),
    col("event.payload.discrepancy_flag")
        .alias("discrepancy_flag"),
    col("event.payload.delay_flag")
        .alias("delay_flag"),
)


# ---------------------------------------------------------
# 6. Remove Lifecycle Duplicates
# One Trade Finance transaction can generate many events.
# ---------------------------------------------------------
unique_transactions = (
    trade_events
    .filter(
        col("transaction_id").startswith("TF-")
        & col("currency").isNotNull()
        & col("amount").isNotNull()
    )
    .dropDuplicates(["transaction_id"])
)


# ---------------------------------------------------------
# 7. Real-Time Currency Exposure Analytics
# ---------------------------------------------------------
currency_kpis = (
    unique_transactions
    .groupBy("currency")
    .agg(
        count("*").alias("unique_transactions"),

        spark_round(
            spark_sum("amount"), 2
        ).alias("total_value"),

        spark_round(
            avg("amount"), 2
        ).alias("avg_transaction_value"),

        spark_sum(
            when(
                col("customer_risk_rating") == "HIGH", 1
            ).otherwise(0)
        ).alias("high_risk_transactions"),

        spark_sum(
            when(
                col("discrepancy_flag") == 1, 1
            ).otherwise(0)
        ).alias("discrepancy_transactions"),

        spark_sum(
            when(
                col("delay_flag") == 1, 1
            ).otherwise(0)
        ).alias("delayed_transactions"),
    )
    .orderBy("currency")
)


# ---------------------------------------------------------
# 8. Streaming KPI Output
# ---------------------------------------------------------
print("=" * 76)
print("REAL-TIME TRADE FINANCE ANALYTICS")
print("Unique Transaction & Currency Exposure Monitoring")
print("=" * 76)


query = (
    currency_kpis.writeStream
    .format("console")
    .outputMode("complete")
    .option("truncate", "false")
    .option("numRows", "20")
    .start()
)


query.awaitTermination()