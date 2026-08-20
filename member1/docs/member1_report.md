# Member 1 Report – Trade Finance Intelligence & Risk Management

**Member:** Gurkirat Singh · Member 1 (Business & Data Architecture)

---

## 1. Executive Summary

Commercial banks process high volumes of Trade Finance instruments (Letters of Credit, Guarantees, Documentary Collections). Operational systems are optimized for transaction processing, not portfolio risk analytics or real-time anomaly detection. This project builds a Big Data platform that lands historical Trade Finance data on HDFS, processes it with batch and streaming engines, stores operational lookups in HBase, runs ML risk models, and surfaces decisions in Power BI.

Member 1 defines the business case, dataset, end-to-end architecture, HDFS landing zone, and YARN monitoring foundation used by the rest of the team.

## 2. Business Problem

Banks need answers such as:

- Which products / corridors carry the highest exposure?
- Which transactions show discrepancy or delay risk?
- How do sanctions / compliance hits concentrate by counterparty?
- What is arriving *right now* that needs an alert?

Running these workloads on the core Trade Finance OLTP system risks performance impact and lacks scalable analytics. A separate Big Data platform is required.

## 3. Business Requirements

| ID | Requirement |
|---|---|
| BR-1 | Ingest historical Trade Finance transactions and related parties |
| BR-2 | Durable distributed storage (HDFS) as system of record for raw/curated files |
| BR-3 | Batch analytics on historical portfolio (Member 2) |
| BR-4 | Fast operational lookup of transactions/customers (HBase – Member 2) |
| BR-5 | Real-time event stream for new transactions / risk alerts (Member 3) |
| BR-6 | ML anomaly / discrepancy / delay / volume forecasts (Member 4) |
| BR-7 | Management dashboards for decision support (Member 4 / Power BI) |
| BR-8 | Observable cluster resources via YARN |

## 4. Solution Overview

```
Trade Finance Sources (synthetic)
        │
        ▼
   HDFS (Member 1)  ─────────────────────────────┐
        │                                        │
        ├─► MapReduce / Hive / HBase (Member 2)  │
        │                                        │
        ├─► Kafka + Spark Streaming (Member 3) ◄─┘ events
        │
        └─► ML + Power BI (Member 4)
```

Member 1 owns the left side: business framing, dataset description, architecture diagram, HDFS layout, and YARN visibility.

## 5. Architecture Diagram (logical)

```
┌─────────────────────────────────────────────────────────────┐
│                 Trade Finance Bank (context)                │
│  LC / Guarantee / Collection systems + compliance services  │
└────────────────────────────┬────────────────────────────────┘
                             │ historical files + events
                             ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────────────┐
│    HDFS      │   │    YARN      │   │  ZooKeeper / Kafka   │
│ raw/curated  │   │ job + RAM    │   │  coordination/stream │
└──────┬───────┘   └──────────────┘   └──────────┬───────────┘
       │                                         │
       ▼                                         ▼
┌──────────────┐                          ┌──────────────┐
│ Hive / HBase │◄── batch analytics ──────│ Spark Stream │
└──────┬───────┘                          └──────┬───────┘
       │                                         │
       └────────────► ML scores / Power BI ◄─────┘
```

## 6. Technology Stack (platform)

| Layer | Technology | Member |
|---|---|---|
| Storage | HDFS | 1 |
| Resource mgmt | YARN | 1 (monitor) / shared |
| Batch / warehouse | MapReduce, Hive | 2 |
| Operational NoSQL | HBase | 2 |
| Streaming | Kafka, Spark Structured Streaming | 3 |
| Intelligence | Spark/Python ML, Power BI | 4 |
| Orchestration | Docker Compose lab stack | team |

## 7. Dataset Description

Primary historical datasets (repo `data/trade-finance/`):

| File | Role |
|---|---|
| `transactions.json` | ~5000 Trade Finance transactions (LC, Guarantee, etc.) |
| `customers.json` | Applicant / customer master |
| `counterparties.json` | Beneficiary / counterparty master |
| `events.jsonl` | Lifecycle events for streaming / lineage |

Sample fields on a transaction: `transaction_id`, `product_type`, `applicant_id`, `beneficiary_id`, countries, `currency`, `amount`, dates, `status`, discrepancy/delay flags, `customer_risk_rating`.

Member 1 demo sample: `member1/data/sample_transactions.csv` (20 rows) for quick HDFS screenshots. Full JSON remains the team source of truth.

## 8. HDFS Implementation

Target layout:

```
/user/tradefinance/
├── raw/
│   ├── transactions/
│   ├── customers/
│   ├── counterparties/
│   └── events/
├── curated/
└── exports/
```

Activities:

1. Create directories  
2. Upload historical sample / full datasets  
3. `ls` / `du` / `cat | head` to validate  
4. Document path + sizes for the team  

Script: `member1/scripts/prepare_hdfs.sh`

## 9. YARN Implementation

Member 1 validates that YARN is the cluster resource manager for MapReduce/Spark jobs used downstream:

- ResourceManager UI (typically http://localhost:8088)
- `yarn node -list`
- `yarn application -list` (before/after a sample job)

Script: `member1/scripts/yarn_checks.sh`

Purpose: prove the platform can schedule distributed work before Members 2–4 run heavy jobs.

## 10. Handoff to Member 2

With HDFS populated and architecture agreed, Member 2 runs MapReduce aggregations, Hive portfolio SQL, and HBase operational models on the landed Trade Finance data.
