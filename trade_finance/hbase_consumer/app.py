import json
import time
import traceback
import socket
from datetime import datetime

from thrift.transport.TTransport import TTransportException

from confluent_kafka import Consumer, Producer

from trade_finance.common.config import KAFKA_BOOTSTRAP, INPUT_TOPICS, TOPICS
from trade_finance.common.hbase_schema import connect, ensure_schema
from trade_finance.common.hive_bootstrap import apply_hive_schema


# ---------------------------------------------------------------------------
# Diagnostic helper
# ---------------------------------------------------------------------------

def log(message):
    print(
        f"[{datetime.now().isoformat(timespec='seconds')}] {message}",
        flush=True,
    )


# ---------------------------------------------------------------------------
# HBase / Hive initialization and resilient connection management
# ---------------------------------------------------------------------------

HBASE_TABLE_NAMES = [
    "trade_transactions",
    "trade_events",
    "trade_documents",
    "trade_counterparties",
    "trade_ml_results",
    "trade_fx_rates",
]

HBASE_MAX_RETRIES = 5
HBASE_RETRY_BACKOFF_SECONDS = 2

conn = None
tables = {}


def close_hbase_connection():
    global conn
    if conn is not None:
        try:
            conn.close()
        except Exception as exc:
            log(f"HBase connection close warning: {exc}")
        finally:
            conn = None


def open_hbase_connection(ensure=False):
    global conn, tables

    close_hbase_connection()

    log("Connecting to HBase...")
    conn = connect()
    log("HBase connection established.")

    if ensure:
        log("Ensuring HBase schema...")
        ensure_schema(conn)
        log("HBase schema ready.")

    tables = {
        name: conn.table(name)
        for name in HBASE_TABLE_NAMES
    }

    log(
        "HBase table handles initialized: "
        + ", ".join(tables.keys())
    )


def is_hbase_transport_error(exc):
    current = exc
    visited = set()

    while current is not None and id(current) not in visited:
        visited.add(id(current))

        if isinstance(
            current,
            (
                BrokenPipeError,
                ConnectionResetError,
                ConnectionAbortedError,
                ConnectionRefusedError,
                TimeoutError,
                EOFError,
                socket.timeout,
                socket.error,
                TTransportException,
            ),
        ):
            return True

        text = str(current).lower()
        if any(
            marker in text
            for marker in (
                "broken pipe",
                "connection reset",
                "connection aborted",
                "connection refused",
                "socket read 0 bytes",
                "transport exception",
                "timed out",
                "not open",
            )
        ):
            return True

        current = current.__cause__ or current.__context__

    return False


open_hbase_connection(ensure=True)

log("Applying Hive schema...")
apply_hive_schema()
log("Hive schema ready.")


# ---------------------------------------------------------------------------
# Kafka Consumer
# ---------------------------------------------------------------------------

log(
    f"Creating Kafka consumer. "
    f"Bootstrap={KAFKA_BOOTSTRAP}, "
    f"Group=tf-hbase-writer"
)

consumer = Consumer(
    {
        "bootstrap.servers": KAFKA_BOOTSTRAP,

        # Stable consumer group used by the HBase writer.
        "group.id": "tf-hbase-writer",

        # Explicitly use the classic consumer-group protocol.
        "group.protocol": "classic",

        # Explicit partition assignment strategy for the classic protocol.
        "partition.assignment.strategy": "range",

        # Consume historical events when no committed offset exists.
        "auto.offset.reset": "earliest",

        # Commit only after successful HBase persistence.
        "enable.auto.commit": False,

        # ------------------------------------------------------------------
        # Consumer-group stability
        # ------------------------------------------------------------------

        "session.timeout.ms": 60000,

        "heartbeat.interval.ms": 10000,

        # HBase persistence is synchronous. Give processing enough time
        # before Kafka considers the application stalled.
        "max.poll.interval.ms": 900000,

        # ------------------------------------------------------------------
        # Connection resilience
        # ------------------------------------------------------------------

        "socket.keepalive.enable": True,

        "reconnect.backoff.ms": 500,

        "reconnect.backoff.max.ms": 5000,

        # Give this consumer an explicit client identity so it is easier
        # to identify in kafka-consumer-groups output.
        "client.id": "tf-hbase-consumer",
    }
)


# ---------------------------------------------------------------------------
# Kafka assignment callbacks
# ---------------------------------------------------------------------------

def on_assign(consumer_instance, partitions):
    log(
        "Kafka partitions ASSIGNED: "
        + ", ".join(
            f"{p.topic}[{p.partition}]"
            for p in partitions
        )
    )


def on_revoke(consumer_instance, partitions):
    log(
        "Kafka partitions REVOKED: "
        + ", ".join(
            f"{p.topic}[{p.partition}]"
            for p in partitions
        )
    )


def on_lost(consumer_instance, partitions):
    log(
        "Kafka partitions LOST: "
        + ", ".join(
            f"{p.topic}[{p.partition}]"
            for p in partitions
        )
    )


log(
    "Registering Kafka subscription: "
    + ", ".join(INPUT_TOPICS)
)

consumer.subscribe(
    INPUT_TOPICS,
    on_assign=on_assign,
    on_revoke=on_revoke,
    on_lost=on_lost,
)

log("Kafka subscription registered.")


# ---------------------------------------------------------------------------
# Kafka Dead Letter Queue Producer
# ---------------------------------------------------------------------------

dlq = Producer(
    {
        "bootstrap.servers": KAFKA_BOOTSTRAP,
        "client.id": "tf-hbase-dlq",
    }
)

log("Kafka DLQ producer initialized.")


# ---------------------------------------------------------------------------
# Utility functions
# ---------------------------------------------------------------------------

def enc(x):
    return str(x).encode("utf-8")


# ---------------------------------------------------------------------------
# Trade transaction projection
# ---------------------------------------------------------------------------

def update_transaction(e):
    p = e.get("payload", {})

    tid = e["transaction_id"]

    if tid == "REFERENCE":
        return

    row = {}

    mapping = {
        b"instrument:product_type": "product_type",
        b"instrument:status": "status",
        b"instrument:issue_date": "issue_date",
        b"instrument:expiry_date": "expiry_date",

        b"parties:applicant_id": "applicant_id",
        b"parties:beneficiary_id": "beneficiary_id",

        b"geography:applicant_country": "applicant_country",
        b"geography:beneficiary_country": "beneficiary_country",

        b"trade:goods_category": "goods_category",

        b"financial:currency": "currency",
        b"financial:amount": "amount",

        b"metrics:amendment_count": "amendment_count",
        b"metrics:document_count": "document_count",
        b"metrics:processing_days": "processing_days",
        b"metrics:discrepancy_flag": "discrepancy_flag",
        b"metrics:delay_flag": "delay_flag",
        b"metrics:counterparty_relationship_years":
            "counterparty_relationship_years",

        b"risk:customer_risk_rating": "customer_risk_rating",
    }

    for col, key in mapping.items():
        if key in p and p[key] is not None:
            row[col] = enc(p[key])

    row[b"audit:last_event_id"] = enc(e["event_id"])
    row[b"audit:last_event_type"] = enc(e["event_type"])
    row[b"audit:last_event_time"] = enc(e["event_time"])

    tables["trade_transactions"].put(
        enc(tid),
        row,
    )


# ---------------------------------------------------------------------------
# Persist Kafka event into HBase
# ---------------------------------------------------------------------------

def persist_once(e):
    tid = e["transaction_id"]
    et = e["event_type"]
    p = e.get("payload", {})

    event_id = e["event_id"]

    event_key = (
        f'{tid}#{e["event_time"]}#{event_id}'
    )

    # -----------------------------------------------------------------------
    # Event history
    # -----------------------------------------------------------------------

    log(
        f"HBase PUT trade_events START "
        f"event_id={event_id}"
    )

    started = time.monotonic()

    tables["trade_events"].put(
        enc(event_key),
        {
            b"event:type":
                enc(et),

            b"event:time":
                enc(e["event_time"]),

            b"source:system":
                enc(e["source"]),

            b"workflow:aggregate_type":
                enc(e["aggregate_type"]),

            b"workflow:aggregate_id":
                enc(e["aggregate_id"]),

            b"audit:schema_version":
                enc(e.get("schema_version", "1.0")),

            b"event:payload":
                enc(
                    json.dumps(
                        p,
                        separators=(",", ":"),
                    )
                ),
        },
    )

    log(
        f"HBase PUT trade_events COMPLETE "
        f"event_id={event_id} "
        f"duration={time.monotonic() - started:.3f}s"
    )

    # -----------------------------------------------------------------------
    # Document projection
    # -----------------------------------------------------------------------

    if e["aggregate_type"] == "DOCUMENT":

        log(
            f"HBase PUT trade_documents START "
            f"event_id={event_id}"
        )

        started = time.monotonic()

        tables["trade_documents"].put(
            enc(e["aggregate_id"]),
            {
                b"document:transaction_id":
                    enc(tid),

                b"document:type":
                    enc(p.get("document_type", "")),

                b"presentation:event_type":
                    enc(et),

                b"audit:last_event_time":
                    enc(e["event_time"]),
            },
        )

        log(
            f"HBase PUT trade_documents COMPLETE "
            f"event_id={event_id} "
            f"duration={time.monotonic() - started:.3f}s"
        )

    # -----------------------------------------------------------------------
    # FX Rate projection
    # -----------------------------------------------------------------------

    if et == "FX_RATE_UPDATED":

        log(
            f"HBase PUT trade_fx_rates START "
            f"event_id={event_id}"
        )

        started = time.monotonic()

        tables["trade_fx_rates"].put(
            enc(e["aggregate_id"]),
            {
                b"rate:base_currency":
                    enc(p["base_currency"]),

                b"rate:quote_currency":
                    enc(p["quote_currency"]),

                b"rate:value":
                    enc(p["rate"]),

                b"audit:last_event_time":
                    enc(e["event_time"]),
            },
        )

        log(
            f"HBase PUT trade_fx_rates COMPLETE "
            f"event_id={event_id} "
            f"duration={time.monotonic() - started:.3f}s"
        )

    # -----------------------------------------------------------------------
    # Main transaction projection
    # -----------------------------------------------------------------------

    log(
        f"HBase transaction projection START "
        f"event_id={event_id}"
    )

    started = time.monotonic()

    update_transaction(e)

    log(
        f"HBase transaction projection COMPLETE "
        f"event_id={event_id} "
        f"duration={time.monotonic() - started:.3f}s"
    )


# ---------------------------------------------------------------------------
# Resilient HBase persistence
# ---------------------------------------------------------------------------

def persist(e):
    event_id = e.get("event_id", "<missing-event-id>")

    for attempt in range(1, HBASE_MAX_RETRIES + 1):
        try:
            persist_once(e)
            return

        except Exception as exc:
            if not is_hbase_transport_error(exc):
                raise

            log(
                f"HBase transport failure "
                f"event_id={event_id} "
                f"attempt={attempt}/{HBASE_MAX_RETRIES} "
                f"error={exc}"
            )

            if attempt >= HBASE_MAX_RETRIES:
                raise

            delay = HBASE_RETRY_BACKOFF_SECONDS * attempt
            log(
                f"Reconnecting to HBase before retrying SAME event "
                f"event_id={event_id} delay={delay}s"
            )

            close_hbase_connection()
            time.sleep(delay)

            try:
                open_hbase_connection(ensure=False)
            except Exception as reconnect_exc:
                log(
                    f"HBase reconnect attempt failed "
                    f"event_id={event_id} error={reconnect_exc}"
                )
                if attempt >= HBASE_MAX_RETRIES:
                    raise


# ---------------------------------------------------------------------------
# Kafka processing loop
# ---------------------------------------------------------------------------

log(
    f"Trade Finance HBase consumer starting. "
    f"Kafka={KAFKA_BOOTSTRAP}, "
    f"Group=tf-hbase-writer, "
    f"Topics={INPUT_TOPICS}"
)

poll_count = 0


try:

    while True:

        poll_count += 1

        # Avoid flooding the log once everything is working.
        # We still log periodically while the consumer is idle.
        if poll_count == 1 or poll_count % 10 == 0:
            log(
                f"Calling consumer.poll() "
                f"poll_count={poll_count}"
            )

        msg = consumer.poll(1.0)

        if msg is None:

            if poll_count % 10 == 0:
                log(
                    "Kafka poll returned no message."
                )

            continue

        if msg.error():

            log(
                f"Kafka consumer error: {msg.error()}"
            )

            continue

        log(
            f"Kafka message received: "
            f"topic={msg.topic()} "
            f"partition={msg.partition()} "
            f"offset={msg.offset()}"
        )

        try:

            e = json.loads(msg.value())

            event_id = e.get(
                "event_id",
                "<missing-event-id>",
            )

            log(
                f"Persist START "
                f"event_id={event_id}"
            )

            persist_started = time.monotonic()

            persist(e)

            log(
                f"Persist COMPLETE "
                f"event_id={event_id} "
                f"duration="
                f"{time.monotonic() - persist_started:.3f}s"
            )

            # ---------------------------------------------------------------
            # Offset commit
            # ---------------------------------------------------------------

            log(
                f"Kafka commit REQUEST "
                f"topic={msg.topic()} "
                f"partition={msg.partition()} "
                f"offset={msg.offset()}"
            )

            consumer.commit(
                message=msg,
                asynchronous=False,
            )

            log(
                f"Kafka commit COMPLETE "
                f"topic={msg.topic()} "
                f"partition={msg.partition()} "
                f"offset={msg.offset()}"
            )

        except Exception as exc:

            log(
                f"Failed event: "
                f"topic={msg.topic()} "
                f"partition={msg.partition()} "
                f"offset={msg.offset()} "
                f"error={exc}"
            )

            traceback.print_exc()

            try:

                log(
                    f"DLQ produce START "
                    f"topic={TOPICS['dlq']}"
                )

                dlq.produce(
                    TOPICS["dlq"],
                    key=msg.key(),
                    value=msg.value(),
                )

                dlq.flush()

                log(
                    f"DLQ produce COMPLETE "
                    f"topic={TOPICS['dlq']}"
                )

                # The event could not be persisted after bounded retries,
                # but it is now durably handed to the DLQ. Commit its source
                # offset so one poison event cannot block the partition forever.
                consumer.commit(
                    message=msg,
                    asynchronous=False,
                )

                log(
                    f"Kafka offset committed after DLQ "
                    f"topic={msg.topic()} "
                    f"partition={msg.partition()} "
                    f"offset={msg.offset()}"
                )

            except Exception as dlq_exc:

                log(
                    f"DLQ failure: {dlq_exc}"
                )

                traceback.print_exc()


except KeyboardInterrupt:

    log(
        "Shutdown requested."
    )


except Exception as fatal_exc:

    log(
        f"FATAL consumer error: {fatal_exc}"
    )

    traceback.print_exc()

    raise


finally:

    log(
        "Closing Kafka consumer..."
    )

    try:
        consumer.close()
    except Exception as close_exc:
        log(
            f"Kafka consumer close error: {close_exc}"
        )

    log(
        "Flushing DLQ producer..."
    )

    try:
        dlq.flush(10)
    except Exception as flush_exc:
        log(
            f"DLQ producer flush error: {flush_exc}"
        )

    log(
        "Trade Finance HBase consumer stopped."
    )