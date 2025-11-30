#!/bin/bash
# M3V3 Demo: Iceberg Time Travel and ACID Queries
# Snapshots, version history, and transactional queries

set -e
cd "$(dirname "$0")/.."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  M3V3: Iceberg Time Travel & ACID${NC}"
echo -e "${BLUE}========================================${NC}"

# Ensure services are running
docker compose up -d

# Step 1: MinIO warehouse
echo -e "\n${CYAN}Step 1: Prepare the MinIO warehouse${NC}"
echo -e "${YELLOW}1. Open the MinIO web console: ${GREEN}http://localhost:9001${NC}"
echo -e "${YELLOW}2. Login: ${GREEN}minioadmin / minioadmin${NC}"
echo -e "${YELLOW}3. Verify the bucket 'warehouse' exists (created automatically)${NC}"
echo ""
echo -e "${YELLOW}Connection details for Flink and Trino:${NC}"
echo -e "   Endpoint:   ${GREEN}http://minio:9000${NC}"
echo -e "   Access key: ${GREEN}minioadmin${NC}"
echo -e "   Secret key: ${GREEN}minioadmin${NC}"
echo ""
echo -e "${YELLOW}These are demo defaults; in production, use secure credentials.${NC}"
read -p "Press Enter to continue..."

# Step 2: Flink Iceberg Catalog
echo -e "\n${CYAN}Step 2: Configure an Iceberg catalog in Flink SQL${NC}"
echo -e "${YELLOW}Open Flink SQL CLI:${NC}"
echo -e "  ${GREEN}docker exec -it cdc-lab-flink-jobmanager-1 ./bin/sql-client.sh${NC}"
echo ""
echo -e "${YELLOW}Create an Iceberg catalog pointing to MinIO:${NC}"
echo -e "${GREEN}"
cat << 'EOF'
CREATE CATALOG lakehouse WITH (
  'type' = 'iceberg',
  'catalog-type' = 'rest',
  'uri' = 'http://iceberg-rest:8181',
  'warehouse' = 's3://warehouse/',
  'io-impl' = 'org.apache.iceberg.aws.s3.S3FileIO',
  's3.endpoint' = 'http://minio:9000',
  's3.access-key-id' = 'minioadmin',
  's3.secret-access-key' = 'minioadmin',
  's3.path-style-access' = 'true'
);
EOF
echo -e "${NC}"
echo -e "${YELLOW}Switch to this catalog and create a database:${NC}"
echo -e "${GREEN}"
cat << 'EOF'
USE CATALOG lakehouse;
CREATE DATABASE IF NOT EXISTS demo;
USE demo;
EOF
echo -e "${NC}"
echo -e "${YELLOW}Now Flink treats MinIO as the backing store for Iceberg tables.${NC}"
read -p "Press Enter to continue..."

# Step 3: Create Iceberg tables with upsert semantics
echo -e "\n${CYAN}Step 3: Create Iceberg tables with upsert semantics${NC}"
echo -e "${YELLOW}We'll persist two canonical tables: customers_canonical and orders_canonical${NC}"
echo ""
echo -e "${YELLOW}1. Define the customers_canonical table:${NC}"
echo -e "${GREEN}"
cat << 'EOF'
CREATE TABLE customers_canonical (
  customer_id      INT,
  full_name        STRING,
  primary_email    STRING,
  country_code     STRING,
  created_at       TIMESTAMP(3),
  updated_at       TIMESTAMP(3),
  is_deleted       BOOLEAN,
  PRIMARY KEY (customer_id) NOT ENFORCED
) WITH (
  'format-version' = '2'
);
EOF
echo -e "${NC}"
echo -e "${YELLOW}The PRIMARY KEY tells the engine to treat writes as upserts.${NC}"
echo ""
echo -e "${YELLOW}2. Define the orders_canonical table:${NC}"
echo -e "${GREEN}"
cat << 'EOF'
CREATE TABLE orders_canonical (
  order_id         BIGINT,
  customer_id      INT,
  total_amount     DECIMAL(18,2),
  currency_code    STRING,
  status           STRING,
  created_at       TIMESTAMP(3),
  updated_at       TIMESTAMP(3),
  is_deleted       BOOLEAN,
  PRIMARY KEY (order_id) NOT ENFORCED
) WITH (
  'format-version' = '2'
);
EOF
echo -e "${NC}"
read -p "Press Enter to continue..."

# Step 3b: Connect streaming sources to Iceberg
echo -e "\n${CYAN}Step 3 (continued): Connect streaming sources to Iceberg${NC}"
echo -e "${YELLOW}First, create the CDC source tables (from Kafka):${NC}"
cat sql/flink/create_customers_raw.sql
echo ""
echo -e "${YELLOW}Then start the streaming INSERT jobs:${NC}"
echo -e "${GREEN}"
cat << 'EOF'
INSERT INTO customers_canonical
SELECT
  customer_id,
  COALESCE(full_name, first_name || ' ' || last_name) AS full_name,
  COALESCE(email, CAST(customer_id AS STRING) || '@example.local') AS primary_email,
  country AS country_code,
  CURRENT_TIMESTAMP AS created_at,
  CURRENT_TIMESTAMP AS updated_at,
  FALSE AS is_deleted
FROM customers_raw;
EOF
echo -e "${NC}"
echo -e "${YELLOW}Let the streaming job run for a minute to write snapshots...${NC}"
read -p "Press Enter to continue..."

# Step 4: Trino Iceberg catalog
echo -e "\n${CYAN}Step 4: Configure Trino's Iceberg catalog${NC}"
echo -e "${YELLOW}The Trino catalog is already configured in etc/catalog/lakehouse.properties:${NC}"
echo -e "${GREEN}"
cat etc/catalog/lakehouse.properties
echo -e "${NC}"
echo ""
echo -e "${YELLOW}Key points:${NC}"
echo "  • Both Flink and Trino point to the same warehouse"
echo "  • Both use the same S3 endpoint (MinIO)"
echo "  • The REST catalog ensures consistent metadata"
read -p "Press Enter to continue..."

# Step 5: Query in Trino
echo -e "\n${CYAN}Step 5: Query the canonical tables in Trino${NC}"
echo -e "${YELLOW}Start the Trino CLI:${NC}"
echo -e "  ${GREEN}docker exec -it cdc-lab-trino-1 trino --catalog lakehouse --schema demo${NC}"
echo ""
echo -e "${YELLOW}List the tables:${NC}"
echo -e "  ${GREEN}SHOW TABLES;${NC}"
echo ""
echo -e "${YELLOW}You should see:${NC}"
echo "  • customers_canonical"
echo "  • orders_canonical"
echo ""
echo -e "${YELLOW}Run a simple query:${NC}"
echo -e "${GREEN}"
cat << 'EOF'
SELECT customer_id, full_name, primary_email
FROM customers_canonical
ORDER BY customer_id
LIMIT 10;
EOF
echo -e "${NC}"
echo -e "${YELLOW}You're now querying the same Iceberg tables that Flink is updating!${NC}"
read -p "Press Enter to continue..."

# Step 6: Time travel with snapshots
echo -e "\n${CYAN}Step 6: Time travel with snapshots for debugging${NC}"
echo -e "${YELLOW}Iceberg tracks each change as a snapshot. View them:${NC}"
echo -e "${GREEN}"
cat << 'EOF'
SELECT snapshot_id, committed_at, operation
FROM "customers_canonical$snapshots"
ORDER BY committed_at DESC;
EOF
echo -e "${NC}"
echo -e "${YELLOW}Note the latest snapshot_id and an older one.${NC}"
echo ""
echo -e "${YELLOW}Query a specific historical snapshot (time travel):${NC}"
echo -e "${GREEN}"
cat << 'EOF'
-- Replace <old_snapshot_id> with actual BIGINT from $snapshots table
SELECT customer_id, full_name, primary_email
FROM customers_canonical
FOR VERSION AS OF <old_snapshot_id>
WHERE customer_id = 1;
EOF
echo -e "${NC}"
echo -e "${YELLOW}Compare with current state (no FOR VERSION AS OF):${NC}"
echo -e "${GREEN}"
cat << 'EOF'
SELECT customer_id, full_name, primary_email
FROM customers_canonical
WHERE customer_id = 1;
EOF
echo -e "${NC}"
echo -e "${YELLOW}This lets you see exactly how records changed - perfect for debugging!${NC}"
read -p "Press Enter to continue..."

# Step 7: Demonstrate ACID
echo -e "\n${CYAN}Step 7: Validate ACID and snapshot isolation${NC}"
echo -e "${YELLOW}To see snapshot isolation in action:${NC}"
echo ""
echo -e "${YELLOW}1. In one terminal, keep a Trino session open and repeatedly run:${NC}"
echo -e "   ${GREEN}SELECT COUNT(*) FROM orders_canonical;${NC}"
echo ""
echo -e "${YELLOW}2. In parallel, trigger a burst of new orders in Postgres:${NC}"
docker exec cdc-lab-postgres-1 psql -U appuser -d appdb -c "
INSERT INTO orders (order_id, customer_id, order_total, status) VALUES
(201, 1, 99.99, 'PENDING'),
(202, 2, 149.99, 'PENDING'),
(203, 3, 79.99, 'PENDING')
ON CONFLICT (order_id) DO UPDATE SET order_total = EXCLUDED.order_total;
"
echo -e "${GREEN}✓ Inserted 3 new orders${NC}"
echo ""
echo -e "${YELLOW}3. Watch Trino's counts:${NC}"
echo "   • Each query reads a consistent snapshot"
echo "   • Counts jump atomically between snapshots"
echo "   • You never see half-applied data"
echo ""
echo -e "${YELLOW}This is Iceberg's ACID behavior:${NC}"
echo "   • Each commit produces a new snapshot"
echo "   • Trino queries bind to a specific snapshot"
echo "   • No 'in-progress' or partial data is visible"
read -p "Press Enter to continue..."

# Step 8: Additional Iceberg metadata
echo -e "\n${CYAN}Step 8: Explore Iceberg metadata tables${NC}"
echo -e "${YELLOW}View table history:${NC}"
echo -e "  ${GREEN}SELECT * FROM \"customers_canonical\$history\";${NC}"
echo ""
echo -e "${YELLOW}View data files:${NC}"
echo -e "${GREEN}"
cat << 'EOF'
SELECT file_path, record_count, file_size_in_bytes
FROM "customers_canonical$files";
EOF
echo -e "${NC}"
echo ""
echo -e "${YELLOW}View manifest files:${NC}"
echo -e "  ${GREEN}SELECT * FROM \"customers_canonical\$manifests\";${NC}"
echo ""
echo -e "${YELLOW}View partitions (if partitioned):${NC}"
echo -e "  ${GREEN}SELECT * FROM \"customers_canonical\$partitions\";${NC}"

echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}  M3V3 Demo Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Key Takeaways:${NC}"
echo "  • Iceberg stores data as immutable Parquet files in MinIO"
echo "  • Each commit creates a new snapshot"
echo "  • Time travel allows querying historical states for debugging"
echo "  • ACID guarantees: queries always see consistent data"
echo "  • Both Flink and Trino share the same catalog and tables"
echo "  • Analysts query 'just a table' without knowing about Kafka"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "  • Flink SQL:  docker exec -it cdc-lab-flink-jobmanager-1 ./bin/sql-client.sh"
echo "  • Trino CLI:  docker exec -it cdc-lab-trino-1 trino --catalog lakehouse --schema demo"
echo "  • MinIO UI:   http://localhost:9001"
