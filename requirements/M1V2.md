# Demo Prep: Postgres → Debezium → Kafka → Schema Registry → Flink → Iceberg → Trino

Use this playbook to prep the CDC lab before recording the demo. Commands assume you run them from the repo root with Docker Desktop up and 4+ vCPUs / 12 GB RAM.

## 1) Boot and verify the stack
- Start services and confirm they are healthy:
  ```bash
docker compose up -d
docker compose ps
  ```
- Spot-check seed data in Postgres (orders are preloaded as 101–103):
  ```bash
psql "postgresql://appuser:apppass@localhost:5432/appdb" -c "SELECT order_id, status, order_total FROM orders ORDER BY order_id LIMIT 5;"
  ```
- Register the Debezium connector so Kafka starts receiving change events:
  ```bash
curl -X POST \
  -H "Content-Type: application/json" \
  --data @connectors/postgres-cdc-connector.json \
  http://localhost:8083/connectors
  ```
  Watch for a 201 Created response. If you rerun, a 409 is OK (it means the connector already exists).

## 2) Screen-share script and commands
Follow these commands on-screen to mirror the narrated flow. Replace `101` with any existing `order_id` if you reseeded the database.

### Step 1 – Change a row in the source database
```bash
psql "postgresql://appuser:apppass@localhost:5432/appdb" <<'SQL'
\pset pager off
SELECT order_id, status, order_total FROM orders ORDER BY order_id LIMIT 3;
UPDATE orders SET status = 'SHIPPED' WHERE order_id = 101;
SQL
```
Narration: “We’re pretending a customer’s order just got shipped. Now we’ll see how this tiny change flows through the stack.”

### Step 2 – See the change as a Kafka message
Use the Debezium topic `appdb.public.orders` (keyed by `order_id`).
```bash
docker compose exec kafka kafka-console-consumer \
  --bootstrap-server kafka:9092 \
  --topic appdb.public.orders \
  --from-beginning \
  --property print.key=true \
  --property print.value=true \
  --max-messages 5
```
Call out the key (`101`) and the value envelope with `before`, `after`, and `op` fields.

### Step 3 – Check the schema in Schema Registry
```bash
curl http://localhost:8081/subjects
curl http://localhost:8081/subjects/appdb.public.orders-value/versions/latest
```
Highlight the subject names (`…-key` and `…-value`) and the schema fields like `before`/`after` plus the version number. Explain that Schema Registry tracks and validates schema evolution.

### Step 4 – Read the topic as a table in Flink SQL
Launch the SQL client in the JobManager container and register a simple Kafka source table:
```bash
docker compose exec flink-jobmanager ./bin/sql-client.sh <<'SQL'
CREATE TABLE orders_raw (
  order_id INT,
  customer_id INT,
  order_total DECIMAL(10,2),
  order_ts TIMESTAMP_LTZ(3),
  status STRING,
  PRIMARY KEY (order_id) NOT ENFORCED
) WITH (
  'connector' = 'kafka',
  'topic' = 'appdb.public.orders',
  'format' = 'avro',
  'scan.startup.mode' = 'earliest-offset'
);

SELECT * FROM orders_raw WHERE order_id = 101;
SQL
```
Narration: “Flink SQL is reading from the Kafka topic and presenting it as a table. Our update to SHIPPED is visible as the latest row.”

### Step 5 – Sink to an Iceberg table
Continue in the same SQL client session (or reopen) to register the catalog and sink table:
```bash
docker compose exec flink-jobmanager ./bin/sql-client.sh <<'SQL'
CREATE CATALOG lakehouse WITH (
  'type' = 'iceberg',
  'catalog-type' = 'hadoop',
  'warehouse' = 's3a://iceberg-warehouse/',
  's3.endpoint' = 'http://minio:9000',
  's3.access-key' = 'minioadmin',
  's3.secret-key' = 'minioadmin',
  's3.path-style-access' = 'true'
);
USE CATALOG lakehouse;
CREATE DATABASE IF NOT EXISTS demo;
USE demo;

CREATE TABLE IF NOT EXISTS orders_canonical (
  order_id INT,
  status STRING,
  PRIMARY KEY (order_id) NOT ENFORCED
) WITH (
  'connector' = 'iceberg',
  'format-version' = '2'
);

INSERT INTO orders_canonical
SELECT order_id, status FROM orders_raw;
SQL
```
Narration: “Flink takes the stream from Kafka and writes it into an Iceberg table. Iceberg snapshots each commit.”

### Step 6 – Query the Iceberg table from Trino
```bash
docker compose exec trino trino --catalog lakehouse --schema demo \
  --execute "SELECT order_id, status FROM orders_canonical WHERE order_id = 101;"
```
Optional aggregate:
```bash
docker compose exec trino trino --catalog lakehouse --schema demo \
  --execute "SELECT status, COUNT(*) FROM orders_canonical GROUP BY status;"
```
Narration: “This is the same order we changed. It flowed through Kafka, Schema Registry, Flink, and Iceberg; Trino now sees it like any other table.”

## 3) Quick pre-demo checks
Run these just before recording to ensure everything is alive:
- Connector status: `curl http://localhost:8083/connectors/postgres-cdc-connector/status`
- Kafka topic exists: `docker compose exec kafka kafka-topics --bootstrap-server kafka:9092 --list | grep appdb.public.orders`
- Flink catalog reachable: `docker compose exec flink-jobmanager ./bin/sql-client.sh -e "SHOW CATALOGS;"`
- Trino health: `docker compose exec trino trino --execute "SELECT 1;"`
