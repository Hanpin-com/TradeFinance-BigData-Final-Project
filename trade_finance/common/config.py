import os

KAFKA_BOOTSTRAP = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092")
HBASE_HOST = os.getenv("HBASE_HOST", "hbase")
HBASE_PORT = int(os.getenv("HBASE_PORT", "9090"))
HIVE_HOST = os.getenv("HIVE_HOST", "hive-server")
HIVE_PORT = int(os.getenv("HIVE_PORT", "10000"))

TOPICS = {
    "lc": "tf.lc.events",
    "guarantee": "tf.guarantee.events",
    "collection": "tf.collection.events",
    "payment": "tf.payment.events",
    "document": "tf.document.events",
    "shipment": "tf.shipment.events",
    "compliance": "tf.compliance.events",
    "sanctions": "tf.sanctions.events",
    "limit": "tf.limit.events",
    "fx": "tf.fx.events",
    "anomaly": "tf.ml.anomaly-results",
    "discrepancy": "tf.ml.discrepancy-results",
    "delay": "tf.ml.delay-results",
    "forecast": "tf.ml.forecast-results",
    "dlq": "tf.dlq.events",
}

INPUT_TOPICS = [
    TOPICS["lc"], TOPICS["guarantee"], TOPICS["collection"], TOPICS["payment"],
    TOPICS["document"], TOPICS["shipment"], TOPICS["compliance"],
    TOPICS["sanctions"], TOPICS["limit"], TOPICS["fx"],
]
