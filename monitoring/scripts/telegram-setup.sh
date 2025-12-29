#!/bin/bash

# Telegram Bot Setup Helper Script
# BEGA L2 모니터링 알림용 Telegram 봇 설정 도우미

set -e

echo "========================================="
echo "  BEGA L2 Telegram 봇 설정 도우미"
echo "========================================="
echo ""

# Step 1: Bot Token 입력
echo "📱 Step 1: Bot Token 입력"
echo ""
echo "1. Telegram에서 @BotFather 검색"
echo "2. /newbot 명령으로 새 봇 생성"
echo "3. Bot Token 복사"
echo ""
read -p "Bot Token을 입력하세요: " BOT_TOKEN

if [ -z "$BOT_TOKEN" ]; then
    echo "❌ Bot Token이 비어있습니다."
    exit 1
fi

# Validate bot token format
if [[ ! $BOT_TOKEN =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
    echo "❌ Bot Token 형식이 올바르지 않습니다."
    echo "   형식: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
    exit 1
fi

echo "✅ Bot Token 형식 확인 완료"
echo ""

# Step 2: Bot 유효성 확인
echo "📡 Step 2: Bot 유효성 확인 중..."
BOT_INFO=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getMe")

if echo "$BOT_INFO" | grep -q '"ok":true'; then
    BOT_USERNAME=$(echo "$BOT_INFO" | python3 -c "import sys, json; print(json.load(sys.stdin)['result']['username'])")
    echo "✅ Bot 확인 완료: @$BOT_USERNAME"
else
    echo "❌ Bot Token이 유효하지 않습니다."
    echo "$BOT_INFO"
    exit 1
fi

echo ""

# Step 3: Chat ID 확인
echo "💬 Step 3: Chat ID 확인"
echo ""
echo "다음 중 하나를 선택하세요:"
echo "  1) 개인 채팅으로 알림 받기"
echo "  2) 그룹 채팅으로 알림 받기"
echo ""
read -p "선택 (1 또는 2): " CHAT_TYPE

echo ""
if [ "$CHAT_TYPE" = "1" ]; then
    echo "📝 개인 채팅 설정:"
    echo "   1. @$BOT_USERNAME 봇에게 메시지 보내기 (예: /start)"
    echo "   2. 아무 메시지나 입력하기"
elif [ "$CHAT_TYPE" = "2" ]; then
    echo "📝 그룹 채팅 설정:"
    echo "   1. Telegram에서 새 그룹 생성"
    echo "   2. @$BOT_USERNAME 봇을 그룹에 초대"
    echo "   3. 그룹에서 아무 메시지나 입력하기"
else
    echo "❌ 잘못된 선택입니다."
    exit 1
fi

echo ""
read -p "봇에게 메시지를 보냈습니까? (y/n): " SENT_MESSAGE

if [ "$SENT_MESSAGE" != "y" ] && [ "$SENT_MESSAGE" != "Y" ]; then
    echo "먼저 봇에게 메시지를 보낸 후 다시 실행해주세요."
    exit 1
fi

echo ""
echo "🔍 Chat ID 조회 중..."

UPDATES=$(curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates")

# Check if there are any updates
if echo "$UPDATES" | grep -q '"result":\[\]'; then
    echo "❌ 메시지를 찾을 수 없습니다."
    echo "   봇에게 메시지를 보냈는지 확인해주세요."
    exit 1
fi

# Extract Chat ID
CHAT_ID=$(echo "$UPDATES" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if data['result']:
        chat_id = data['result'][-1]['message']['chat']['id']
        print(chat_id)
    else:
        print('ERROR')
except:
    print('ERROR')
")

if [ "$CHAT_ID" = "ERROR" ] || [ -z "$CHAT_ID" ]; then
    echo "❌ Chat ID를 찾을 수 없습니다."
    echo ""
    echo "수동으로 확인하려면 다음 URL을 브라우저에서 열어보세요:"
    echo "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates"
    exit 1
fi

echo "✅ Chat ID 확인 완료: $CHAT_ID"
echo ""

# Step 4: Test message
echo "📨 Step 4: 테스트 메시지 발송"
read -p "테스트 메시지를 보내시겠습니까? (y/n): " SEND_TEST

if [ "$SEND_TEST" = "y" ] || [ "$SEND_TEST" = "Y" ]; then
    TEST_MSG="🎉 <b>BEGA L2 알림 테스트</b>

Bot Token: ✅
Chat ID: ✅

설정이 완료되었습니다!
이제 BEGA L2 모니터링 알림을 받을 수 있습니다."

    RESULT=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d "chat_id=${CHAT_ID}" \
        -d "text=${TEST_MSG}" \
        -d "parse_mode=HTML")

    if echo "$RESULT" | grep -q '"ok":true'; then
        echo "✅ 테스트 메시지 전송 완료!"
        echo "   Telegram을 확인해보세요."
    else
        echo "⚠️ 테스트 메시지 전송 실패"
        echo "$RESULT"
    fi
fi

echo ""
echo "========================================="
echo "  설정 완료!"
echo "========================================="
echo ""
echo "다음 정보를 monitoring/alertmanager.yml에 입력하세요:"
echo ""
echo "  bot_token: '$BOT_TOKEN'"
echo "  chat_id: $CHAT_ID"
echo ""
echo "또는 .env 파일에 추가:"
echo ""
echo "  TELEGRAM_BOT_TOKEN=$BOT_TOKEN"
echo "  TELEGRAM_CHAT_ID=$CHAT_ID"
echo ""
echo "자세한 설정 방법은 monitoring/TELEGRAM_SETUP.md를 참고하세요."
echo ""
