# Member 1 – Business & Data Architecture

**Student:** Gurkirat Singh (N01604571)  
**Branch:** `member1-business-architecture`  
**Role:** Business problem, dataset, overall architecture, HDFS, YARN  

## Scope (from team distribution)

| Area | Deliverable |
|---|---|
| Business | Problem, requirements, executive narrative |
| Architecture | End-to-end Trade Finance Big Data flow |
| Dataset | Coordinate / describe Trade Finance historical + event data |
| HDFS | Directory layout, upload, validate metadata |
| YARN | Show cluster resource / job monitoring |

**Presentation focus:** *Why are we building this?* Bank → Trade Finance data → problem → Big Data solution → handoff to Member 2.

## Folder

```
member1/
├── README.md
├── SCREENSHOT_RUNBOOK.md
├── docs/
│   ├── member1_report.md      # report sections for Member 1
│   └── architecture.md
├── data/
│   └── sample_transactions.csv
├── scripts/
│   ├── prepare_hdfs.sh
│   └── yarn_checks.sh
└── screenshots/
```

## Quick showcase

1. Follow `SCREENSHOT_RUNBOOK.md`
2. Full report text: `docs/member1_report.md`
3. Full project data: `../data/trade-finance/` (transactions, events, customers)

## Downstream handoff

Member 1 lands historical data on HDFS and owns the architecture story.  
Member 2 continues: MapReduce / Hive / HBase analytics on that data.
