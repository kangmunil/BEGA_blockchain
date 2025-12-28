#!/bin/bash
# L1 컨트랙트 배포 검증 스크립트

echo "🔍 BEGA L2 배포 검증 시작..."
echo ""

CONFIG_DIR="/Users/kangmunil/Project/BEGA/config"

# 1. 필수 파일 존재 확인
echo "📁 1. 필수 파일 확인..."
if [ -f "$CONFIG_DIR/genesis.json" ]; then
    echo "  ✅ genesis.json 존재"
else
    echo "  ❌ genesis.json 없음"
    exit 1
fi

if [ -f "$CONFIG_DIR/rollup.json" ]; then
    echo "  ✅ rollup.json 존재"
else
    echo "  ❌ rollup.json 없음"
    exit 1
fi

if [ -f "$CONFIG_DIR/state.json" ]; then
    echo "  ✅ state.json 존재"
else
    echo "  ⚠️  state.json 없음 (선택사항)"
fi

echo ""

# 2. genesis.json 검증
echo "🔎 2. Genesis 파일 검증..."
if command -v jq &> /dev/null; then
    GENESIS_CHAIN_ID=$(cat "$CONFIG_DIR/genesis.json" | jq -r '.config.chainId // empty')
    if [ "$GENESIS_CHAIN_ID" = "12345678" ]; then
        echo "  ✅ Chain ID 일치: $GENESIS_CHAIN_ID"
    else
        echo "  ⚠️  Chain ID 불일치: $GENESIS_CHAIN_ID (예상: 12345678)"
    fi

    GENESIS_ALLOC=$(cat "$CONFIG_DIR/genesis.json" | jq '.alloc | length')
    echo "  ℹ️  Genesis 계정 수: $GENESIS_ALLOC"
else
    echo "  ⚠️  jq가 설치되지 않아 상세 검증을 건너뜁니다"
fi

echo ""

# 3. rollup.json 검증
echo "🔎 3. Rollup 설정 검증..."
if command -v jq &> /dev/null; then
    L2_CHAIN_ID=$(cat "$CONFIG_DIR/rollup.json" | jq -r '.genesis.l2.chain_id // .l2_chain_id // empty')
    echo "  ℹ️  L2 Chain ID: $L2_CHAIN_ID"

    BLOCK_TIME=$(cat "$CONFIG_DIR/rollup.json" | jq -r '.block_time // empty')
    echo "  ℹ️  Block Time: ${BLOCK_TIME}s"

    # Custom Gas Token 확인
    GAS_TOKEN=$(cat "$CONFIG_DIR/rollup.json" | jq -r '.genesis.system_config.gas_paying_token // empty' 2>/dev/null)
    if [ ! -z "$GAS_TOKEN" ] && [ "$GAS_TOKEN" != "null" ]; then
        echo "  ✅ Custom Gas Token 설정됨: $GAS_TOKEN"
    fi
fi

echo ""

# 4. 시크릿 파일 확인
echo "🔐 4. 시크릿 파일 확인..."
SECRETS_DIR="/Users/kangmunil/Project/BEGA/secrets"
for file in jwt.txt sequencer.key batcher.key proposer.key; do
    if [ -f "$SECRETS_DIR/$file" ]; then
        SIZE=$(wc -c < "$SECRETS_DIR/$file" | tr -d ' ')
        echo "  ✅ $file 존재 (${SIZE} bytes)"
    else
        echo "  ❌ $file 없음"
    fi
done

echo ""
echo "================================================"
echo "✅ 배포 검증 완료!"
echo "================================================"
echo ""
echo "다음 단계:"
echo "1. docker compose up -d 실행"
echo "2. ./scripts/check-health.sh로 상태 확인"
echo "3. MetaMask에 네트워크 추가"
echo ""
