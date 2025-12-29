# Telegram 알림 빠른 시작 가이드

BEGA L2 모니터링 알림을 Telegram으로 5분 안에 설정하기

## 🚀 빠른 설정 (3단계)

### 1단계: 자동 설정 스크립트 실행

```bash
cd /Users/kangmunil/Project/BEGA
./monitoring/scripts/telegram-setup.sh
```

스크립트가 다음을 자동으로 수행합니다:
- Bot Token 유효성 확인
- Chat ID 자동 조회
- 테스트 메시지 발송
- 설정 정보 출력

### 2단계: Alertmanager 설정 파일 수정

스크립트가 출력한 정보를 사용하여 [monitoring/alertmanager.yml](alertmanager.yml) 수정:

```bash
# 편집기로 열기
nano monitoring/alertmanager.yml
# 또는
code monitoring/alertmanager.yml
```

**주석 해제 및 정보 입력:**

```yaml
receivers:
  - name: 'critical-alerts'
    telegram_configs:  # 주석 제거 (#)
      - bot_token: '123456789:ABCdefGHIjklMNOpqrsTUVwxyz'  # 스크립트 출력값
        chat_id: 123456789  # 스크립트 출력값
        send_resolved: true
        parse_mode: 'HTML'
        message: |
          🚨 <b>CRITICAL ALERT</b> 🚨

          <b>{{ .GroupLabels.alertname }}</b>

          {{ range .Alerts }}
          <b>컴포넌트:</b> {{ .Labels.component }}
          <b>설명:</b> {{ .Annotations.description }}

          ⏰ {{ .StartsAt.Format "2006-01-02 15:04:05" }}
          {{ end }}

  - name: 'warning-alerts'
    telegram_configs:  # 주석 제거 (#)
      - bot_token: '123456789:ABCdefGHIjklMNOpqrsTUVwxyz'
        chat_id: 123456789
        send_resolved: true
        parse_mode: 'HTML'
        message: |
          ⚠️ <b>WARNING</b>

          <b>{{ .GroupLabels.alertname }}</b>

          {{ range .Alerts }}
          <b>설명:</b> {{ .Annotations.description }}
          {{ end }}
```

### 3단계: Alertmanager 재시작

```bash
docker compose restart alertmanager

# 로그로 정상 작동 확인
docker compose logs -f alertmanager
```

## ✅ 테스트

### 방법 1: 테스트 알림 수동 발송

```bash
curl -H "Content-Type: application/json" -d '[{
  "labels": {
    "alertname": "TestAlert",
    "severity": "critical",
    "component": "test"
  },
  "annotations": {
    "summary": "테스트 알림",
    "description": "BEGA L2 Telegram 알림이 정상적으로 작동합니다!"
  }
}]' http://localhost:9093/api/v1/alerts
```

**기대 결과**: 몇 초 내로 Telegram으로 테스트 알림 도착

### 방법 2: 실제 알림 트리거

```bash
# Batcher 서비스 중단 (1분 후 BatcherDown 알림 발생)
docker compose stop l2-batcher

# Telegram 알림 확인 후 재시작
docker compose start l2-batcher
```

## 📱 수신된 알림 예시

**Critical 알림:**
```
🚨 CRITICAL ALERT 🚨

BatcherDown

컴포넌트: l2-batcher
설명: Batcher service is down. L2 transactions will not be posted to L1.

⏰ 2025-12-29 11:30:00
```

**Warning 알림:**
```
⚠️ WARNING

LowPeerCount

설명: L2 node has only 0 peers. This may indicate network connectivity issues.
```

## 🔧 트러블슈팅

### 알림이 오지 않음

1. **Alertmanager 로그 확인**
   ```bash
   docker compose logs alertmanager | grep -i "error\|telegram"
   ```

2. **Bot이 차단되지 않았는지 확인**
   - Telegram 앱에서 봇 대화창 열기
   - "Unblock" 또는 "Start" 버튼 클릭

3. **설정 문법 확인**
   ```bash
   # YAML 들여쓰기가 올바른지 확인
   cat monitoring/alertmanager.yml
   ```

### "Unauthorized" 에러

- Bot Token이 잘못됨
- BotFather에서 토큰 재발급: `/token`

### "Chat not found" 에러

- Chat ID가 잘못됨
- 봇과 대화를 시작하지 않음 → `/start` 입력
- 그룹에서 봇이 제거됨 → 다시 초대

## 📚 더 자세한 설정

- [상세 설정 가이드](TELEGRAM_SETUP.md)
- [Alertmanager 설정 가이드](ALERT_SETUP.md)
- [대시보드 사용법](README.md)

## 💡 팁

### 여러 사람에게 알림 보내기

그룹 채팅 사용:
1. Telegram에서 그룹 생성
2. 봇을 그룹에 초대
3. Chat ID를 그룹 ID로 변경 (음수 값)

### Critical과 Warning을 다른 채팅으로 분리

```yaml
receivers:
  - name: 'critical-alerts'
    telegram_configs:
      - chat_id: 123456789  # 개인 DM

  - name: 'warning-alerts'
    telegram_configs:
      - chat_id: -100123456789  # 그룹 채팅
```

### 알림 음소거 (유지보수 중)

```bash
# Alertmanager UI에서: http://localhost:9093
# Silences 탭 → New Silence
# 또는 CLI:
curl -X POST http://localhost:9093/api/v1/silences \
  -H "Content-Type: application/json" \
  -d '{
    "matchers": [{"name":"alertname","value":"LowPeerCount"}],
    "startsAt":"2025-12-29T00:00:00Z",
    "endsAt":"2025-12-29T23:59:59Z",
    "comment":"정상 - 시퀀서 모드"
  }'
```

## 🎯 다음 단계

- [ ] 실제 운영 환경에 맞게 알림 threshold 조정
- [ ] 중요 알림에 대한 on-call 로테이션 설정
- [ ] Grafana 대시보드에서 메트릭 시각화
- [ ] 정기적인 알림 규칙 검토 및 업데이트
