#!/bin/bash

#############################################
# BEGA L2 EIP-1559 Parameters Update Script
#############################################
# This script updates EIP-1559 parameters in
# rollup.json and genesis.json to fix stuck
# gas fee issues.
#
# Parameters:
# - Elasticity: 6
# - Denominator: 50
# - Packed hex: 0x0000000000000032
#
# Usage: ./scripts/update-eip1559-params.sh
#############################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PROJECT_ROOT="/Users/kangmunil/Project/BEGA"
CONFIG_DIR="$PROJECT_ROOT/config"
ROLLUP_JSON="$CONFIG_DIR/rollup.json"
GENESIS_JSON="$CONFIG_DIR/genesis.json"
BACKUP_DIR="$CONFIG_DIR/backups"

# EIP-1559 Parameters
# These match deploy-config.json settings
ELASTICITY=6
DENOMINATOR=50

# Calculate packed EIP-1559 params
# Format: 0x[8 bytes total] = 0x[elasticity:4bytes][denominator:4bytes]
# elasticity=6 (0x06), denominator=50 (0x32)
# But the actual encoding is just the denominator in the lower bytes
# Based on OP Stack encoding: last 4 bytes are denominator
EIP1559_PARAMS="0x0000000000000032"  # denominator=50 (0x32)

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}BEGA L2 EIP-1559 Parameters Update${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}ERROR: jq is required but not installed.${NC}"
    echo "Please install jq: brew install jq (macOS) or apt-get install jq (Linux)"
    exit 1
fi

# Check if files exist
if [ ! -f "$ROLLUP_JSON" ]; then
    echo -e "${RED}ERROR: rollup.json not found at $ROLLUP_JSON${NC}"
    exit 1
fi

if [ ! -f "$GENESIS_JSON" ]; then
    echo -e "${RED}ERROR: genesis.json not found at $GENESIS_JSON${NC}"
    exit 1
fi

echo -e "${GREEN}Step 1: Backing up current configuration...${NC}"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Generate backup timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_ROLLUP="$BACKUP_DIR/rollup_${TIMESTAMP}_preupdate.json"
BACKUP_GENESIS="$BACKUP_DIR/genesis_${TIMESTAMP}_preupdate.json"

cp "$ROLLUP_JSON" "$BACKUP_ROLLUP"
cp "$GENESIS_JSON" "$BACKUP_GENESIS"

echo -e "  - Backed up rollup.json to: $BACKUP_ROLLUP"
echo -e "  - Backed up genesis.json to: $BACKUP_GENESIS"

echo ""
echo -e "${GREEN}Step 2: Displaying current EIP-1559 parameters...${NC}"

CURRENT_EIP1559=$(jq -r '.genesis.system_config.eip1559Params' "$ROLLUP_JSON")
CURRENT_ELASTICITY=$(jq -r '.chain_op_config.eip1559Elasticity' "$ROLLUP_JSON")
CURRENT_DENOMINATOR=$(jq -r '.chain_op_config.eip1559Denominator' "$ROLLUP_JSON")

echo -e "  ${YELLOW}Current rollup.json:${NC}"
echo -e "    - eip1559Params: $CURRENT_EIP1559"
echo -e "    - eip1559Elasticity: $CURRENT_ELASTICITY"
echo -e "    - eip1559Denominator: $CURRENT_DENOMINATOR"

# Check genesis.json for SystemConfig
GENESIS_EIP1559=$(jq -r '.alloc["0x0000000000000000000000000000000000000019"].storage["0x0000000000000000000000000000000000000000000000000000000000000065"]' "$GENESIS_JSON" 2>/dev/null || echo "not found")

echo -e "  ${YELLOW}Current genesis.json SystemConfig storage:${NC}"
echo -e "    - EIP-1559 params (slot 0x65): $GENESIS_EIP1559"

echo ""
echo -e "${GREEN}Step 3: Updating rollup.json...${NC}"

# Update rollup.json with correct EIP-1559 parameters
jq --arg eip1559 "$EIP1559_PARAMS" \
   --arg elasticity "$ELASTICITY" \
   --arg denominator "$DENOMINATOR" \
   '.genesis.system_config.eip1559Params = $eip1559 |
    .chain_op_config.eip1559Elasticity = ($elasticity | tonumber) |
    .chain_op_config.eip1559Denominator = ($denominator | tonumber)' \
   "$ROLLUP_JSON" > "$ROLLUP_JSON.tmp" && mv "$ROLLUP_JSON.tmp" "$ROLLUP_JSON"

echo -e "  ${GREEN}✓ Updated rollup.json with new EIP-1559 parameters${NC}"

echo ""
echo -e "${GREEN}Step 4: Updating genesis.json SystemConfig storage...${NC}"

# The SystemConfig contract is deployed at predeploy address 0x0000000000000000000000000000000000000019
# Storage slot 0x65 (101 decimal) contains the eip1559Params
# We need to update this storage slot in the genesis alloc

# First, let's verify the SystemConfig exists in alloc
if jq -e '.alloc["0x0000000000000000000000000000000000000019"]' "$GENESIS_JSON" > /dev/null 2>&1; then
    echo -e "  - Found SystemConfig predeploy at 0x19"

    # Update the storage slot for eip1559Params
    # Pad the value to 32 bytes (64 hex chars)
    PADDED_VALUE=$(printf "0x%064s" "${EIP1559_PARAMS#0x}" | tr ' ' '0')

    jq --arg value "$PADDED_VALUE" \
       '.alloc["0x0000000000000000000000000000000000000019"].storage["0x0000000000000000000000000000000000000000000000000000000000000065"] = $value' \
       "$GENESIS_JSON" > "$GENESIS_JSON.tmp" && mv "$GENESIS_JSON.tmp" "$GENESIS_JSON"

    echo -e "  ${GREEN}✓ Updated genesis.json SystemConfig storage slot 0x65${NC}"
    echo -e "    - New value: $PADDED_VALUE"
else
    echo -e "  ${YELLOW}⚠ WARNING: SystemConfig predeploy not found in genesis.json${NC}"
    echo -e "    This is expected if using a different genesis generation method"
fi

echo ""
echo -e "${GREEN}Step 5: Verifying updates...${NC}"

# Verify rollup.json
NEW_EIP1559=$(jq -r '.genesis.system_config.eip1559Params' "$ROLLUP_JSON")
NEW_ELASTICITY=$(jq -r '.chain_op_config.eip1559Elasticity' "$ROLLUP_JSON")
NEW_DENOMINATOR=$(jq -r '.chain_op_config.eip1559Denominator' "$ROLLUP_JSON")

echo -e "  ${YELLOW}Updated rollup.json:${NC}"
echo -e "    - eip1559Params: $NEW_EIP1559"
echo -e "    - eip1559Elasticity: $NEW_ELASTICITY"
echo -e "    - eip1559Denominator: $NEW_DENOMINATOR"

# Verify genesis.json
NEW_GENESIS_EIP1559=$(jq -r '.alloc["0x0000000000000000000000000000000000000019"].storage["0x0000000000000000000000000000000000000000000000000000000000000065"]' "$GENESIS_JSON" 2>/dev/null || echo "not found")

echo -e "  ${YELLOW}Updated genesis.json SystemConfig storage:${NC}"
echo -e "    - EIP-1559 params (slot 0x65): $NEW_GENESIS_EIP1559"

# Validation
echo ""
if [ "$NEW_EIP1559" == "$EIP1559_PARAMS" ] && [ "$NEW_ELASTICITY" == "$ELASTICITY" ] && [ "$NEW_DENOMINATOR" == "$DENOMINATOR" ]; then
    echo -e "${GREEN}✓ SUCCESS: All EIP-1559 parameters updated correctly!${NC}"
else
    echo -e "${RED}✗ WARNING: Some parameters may not have updated correctly${NC}"
    echo -e "  Expected eip1559Params: $EIP1559_PARAMS, Got: $NEW_EIP1559"
    echo -e "  Expected elasticity: $ELASTICITY, Got: $NEW_ELASTICITY"
    echo -e "  Expected denominator: $DENOMINATOR, Got: $NEW_DENOMINATOR"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Update Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "  1. ${YELLOW}IMPORTANT:${NC} You MUST restart your nodes for changes to take effect:"
echo -e "     ${GREEN}docker-compose restart op-node op-geth${NC}"
echo -e ""
echo -e "  2. After restart, verify gas prices are updating correctly:"
echo -e "     ${GREEN}cast block latest --rpc-url http://localhost:8545${NC}"
echo -e ""
echo -e "  3. Monitor the gas price over several blocks to confirm it's changing"
echo -e ""
echo -e "${YELLOW}What changed:${NC}"
echo -e "  - EIP-1559 denominator: 0 → 50 (enables 2% gas price adjustment per block)"
echo -e "  - EIP-1559 elasticity: set to 6 (allows blocks up to 6x target size)"
echo -e "  - This fixes the stuck gas price issue (was 0x00...00, now 0x...32)"
echo -e ""
echo -e "${YELLOW}Notes:${NC}"
echo -e "  - Backups stored in: $BACKUP_DIR"
echo -e "  - The DA bond change (1 ETH) in deploy-config.json affects L1 contracts only"
echo -e "  - To apply DA bond changes, you'd need to upgrade L1 contracts (not covered here)"
echo -e "  - The fault game parameters in deploy-config.json are for future deployments"
echo -e ""
