#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  CDC Lab Demo Environment Setup${NC}"
echo -e "${BLUE}========================================${NC}"

cd "$(dirname "$0")/.."

# Function to check if a service is healthy
wait_for_service() {
    local service=$1
    local max_attempts=${2:-30}
    local attempt=1
    
    echo -e "${YELLOW}Waiting for $service to be ready...${NC}"
    while [ $attempt -le $max_attempts ]; do
        if docker compose ps $service 2>/dev/null | grep -q "healthy\|running"; then
            echo -e "${GREEN}✓ $service is ready${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    echo -e "${RED}✗ $service failed to start${NC}"
    return 1
}

# Step 1: Start all services
echo -e "\n${BLUE}Step 1: Starting Docker services...${NC}"
docker compose up -d

# Step 2: Wait for core services
echo -e "\n${BLUE}Step 2: Waiting for services to be healthy...${NC}"
wait_for_service postgres 20
wait_for_service kafka 40
wait_for_service schema-registry 30
wait_for_service connect 60
wait_for_service minio 20
wait_for_service hive-metastore-db 20

# Step 3: Deploy Debezium connector
echo -e "\n${BLUE}Step 3: Deploying Debezium CDC connector...${NC}"
./scripts/deploy-connector.sh

# Step 4: Verify topics exist
echo -e "\n${BLUE}Step 4: Verifying Kafka topics...${NC}"
sleep 5
TOPICS=$(docker exec cdc-lab-kafka-1 kafka-topics --bootstrap-server localhost:9092 --list 2>/dev/null || echo "")

if echo "$TOPICS" | grep -q "appdb.public.customers"; then
    echo -e "${GREEN}✓ Topic appdb.public.customers exists${NC}"
else
    echo -e "${RED}✗ Topic appdb.public.customers not found${NC}"
fi

if echo "$TOPICS" | grep -q "appdb.public.orders"; then
    echo -e "${GREEN}✓ Topic appdb.public.orders exists${NC}"
else
    echo -e "${RED}✗ Topic appdb.public.orders not found${NC}"
fi

# Step 5: Verify CDC data is flowing
echo -e "\n${BLUE}Step 5: Verifying CDC data flow...${NC}"
CUSTOMERS_COUNT=$(docker exec cdc-lab-kafka-1 kafka-console-consumer \
    --bootstrap-server localhost:9092 \
    --topic appdb.public.customers \
    --from-beginning \
    --max-messages 1 \
    --timeout-ms 10000 2>/dev/null | wc -l || echo "0")

if [ "$CUSTOMERS_COUNT" -gt 0 ]; then
    echo -e "${GREEN}✓ CDC data is flowing to Kafka${NC}"
else
    echo -e "${YELLOW}⚠ No CDC data found yet (this may be normal on first run)${NC}"
fi

# Step 6: Print service URLs
echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}  Demo Environment Ready!${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "\n${BLUE}Service URLs:${NC}"
echo -e "  • Kafka UI:        ${GREEN}http://localhost:8085${NC}"
echo -e "  • Schema Registry: ${GREEN}http://localhost:8081${NC}"
echo -e "  • Kafka Connect:   ${GREEN}http://localhost:8083${NC}"
echo -e "  • Flink UI:        ${GREEN}http://localhost:8082${NC}"
echo -e "  • MinIO Console:   ${GREEN}http://localhost:9001${NC} (minioadmin/minioadmin)"
echo -e "  • Trino:           ${GREEN}http://localhost:8080${NC}"
echo -e "  • PostgreSQL:      ${GREEN}localhost:5432${NC} (appuser/apppass)"

echo -e "\n${BLUE}Quick Commands:${NC}"
echo -e "  • Connect to Postgres:  ${YELLOW}docker exec -it cdc-lab-postgres-1 psql -U appuser -d appdb${NC}"
echo -e "  • Flink SQL CLI:        ${YELLOW}docker exec -it cdc-lab-flink-jobmanager-1 ./bin/sql-client.sh${NC}"
echo -e "  • Trino CLI:            ${YELLOW}docker exec -it cdc-lab-trino-1 trino${NC}"
echo -e "  • Kafka console:        ${YELLOW}docker exec -it cdc-lab-kafka-1 kafka-console-consumer --bootstrap-server localhost:9092 --topic appdb.public.customers --from-beginning${NC}"

echo -e "\n${BLUE}Available Demos:${NC}"
echo -e "  • M1V2: CDC end-to-end flow (Postgres → Kafka → Flink → Iceberg → Trino)"
echo -e "  • M1V3: Streaming SQL transformations with canonical schemas"
echo -e "  • M2V1: Debezium connector configuration deep-dive"
echo -e "  • M2V2: Schema evolution and compatibility testing"
echo -e "  • M2V3: CI checks, DLQ, and observability"
echo -e "  • M3V3: Iceberg time travel and ACID queries"

echo -e "\n${GREEN}Run individual demo scripts with: ./scripts/demo-M1V2.sh (etc.)${NC}\n"
