시퀀서 지갑의 ETH 잔고가 바닥나 L2가 멈추는 사고를 방지하기 위해 **Prometheus Alertmanager**를 추가하여 Slack(또는 Discord, Telegram)으로 긴급 알림을 보내는 설정을 추가해 드립니다.

특히 **자체 토큰 가스비** 모델에서는 시퀀서가 ETH를 소모하기만 하므로, 이 알람은 선택이 아니라 **필수**입니다.

---

### 📂 업데이트된 파일 구조

`monitoring` 폴더 내에 Alert 관련 설정 파일 2개가 추가됩니다.

Plaintext

# 

`/my-l2-chain
├── monitoring/
│   ├── prometheus.yml       # (수정됨: 규칙 파일 및 Alertmanager 연결)
│   ├── alert_rules.yml      # (신규: 알림 조건 정의)
│   ├── alertmanager.yml     # (신규: 알림 전송 채널 정의 - Slack/Discord)
│   └── grafana/...
└── docker-compose.yml       # (수정됨: Alertmanager 컨테이너 추가)`

---

### 1. 알림 규칙 정의 (`monitoring/alert_rules.yml`)

가장 중요한 "Batcher ETH 잔고 부족" 알림 규칙을 정의합니다.

(OP Stack 버전에 따라 메트릭 이름이 조금씩 다를 수 있으나, 보통 op_batcher_...balance... 형태입니다.)

YAML

# 

`groups:
  - name: op-stack-alerts
    rules:
      # 1. Batcher ETH 잔고 경보 (0.5 ETH 미만 시)
      # 주의: 메트릭이 Wei 단위일 경우 1e18로 나누어 계산
      - alert: BatcherLowETH
        expr: op_batcher_balance_eth < 0.5 
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "🚨 Critical: Batcher ETH Low"
          description: "Batcher wallet balance is below 0.5 ETH. Refill immediately to prevent L2 halt."

      # 2. 시퀀서 동작 중지 경보 (최근 배치 제출 실패)
      - alert: BatchSubmissionFailed
        expr: rate(op_batcher_batch_submitter_batch_submission_failures_total[5m]) > 0
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "⚠️ Warning: Batch Submission Failing"
          description: "Batcher is failing to submit txs to L1/Celestia."`

---

### 2. 알림 채널 설정 (`monitoring/alertmanager.yml`)

Slack이나 Discord 웹훅(Webhook) URL을 사용하여 알림을 받습니다.

- **Slack/Discord:** Incoming Webhook URL을 발급받아 `api_url`에 넣으세요.
- **Telegram:** `telegram_configs` 섹션을 사용해야 합니다 (Bot Token, Chat ID 필요).

YAML

# 

`global:
  resolve_timeout: 5m

route:
  group_by: ['alertname']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 1h
  receiver: 'slack-notifications' # 기본 수신자

receivers:
  - name: 'slack-notifications'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/T00000/B00000/XXXXXXXX' # 👈 여기에 본인의 웹훅 URL 입력
        channel: '#l2-ops-alert'
        send_resolved: true
        title: '{{ .CommonAnnotations.summary }}'
        text: '{{ .CommonAnnotations.description }}'`

---

### 3. Prometheus 설정 수정 (`monitoring/prometheus.yml`)

Prometheus가 위에서 만든 규칙(`alert_rules.yml`)을 읽고, 조건 만족 시 `alertmanager` 컨테이너로 신호를 보내도록 설정합니다.

YAML

# 

`global:
  scrape_interval: 15s
  evaluation_interval: 15s # 규칙 검사 주기

# [추가됨] Alertmanager 연결 설정
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - 'alertmanager:9093' # Docker 서비스명

# [추가됨] 규칙 파일 로드
rule_files:
  - "alert_rules.yml"

scrape_configs:
  # ... (기존 설정 유지: op-geth, op-node 등) ...
  - job_name: 'op-batcher'
    static_configs:
      - targets: ['l2-batcher:7301']`

---

### 4. Docker Compose 수정 (`docker-compose.yml`)

`alertmanager` 서비스를 추가합니다.

YAML

# 

`version: '3.8'

services:
  # ... (기존 l2-geth, l2-node, l2-batcher 등) ...

  # ... (기존 prometheus) ...
  prometheus:
    image: prom/prometheus:latest
    restart: unless-stopped
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - ./monitoring/alert_rules.yml:/etc/prometheus/alert_rules.yml # [추가] 규칙 파일 마운트
    ports:
      - "9090:9090"
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
    depends_on:
      - alertmanager

  # [신규 추가] Alertmanager
  alertmanager:
    image: prom/alertmanager:latest
    restart: unless-stopped
    ports:
      - "9093:9093"
    volumes:
      - ./monitoring/alertmanager.yml:/etc/alertmanager/alertmanager.yml
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'

  # ... (기존 grafana) ...`

---

### 🚀 적용 및 테스트 방법

1. **설정 적용 및 재시작:**Bash
    
    # 
    
    `docker compose up -d`
    
2. **Alertmanager 상태 확인:**
    - 브라우저에서 `http://localhost:9093` 접속.
    - Status 탭에서 Config가 잘 로드되었는지 확인.
3. **Prometheus 규칙 확인:**
    - 브라우저에서 `http://localhost:9090` 접속 -> **Alerts** 메뉴 클릭.
    - `BatcherLowETH`가 초록색(Inactive) 상태면 정상입니다.
4. **테스트 (강제 알림 발생):**
    - `alert_rules.yml`에서 `expr: op_batcher_balance_eth < 1000` (현재 잔고보다 높은 값)으로 잠시 수정하고 컨테이너를 재시작해보세요.
    - 1분 뒤 Slack/Discord로 알림이 오는지 확인합니다.

### 💡 운영 팁

- **Telegram 봇 연동:** Slack 대신 텔레그램을 쓰시려면 `alertmanager.yml`에서 `slack_configs` 대신 아래와 같이 설정하세요.YAML
    
    # 
    
    `telegram_configs:
      - bot_token: '123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11'
        chat_id: -100123456789
        message: '{{ .CommonAnnotations.summary }}: {{ .CommonAnnotations.description }}'`
    

