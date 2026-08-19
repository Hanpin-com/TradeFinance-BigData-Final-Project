#!/usr/bin/env bash
set -euo pipefail
B="${1:-localhost:9092}"
topics=(tf.lc.events tf.guarantee.events tf.collection.events tf.payment.events tf.document.events
tf.shipment.events tf.compliance.events tf.sanctions.events tf.limit.events tf.fx.events
tf.ml.anomaly-results tf.ml.discrepancy-results tf.ml.delay-results tf.ml.forecast-results tf.dlq.events)
for t in "${topics[@]}"; do
  /opt/kafka/bin/kafka-topics.sh --bootstrap-server "$B" --create --if-not-exists --topic "$t" --partitions 3 --replication-factor 1
done
