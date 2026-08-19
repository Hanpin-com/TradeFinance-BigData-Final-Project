import json, os, random, math
from datetime import datetime, timedelta, timezone
from pathlib import Path
from faker import Faker

SEED = int(os.getenv("TF_RANDOM_SEED", "42"))
COUNT = int(os.getenv("TF_TRANSACTION_COUNT", "5000"))
OUT = Path(os.getenv("OUTPUT_DIR", "/data/trade-finance"))
OUT.mkdir(parents=True, exist_ok=True)
random.seed(SEED)
fake = Faker()
Faker.seed(SEED)

COUNTRIES = ["CA","US","DE","GB","FR","CN","JP","MX","BR","IN","SG","AE"]
CURRENCIES = ["CAD","USD","EUR","GBP","JPY","CNY"]
PRODUCTS = ["IMPORT_LC","EXPORT_LC","GUARANTEE","COLLECTION"]
GOODS = ["INDUSTRIAL_EQUIPMENT","ELECTRONICS","AGRICULTURE","CHEMICALS","TEXTILES","AUTO_PARTS"]
DOC_TYPES = ["COMMERCIAL_INVOICE","BILL_OF_LADING","PACKING_LIST","CERTIFICATE_OF_ORIGIN","INSURANCE_CERTIFICATE"]

def iso(dt): return dt.astimezone(timezone.utc).isoformat()

customers = []
counterparties = []
for i in range(1, 1201):
    customers.append({"customer_id":f"CUST-{i:05d}","name":fake.company(),"country":"CA",
                      "industry":random.choice(GOODS),"risk_rating":random.choice(["LOW","MEDIUM","HIGH"])})
for i in range(1, 3501):
    counterparties.append({"counterparty_id":f"CP-{i:05d}","name":fake.company(),
                           "country":random.choice(COUNTRIES[1:]),"relationship_years":random.randint(0,15)})

(OUT/"customers.json").write_text(json.dumps(customers, indent=2), encoding="utf-8")
(OUT/"counterparties.json").write_text(json.dumps(counterparties, indent=2), encoding="utf-8")

events = []
transactions = []
now = datetime.now(timezone.utc)

for i in range(1, COUNT+1):
    txid = f"TF-{now.year}-{i:07d}"
    product = random.choice(PRODUCTS)
    applicant = random.choice(customers)
    cp = random.choice(counterparties)
    issue = now - timedelta(days=random.randint(1, 730))
    amount = round(random.lognormvariate(13.0, 1.05), 2)
    currency = random.choice(CURRENCIES)
    amendment_count = random.randint(0,5)
    doc_count = random.randint(3,10)
    processing_days = max(1, int(random.gauss(7 + amendment_count*1.5, 4)))
    discrepancy = 1 if random.random() < min(.75, .08 + amendment_count*.07 + (0.1 if cp["relationship_years"] < 1 else 0)) else 0
    delayed = 1 if processing_days > 10 else 0
    status = random.choice(["ACTIVE","SETTLED","CLOSED"])
    tx = {
        "transaction_id":txid, "product_type":product,
        "applicant_id":applicant["customer_id"], "beneficiary_id":cp["counterparty_id"],
        "applicant_country":applicant["country"], "beneficiary_country":cp["country"],
        "currency":currency, "amount":amount, "issue_date":issue.date().isoformat(),
        "expiry_date":(issue+timedelta(days=random.randint(60,180))).date().isoformat(),
        "status":status, "goods_category":random.choice(GOODS), "amendment_count":amendment_count,
        "document_count":doc_count, "processing_days":processing_days,
        "discrepancy_flag":discrepancy, "delay_flag":delayed,
        "counterparty_relationship_years":cp["relationship_years"],
        "customer_risk_rating":applicant["risk_rating"],
    }
    transactions.append(tx)

    base_payload = dict(tx)
    aggregate = "LETTER_OF_CREDIT" if "LC" in product else product
    def add(event_type, source, when, payload=None, aggregate_type=aggregate, aggregate_id=txid):
        events.append({
          "event_id":f"EV-{len(events)+1:010d}", "event_type":event_type, "event_time":iso(when),
          "source":source, "aggregate_type":aggregate_type, "aggregate_id":aggregate_id,
          "transaction_id":txid, "schema_version":"1.0", "payload": payload or base_payload
        })

    if product in ("IMPORT_LC","EXPORT_LC"):
        add("LC_APPLICATION_RECEIVED","lc-system",issue)
        add("LIMIT_CHECK_COMPLETED","limit-system",issue+timedelta(minutes=15),
            {"limit_status":"APPROVED","utilization_pct":round(random.uniform(10,85),2), **base_payload})
        add("COMPLIANCE_SCREENING_COMPLETED","compliance-system",issue+timedelta(minutes=30),
            {"result":"CLEAR","risk_rating":applicant["risk_rating"], **base_payload})
        add("SANCTIONS_SCREENING_COMPLETED","sanctions-system",issue+timedelta(minutes=40),
            {"result":"NO_MATCH", **base_payload})
        add("LC_ISSUED","lc-system",issue+timedelta(hours=2))
        for a in range(amendment_count):
            add("LC_AMENDED","lc-system",issue+timedelta(days=a+1), {"amendment_number":a+1, **base_payload})
    elif product == "GUARANTEE":
        add("GUARANTEE_APPLICATION_RECEIVED","guarantee-system",issue)
        add("GUARANTEE_ISSUED","guarantee-system",issue+timedelta(hours=2))
    else:
        add("COLLECTION_RECEIVED","collection-system",issue)
        add("COLLECTION_REGISTERED","collection-system",issue+timedelta(hours=1))

    ship_time = issue + timedelta(days=random.randint(2,20))
    add("SHIPMENT_RECORDED","shipment-system",ship_time,
        {"shipment_id":f"SHP-{i:07d}","transport_mode":random.choice(["SEA","AIR","ROAD"]), **base_payload},
        "SHIPMENT", f"SHP-{i:07d}")

    presentation = ship_time + timedelta(days=random.randint(1,8))
    for d in range(doc_count):
        docid=f"DOC-{i:07d}-{d+1:02d}"
        add("DOCUMENT_PRESENTED","document-system",presentation+timedelta(minutes=d),
            {"document_id":docid,"document_type":random.choice(DOC_TYPES),"presentation_no":1, **base_payload},
            "DOCUMENT", docid)
    if discrepancy:
        add("DISCREPANCY_IDENTIFIED","document-system",presentation+timedelta(hours=5),
            {"discrepancy_code":random.choice(["LATE_SHIPMENT","AMOUNT_MISMATCH","MISSING_DOCUMENT","DESCRIPTION_MISMATCH"]), **base_payload})
    else:
        add("DOCUMENTS_COMPLIANT","document-system",presentation+timedelta(hours=5))

    payment_time = presentation + timedelta(days=processing_days)
    add("PAYMENT_AUTHORIZED","payment-system",payment_time)
    add("PAYMENT_SETTLED","payment-system",payment_time+timedelta(minutes=30),
        {"settlement_amount":amount,"currency":currency, **base_payload})

# Generate reference FX events
for ccy in CURRENCIES:
    events.append({
        "event_id":f"EV-{len(events)+1:010d}","event_type":"FX_RATE_UPDATED","event_time":iso(now),
        "source":"fx-feed","aggregate_type":"FX_RATE","aggregate_id":f"{ccy}CAD",
        "transaction_id":"REFERENCE","schema_version":"1.0",
        "payload":{"base_currency":ccy,"quote_currency":"CAD","rate":round(random.uniform(.009,1.9),6)}
    })

with (OUT/"events.jsonl").open("w", encoding="utf-8") as f:
    for e in sorted(events, key=lambda x: x["event_time"]):
        f.write(json.dumps(e, separators=(",",":"))+"\n")
(OUT/"transactions.json").write_text(json.dumps(transactions, indent=2), encoding="utf-8")
print(f"Generated {len(transactions)} transactions and {len(events)} lifecycle events in {OUT}")
