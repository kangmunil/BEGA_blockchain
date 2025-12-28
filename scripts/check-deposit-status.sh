#!/bin/bash

DEPOSIT_TX="0x2d8e23c2430a932c5a13525954115dc370f7e7c79c1325dc5b9be858dcf9e65d"
L1_RPC="https://eth-sepolia.g.alchemy.com/v2/V27iwWEWmqkuvqHc3nAUF"

echo "=== L1 Deposit Transaction Status ==="
echo ""

# Get receipt
RECEIPT=$(~/.foundry/bin/cast receipt $DEPOSIT_TX --rpc-url $L1_RPC --json 2>/dev/null)

if [ $? -eq 0 ]; then
    STATUS=$(echo $RECEIPT | jq -r '.status')
    BLOCK=$(echo $RECEIPT | jq -r '.blockNumber')
    GAS_USED=$(echo $RECEIPT | jq -r '.gasUsed')

    echo "Transaction Hash: $DEPOSIT_TX"
    echo "Status: $([ "$STATUS" == "0x1" ] && echo "✅ Success" || echo "❌ Failed")"
    echo "Block Number: $BLOCK"
    echo "Gas Used: $GAS_USED"
    echo ""
    echo "View on Etherscan:"
    echo "https://sepolia.etherscan.io/tx/$DEPOSIT_TX"
    echo ""
    echo "L2 Processing:"
    echo "  - Usually takes 5-10 minutes"
    echo "  - Run: ./scripts/check-l2-balance.sh"
else
    echo "⏳ Transaction not yet confirmed on L1..."
    echo "Waiting for confirmation..."
fi
