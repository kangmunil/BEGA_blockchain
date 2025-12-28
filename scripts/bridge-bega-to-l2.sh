#!/bin/bash
set -e

echo "=== Bridging BEGA from L1 to L2 ==="
echo ""

# Load environment
source .env

# Addresses
L1_BEGA="0x55B746d21bCEb81374e818C809d0a8145e4Be2e1"
L1_BRIDGE="0xe07c38a86d385298813dfbf1c4572b3ee941923d"
DEPLOYER="0x314cfbF516c7EA668F52Cd02feeCf1Aa4eF1e01e"

# Amount to bridge (in wei) - 1000 BEGA
AMOUNT="1000000000000000000000"

echo "Configuration:"
echo "  L1 BEGA: $L1_BEGA"
echo "  L1 Bridge: $L1_BRIDGE"
echo "  Recipient (L2): $DEPLOYER"
echo "  Amount: 1000 BEGA"
echo ""

# Step 1: Check L1 BEGA balance
echo "Step 1: Checking L1 BEGA balance..."
L1_BALANCE=$(~/.foundry/bin/cast call $L1_BEGA "balanceOf(address)(uint256)" $DEPLOYER --rpc-url $L1_RPC_URL)
echo "L1 Balance: $L1_BALANCE wei"

if [ "$L1_BALANCE" = "0x0" ] || [ "$L1_BALANCE" = "0" ]; then
    echo "Error: Insufficient L1 BEGA balance!"
    exit 1
fi

echo ""
# Step 2: Approve L1 Bridge
echo "Step 2: Approving L1 Bridge to spend BEGA..."
APPROVE_TX=$(~/.foundry/bin/cast send $L1_BEGA \
    "approve(address,uint256)" \
    $L1_BRIDGE \
    $AMOUNT \
    --rpc-url $L1_RPC_URL \
    --private-key $DEPLOYER_PRIVATE_KEY \
    --json | jq -r '.transactionHash')

echo "Approval TX: $APPROVE_TX"
sleep 5

echo ""
# Step 3: Deposit to L2
echo "Step 3: Depositing BEGA to L2..."

# depositERC20(address _l1Token, address _l2Token, uint256 _amount, uint32 _minGasLimit, bytes calldata _extraData)
# For custom gas token, _l2Token should be address(0) or the gas token address
DEPOSIT_TX=$(~/.foundry/bin/cast send $L1_BRIDGE \
    "depositERC20(address,address,uint256,uint32,bytes)" \
    $L1_BEGA \
    "0x0000000000000000000000000000000000000000" \
    $AMOUNT \
    200000 \
    "0x" \
    --rpc-url $L1_RPC_URL \
    --private-key $DEPLOYER_PRIVATE_KEY \
    --json | jq -r '.transactionHash')

echo "Deposit TX: $DEPOSIT_TX"
echo ""
echo "=== Bridge Transaction Submitted ==="
echo ""
echo "IMPORTANT:"
echo "  - Wait ~5-10 minutes for L2 confirmation"
echo "  - Check L2 balance with:"
echo "    cast balance $DEPLOYER --rpc-url http://localhost:8545 --ether"
echo ""
echo "L1 TX: https://sepolia.etherscan.io/tx/$DEPOSIT_TX"
