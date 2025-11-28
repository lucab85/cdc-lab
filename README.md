# CDC Lab Stack

Mini data platform that lets you demo end-to-end CDC patterns (Debezium → Kafka → Schema Registry → Flink → Iceberg → Trino) on macOS, Windows (WSL2), or Linux. Everything runs in Docker so you can tear it down and rebuild quickly between classes.

## Prerequisites

- Docker Desktop (4 vCPUs / 12+ GB RAM / 40 GB free disk recommended)
- SQL client of your choice (`psql`, DBeaver, TablePlus, etc.)
- `curl` for REST calls (already available on macOS)

## Stack Overview

| Service | Purpose | Host Port |
| --- | --- | --- |
| `postgres` | Source OLTP DB seeded with demo data | `5432`
| `zookeeper`, `kafka` | Single-node Kafka cluster | `2181`, `9092`
| `schema-registry` | Avro schemas for Kafka keys/values | `8081`
| `connect` | Kafka Connect running Debezium Postgres connector | `8083`
| `flink-jobmanager` / `flink-taskmanager` | Streaming SQL engine | JM UI `8082`
| `minio` | S3-compatible object storage (+console) | `9000`, `9001`
| `minio-bucket-init` | Creates `iceberg-warehouse` bucket on startup | N/A
| `trino` | Interactive SQL over Iceberg warehouse | `8080`
| `kafka-ui` | Optional UI for topics, schemas, DLQs | `8085`

Data & config artifacts live under the repo tree:

```
connectors/      # Debezium connector JSON
sql/postgres-... # Seed data
sql/flink/       # Flink SQL scripts (raw, canonical, Iceberg catalog)
sql/trino/       # Demo queries for Trino
schemas/         # Avro schemas (v1, breaking v2, fixed v2)
ci/              # Schema validation script + GitHub Action
etc/catalog/     # Trino Iceberg catalog config
```

## Getting Started

1. **Start the stack**
   ```bash
   docker compose up -d
   docker compose ps
   ```

2. **Confirm Postgres data**
   ```bash
   psql "postgresql://appuser:apppass@localhost:5432/appdb" -c "SELECT * FROM customers;"
   ```

3. **Register the Debezium connector**
   ```bash
   curl -X POST \
     -H "Content-Type: application/json" \
     --data @connectors/postgres-cdc-connector.json \
     http://localhost:8083/connectors
   ```
   Watch records flow via Kafka UI (`http://localhost:8085`).

4. **Run Flink SQL scripts**
   ```bash
   docker compose exec flink-jobmanager ./bin/sql-client.sh -f /opt/flink/usrlib/create_customers_raw.sql
   docker compose exec flink-jobmanager ./bin/sql-client.sh -f /opt/flink/usrlib/create_customers_canonical.sql
   docker compose exec flink-jobmanager ./bin/sql-client.sh -f /opt/flink/usrlib/iceberg_catalog.sql
   ```

5. **Query with Trino**
   - Open `http://localhost:8080/ui/` or use the CLI: `docker compose exec trino trino --server localhost:8080`.
   - Run statements from `sql/trino/demo_queries.sql`.

## Schema Registry Demo Flow

1. Register `schemas/customer-v1.avsc` under subject `appdb.public.customers-value` (happens automatically via Debezium).
2. Attempt to register `schemas/customer-v2-breaking.avsc` manually to trigger a 409.
3. Switch compatibility to `BACKWARD_TRANSITIVE` and register `customer-v2-fixed.avsc`.

## Observability & Guardrails

- Debezium connector is configured with a DLQ topic `dlq.customers`. Use Kafka UI to inspect failures.
- Add Prometheus/Grafana later if you want metrics; hooks are left open.
- CI pipeline example lives in `ci/` (run `python ci/validate_schemas.py`).

## Reset Between Classes

```bash
docker compose down -v
rm -rf minio-data  # optional if you want a pristine warehouse
docker compose up -d
psql ... -f sql/postgres-init.sql  # optional reseed
```

Re-register the Debezium connector and replay the Flink SQL scripts any time you reset the stack.

## Troubleshooting Tips

- If Kafka Connect fails to start, run `docker compose logs connect` and verify Schema Registry (8081) is reachable.
- If Flink SQL cannot access MinIO, make sure the `iceberg-warehouse` bucket exists (the `minio-bucket-init` job handles it) and that the stack was restarted after any changes.
- For schema experiments, the Schema Registry REST API is at `http://localhost:8081`. Use `curl` or tools like Postman to inspect subjects.
# cdc-lab
