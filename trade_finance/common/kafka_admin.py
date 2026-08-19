import time
from confluent_kafka.admin import AdminClient, NewTopic
from confluent_kafka import KafkaException
from trade_finance.common.config import KAFKA_BOOTSTRAP, TOPICS

def ensure_topics():
    admin = AdminClient({"bootstrap.servers": KAFKA_BOOTSTRAP})
    existing = admin.list_topics(timeout=15).topics
    specs = []
    for topic in TOPICS.values():
        if topic not in existing:
            specs.append(NewTopic(topic, num_partitions=3, replication_factor=1))
    if not specs:
        return
    futures = admin.create_topics(specs)
    for topic, future in futures.items():
        try:
            future.result()
            print(f"Created Kafka topic {topic}", flush=True)
        except Exception as exc:
            if "TOPIC_ALREADY_EXISTS" not in str(exc):
                raise
