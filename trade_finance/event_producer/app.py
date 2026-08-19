import json, os, time
from confluent_kafka import Producer
from trade_finance.common.config import KAFKA_BOOTSTRAP, TOPICS
from trade_finance.common.kafka_admin import ensure_topics

ensure_topics()
producer = Producer({
    "bootstrap.servers": KAFKA_BOOTSTRAP,
    "client.id": "tf-event-producer",
    "enable.idempotence": True,
    "acks": "all",
})
path = os.getenv("TF_EVENTS_FILE", "/data/trade-finance/events.jsonl")
delay = int(os.getenv("TF_PRODUCER_DELAY_MS", "0")) / 1000.0

def route(e):
    t=e["event_type"]
    if t.startswith("LC_"): return TOPICS["lc"]
    if t.startswith("GUARANTEE_"): return TOPICS["guarantee"]
    if t.startswith("COLLECTION_"): return TOPICS["collection"]
    if t.startswith("PAYMENT_"): return TOPICS["payment"]
    if t.startswith("DOCUMENT") or t.startswith("DISCREPANCY"): return TOPICS["document"]
    if t.startswith("SHIPMENT_"): return TOPICS["shipment"]
    if t.startswith("COMPLIANCE_"): return TOPICS["compliance"]
    if t.startswith("SANCTIONS_"): return TOPICS["sanctions"]
    if t.startswith("LIMIT_"): return TOPICS["limit"]
    if t.startswith("FX_"): return TOPICS["fx"]
    return TOPICS["dlq"]

count=0
with open(path, encoding="utf-8") as f:
    for line in f:
        e=json.loads(line)
        producer.produce(route(e), key=e["transaction_id"], value=json.dumps(e,separators=(",",":")))
        producer.poll(0)
        count += 1
        if delay: time.sleep(delay)
producer.flush()
print(f"Published {count} Trade Finance events.")
