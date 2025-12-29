# BEGA L2 알림 설정 가이드

## Slack 알림 설정

### 1. Slack Incoming Webhook 생성

1. Slack 워크스페이스에서 https://api.slack.com/apps 접속
2. "Create New App" 클릭
3. "From scratch" 선택
4. App 이름 입력 (예: "BEGA L2 Alerts")
5. 워크스페이스 선택
6. "Incoming Webhooks" 클릭
7. "Activate Incoming Webhooks" ON으로 변경
8. "Add New Webhook to Workspace" 클릭
9. 알림을 받을 채널 선택 (예: #bega-l2-alerts)
10. Webhook URL 복사 (예: https://hooks.slack.com/services/T00000000/B00000000/XXXXXXXXXXXXXXXXXXXX)

### 2. Alertmanager 설정 파일 수정

[monitoring/alertmanager.yml](alertmanager.yml) 파일을 열고 다음과 같이 수정:

```yaml
receivers:
  - name: 'critical-alerts'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'  # 여기에 Webhook URL 입력
        channel: '#bega-l2-alerts'
        title: 'CRITICAL: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
        color: 'danger'

  - name: 'warning-alerts'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'  # 여기에 Webhook URL 입력
        channel: '#bega-l2-warnings'
        title: 'WARNING: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'
        color: 'warning'
```

### 3. Alertmanager 재시작

```bash
docker compose restart alertmanager
```

### 4. 알림 테스트

#### 방법 1: 서비스 중단 시뮬레이션
```bash
# Batcher를 잠시 중단하여 알림 테스트
docker compose stop l2-batcher

# 1분 후 BatcherDown 알림이 발생해야 함

# 서비스 재시작
docker compose start l2-batcher
```

#### 방법 2: Alertmanager API로 직접 테스트
```bash
curl -H "Content-Type: application/json" -d '[{
  "labels": {
    "alertname": "TestAlert",
    "severity": "critical",
    "component": "test"
  },
  "annotations": {
    "summary": "Test Alert",
    "description": "This is a test alert from BEGA L2 monitoring"
  }
}]' http://localhost:9093/api/v1/alerts
```

---

## Discord 알림 설정

### 1. Discord Webhook 생성

1. Discord 서버 설정 > 연동 > 웹후크
2. "새 웹후크" 클릭
3. 웹후크 이름 설정 (예: "BEGA L2 Alerts")
4. 채널 선택
5. "웹후크 URL 복사" 클릭

### 2. Alertmanager 설정 파일 수정

Discord는 Slack과 다른 포맷을 사용하므로 `webhook_configs` 사용:

```yaml
receivers:
  - name: 'critical-alerts'
    webhook_configs:
      - url: 'https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN/slack'
        send_resolved: true

  - name: 'warning-alerts'
    webhook_configs:
      - url: 'https://discord.com/api/webhooks/YOUR_WEBHOOK_ID/YOUR_WEBHOOK_TOKEN/slack'
        send_resolved: true
```

> **주의**: Discord webhook URL 끝에 `/slack`을 추가하면 Slack 포맷 호환 모드로 동작합니다.

### 3. Alertmanager 재시작

```bash
docker compose restart alertmanager
```

---

## 이메일 알림 설정

### SMTP 설정

```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'bega-l2-alerts@example.com'
  smtp_auth_username: 'your-email@gmail.com'
  smtp_auth_password: 'your-app-password'
  smtp_require_tls: true

receivers:
  - name: 'critical-alerts'
    email_configs:
      - to: 'admin@example.com'
        headers:
          Subject: '[CRITICAL] BEGA L2 Alert: {{ .GroupLabels.alertname }}'
        html: |
          <h2>BEGA L2 Critical Alert</h2>
          <p><strong>Alert:</strong> {{ .GroupLabels.alertname }}</p>
          {{ range .Alerts }}
          <p>{{ .Annotations.description }}</p>
          {{ end }}
```

---

## 알림 규칙 확인

### Prometheus에서 활성 알림 확인

```bash
# 현재 발생 중인 알림 조회
curl http://localhost:9090/api/v1/alerts | python3 -m json.tool

# 알림 규칙 상태 확인
curl http://localhost:9090/api/v1/rules | python3 -m json.tool
```

### Alertmanager에서 알림 상태 확인

```bash
# 활성 알림 조회
curl http://localhost:9093/api/v1/alerts | python3 -m json.tool

# Alertmanager 설정 확인
curl http://localhost:9093/api/v1/status | python3 -m json.tool
```

### Grafana에서 알림 확인

1. http://localhost:3001 접속
2. 왼쪽 메뉴 > Alerting 클릭
3. Alert rules 확인

---

## 알림 음소거 (Silencing)

특정 기간 동안 알림을 음소거하려면:

### Alertmanager UI 사용
1. http://localhost:9093 접속
2. "Silences" 탭 클릭
3. "New Silence" 클릭
4. Matcher 설정 (예: `alertname="BatcherLowETH"`)
5. 시작 시간과 종료 시간 설정
6. Comment 입력
7. "Create" 클릭

### CLI로 음소거 생성
```bash
amtool silence add alertname="BatcherLowETH" \
  --duration=2h \
  --comment="Planned maintenance" \
  --alertmanager.url=http://localhost:9093
```

---

## 자주 발생하는 문제

### Slack 알림이 오지 않음
1. Webhook URL이 올바른지 확인
2. Alertmanager 로그 확인: `docker compose logs alertmanager`
3. Slack App이 채널에 추가되었는지 확인
4. Alertmanager 설정 파일 문법 오류 확인

### Discord 알림이 오지 않음
1. Webhook URL 끝에 `/slack` 추가 확인
2. Discord 서버 설정에서 웹후크가 활성화되었는지 확인

### 알림이 너무 많이 발생함
1. `repeat_interval` 값 증가 (기본 12시간)
2. `group_interval` 조정하여 알림 그룹화
3. Alert 규칙의 `for` 기간 증가

### 알림이 발생하지 않음
1. Prometheus에서 메트릭이 수집되고 있는지 확인
2. Alert 규칙이 로드되었는지 확인: http://localhost:9090/alerts
3. Alertmanager가 Prometheus와 연결되어 있는지 확인

---

## 알림 템플릿 커스터마이징

더 상세한 알림을 위한 템플릿 예시:

```yaml
receivers:
  - name: 'critical-alerts'
    slack_configs:
      - api_url: 'YOUR_WEBHOOK_URL'
        channel: '#bega-l2-alerts'
        title: ':fire: CRITICAL ALERT: {{ .GroupLabels.alertname }}'
        text: |
          *Component:* {{ .GroupLabels.component }}
          *Severity:* {{ .CommonLabels.severity }}

          {{ range .Alerts }}
          *Summary:* {{ .Annotations.summary }}
          *Description:* {{ .Annotations.description }}
          *Time:* {{ .StartsAt.Format "2006-01-02 15:04:05" }}
          {{ end }}

          <http://localhost:3001|Open Grafana> | <http://localhost:9093|View in Alertmanager>
        color: 'danger'
        send_resolved: true
```

---

## 다음 단계

1. 실제 운영 환경에서는 Slack/Discord 웹훅을 환경 변수로 관리하세요
2. 중요도에 따라 알림 채널을 분리하세요 (critical, warning, info)
3. On-call 로테이션을 위해 PagerDuty 또는 Opsgenie 통합을 고려하세요
4. 알림 규칙을 정기적으로 검토하고 튜닝하세요
