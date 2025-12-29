#!/bin/bash

#############################################
# BEGA L2 EIP-1559 Parameters Verification
#############################################
# This script verifies that EIP-1559 parameters
# are correctly set in all configuration files
#
# Usage: ./scripts/verify-eip1559-params.sh
#############################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_ROOT="/Users/kangmunil/Project/BEGA"
CONFIG_DIR="$PROJECT_ROOT/config"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}BEGA L2 EIP-1559 Parameters Verification${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}ERROR: jq is required. Install with: brew install jq${NC}"
    exit 1
fi

echo -e "${GREEN}1. Deploy Config (deploy-config.json)${NC}"
echo -e "${YELLOW}--------------------------------------${NC}"
jq -r '"  L2 Block Time:           \(.l2BlockTime)s
  L2 Gas Limit:            \(.l2GenesisBlockGasLimit)
  EIP-1559 Elasticity:     \(.l2GenesisEip1559Elasticity)
  EIP-1559 Denominator:    \(.l2GenesisEip1559Denominator)
  DA Bond Size:            \(.daBondSize) wei (\(.daBondSize | tonumber / 1000000000000000000) ETH)
  Fault Game Max Depth:    \(.faultGameMaxDepth)
  Fault Game Split Depth:  \(.faultGameSplitDepth)
  Fault Game Max Duration: \(.faultGameMaxDuration)s (\(.faultGameMaxDuration | tonumber / 86400) days)"' \
  "$CONFIG_DIR/deploy-config.json"

echo ""
echo -e "${GREEN}2. Rollup Config (rollup.json)${NC}"
echo -e "${YELLOW}--------------------------------------${NC}"
jq -r '"  L2 Chain ID:             \(.l2_chain_id)
  Block Time:              \(.block_time)s
  Gas Limit:               \(.genesis.system_config.gasLimit)
  EIP-1559 Params (hex):   \(.genesis.system_config.eip1559Params)
  EIP-1559 Elasticity:     \(.chain_op_config.eip1559Elasticity)
  EIP-1559 Denominator:    \(.chain_op_config.eip1559Denominator)"' \
  "$CONFIG_DIR/rollup.json"

echo ""
echo -e "${GREEN}3. L1 Contract Addresses${NC}"
echo -e "${YELLOW}--------------------------------------${NC}"
jq -r '"  OptimismPortal:          \(.deposit_contract_address)
  SystemConfig:            \(.l1_system_config_address)
  ProtocolVersions:        \(.protocol_versions_address)
  Batch Inbox:             \(.batch_inbox_address)"' \
  "$CONFIG_DIR/rollup.json"

echo ""
echo -e "${GREEN}4. Parameter Validation${NC}"
echo -e "${YELLOW}--------------------------------------${NC}"

# Extract values
ROLLUP_EIP1559=$(jq -r '.genesis.system_config.eip1559Params' "$CONFIG_DIR/rollup.json")
ROLLUP_ELASTICITY=$(jq -r '.chain_op_config.eip1559Elasticity' "$CONFIG_DIR/rollup.json")
ROLLUP_DENOMINATOR=$(jq -r '.chain_op_config.eip1559Denominator' "$CONFIG_DIR/rollup.json")

DEPLOY_ELASTICITY=$(jq -r '.l2GenesisEip1559Elasticity' "$CONFIG_DIR/deploy-config.json")
DEPLOY_DENOMINATOR=$(jq -r '.l2GenesisEip1559Denominator' "$CONFIG_DIR/deploy-config.json")
DA_BOND=$(jq -r '.daBondSize' "$CONFIG_DIR/deploy-config.json")

# Expected values
EXPECTED_EIP1559="0x0000000000000032"
EXPECTED_ELASTICITY="6"
EXPECTED_DENOMINATOR="50"
EXPECTED_DA_BOND="1000000000000000000"

# Validation checks
ALL_VALID=true

if [ "$ROLLUP_EIP1559" == "$EXPECTED_EIP1559" ]; then
    echo -e "  ${GREEN}✓${NC} EIP-1559 Params (hex):     $ROLLUP_EIP1559 ${GREEN}(CORRECT)${NC}"
else
    echo -e "  ${RED}✗${NC} EIP-1559 Params (hex):     $ROLLUP_EIP1559 ${RED}(EXPECTED: $EXPECTED_EIP1559)${NC}"
    ALL_VALID=false
fi

if [ "$ROLLUP_ELASTICITY" == "$EXPECTED_ELASTICITY" ] && [ "$DEPLOY_ELASTICITY" == "$EXPECTED_ELASTICITY" ]; then
    echo -e "  ${GREEN}✓${NC} EIP-1559 Elasticity:       $ROLLUP_ELASTICITY ${GREEN}(CORRECT)${NC}"
else
    echo -e "  ${RED}✗${NC} EIP-1559 Elasticity:       rollup=$ROLLUP_ELASTICITY deploy=$DEPLOY_ELASTICITY ${RED}(EXPECTED: $EXPECTED_ELASTICITY)${NC}"
    ALL_VALID=false
fi

if [ "$ROLLUP_DENOMINATOR" == "$EXPECTED_DENOMINATOR" ] && [ "$DEPLOY_DENOMINATOR" == "$EXPECTED_DENOMINATOR" ]; then
    echo -e "  ${GREEN}✓${NC} EIP-1559 Denominator:      $ROLLUP_DENOMINATOR ${GREEN}(CORRECT)${NC}"
else
    echo -e "  ${RED}✗${NC} EIP-1559 Denominator:      rollup=$ROLLUP_DENOMINATOR deploy=$DEPLOY_DENOMINATOR ${RED}(EXPECTED: $EXPECTED_DENOMINATOR)${NC}"
    ALL_VALID=false
fi

if [ "$DA_BOND" == "$EXPECTED_DA_BOND" ]; then
    echo -e "  ${GREEN}✓${NC} DA Bond Size:              1 ETH ${GREEN}(CORRECT)${NC}"
else
    echo -e "  ${YELLOW}!${NC} DA Bond Size:              $(echo "scale=2; $DA_BOND / 1000000000000000000" | bc) ETH ${YELLOW}(deploy-config only, requires L1 upgrade)${NC}"
fi

echo ""
echo -e "${YELLOW}--------------------------------------${NC}"

if [ "$ALL_VALID" = true ]; then
    echo -e "${GREEN}✓ ALL EIP-1559 PARAMETERS VALID!${NC}"
    echo ""
    echo -e "${YELLOW}Status:${NC} Configuration files are correctly set"
    echo -e "${YELLOW}Action Required:${NC} Restart nodes if not already done:"
    echo -e "  ${GREEN}docker-compose restart op-node op-geth${NC}"
else
    echo -e "${RED}✗ VALIDATION FAILED!${NC}"
    echo ""
    echo -e "${YELLOW}Action Required:${NC} Re-run the update script:"
    echo -e "  ${GREEN}./scripts/update-eip1559-params.sh${NC}"
fi

echo ""
echo -e "${YELLOW}========================================${NC}"
echo ""

# Return exit code based on validation
if [ "$ALL_VALID" = true ]; then
    exit 0
else
    exit 1
fi
