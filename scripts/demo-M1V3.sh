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
echo -e "\n${YELLOW}Check the canonical table - should show only one row per customer with latest values${NC}"
echo "SELECT * FROM customers_canonical ORDER BY customer_id;"

echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}  M1V3 Demo Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Demonstrated: Schema evolution, COALESCE for NULL handling, upsert semantics"
