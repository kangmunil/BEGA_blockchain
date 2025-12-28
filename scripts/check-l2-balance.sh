#!/bin/bash

DEPLOYER="0x314cfbF516c7EA668F52Cd02feeCf1Aa4eF1e01e"
L2_RPC="http://localhost:8545"

echo "=== L2 BEGA Balance Monitor ==="
echo "Address: $DEPLOYER"
echo ""
echo "Checking balance every 10 seconds... (Press Ctrl+C to stop)"
echo ""

while true; do
    BALANCE=$(~/.foundry/bin/cast balance $DEPLOYER --rpc-url $L2_RPC --ether 2>/dev/null)
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

    echo "[$TIMESTAMP] Balance: $BALANCE BEGA"

    # Exit if balance is not zero
    if [[ "$BALANCE" != "0.000000000000000000" ]]; then
        echo ""
        echo "🎉 BEGA has arrived on L2!"
        echo ""
        echo "You can now deploy OptimismMintableERC20:"
        echo "  ./scripts/deploy-l2-bega.sh"
        exit 0
    fi

    sleep 10
done
