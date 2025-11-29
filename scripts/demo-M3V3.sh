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

# Step 1: MinIO warehouse
echo -e "\n${CYAN}Step 1: Check MinIO warehouse${NC}"
echo -e "${YELLOW}Open MinIO Console: http://localhost:9001${NC}"
echo -e "${YELLOW}Login: minioadmin / minioadmin${NC}"
echo ""
echo -e "The warehouse bucket contains Iceberg table data and metadata"
read -p "Press Enter to continue..."

# Step 2: Flink Iceberg Catalog
echo -e "\n${CYAN}Step 2: Create Iceberg catalog in Flink SQL${NC}"
echo -e "${YELLOW}Open Flink SQL CLI:${NC}"
echo -e "  docker exec -it cdc-lab-flink-jobmanager-1 ./bin/sql-client.sh"
echo ""
echo -e "${YELLOW}Create the catalog:${NC}"
cat sql/flink/iceberg_catalog.sql
read -p "Press Enter to continue..."

# Step 3: Create and populate tables
echo -e "\n${CYAN}Step 3: Populate Iceberg tables from CDC streams${NC}"
echo -e "${YELLOW}First create the source tables:${NC}"
cat sql/flink/create_customers_raw.sql
echo ""
echo -e "${YELLOW}Then insert into Iceberg:${NC}"
cat sql/flink/insert_customers_iceberg.sql
echo ""
echo -e "${YELLOW}Let it run for a minute to create some snapshots...${NC}"
read -p "Press Enter to continue..."

# Step 4: Trino Iceberg queries
echo -e "\n${CYAN}Step 4: Query Iceberg from Trino${NC}"
echo -e "${YELLOW}Open Trino CLI:${NC}"
echo -e "  docker exec -it cdc-lab-trino-1 trino --catalog lakehouse"
echo ""
echo -e "${YELLOW}Show available schemas and tables:${NC}"
echo "SHOW SCHEMAS FROM lakehouse;"
echo "SHOW TABLES FROM lakehouse.demo;"
echo ""
echo -e "${YELLOW}Query customers:${NC}"
echo "SELECT * FROM lakehouse.demo.customers_iceberg ORDER BY customer_id;"
read -p "Press Enter to continue..."

# Step 5: Time travel with snapshots
echo -e "\n${CYAN}Step 5: Time Travel with Snapshots${NC}"
echo -e "${YELLOW}View snapshot history:${NC}"
echo 'SELECT snapshot_id, committed_at, operation'
echo 'FROM "lakehouse"."demo"."customers_iceberg$snapshots"'
echo 'ORDER BY committed_at DESC;'
echo ""
echo -e "${YELLOW}Query a specific snapshot:${NC}"
echo 'SELECT customer_id, full_name, primary_email'
echo 'FROM lakehouse.demo.customers_iceberg'
echo 'FOR VERSION AS OF <snapshot_id>'
echo 'WHERE customer_id = 1;'
echo ""
echo -e "${YELLOW}Compare before and after a change to debug issues${NC}"
read -p "Press Enter to continue..."

# Step 6: Demonstrate ACID
echo -e "\n${CYAN}Step 6: ACID Transaction Demonstration${NC}"
echo -e "${YELLOW}Make an update in Postgres:${NC}"
docker exec cdc-lab-postgres-1 psql -U appuser -d appdb -c "
UPDATE customers SET email = 'acid-test@example.com' WHERE customer_id = 1;
"
echo -e "${GREEN}✓ Updated customer 1${NC}"

echo -e "\n${YELLOW}Trino queries always see consistent snapshots:${NC}"
echo "  • Each query binds to a specific snapshot"
echo "  • You never see partial writes"
echo "  • Counts jump atomically between snapshots"
echo ""
echo -e "${YELLOW}Run this repeatedly in Trino while data is streaming:${NC}"
echo "SELECT COUNT(*) FROM lakehouse.demo.customers_iceberg;"
read -p "Press Enter to continue..."

# Step 7: Additional Iceberg features
echo -e "\n${CYAN}Step 7: Additional Iceberg Features${NC}"
echo -e "${YELLOW}View table history:${NC}"
echo 'SELECT * FROM "lakehouse"."demo"."customers_iceberg$history";'
echo ""
echo -e "${YELLOW}View files (data files):${NC}"
echo 'SELECT file_path, record_count, file_size_in_bytes'
echo 'FROM "lakehouse"."demo"."customers_iceberg$files";'
echo ""
echo -e "${YELLOW}View manifest files:${NC}"
echo 'SELECT * FROM "lakehouse"."demo"."customers_iceberg$manifests";'

echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}  M3V3 Demo Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Key Takeaways:${NC}"
echo "  • Iceberg stores data as immutable Parquet files"
echo "  • Each commit creates a new snapshot"
echo "  • Time travel allows querying historical states"
echo "  • ACID guarantees: queries always see consistent data"
echo "  • Analysts query 'just a table' without knowing about Kafka"
