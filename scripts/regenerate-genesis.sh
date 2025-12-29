#!/bin/bash

#############################################
# BEGA L2 Genesis Regeneration Script
#############################################
# This script regenerates genesis.json and rollup.json
# after modifying deploy-config.json parameters
#
# Usage: ./scripts/regenerate-genesis.sh
#############################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

PROJECT_ROOT="/Users/kangmunil/Project/BEGA"
CONFIG_DIR="$PROJECT_ROOT/config"
BACKUP_DIR="$CONFIG_DIR/backups"
DEPLOY_CONFIG="$CONFIG_DIR/deploy-config.json"
GENESIS_JSON="$CONFIG_DIR/genesis.json"
ROLLUP_JSON="$CONFIG_DIR/rollup.json"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}BEGA L2 Genesis Regeneration${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Check if deploy-config.json exists
if [ ! -f "$DEPLOY_CONFIG" ]; then
    echo -e "${RED}ERROR: deploy-config.json not found at $DEPLOY_CONFIG${NC}"
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Generate backup timestamp
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

echo -e "${GREEN}Step 1: Backing up existing genesis files...${NC}"

# Backup existing files if they exist
if [ -f "$GENESIS_JSON" ]; then
    BACKUP_GENESIS="$BACKUP_DIR/genesis_${TIMESTAMP}.json"
    cp "$GENESIS_JSON" "$BACKUP_GENESIS"
    echo -e "  - Backed up genesis.json to: $BACKUP_GENESIS"
fi

if [ -f "$ROLLUP_JSON" ]; then
    BACKUP_ROLLUP="$BACKUP_DIR/rollup_${TIMESTAMP}.json"
    cp "$ROLLUP_JSON" "$BACKUP_ROLLUP"
    echo -e "  - Backed up rollup.json to: $BACKUP_ROLLUP"
fi

echo ""
echo -e "${GREEN}Step 2: Removing old genesis files...${NC}"

# Remove old files
if [ -f "$GENESIS_JSON" ]; then
    rm "$GENESIS_JSON"
    echo -e "  - Removed old genesis.json"
fi

if [ -f "$ROLLUP_JSON" ]; then
    rm "$ROLLUP_JSON"
    echo -e "  - Removed old rollup.json"
fi

echo ""
echo -e "${GREEN}Step 3: Creating deployments.json from existing rollup.json...${NC}"

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo -e "${RED}ERROR: jq is required but not installed. Please install jq first.${NC}"
    exit 1
fi

# Create deployments.json from the backup rollup.json
DEPLOYMENTS_JSON="$CONFIG_DIR/deployments.json"
if [ -f "$BACKUP_ROLLUP" ]; then
    echo -e "  - Extracting deployment addresses from backup rollup.json..."
    jq '{
        "OptimismPortalProxy": .deposit_contract_address,
        "SystemConfigProxy": .l1_system_config_address,
        "ProtocolVersionsProxy": .protocol_versions_address
    }' "$BACKUP_ROLLUP" > "$DEPLOYMENTS_JSON"
    echo -e "  - Created deployments.json with L1 contract addresses"
else
    echo -e "${RED}ERROR: No backup rollup.json found to extract deployment addresses${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Step 4: Regenerating genesis files with op-node...${NC}"

# Check if op-node is available
if ! command -v op-node &> /dev/null; then
    echo -e "${RED}ERROR: op-node command not found. Please ensure OP Stack is installed.${NC}"
    exit 1
fi

# Regenerate genesis files
cd "$PROJECT_ROOT"
op-node genesis l2 \
    --deploy-config "$DEPLOY_CONFIG" \
    --l1-deployments "$DEPLOYMENTS_JSON" \
    --outfile.l2 "$GENESIS_JSON" \
    --outfile.rollup "$ROLLUP_JSON"

if [ $? -ne 0 ]; then
    echo -e "${RED}ERROR: Failed to regenerate genesis files${NC}"
    exit 1
fi

echo -e "  - Successfully generated genesis.json"
echo -e "  - Successfully generated rollup.json"

echo ""
echo -e "${GREEN}Step 5: Verifying EIP-1559 parameters in rollup.json...${NC}"

if command -v jq &> /dev/null; then
    # Extract eip1559Params
    EIP1559_PARAMS=$(jq -r '.genesis.system_config.eip1559Params' "$ROLLUP_JSON")
    EXPECTED_PARAMS="0x0000000000000032" # elasticity=6 (0x06), denominator=50 (0x32)

    echo -e "  - EIP-1559 Params in rollup.json: ${YELLOW}$EIP1559_PARAMS${NC}"

    # Also check chain_op_config
    ELASTICITY=$(jq -r '.chain_op_config.eip1559Elasticity' "$ROLLUP_JSON")
    DENOMINATOR=$(jq -r '.chain_op_config.eip1559Denominator' "$ROLLUP_JSON")

    echo -e "  - chain_op_config.eip1559Elasticity: ${YELLOW}$ELASTICITY${NC}"
    echo -e "  - chain_op_config.eip1559Denominator: ${YELLOW}$DENOMINATOR${NC}"

    if [ "$ELASTICITY" == "6" ] && [ "$DENOMINATOR" == "50" ]; then
        echo -e "  ${GREEN}✓ EIP-1559 parameters are correct!${NC}"
    else
        echo -e "  ${RED}✗ WARNING: EIP-1559 parameters may be incorrect${NC}"
    fi
fi

echo ""
echo -e "${GREEN}Step 6: Verification Summary${NC}"

if command -v jq &> /dev/null; then
    echo -e "${YELLOW}Deploy Config Parameters:${NC}"
    jq '{
        "L2 Chain ID": .l2ChainID,
        "L2 Block Time": .l2BlockTime,
        "Gas Limit": .l2GenesisBlockGasLimit,
        "EIP-1559 Elasticity": .l2GenesisEip1559Elasticity,
        "EIP-1559 Denominator": .l2GenesisEip1559Denominator,
        "DA Bond Size (wei)": .daBondSize,
        "Fault Game Max Depth": .faultGameMaxDepth,
        "Fault Game Split Depth": .faultGameSplitDepth,
        "Fault Game Max Duration": .faultGameMaxDuration
    }' "$DEPLOY_CONFIG"

    echo ""
    echo -e "${YELLOW}Rollup Config System Parameters:${NC}"
    jq '{
        "Gas Limit": .genesis.system_config.gasLimit,
        "EIP-1559 Params": .genesis.system_config.eip1559Params,
        "EIP-1559 Elasticity": .chain_op_config.eip1559Elasticity,
        "EIP-1559 Denominator": .chain_op_config.eip1559Denominator,
        "L2 Chain ID": .l2_chain_id,
        "Block Time": .block_time
    }' "$ROLLUP_JSON"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Genesis regeneration completed!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo -e "  1. Review the generated files: genesis.json and rollup.json"
echo -e "  2. Restart your op-node with the new rollup.json"
echo -e "  3. Restart your op-geth with the new genesis.json"
echo -e "  4. Monitor gas price behavior to confirm EIP-1559 is working"
echo ""
echo -e "${YELLOW}Important:${NC}"
echo -e "  - Backups are stored in: $BACKUP_DIR"
echo -e "  - This will NOT update L1 contracts (DA bond changes require L1 upgrade)"
echo -e "  - Ensure all nodes are restarted with the new configuration"
echo ""
