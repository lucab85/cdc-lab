#!/bin/bash
# M2V3 Demo: CI Checks, DLQ, and Observability
# Schema validation, dead letter queues, and monitoring

set -e
cd "$(dirname "$0")/.."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  M2V3: CI, DLQ, and Observability${NC}"
echo -e "${BLUE}========================================${NC}"

# Step 1: CI Schema Validation
echo -e "\n${CYAN}Step 1: CI Schema Validation${NC}"
echo -e "${YELLOW}File: ci/validate_schemas.py${NC}"
cat ci/validate_schemas.py
echo ""
read -p "Press Enter to run validation..."

echo -e "${YELLOW}Running schema validation...${NC}"
if python3 ci/validate_schemas.py schemas/; then
    echo -e "${GREEN}✓ All schemas are valid${NC}"
else
    echo -e "${RED}✗ Schema validation failed${NC}"
fi
read -p "Press Enter to continue..."

# Step 2: GitHub Actions example
echo -e "\n${CYAN}Step 2: CI Pipeline Configuration${NC}"
echo -e "${YELLOW}File: ci/github-actions-schema-check.yml${NC}"
cat ci/github-actions-schema-check.yml
read -p "Press Enter to continue..."

# Step 3: DLQ Configuration
echo -e "\n${CYAN}Step 3: Dead Letter Queue Configuration${NC}"
echo -e "${YELLOW}The connector includes DLQ settings:${NC}"
cat connectors/postgres-cdc-connector.json | grep -A5 '"errors'
echo ""
echo -e "${YELLOW}When messages fail, they go to a DLQ topic instead of being lost${NC}"
echo -e "${YELLOW}To add a dedicated DLQ topic, add:${NC}"
echo '  "errors.deadletterqueue.topic.name": "dlq.customers"'
echo '  "errors.deadletterqueue.context.headers.enable": "true"'
read -p "Press Enter to continue..."

# Step 4: Check connector metrics
echo -e "\n${CYAN}Step 4: Connector Metrics and Status${NC}"
echo -e "${YELLOW}Connector status:${NC}"
curl -s http://localhost:8083/connectors/postgres-cdc-connector/status | python3 -m json.tool 2>/dev/null | head -20

echo -e "\n${YELLOW}Task status:${NC}"
curl -s http://localhost:8083/connectors/postgres-cdc-connector/tasks/0/status | python3 -m json.tool 2>/dev/null
read -p "Press Enter to continue..."

# Step 5: Kafka Consumer Lag
echo -e "\n${CYAN}Step 5: Check Consumer Group Lag${NC}"
echo -e "${YELLOW}Listing consumer groups...${NC}"
docker exec cdc-lab-kafka-1 kafka-consumer-groups --bootstrap-server localhost:9092 --list 2>/dev/null

echo -e "\n${YELLOW}Example: Check lag for a consumer group${NC}"
echo "docker exec cdc-lab-kafka-1 kafka-consumer-groups --bootstrap-server localhost:9092 --group <group-name> --describe"
read -p "Press Enter to continue..."

# Step 6: Observability Dashboard Recommendations
echo -e "\n${CYAN}Step 6: Observability Recommendations${NC}"
echo -e "${YELLOW}Key metrics to monitor:${NC}"
echo "  • Schema Registry:"
echo "    - HTTP 409 responses (compatibility failures)"
echo "    - Subject count and version growth"
echo ""
echo "  • Kafka Connect:"
echo "    - Connector status (RUNNING/FAILED/PAUSED)"
echo "    - Task error count"
echo "    - Records processed per second"
echo ""
echo "  • Consumer Lag:"
echo "    - Lag per consumer group"
echo "    - Lag growth rate"
echo ""
echo "  • DLQ:"
echo "    - Message count in DLQ topics"
echo "    - Error types in DLQ headers"
read -p "Press Enter to continue..."

# Step 7: Runbook Template
echo -e "\n${CYAN}Step 7: Incident Runbook Template${NC}"
echo -e "${YELLOW}=== CDC Pipeline Incident Runbook ===${NC}"
echo ""
echo -e "${YELLOW}Symptoms:${NC}"
echo "  □ Schema Registry 409 errors"
echo "  □ Consumer lag > threshold"
echo "  □ DLQ rate > 0.1%"
echo ""
echo -e "${YELLOW}Quick Triage:${NC}"
echo "  1. curl http://localhost:8081/subjects - check recent changes"
echo "  2. docker exec kafka kafka-consumer-groups --describe"
echo "  3. Check DLQ topic for error patterns"
echo ""
echo -e "${YELLOW}Standard Actions:${NC}"
echo "  • Schema incompatibility → rollback or roll-forward fix"
echo "  • High lag → scale consumers or check for errors"
echo "  • High DLQ → identify bad producer/data pattern"

echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}  M2V3 Demo Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
