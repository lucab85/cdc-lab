#!/bin/bash
# M2V2 Demo: Schema Evolution and Compatibility Testing
# Testing breaking vs compatible schema changes with Schema Registry

set -e
cd "$(dirname "$0")/.."

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  M2V2: Schema Evolution Demo${NC}"
echo -e "${BLUE}========================================${NC}"

# Step 1: Register initial schema
echo -e "\n${CYAN}Step 1: Register initial customer schema (v1)${NC}"
echo -e "${YELLOW}File: schemas/customer-v1.avsc${NC}"
cat schemas/customer-v1.avsc
echo ""

SCHEMA_V1=$(cat schemas/customer-v1.avsc | tr -d '\n' | sed 's/"/\\"/g')
curl -s -X POST \
    -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    --data "{\"schema\": \"$SCHEMA_V1\"}" \
    http://localhost:8081/subjects/customer-updates-value/versions | python3 -m json.tool 2>/dev/null || \
echo "Schema registered"
read -p "Press Enter to continue..."

# Step 2: Check compatibility setting
echo -e "\n${CYAN}Step 2: Check current compatibility setting${NC}"
echo -e "${YELLOW}GET /config/customer-updates-value${NC}"
curl -s http://localhost:8081/config/customer-updates-value 2>/dev/null || echo '{"compatibilityLevel":"BACKWARD"}'
echo ""
read -p "Press Enter to continue..."

# Step 3: Try breaking change
echo -e "\n${CYAN}Step 3: Try to register a BREAKING schema change${NC}"
echo -e "${YELLOW}File: schemas/customer-v2-breaking.avsc${NC}"
echo -e "${RED}This schema renames 'email' to 'primary_email' - breaking!${NC}"
cat schemas/customer-v2-breaking.avsc
echo ""

echo -e "${YELLOW}Attempting to register...${NC}"
SCHEMA_BREAKING=$(cat schemas/customer-v2-breaking.avsc | tr -d '\n' | sed 's/"/\\"/g')
RESULT=$(curl -s -X POST \
    -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    --data "{\"schema\": \"$SCHEMA_BREAKING\"}" \
    http://localhost:8081/subjects/customer-updates-value/versions)
echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"

if echo "$RESULT" | grep -q "409\|incompatible"; then
    echo -e "\n${GREEN}✓ Schema Registry correctly REJECTED the breaking change!${NC}"
else
    echo -e "\n${YELLOW}Note: May have succeeded if no previous version or different mode${NC}"
fi
read -p "Press Enter to continue..."

# Step 4: Set stricter compatibility
echo -e "\n${CYAN}Step 4: Set BACKWARD_TRANSITIVE compatibility${NC}"
echo -e "${YELLOW}This requires compatibility with ALL previous versions${NC}"
curl -s -X PUT \
    -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    --data '{"compatibility": "BACKWARD_TRANSITIVE"}' \
    http://localhost:8081/config/customer-updates-value | python3 -m json.tool 2>/dev/null || echo "Compatibility set"
read -p "Press Enter to continue..."

# Step 5: Register compatible change
echo -e "\n${CYAN}Step 5: Register a COMPATIBLE schema change${NC}"
echo -e "${YELLOW}File: schemas/customer-v2-fixed.avsc${NC}"
echo -e "${GREEN}This adds primary_email as OPTIONAL with default, keeps email${NC}"
cat schemas/customer-v2-fixed.avsc
echo ""

echo -e "${YELLOW}Attempting to register...${NC}"
SCHEMA_FIXED=$(cat schemas/customer-v2-fixed.avsc | tr -d '\n' | sed 's/"/\\"/g')
RESULT=$(curl -s -X POST \
    -H "Content-Type: application/vnd.schemaregistry.v1+json" \
    --data "{\"schema\": \"$SCHEMA_FIXED\"}" \
    http://localhost:8081/subjects/customer-updates-value/versions)
echo "$RESULT" | python3 -m json.tool 2>/dev/null || echo "$RESULT"

if echo "$RESULT" | grep -q '"id"'; then
    echo -e "\n${GREEN}✓ Compatible schema registered successfully!${NC}"
fi
read -p "Press Enter to continue..."

# Step 6: List versions
echo -e "\n${CYAN}Step 6: List all schema versions${NC}"
curl -s http://localhost:8081/subjects/customer-updates-value/versions | python3 -m json.tool 2>/dev/null || \
curl -s http://localhost:8081/subjects/customer-updates-value/versions

echo -e "\n${BLUE}========================================${NC}"
echo -e "${GREEN}  M2V2 Demo Complete!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Key Takeaways:${NC}"
echo "  • Breaking changes (removing/renaming required fields) are rejected"
echo "  • Compatible changes (adding optional fields with defaults) succeed"
echo "  • BACKWARD_TRANSITIVE ensures compatibility with ALL versions"
echo ""
echo -e "${YELLOW}Roll-forward pattern:${NC}"
echo "  1. Keep old fields"
echo "  2. Add new fields as optional with defaults"
echo "  3. Gradually migrate consumers to new fields"
echo "  4. Eventually deprecate old fields"
