#!/bin/bash
# M1V2 Demo: CDC End-to-End Flow
# Postgres → Kafka → Schema Registry → Flink SQL → Iceberg → Trino

set -e
cd "$(dirname "$0")/.."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  M1V2: CDC End-to-End Flow Demo${NC}"
echo -e "${BLUE}========================================${NC}"

# Step 1: Show current orders
echo -e "\n${CYAN}Step 1: Show current orders in PostgreSQL${NC}"
echo -e "${YELLOW}Running: SELECT order_id, status, order_total FROM orders ORDER BY order_id LIMIT 5;${NC}"
docker exec cdc-lab-postgres-1 psql -U appuser -d appdb -c "SELECT order_id, status, order_total FROM orders ORDER BY order_id LIMIT 5;"
read -p "Press Enter to continue..."

# Step 2: Update a row
echo -e "\n${CYAN}Step 2: Update order status to simulate shipping${NC}"
echo -e "${YELLOW}Running: UPDATE orders SET status = 'SHIPPED' WHERE order_id = 101;${NC}"
docker exec cdc-lab-postgres-1 psql -U appuser -d appdb -c "UPDATE orders SET status = 'SHIPPED' WHERE order_id = 101;"
echo -e "${GREEN}✓ Order 101 updated to SHIPPED${NC}"
read -p "Press Enter to continue..."

# Step 3: See the Kafka message
echo -e "\n${CYAN}Step 3: See the change in Kafka${NC}"
echo -e "${YELLOW}Reading latest messages from appdb.public.orders...${NC}"
docker exec cdc-lab-kafka-1 kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic appdb.public.orders \
    --from-beginning \
    --max-messages 5 \
    --property print.key=true \
    --property key.separator=" | " 2>/dev/null | head -20
echo -e "\n${GREEN}Notice the 'before' and 'after' envelope showing what changed${NC}"
read -p "Press Enter to continue..."

# Step 4: Check Schema Registry
echo -e "\n${CYAN}Step 4: Check Schema Registry subjects${NC}"
echo -e "${YELLOW}Listing Schema Registry subjects...${NC}"
curl -s http://localhost:8081/subjects | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8081/subjects
echo ""
read -p "Press Enter to continue..."

# Step 5: Flink SQL instructions
echo -e "\n${CYAN}Step 5: Read the topic as a table in Flink SQL${NC}"
echo -e "${YELLOW}Open Flink SQL CLI:${NC}"
echo -e "  docker exec -it cdc-lab-flink-jobmanager-1 ./bin/sql-client.sh"
echo -e "\n${YELLOW}Then run these commands:${NC}"
cat sql/flink/create_orders_raw.sql
echo -e "\n${YELLOW}Query the data:${NC}"
echo "SELECT * FROM orders_raw WHERE order_id = 101;"
read -p "Press Enter to continue..."

# Step 6: Sink to Iceberg
echo -e "\n${CYAN}Step 6: Sink to Iceberg table${NC}"
echo -e "${YELLOW}In Flink SQL, first create the Iceberg catalog:${NC}"
cat sql/flink/iceberg_catalog.sql
echo -e "\n${YELLOW}Then insert data:${NC}"
cat sql/flink/insert_orders_iceberg.sql
read -p "Press Enter to continue..."

# Step 7: Query from Trino
echo -e "\n${CYAN}Step 7: Query the Iceberg table from Trino${NC}"
echo -e "${YELLOW}Open Trino CLI:${NC}"
echo -e "  docker exec -it cdc-lab-trino-1 trino --catalog lakehouse --schema demo"
echo -e "\n${YELLOW}Run query:${NC}"
echo "SELECT order_id, status, total_amount FROM orders_iceberg WHERE order_id = 101;"
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}  M1V2 Demo Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "The data flowed: PostgreSQL → Debezium → Kafka → Flink SQL → Iceberg → Trino"
