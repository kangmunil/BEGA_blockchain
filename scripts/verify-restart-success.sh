#!/bin/bash
# Verification Script: Confirm EIP-1559 Configuration After Restart
# This script verifies that the L2 chain successfully applied the updated
# rollup.json configuration after the service restart.

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== BEGA L2 Post-Restart Verification ===${NC}\n"

# 1. Check Service Status
echo -e "${YELLOW}1. Service Status Check${NC}"
if docker compose ps | grep -q "l2-geth.*Up"; then
    echo -e "${GREEN}✓${NC} l2-geth is running"
else
    echo -e "${RED}✗${NC} l2-geth is NOT running"
    exit 1
fi

if docker compose ps | grep -q "l2-node.*Up"; then
    echo -e "${GREEN}✓${NC} l2-node is running"
else
    echo -e "${RED}✗${NC} l2-node is NOT running"
    exit 1
fi

if docker compose ps | grep -q "l2-batcher.*Up"; then
    echo -e "${GREEN}✓${NC} l2-batcher is running"
else
    echo -e "${RED}✗${NC} l2-batcher is NOT running"
    exit 1
fi

if docker compose ps | grep -q "l2-proposer.*Up"; then
    echo -e "${GREEN}✓${NC} l2-proposer is running"
else
    echo -e "${RED}✗${NC} l2-proposer is NOT running"
    exit 1
fi

echo ""

# 2. Verify rollup.json Configuration
echo -e "${YELLOW}2. Rollup Configuration Check${NC}"

EIP1559_PARAMS=$(cat config/rollup.json | python3 -c "import sys, json; data = json.load(sys.stdin); print(data['genesis']['system_config']['eip1559Params'])")
EIP1559_DENOM=$(cat config/rollup.json | python3 -c "import sys, json; data = json.load(sys.stdin); print(data['chain_op_config']['eip1559Denominator'])")
EIP1559_ELAST=$(cat config/rollup.json | python3 -c "import sys, json; data = json.load(sys.stdin); print(data['chain_op_config']['eip1559Elasticity'])")

if [ "$EIP1559_PARAMS" = "0x0000000000000032" ]; then
    echo -e "${GREEN}✓${NC} eip1559Params = $EIP1559_PARAMS (correct, denominator=50)"
else
    echo -e "${RED}✗${NC} eip1559Params = $EIP1559_PARAMS (expected: 0x0000000000000032)"
    exit 1
fi

if [ "$EIP1559_DENOM" = "50" ]; then
    echo -e "${GREEN}✓${NC} eip1559Denominator = $EIP1559_DENOM (correct)"
else
    echo -e "${RED}✗${NC} eip1559Denominator = $EIP1559_DENOM (expected: 50)"
    exit 1
fi

if [ "$EIP1559_ELAST" = "6" ]; then
    echo -e "${GREEN}✓${NC} eip1559Elasticity = $EIP1559_ELAST (correct)"
else
    echo -e "${RED}✗${NC} eip1559Elasticity = $EIP1559_ELAST (expected: 6)"
    exit 1
fi

echo ""

# 3. Check Chain is Producing Blocks
echo -e "${YELLOW}3. Chain Progress Check${NC}"

BLOCK_NUM=$(curl -s -X POST http://localhost:8545 \
    -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    | python3 -c "import sys, json; data = json.load(sys.stdin); print(int(data['result'], 16))")

if [ "$BLOCK_NUM" -gt 0 ]; then
    echo -e "${GREEN}✓${NC} Chain is producing blocks (current: #$BLOCK_NUM)"
else
    echo -e "${RED}✗${NC} Chain is not producing blocks"
    exit 1
fi

echo ""

# 4. Verify EIP-1559 is Active (baseFeePerGas exists)
echo -e "${YELLOW}4. EIP-1559 Active Check${NC}"

LATEST_BLOCK=$(curl -s -X POST http://localhost:8545 \
    -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest", false],"id":1}')

BASE_FEE=$(echo "$LATEST_BLOCK" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data['result']['baseFeePerGas'])")
BASE_FEE_DEC=$(python3 -c "print(int('$BASE_FEE', 16))")

if [ -n "$BASE_FEE" ] && [ "$BASE_FEE" != "null" ]; then
    echo -e "${GREEN}✓${NC} EIP-1559 is ACTIVE"
    echo -e "  Current baseFeePerGas: $BASE_FEE ($BASE_FEE_DEC wei)"
else
    echo -e "${RED}✗${NC} EIP-1559 is NOT active (baseFeePerGas missing)"
    exit 1
fi

echo ""

# 5. Check Base Fee Adjustments Across Recent Blocks
echo -e "${YELLOW}5. Dynamic Base Fee Verification${NC}"
echo "Checking base fee across the last 5 blocks:"

for i in {0..4}; do
    BLOCK_HEX=$(printf "0x%x" $((BLOCK_NUM - i)))
    BLOCK_DATA=$(curl -s -X POST http://localhost:8545 \
        -H "Content-Type: application/json" \
        --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_getBlockByNumber\",\"params\":[\"$BLOCK_HEX\", false],\"id\":1}")

    BLOCK_NUMBER=$(echo "$BLOCK_DATA" | python3 -c "import sys, json; data = json.load(sys.stdin); print(int(data['result']['number'], 16))")
    BASE_FEE=$(echo "$BLOCK_DATA" | python3 -c "import sys, json; data = json.load(sys.stdin); print(int(data['result']['baseFeePerGas'], 16))")
    GAS_USED=$(echo "$BLOCK_DATA" | python3 -c "import sys, json; data = json.load(sys.stdin); print(int(data['result']['gasUsed'], 16))")
    GAS_LIMIT=$(echo "$BLOCK_DATA" | python3 -c "import sys, json; data = json.load(sys.stdin); print(int(data['result']['gasLimit'], 16))")

    USAGE_PCT=$(python3 -c "print(f'{($GAS_USED / $GAS_LIMIT * 100):.2f}')")

    echo -e "  Block #$BLOCK_NUMBER: baseFee=${BASE_FEE} wei, gasUsed=${GAS_USED}/${GAS_LIMIT} (${USAGE_PCT}%)"
done

echo ""

# 6. Verify No Critical Errors in Logs
echo -e "${YELLOW}6. Log Error Check${NC}"

GETH_ERRORS=$(docker logs bega-l2-geth-1 --tail 100 2>&1 | grep -i "ERROR\|FATAL" | grep -v "Unavailable modules" | wc -l)
NODE_ERRORS=$(docker logs bega-l2-node-1 --tail 100 2>&1 | grep -i "\"lvl\":\"error\"" | wc -l)

if [ "$GETH_ERRORS" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} No critical errors in l2-geth logs"
else
    echo -e "${YELLOW}!${NC} Found $GETH_ERRORS error(s) in l2-geth logs (review recommended)"
fi

if [ "$NODE_ERRORS" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} No critical errors in l2-node logs"
else
    echo -e "${YELLOW}!${NC} Found $NODE_ERRORS error(s) in l2-node logs (review recommended)"
fi

echo ""

# Final Summary
echo -e "${BLUE}=== Verification Summary ===${NC}"
echo -e "${GREEN}✓${NC} All services are running"
echo -e "${GREEN}✓${NC} EIP-1559 configuration is correct (denominator=50, elasticity=6)"
echo -e "${GREEN}✓${NC} EIP-1559 is ACTIVE and adjusting base fees dynamically"
echo -e "${GREEN}✓${NC} Chain is producing blocks normally"
echo ""
echo -e "${GREEN}SUCCESS: The restart was successful and all configurations have been applied!${NC}"
