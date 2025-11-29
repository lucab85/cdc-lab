#!/bin/bash
# M1V3 Demo: Streaming SQL Transformations
# Building canonical schemas with COALESCE, CAST, and upserts

set -e
cd "$(dirname "$0")/.."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  M1V3: Streaming SQL Transformations${NC}"
echo -e "${BLUE}========================================${NC}"

# Step 1: Show current customers
echo -e "\n${CYAN}Step 1: Check current customers in PostgreSQL${NC}"
docker compose up -d
docker exec cdc-lab-postgres-1 psql -U appuser -d appdb -c "SELECT * FROM customers;"
read -p "Press Enter to continue..."

# Step 2: Introduce schema change
echo -e "\n${CYAN}Step 2: Add a new column (schema evolution)${NC}"
echo -e "${YELLOW}Adding full_name column...${NC}"
docker exec cdc-lab-postgres-1 psql -U appuser -d appdb -c "
ALTER TABLE customers ADD COLUMN IF NOT EXISTS full_name TEXT;
UPDATE customers SET full_name = first_name || ' ' || last_name WHERE full_name IS NULL;
"
echo -e "${GREEN}✓ Added full_name column${NC}"
read -p "Press Enter to continue..."

# Step 3: Insert new row with NULL email
echo -e "\n${CYAN}Step 3: Insert customer with NULL email${NC}"
docker exec cdc-lab-postgres-1 psql -U appuser -d appdb -c "
INSERT INTO customers (customer_id, first_name, last_name, email, country, full_name)
VALUES (4, 'Daria', 'Khan', NULL, 'NL', 'Daria Khan')
ON CONFLICT (customer_id) DO UPDATE SET email = EXCLUDED.email, full_name = EXCLUDED.full_name;
"
echo -e "${GREEN}✓ Inserted customer with NULL email${NC}"
docker exec cdc-lab-postgres-1 psql -U appuser -d appdb -c "SELECT * FROM customers WHERE customer_id = 4;"
read -p "Press Enter to continue..."

# Step 4: Show Flink SQL source table
echo -e "\n${CYAN}Step 4: Define the streaming source table in Flink SQL${NC}"
echo -e "${YELLOW}Open Flink SQL CLI:${NC}"
echo -e "  docker exec -it cdc-lab-flink-jobmanager-1 ./bin/sql-client.sh"
echo -e "\n${YELLOW}Create the source table:${NC}"
cat sql/flink/create_customers_raw.sql
read -p "Press Enter to continue..."

# Step 5: Build canonical table with transformations
echo -e "\n${CYAN}Step 5: Build customers_canonical with COALESCE${NC}"
echo -e "${YELLOW}This handles NULL values and schema evolution:${NC}"
cat sql/flink/create_customers_canonical.sql
echo -e "\n${YELLOW}Key transformations:${NC}"
echo "  • COALESCE(full_name, first_name || ' ' || last_name) - handles old/new schema"
echo "  • COALESCE(email, customer_id || '@example.local') - ensures email is never NULL"
echo "  • PRIMARY KEY for upsert semantics - one row per customer"
read -p "Press Enter to continue..."

# Step 6: Verify upserts
echo -e "\n${CYAN}Step 6: Test upserts by updating a row${NC}"
echo -e "${YELLOW}Updating Ana's email...${NC}"
docker exec cdc-lab-postgres-1 psql -U appuser -d appdb -c "
UPDATE customers SET email = 'ana.new@example.com' WHERE customer_id = 1;
"
echo -e "${GREEN}✓ Email updated${NC}"
read -p "Press Enter to continue..."

# Step 7: Query options
echo -e "\n${CYAN}Step 7: Query the transformed data${NC}"
echo -e "${YELLOW}You have multiple options to verify the transformations:${NC}"
echo ""
echo -e "${BLUE}Option A: Query source data in Trino (PostgreSQL catalog)${NC}"
echo -e "  docker exec -it cdc-lab-trino-1 trino --catalog postgres --schema public"
echo -e "  ${GREEN}SELECT * FROM customers ORDER BY customer_id;${NC}"
echo ""
echo -e "${BLUE}Option B: Query CDC topic in Flink SQL${NC}"
echo -e "  docker exec -it cdc-lab-flink-jobmanager-1 ./bin/sql-client.sh"
echo -e "  ${GREEN}-- First create the source table (paste from sql/flink/create_customers_raw.sql)${NC}"
echo -e "  ${GREEN}SELECT * FROM customers_raw;${NC}"
echo ""
echo -e "${BLUE}Option C: Query the upsert-kafka canonical table in Flink SQL${NC}"
echo -e "  ${GREEN}-- After creating customers_canonical table:${NC}"
echo -e "  ${GREEN}SELECT * FROM customers_canonical ORDER BY customer_id;${NC}"
echo ""
echo -e "${BLUE}Option D: Read from Kafka topic directly${NC}"
echo -e "  docker exec cdc-lab-kafka-1 kafka-console-consumer \\"
echo -e "    --bootstrap-server localhost:9092 \\"
echo -e "    --topic appdb.public.customers \\"
echo -e "    --from-beginning --max-messages 5"
read -p "Press Enter to continue..."

# Step 8: Show the final state in PostgreSQL
echo -e "\n${CYAN}Step 8: Verify final state in PostgreSQL${NC}"
echo -e "${YELLOW}Current customers table with all changes:${NC}"
docker exec cdc-lab-postgres-1 psql -U appuser -d appdb -c "
SELECT customer_id, first_name, last_name, email, country, full_name FROM customers ORDER BY customer_id;
"

echo -e "\n${YELLOW}Let's also check the Kafka topic has all our changes:${NC}"
docker exec cdc-lab-kafka-1 kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic appdb.public.customers \
    --from-beginning \
    --max-messages 5 \
    --timeout-ms 5000 2>/dev/null | head -10

echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}  M1V3 Demo Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Demonstrated: Schema evolution, COALESCE for NULL handling, upsert semantics"
echo ""
echo -e "${YELLOW}Key Takeaways:${NC}"
echo "  1. Schema changes (new columns) flow through CDC automatically"
echo "  2. COALESCE handles NULL values and provides defaults"
echo "  3. PRIMARY KEY enables upsert semantics (one row per key)"
echo "  4. Flink SQL transforms raw CDC events into clean canonical tables"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  • Run Flink SQL to create customers_canonical table"
echo "  • Start the INSERT INTO job to continuously transform data"
echo "  • Query from Trino once Iceberg tables are populated"
