#!/bin/bash
# M2V1 Demo: Debezium Connector Configuration Deep-Dive
# Exploring connector settings, filters, and key handling

set -e
cd "$(dirname "$0")/.."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  M2V1: Debezium Connector Deep-Dive${NC}"
echo -e "${BLUE}========================================${NC}"

# Step 1: Show connector JSON
echo -e "\n${CYAN}Step 1: Review the Debezium connector configuration${NC}"
echo -e "${YELLOW}File: connectors/postgres-cdc-connector.json${NC}"
cat connectors/postgres-cdc-connector.json | python3 -m json.tool 2>/dev/null || cat connectors/postgres-cdc-connector.json
read -p "Press Enter to continue..."

# Step 2: Explain key settings
echo -e "\n${CYAN}Step 2: Key configuration options explained${NC}"
echo -e "${YELLOW}Snapshot settings:${NC}"
echo '  "snapshot.mode": "initial"  - Takes initial snapshot, then tails WAL'
echo '  "slot.name": "debezium_slot" - Replication slot name'
echo ""
echo -e "${YELLOW}Filter settings:${NC}"
echo '  "table.include.list": "public.customers,public.orders" - Only CDC these tables'
echo '  "topic.prefix": "appdb" - Prefix for Kafka topics'
echo ""
echo -e "${YELLOW}Converter settings:${NC}"
echo '  "key.converter": JsonConverter - Message key format'
echo '  "value.converter": JsonConverter - Message value format'
read -p "Press Enter to continue..."

# Step 3: Check connector status
echo -e "\n${CYAN}Step 3: Check connector status via REST API${NC}"
echo -e "${YELLOW}GET /connectors/postgres-cdc-connector/status${NC}"
curl -s http://localhost:8083/connectors/postgres-cdc-connector/status | python3 -m json.tool 2>/dev/null || \
curl -s http://localhost:8083/connectors/postgres-cdc-connector/status
read -p "Press Enter to continue..."

# Step 4: Inspect topics
echo -e "\n${CYAN}Step 4: Inspect created Kafka topics${NC}"
echo -e "${YELLOW}Topics follow the pattern: <topic.prefix>.<schema>.<table>${NC}"
docker exec cdc-lab-kafka-1 kafka-topics --bootstrap-server localhost:9092 --list | grep -E "^appdb\.|^connect-"
read -p "Press Enter to continue..."

# Step 5: Check Schema Registry
echo -e "\n${CYAN}Step 5: Check Schema Registry subjects${NC}"
echo -e "${YELLOW}With JSON converters, Schema Registry is not used for CDC topics${NC}"
echo -e "${YELLOW}But we can still register Avro schemas for canonical tables${NC}"
curl -s http://localhost:8081/subjects | python3 -m json.tool 2>/dev/null || curl -s http://localhost:8081/subjects
read -p "Press Enter to continue..."

# Step 6: Insert test data and see message
echo -e "\n${CYAN}Step 6: Insert test data and inspect Kafka message${NC}"
docker exec cdc-lab-postgres-1 psql -U appuser -d appdb -c "
INSERT INTO customers (customer_id, first_name, last_name, email, country)
VALUES (99, 'Test', 'User', 'test@example.com', 'US')
ON CONFLICT (customer_id) DO UPDATE SET email = EXCLUDED.email;
"
echo -e "${GREEN}✓ Inserted test customer${NC}"
sleep 2

echo -e "\n${YELLOW}Reading the message from Kafka (note key and envelope):${NC}"
docker exec cdc-lab-kafka-1 kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic appdb.public.customers \
    --from-beginning \
    --max-messages 1 \
    --property print.key=true 2>/dev/null | tail -5

echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}  M2V1 Demo Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Tips for local dev:"
echo "  • Use snapshot.mode='initial' for fast feedback"
echo "  • Keep table.include.list tight to avoid noisy topics"
echo ""
echo -e "Tips for CI:"
echo "  • Use snapshot.mode='initial_only' for deterministic runs"
echo "  • Use unique slot.name per environment"
