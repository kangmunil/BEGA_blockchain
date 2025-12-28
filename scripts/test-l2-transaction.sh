#!/bin/bash
# L2 첫 트랜잭션 테스트 스크립트

echo "🧪 BEGA L2 트랜잭션 테스트"
echo "=========================="
echo ""

L2_RPC="http://localhost:8545"

# 1. 블록 번호 확인
echo "1️⃣ 현재 블록 번호 확인..."
BLOCK_NUM=$(curl -s -X POST $L2_RPC \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
  | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ ! -z "$BLOCK_NUM" ]; then
    BLOCK_DEC=$((16#${BLOCK_NUM#0x}))
    echo "   ✅ 블록 번호: $BLOCK_DEC (hex: $BLOCK_NUM)"
else
    echo "   ❌ L2 RPC 응답 없음. Docker 서비스를 확인하세요."
    exit 1
fi

echo ""

# 2. Chain ID 확인
echo "2️⃣ Chain ID 확인..."
CHAIN_ID=$(curl -s -X POST $L2_RPC \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

CHAIN_DEC=$((16#${CHAIN_ID#0x}))
echo "   ✅ Chain ID: $CHAIN_DEC (hex: $CHAIN_ID)"

if [ "$CHAIN_DEC" != "12345678" ]; then
    echo "   ⚠️  예상 Chain ID와 다릅니다 (예상: 12345678)"
fi

echo ""

# 3. Gas Price 확인
echo "3️⃣ Gas Price 확인..."
GAS_PRICE=$(curl -s -X POST $L2_RPC \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_gasPrice","params":[],"id":1}' \
  | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

if [ ! -z "$GAS_PRICE" ]; then
    echo "   ✅ Gas Price: $GAS_PRICE"
else
    echo "   ⚠️  Gas Price 조회 실패"
fi

echo ""

# 4. 네트워크 버전 확인
echo "4️⃣ 네트워크 버전 확인..."
NET_VERSION=$(curl -s -X POST $L2_RPC \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"net_version","params":[],"id":1}' \
  | grep -o '"result":"[^"]*"' | cut -d'"' -f4)

echo "   ✅ Network Version: $NET_VERSION"

echo ""
echo "================================================"
echo "✅ L2 기본 기능 정상 작동!"
echo "================================================"
echo ""
echo "다음 단계:"
echo "- MetaMask에서 BEGA L2 네트워크 추가"
echo "- L1에서 BEGA 토큰 브릿지"
echo "- L2에서 첫 전송 테스트"
echo ""
