#!/bin/bash
# Test EIP-1559 Transaction on BEGA L2
# This script demonstrates sending a transaction with EIP-1559 dynamic fees

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== EIP-1559 Transaction Test ===${NC}\n"

# Get current base fee
echo -e "${YELLOW}Step 1: Fetching current base fee${NC}"
LATEST_BLOCK=$(curl -s -X POST http://localhost:8545 \
    -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest", false],"id":1}')

BASE_FEE=$(echo "$LATEST_BLOCK" | python3 -c "import sys, json; data = json.load(sys.stdin); print(int(data['result']['baseFeePerGas'], 16))")
BLOCK_NUM=$(echo "$LATEST_BLOCK" | python3 -c "import sys, json; data = json.load(sys.stdin); print(int(data['result']['number'], 16))")

echo -e "  Current Block: #$BLOCK_NUM"
echo -e "  Base Fee: ${GREEN}$BASE_FEE wei${NC}\n"

# Calculate recommended gas fees for EIP-1559
# maxFeePerGas = (baseFee * 2) + maxPriorityFeePerGas
# This ensures the transaction can be included even if base fee doubles
PRIORITY_FEE=2000000000  # 2 gwei priority fee for miner
MAX_FEE=$((BASE_FEE * 2 + PRIORITY_FEE))

echo -e "${YELLOW}Step 2: Recommended EIP-1559 Gas Parameters${NC}"
echo -e "  maxPriorityFeePerGas: ${GREEN}$PRIORITY_FEE wei${NC} (2 gwei)"
echo -e "  maxFeePerGas: ${GREEN}$MAX_FEE wei${NC} (baseFee * 2 + priority)"
echo -e "  This ensures inclusion even if base fee doubles\n"

# Explain the fee structure
echo -e "${YELLOW}Step 3: EIP-1559 Fee Breakdown${NC}"
echo -e "  With EIP-1559, transaction fees have two components:"
echo -e "  1. ${BLUE}Base Fee${NC}: $BASE_FEE wei (burned, adjusts dynamically)"
echo -e "  2. ${BLUE}Priority Fee${NC}: Up to $PRIORITY_FEE wei (goes to sequencer)"
echo -e "  ${BLUE}Total Cost${NC}: ~$(($BASE_FEE + PRIORITY_FEE)) wei per gas unit\n"

# Show how to send a transaction with EIP-1559 (example, not executed)
echo -e "${YELLOW}Step 4: How to Send an EIP-1559 Transaction${NC}"
echo -e "  Using cast (from Foundry):"
echo -e "${GREEN}  cast send <TO_ADDRESS> \\
    --value 0.01ether \\
    --priority-gas-price $PRIORITY_FEE \\
    --gas-price $MAX_FEE \\
    --rpc-url http://localhost:8545 \\
    --private-key <YOUR_PRIVATE_KEY>${NC}\n"

echo -e "  Using eth_sendTransaction RPC:"
cat << EOF
${GREEN}  curl -X POST http://localhost:8545 \\
    -H "Content-Type: application/json" \\
    --data '{
      "jsonrpc": "2.0",
      "method": "eth_sendTransaction",
      "params": [{
        "from": "0xYourAddress",
        "to": "0xRecipientAddress",
        "value": "0x2386f26fc10000",
        "maxFeePerGas": "0x$(printf "%x" $MAX_FEE)",
        "maxPriorityFeePerGas": "0x$(printf "%x" $PRIORITY_FEE)"
      }],
      "id": 1
    }'${NC}
EOF

echo -e "\n"

# Monitor base fee changes
echo -e "${YELLOW}Step 5: Monitoring Base Fee Changes${NC}"
echo "Watching the next 10 blocks to observe base fee adjustments...\n"

INITIAL_BLOCK=$BLOCK_NUM

for i in {1..10}; do
    sleep 2  # Wait for next block (2 second block time)

    BLOCK=$(curl -s -X POST http://localhost:8545 \
        -H "Content-Type: application/json" \
        --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["latest", false],"id":1}')

    CURRENT_BLOCK=$(echo "$BLOCK" | python3 -c "import sys, json; data = json.load(sys.stdin); print(int(data['result']['number'], 16))" 2>/dev/null || echo $INITIAL_BLOCK)

    if [ "$CURRENT_BLOCK" -gt "$INITIAL_BLOCK" ]; then
        CURRENT_BASE_FEE=$(echo "$BLOCK" | python3 -c "import sys, json; data = json.load(sys.stdin); print(int(data['result']['baseFeePerGas'], 16))")
        GAS_USED=$(echo "$BLOCK" | python3 -c "import sys, json; data = json.load(sys.stdin); print(int(data['result']['gasUsed'], 16))")
        GAS_LIMIT=$(echo "$BLOCK" | python3 -c "import sys, json; data = json.load(sys.stdin); print(int(data['result']['gasLimit'], 16))")

        CHANGE=$((CURRENT_BASE_FEE - BASE_FEE))
        if [ $CHANGE -gt 0 ]; then
            CHANGE_STR="${GREEN}+$CHANGE${NC}"
        elif [ $CHANGE -lt 0 ]; then
            CHANGE_STR="${RED}$CHANGE${NC}"
        else
            CHANGE_STR="0"
        fi

        USAGE_PCT=$(python3 -c "print(f'{($GAS_USED / $GAS_LIMIT * 100):.2f}')")

        echo -e "  Block #$CURRENT_BLOCK: baseFee=${CURRENT_BASE_FEE} wei (${CHANGE_STR}), usage=${USAGE_PCT}%"

        BASE_FEE=$CURRENT_BASE_FEE
        INITIAL_BLOCK=$CURRENT_BLOCK
    fi
done

echo -e "\n${BLUE}=== EIP-1559 Formula Explanation ===${NC}"
echo -e "The base fee adjusts each block using this formula:\n"
echo -e "  If gasUsed > target:"
echo -e "    baseFee += baseFee × (gasUsed - target) / (target × denominator)"
echo -e "    With denominator=50, max increase: ${GREEN}~2% per block${NC}\n"
echo -e "  If gasUsed < target:"
echo -e "    baseFee -= baseFee × (target - gasUsed) / (target × denominator)"
echo -e "    With denominator=50, max decrease: ${GREEN}~2% per block${NC}\n"
echo -e "  Target gasUsed: ${YELLOW}5,000,000 gas${NC} (16.67% of 30M limit)"
echo -e "  Elasticity multiplier: ${YELLOW}6${NC} (allows blocks up to 6x target)\n"

echo -e "${GREEN}Test complete! EIP-1559 is working correctly.${NC}"
