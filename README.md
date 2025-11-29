# CDC Lab Stack

Mini data platform that lets you demo end-to-end CDC patterns (Debezium → Kafka → Schema Registry → Flink → Iceberg → Trino) on macOS, Windows (WSL2), or Linux. Everything runs in Docker so you can tear it down and rebuild quickly between classes.

## Prerequisites

- Docker Desktop (4 vCPUs / 12+ GB RAM / 40 GB free disk recommended)
- SQL client of your choice (`psql`, DBeaver, TablePlus, etc.)
- `curl` for REST calls (already available on macOS)
- Python 3 (for schema validation)

## Stack Overview

| Service | Purpose | Host Port |
| --- | --- | --- |
| `postgres` | Source OLTP DB seeded with demo data | `5432` |
| `zookeeper`, `kafka` | Single-node Kafka cluster | `2181`, `9092` |
| `schema-registry` | Avro schemas for Kafka keys/values | `8081` |
| `connect` | Kafka Connect running Debezium Postgres connector | `8083` |
| `flink-jobmanager` / `flink-taskmanager` | Streaming SQL engine | JM UI `8082` |
| `minio` | S3-compatible object storage (+console) | `9000`, `9001` |
| `minio-bucket-init` | Creates `warehouse` bucket on startup | N/A |
| `hive-metastore-db` | PostgreSQL for Trino Iceberg catalog | N/A |
| `trino` | Interactive SQL over Iceberg warehouse | `8080` |
| `kafka-ui` | Optional UI for topics, schemas, DLQs | `8085` |

## Quick Start

```bash
# Start the stack
./scripts/run-demo.sh

# Or manually:
docker compose up -d
./scripts/deploy-connector.sh
```

## Available Demos

| Demo | Description | Script |
| --- | --- | --- |
| **M1V2** | CDC End-to-End Flow | `./scripts/demo-M1V2.sh` |
| **M1V3** | Streaming SQL Transformations | `./scripts/demo-M1V3.sh` |
| **M2V1** | Debezium Connector Deep-Dive | `./scripts/demo-M2V1.sh` |
| **M2V2** | Schema Evolution & Compatibility | `./scripts/demo-M2V2.sh` |
| **M2V3** | CI Checks, DLQ & Observability | `./scripts/demo-M2V3.sh` |
| **M3V3** | Iceberg Time Travel & ACID | `./scripts/demo-M3V3.sh` |

## Service URLs

- **Kafka UI**: http://localhost:8085
- **Schema Registry**: http://localhost:8081
- **Kafka Connect**: http://localhost:8083
- **Flink UI**: http://localhost:8082
- **MinIO Console**: http://localhost:9001 (minioadmin/minioadmin)
- **Trino**: http://localhost:8080
- **PostgreSQL**: `localhost:5432` (appuser/apppass)

## Quick Commands

```bash
# Connect to PostgreSQL
docker exec -it cdc-lab-postgres-1 psql -U appuser -d appdb

# Flink SQL CLI
docker exec -it cdc-lab-flink-jobmanager-1 ./bin/sql-client.sh

# Trino CLI
docker exec -it cdc-lab-trino-1 trino --catalog lakehouse

# Read Kafka topic
docker exec cdc-lab-kafka-1 kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic appdb.public.customers \
    --from-beginning

# Check connector status
curl http://localhost:8083/connectors/postgres-cdc-connector/status | jq

# List Schema Registry subjects
curl http://localhost:8081/subjects | jq
```

## Directory Structure

```
connectors/      # Debezium connector JSON
sql/postgres-... # Seed data for PostgreSQL
sql/flink/       # Flink SQL scripts (raw, canonical, Iceberg catalog)
sql/trino/       # Demo queries for Trino
schemas/         # Avro schemas (v1, breaking v2, fixed v2)
ci/              # Schema validation script + GitHub Action
etc/catalog/     # Trino Iceberg catalog config
scripts/         # Demo runner and helper scripts
demos/           # Step-by-step demo instructions (M1V2, M1V3, etc.)
docker/flink/    # Custom Flink Dockerfile with connectors
```

## Schema Registry Demo Flow

1. Register `schemas/customer-v1.avsc` under subject `customer-updates-value`
2. Attempt to register `schemas/customer-v2-breaking.avsc` to trigger a 409 error
3. Switch compatibility to `BACKWARD_TRANSITIVE` 
4. Register `schemas/customer-v2-fixed.avsc` successfully

## Observability & Guardrails

- Debezium connector has error tolerance enabled with logging
- Add a DLQ topic by adding `"errors.deadletterqueue.topic.name": "dlq.customers"` to the connector config
- CI schema validation: `python3 ci/validate_schemas.py schemas/`

## Reset Between Classes

```bash
docker compose down -v
docker compose up -d
./scripts/deploy-connector.sh
```

## Troubleshooting

- **Kafka Connect fails**: Check `docker compose logs connect` and verify Schema Registry is reachable
- **Flink SQL errors**: Ensure you've created the raw tables before the canonical/Iceberg tables
- **Trino can't see tables**: Tables must be created in Flink first to populate the Iceberg catalog
- **MinIO bucket missing**: The `minio-bucket-init` service creates it automatically on startup
