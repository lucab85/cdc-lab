#!/bin/bash
# Script to deploy the Debezium CDC connector for Postgres

set -e

CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
CONNECTOR_CONFIG="connectors/postgres-cdc-connector.json"

echo "Waiting for Kafka Connect to be ready..."
until curl -sf "${CONNECT_URL}/connectors" > /dev/null 2>&1; do
    echo "Kafka Connect not ready yet, waiting..."
    sleep 5
done
echo "Kafka Connect is ready!"

echo ""
echo "Deploying Debezium Postgres CDC connector..."

# Check if connector already exists
if curl -sf "${CONNECT_URL}/connectors/postgres-cdc-connector" > /dev/null 2>&1; then
    echo "Connector already exists, updating..."
    curl -X PUT -H "Content-Type: application/json" \
         --data @"${CONNECTOR_CONFIG}" \
         "${CONNECT_URL}/connectors/postgres-cdc-connector/config"
else
    echo "Creating new connector..."
    curl -X POST -H "Content-Type: application/json" \
         --data @"${CONNECTOR_CONFIG}" \
         "${CONNECT_URL}/connectors"
fi

echo ""
echo ""
echo "Connector deployment complete!"
echo ""
echo "Checking connector status..."
sleep 3
curl -s "${CONNECT_URL}/connectors/postgres-cdc-connector/status" | jq .

echo ""
echo "Available Kafka topics:"
docker compose exec kafka kafka-topics --bootstrap-server kafka:9092 --list 2>/dev/null || echo "(Run this from the cdc-lab directory)"
