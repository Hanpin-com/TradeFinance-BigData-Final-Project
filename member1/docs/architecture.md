# System Architecture – Trade Finance Big Data Platform

## Data flow (one page)

1. **Generate / extract** synthetic Trade Finance transactions & lifecycle events.  
2. **Land** historical files on **HDFS** (`/user/tradefinance/raw/...`).  
3. **Batch path:** MapReduce/Hive analytics + HBase operational store (Member 2).  
4. **Stream path:** events → Kafka → Spark Structured Streaming → risk alerts (Member 3).  
5. **Intelligence path:** features → ML models → Power BI (Member 4).  
6. **YARN** schedules batch/stream compute; HDFS persists inputs/outputs.

## Why HDFS first

- Cheap durable landing for multi-GB historical sets  
- Shared input for Pig/MR/Hive/Spark without locking OLTP  
- Clear raw vs curated zones for governance  

## Why YARN

- Shared cluster CPU/memory across MapReduce and Spark  
- Visibility into failed/running jobs for ops demos  

## Member boundaries

| Member | Owns |
|---|---|
| 1 | Business case, dataset story, architecture, HDFS, YARN view |
| 2 | Historical MR/Hive/HBase |
| 3 | Kafka + streaming risk |
| 4 | ML + executive dashboards |
