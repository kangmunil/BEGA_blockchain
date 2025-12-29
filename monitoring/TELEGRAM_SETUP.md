# Telegram 봇 알림 설정 가이드

BEGA L2 모니터링 알림을 Telegram으로 받기 위한 설정 가이드입니다.

## 1단계: Telegram Bot 생성

### BotFather로 봇 생성하기

1. Telegram 앱에서 **@BotFather** 검색 및 시작
2. `/newbot` 명령어 입력
3. 봇 이름 입력 (예: `BEGA L2 Alert Bot`)
4. 봇 사용자명 입력 (예: `bega_l2_alert_bot`)
   - 반드시 `bot`으로 끝나야 함
5. Bot Token 복사 및 저장
   ```
   예시: 123456789:ABCdefGHIjklMNOpqrsTUVwxyz123456789
   ```

### 봇 설정 커스터마이징 (선택사항)

```
/setdescription - 봇 설명 추가
/setabouttext - About 텍스트 추가
/setuserpic - 프로필 사진 설정
```

## 2단계: Chat ID 확인

### 방법 1: 개인 채팅으로 받기

1. 생성한 봇과 대화 시작 (`/start` 입력)
2. 아무 메시지나 입력 (예: "hello")
3. 브라우저에서 다음 URL 접속:
   ```
   https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
   ```
4. `chat` 객체에서 `id` 값 확인
   ```json
   {
     "chat": {
       "id": 123456789,  // 👈 이 값을 사용
       "first_name": "Your Name",
       "type": "private"
     }
   }
   ```

### 방법 2: 그룹 채팅으로 받기

1. Telegram에서 새 그룹 생성 (예: "BEGA L2 Alerts")
2. 생성한 봇을 그룹에 초대
3. 그룹에서 아무 메시지나 입력
4. 브라우저에서 다음 URL 접속:
   ```
   https://api.telegram.org/bot<YOUR_BOT_TOKEN>/getUpdates
   ```
5. `chat` 객체에서 `id` 값 확인 (음수로 시작)
   ```json
   {
     "chat": {
       "id": -100123456789,  // 👈 그룹의 Chat ID (음수)
       "title": "BEGA L2 Alerts",
       "type": "group"
     }
   }
   ```

### 방법 3: CLI로 확인 (편리)

```bash
# Bot Token 변수 설정
export BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz123456789"

# 봇에게 메시지 보낸 후 실행
curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getUpdates" | \
  python3 -c "import sys, json; updates = json.load(sys.stdin)['result']; \
  print('Chat ID:', updates[-1]['message']['chat']['id']) if updates else print('No messages found')"
```

## 3단계: Alertmanager 설정

### alertmanager.yml 수정

[monitoring/alertmanager.yml](alertmanager.yml) 파일을 다음과 같이 수정:

```yaml
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: 'telegram-alerts'  # 기본 수신자를 telegram으로 변경
  routes:
    - match:
        severity: critical
      receiver: 'telegram-critical'
      continue: true

    - match:
        severity: warning
      receiver: 'telegram-warning'
      continue: true

receivers:
  - name: 'telegram-alerts'
    telegram_configs:
      - bot_token: '123456789:ABCdefGHIjklMNOpqrsTUVwxyz123456789'  # 👈 여기에 Bot Token 입력
        chat_id: 123456789  # 👈 여기에 Chat ID 입력 (개인) 또는 -100123456789 (그룹)
        send_resolved: true
        parse_mode: 'HTML'
        message: |
          <b>{{ .GroupLabels.alertname }}</b>

          {{ range .Alerts }}
          <b>상태:</b> {{ .Status }}
          <b>심각도:</b> {{ .Labels.severity }}
          <b>컴포넌트:</b> {{ .Labels.component }}

          <b>요약:</b> {{ .Annotations.summary }}
          <b>설명:</b> {{ .Annotations.description }}

          <b>시작 시간:</b> {{ .StartsAt.Format "2006-01-02 15:04:05" }}
          {{ end }}

  - name: 'telegram-critical'
    telegram_configs:
      - bot_token: '123456789:ABCdefGHIjklMNOpqrsTUVwxyz123456789'
        chat_id: 123456789
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

  - name: 'telegram-warning'
    telegram_configs:
      - bot_token: '123456789:ABCdefGHIjklMNOpqrsTUVwxyz123456789'
        chat_id: 123456789
        send_resolved: true
        parse_mode: 'HTML'
        message: |
          ⚠️ <b>WARNING</b>

          <b>{{ .GroupLabels.alertname }}</b>

          {{ range .Alerts }}
          <b>설명:</b> {{ .Annotations.description }}
          {{ end }}

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'cluster', 'service']
```

### 환경 변수로 관리 (보안 강화)

민감한 정보를 파일에 직접 넣지 않으려면 환경 변수 사용:

**1. .env 파일에 추가:**
```bash
TELEGRAM_BOT_TOKEN=123456789:ABCdefGHIjklMNOpqrsTUVwxyz123456789
TELEGRAM_CHAT_ID=123456789
```

**2. alertmanager 설정을 템플릿으로 변경:**
```yaml
receivers:
  - name: 'telegram-alerts'
    telegram_configs:
      - bot_token: '${TELEGRAM_BOT_TOKEN}'
        chat_id: ${TELEGRAM_CHAT_ID}
```

**3. docker-compose.yml에서 환경 변수 전달:**
```yaml
alertmanager:
  image: prom/alertmanager:latest
  environment:
    - TELEGRAM_BOT_TOKEN=${TELEGRAM_BOT_TOKEN}
    - TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}
  volumes:
    - ./monitoring/alertmanager.yml:/etc/alertmanager/alertmanager.yml
```

## 4단계: 적용 및 테스트

### 설정 적용

```bash
# Alertmanager 재시작
docker compose restart alertmanager

# 로그 확인
docker compose logs -f alertmanager
```

### 설정 확인

```bash
# Alertmanager 상태 확인
curl http://localhost:9093/api/v1/status | python3 -m json.tool

# 설정 문법 검사 (로컬에 amtool 설치된 경우)
amtool check-config monitoring/alertmanager.yml
```

### 테스트 알림 발송

#### 방법 1: 테스트 알림 직접 발송

```bash
curl -H "Content-Type: application/json" -d '[{
  "labels": {
    "alertname": "TestAlert",
    "severity": "warning",
    "component": "test"
  },
  "annotations": {
    "summary": "테스트 알림입니다",
    "description": "BEGA L2 Telegram 알림 테스트"
  }
}]' http://localhost:9093/api/v1/alerts
```

텔레그램으로 테스트 메시지가 도착하면 성공!

#### 방법 2: 서비스 중단으로 실제 알림 테스트

```bash
# Batcher 중단 (1분 후 BatcherDown 알림 발생)
docker compose stop l2-batcher

# 텔레그램 알림 확인 후 재시작
docker compose start l2-batcher
```

## 메시지 포맷 커스터마이징

### HTML 포맷 사용 (추천)

```yaml
parse_mode: 'HTML'
message: |
  <b>굵게</b>
  <i>기울임</i>
  <code>코드</code>
  <pre>코드 블록</pre>
  <a href="http://example.com">링크</a>
```

### Markdown 포맷 사용

```yaml
parse_mode: 'Markdown'
message: |
  *굵게*
  _기울임_
  `코드`
  [링크](http://example.com)
```

### 이모지 활용

```yaml
message: |
  🚨 Critical Alert
  ⚠️ Warning
  ✅ Resolved
  📊 Status: {{ .Status }}
  🔥 Severity: {{ .Labels.severity }}
  ⏰ Time: {{ .StartsAt.Format "15:04:05" }}
```

## 고급 설정

### 여러 채팅으로 분리

Critical은 개인 DM, Warning은 그룹으로:

```yaml
receivers:
  - name: 'telegram-critical'
    telegram_configs:
      - bot_token: 'YOUR_BOT_TOKEN'
        chat_id: 123456789  # 개인 Chat ID
        message: '🚨 CRITICAL: {{ .GroupLabels.alertname }}'

  - name: 'telegram-warning'
    telegram_configs:
      - bot_token: 'YOUR_BOT_TOKEN'
        chat_id: -100123456789  # 그룹 Chat ID
        message: '⚠️ WARNING: {{ .GroupLabels.alertname }}'
```

### 알림 음소거 (Silence)

```bash
# 1시간 동안 LowPeerCount 알림 음소거
amtool silence add alertname="LowPeerCount" \
  --duration=1h \
  --comment="정상 - 시퀀서 모드" \
  --alertmanager.url=http://localhost:9093
```

## 트러블슈팅

### 알림이 오지 않음

1. **Bot Token 확인**
   ```bash
   curl "https://api.telegram.org/bot<YOUR_TOKEN>/getMe"
   ```

2. **Chat ID 확인**
   ```bash
   curl "https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates"
   ```

3. **Alertmanager 로그 확인**
   ```bash
   docker compose logs alertmanager | grep -i telegram
   ```

4. **봇이 차단되지 않았는지 확인**
   - 봇과의 대화창에서 "Unblock" 버튼 클릭
   - 그룹의 경우 봇이 추방되지 않았는지 확인

### "Chat not found" 에러

- Chat ID가 잘못되었거나
- 봇이 그룹에서 제거됨
- `/start` 명령으로 봇과 대화 시작 필요

### "Unauthorized" 에러

- Bot Token이 잘못됨
- BotFather에서 새 토큰 발급 (`/token`)

## 참고 자료

- [Telegram Bot API](https://core.telegram.org/bots/api)
- [Alertmanager Configuration](https://prometheus.io/docs/alerting/latest/configuration/)
- [Prometheus Telegram Integration](https://prometheus.io/docs/alerting/latest/configuration/#telegram_config)
