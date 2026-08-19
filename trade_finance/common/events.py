from dataclasses import dataclass, asdict
from datetime import datetime, timezone
import json, uuid

@dataclass
class TradeEvent:
    event_id: str
    event_type: str
    event_time: str
    source: str
    aggregate_type: str
    aggregate_id: str
    transaction_id: str
    payload: dict
    schema_version: str = "1.0"

    @classmethod
    def create(cls, event_type, source, aggregate_type, aggregate_id, transaction_id, payload):
        return cls(
            event_id=str(uuid.uuid4()),
            event_type=event_type,
            event_time=datetime.now(timezone.utc).isoformat(),
            source=source,
            aggregate_type=aggregate_type,
            aggregate_id=aggregate_id,
            transaction_id=transaction_id,
            payload=payload,
        )

    def to_json(self):
        return json.dumps(asdict(self), separators=(",", ":"), default=str)
