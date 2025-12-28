#!/bin/bash
# Health check script for BEGA L2

set -e

echo "🏥 BEGA L2 Health Check"
echo "======================="
echo ""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if services are running
echo "📦 Checking Docker Services..."
if docker compose ps | grep -q "Up"; then
    echo -e "${GREEN}✅ Docker services are running${NC}"
else
    echo -e "${RED}❌ Docker services are not running${NC}"
    echo "   Run: docker compose up -d"
    exit 1
fi

echo ""

# Check L2 Geth
echo "🔍 Checking L2 Geth (Execution Layer)..."
BLOCK_NUMBER=$(curl -s -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  | grep -o '"result":"[^"]*"' \
  | cut -d'"' -f4)

if [ -n "$BLOCK_NUMBER" ]; then
    BLOCK_DEC=$((16#${BLOCK_NUMBER#0x}))
    echo -e "${GREEN}✅ L2 Geth is responsive${NC}"
    echo "   Latest block: $BLOCK_DEC (hex: $BLOCK_NUMBER)"
else
    echo -e "${RED}❌ L2 Geth is not responding${NC}"
    echo "   Check logs: docker compose logs -f l2-geth"
fi

echo ""

# Check L2 Node
echo "🔍 Checking L2 Node (Consensus Layer)..."
NODE_HEALTH=$(curl -s -X POST http://localhost:8547 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"optimism_syncStatus","params":[],"id":1}' 2>/dev/null || echo "error")

if [[ "$NODE_HEALTH" != "error" ]] && [[ "$NODE_HEALTH" == *"result"* ]]; then
    echo -e "${GREEN}✅ L2 Node is responsive${NC}"
    # Pretty print sync status
    echo "$NODE_HEALTH" | grep -o '"current_l1":[^,}]*' | head -1
else
    echo -e "${RED}❌ L2 Node is not responding${NC}"
    echo "   Check logs: docker compose logs -f l2-node"
fi

echo ""

# Check Celestia connection
echo "🔍 Checking Celestia Connection..."
if curl -s http://localhost:26658 > /dev/null 2>&1; then
    echo -e "${GREEN}✅ Celestia Light Node is accessible${NC}"
else
    echo -e "${YELLOW}⚠️  Celestia Light Node is not accessible on localhost:26658${NC}"
    echo "   Make sure Celestia node is running"
    echo "   Or check DA_SERVER_URL in .env"
fi

echo ""

# Check Batcher
echo "🔍 Checking Batcher Status..."
BATCHER_STATUS=$(docker compose ps l2-batcher --format json 2>/dev/null | grep -o '"State":"[^"]*"' | cut -d'"' -f4)

if [ "$BATCHER_STATUS" = "running" ]; then
    echo -e "${GREEN}✅ Batcher is running${NC}"
    echo "   Recent logs:"
    docker compose logs --tail=3 l2-batcher | tail -3
else
    echo -e "${RED}❌ Batcher is not running${NC}"
    echo "   Check logs: docker compose logs -f l2-batcher"
fi

echo ""

# Check Proposer
echo "🔍 Checking Proposer Status..."
PROPOSER_STATUS=$(docker compose ps l2-proposer --format json 2>/dev/null | grep -o '"State":"[^"]*"' | cut -d'"' -f4)

if [ "$PROPOSER_STATUS" = "running" ]; then
    echo -e "${GREEN}✅ Proposer is running${NC}"
else
    echo -e "${RED}❌ Proposer is not running${NC}"
    echo "   Check logs: docker compose logs -f l2-proposer"
fi

echo ""

# Check Gas Oracle Bot
echo "🔍 Checking Gas Oracle Bot..."
GAS_BOT_STATUS=$(docker compose ps gas-oracle --format json 2>/dev/null | grep -o '"State":"[^"]*"' | cut -d'"' -f4)

if [ "$GAS_BOT_STATUS" = "running" ]; then
    echo -e "${GREEN}✅ Gas Oracle Bot is running${NC}"
    echo "   Recent logs:"
    docker compose logs --tail=3 gas-oracle | tail -3
else
    echo -e "${YELLOW}⚠️  Gas Oracle Bot is not running${NC}"
    echo "   Check logs: docker compose logs -f gas-oracle"
fi

echo ""
echo "======================="
echo "Health check complete!"
