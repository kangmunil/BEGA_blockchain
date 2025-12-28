#!/bin/bash
set -e

echo "=== Deploying L2 BEGA Token via OptimismMintableERC20Factory ==="

# Load environment variables
source .env

# Contract addresses
FACTORY="0x4200000000000000000000000000000000000012"
L1_BEGA="0x55B746d21bCEb81374e818C809d0a8145e4Be2e1"
L1_BRIDGE="0xe07c38a86d385298813dfbf1c4572b3ee941923d"

echo ""
echo "Configuration:"
echo "  Factory: $FACTORY"
echo "  L1 BEGA: $L1_BEGA"
echo "  L1 Bridge: $L1_BRIDGE"
echo "  L2 RPC: http://localhost:8545"
echo ""

# Create the L2 token
echo "Creating OptimismMintableERC20..."
TX_HASH=$(~/.foundry/bin/cast send $FACTORY \
  "createOptimismMintableERC20(address,string,string)" \
  $L1_BEGA \
  "BEGA" \
  "BEGA" \
  --rpc-url http://localhost:8545 \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --json | jq -r '.transactionHash')

echo "Transaction sent: $TX_HASH"
echo ""

# Wait for confirmation
echo "Waiting for confirmation..."
sleep 5

# Get the receipt
RECEIPT=$(~/.foundry/bin/cast receipt $TX_HASH --rpc-url http://localhost:8545 --json)

# Extract L2 token address from logs
L2_TOKEN=$(echo $RECEIPT | jq -r '.logs[] | select(.topics[0] == "0xceeb8e7d520d7f3b65fc11a262b91066940193b05d4f93df3120ed66ef8ae7ba") | .topics[2]' | sed 's/0x000000000000000000000000/0x/')

echo ""
echo "=== Deployment Complete ==="
echo "L2 BEGA Token: $L2_TOKEN"
echo ""
echo "Update your .env file:"
echo "L2_BEGA_TOKEN=$L2_TOKEN"
