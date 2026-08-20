# Member 1 screenshot cheat sheet (showcase)

Save PNGs under `member1/screenshots/`.

---

## 1) Environment → `screenshots/environment/`

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -E 'namenode|datanode|resourcemanager|nodemanager'
```

---

## 2) Architecture → `screenshots/architecture/`

Open `member1/docs/architecture.md` or `member1/docs/member1_report.md` §5 in an editor / browser and screenshot the diagram block.  
(Optional: paste the ASCII diagram into a slide.)

---

## 3) Dataset → `screenshots/dataset/`

```bash
cd member1/data
wc -l sample_transactions.csv
head -5 sample_transactions.csv
# optional: show full repo dataset sizes
wc -l ../data/trade-finance/events.jsonl
ls -lh ../data/trade-finance/
```

(From repo root: `ls -lh data/trade-finance/`.)

---

## 4) HDFS → `screenshots/hdfs/`

```bash
# from TradeFinance-BigData-Final-Project root
docker cp member1/data/sample_transactions.csv namenode:/data/sample_transactions.csv
docker exec -it namenode bash

hdfs dfs -mkdir -p /user/tradefinance/raw/{transactions,customers,counterparties,events}
hdfs dfs -mkdir -p /user/tradefinance/{curated,exports}
hdfs dfs -put -f /data/sample_transactions.csv /user/tradefinance/raw/transactions/
hdfs dfs -ls -R /user/tradefinance
hdfs dfs -du -h /user/tradefinance
hdfs dfs -cat /user/tradefinance/raw/transactions/sample_transactions.csv | head -5
```

---

## 5) YARN → `screenshots/yarn/`

Browser: **http://localhost:8088** → screenshot cluster / apps.

And/or:

```bash
docker exec -it resourcemanager bash -c 'yarn node -list; yarn application -list' 
# if yarn CLI lives on another container in your stack, use namenode:
docker exec -it namenode bash -c 'yarn node -list; yarn application -list' || true
```

Optional “busy” shot: trigger any tiny MapReduce/Spark job later with Member 2/3, then re-screenshot the Applications page.

---

## Done

| Folder | Shows |
|---|---|
| environment | Hadoop/YARN containers up |
| architecture | System diagram |
| dataset | Sample / full data |
| hdfs | mkdir / put / ls / du / cat |
| yarn | RM UI or yarn node/application list |
