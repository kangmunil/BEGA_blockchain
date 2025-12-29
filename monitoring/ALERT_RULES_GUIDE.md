# BEGA L2 알림 규칙 가이드

운영 환경에 최적화된 알림 규칙 설명 및 조정 가이드

## 📊 알림 규칙 개요

총 **13개의 알림 규칙**이 3가지 심각도로 분류됩니다:

| 심각도 | 개수 | 설명 |
|--------|------|------|
| **Critical** | 6개 | 즉시 조치 필요 - 서비스 중단 또는 임박 |
| **Warning** | 5개 | 주의 필요 - 성능 저하 또는 리소스 부족 |
| **Info** | 2개 | 정보성 - 활동 모니터링 |

## 🚨 Critical 알림 (6개)

### 1. BatcherLowETH
```yaml
Threshold: < 0.05 ETH
Duration: 5분
```
**설명**: Batcher 지갑의 ETH 잔고가 매우 낮음
**영향**: ETH가 바닥나면 L1에 배치를 제출할 수 없어 L2 중단
**조치**:
1. Batcher 지갑 주소 확인: `cast wallet address --private-key $BATCHER_PRIVATE_KEY`
2. Sepolia ETH 전송 (faucet 또는 브릿지 사용)
3. 충전 권장량: 0.1 ETH 이상

**Threshold 조정**:
```yaml
# 더 안전한 마진 (0.1 ETH)
expr: op_batcher_default_balance < 0.1

# 메인넷 운영 시 (0.5 ETH)
expr: op_batcher_default_balance < 0.5
```

### 2. BatcherVeryLowETH (Warning으로 분류되지만 중요)
```yaml
Threshold: < 0.1 ETH
Duration: 10분
```
**설명**: Batcher ETH 잔고 경고 (Critical 전 단계)
**조치**: ETH 충전 준비

### 3. L2GethDown
```yaml
Threshold: up == 0
Duration: 1분
```
**설명**: L2 Geth 실행 레이어 다운
**영향**: 사용자가 트랜잭션을 제출할 수 없음
**조치**:
```bash
# 서비스 상태 확인
docker compose ps l2-geth
docker compose logs l2-geth --tail 100

# 재시작
docker compose restart l2-geth
```

### 4. L2NodeDown
```yaml
Threshold: up == 0
Duration: 1분
```
**설명**: L2 Rollup 노드 다운
**영향**: 새로운 블록 생성 불가
**조치**:
```bash
docker compose restart l2-node
```

### 5. BatcherDown
```yaml
Threshold: up == 0
Duration: 1분
```
**설명**: Batcher 서비스 다운
**영향**: L2 트랜잭션이 L1에 게시되지 않음
**조치**:
```bash
docker compose restart l2-batcher
```

### 6. BatcherTxStuck
```yaml
Threshold: pending_txs > 0
Duration: 10분
```
**설명**: Batcher 트랜잭션이 10분 이상 pending 상태
**원인**: L1 가스비 급등, nonce 문제, 네트워크 혼잡
**조치**:
1. L1 가스비 확인: https://etherscan.io/gastracker
2. Batcher 로그 확인: `docker compose logs l2-batcher`
3. 필요시 가스비 설정 조정

## ⚠️ Warning 알림 (5개)

### 1. HighL1GasPrice
```yaml
Threshold: > 20 gwei (Sepolia)
Duration: 10분
```
**설명**: L1 가스비 높음
**영향**: 배치 제출 비용 증가
**조치**: 모니터링, 필요시 배치 제출 빈도 조정

**Threshold 조정**:
```yaml
# Sepolia 테스트넷 (현재)
expr: op_batcher_default_txmgr_basefee_wei / 1e9 > 20

# Ethereum 메인넷
expr: op_batcher_default_txmgr_basefee_wei / 1e9 > 50

# 매우 높은 가스비만 알림
expr: op_batcher_default_txmgr_basefee_wei / 1e9 > 100
```

### 2. L2BlockProductionSlow
```yaml
Threshold: < 0.3 blocks/sec
Duration: 5분
```
**설명**: L2 블록 생성 속도 저하
**정상값**: ~0.5 blocks/sec (2초마다 1블록)
**조치**: Sequencer 로그 확인

**Threshold 조정**:
```yaml
# 더 엄격한 기준
expr: rate(eth_block_number{job="l2-geth"}[5m]) < 0.4

# 더 느슨한 기준
expr: rate(eth_block_number{job="l2-geth"}[5m]) < 0.2
```

### 3. HighMemoryUsage
```yaml
Threshold: > 8 GB
Duration: 15분
```
**설명**: 프로세스 메모리 사용량 높음
**조치**:
- 메모리 사용량 모니터링
- 필요시 서버 리소스 증설
- Archive 노드의 경우 정상일 수 있음

**Threshold 조정**:
```yaml
# 16GB 서버
expr: process_resident_memory_bytes{job=~"l2-geth|l2-node|l2-batcher"} > 12e9

# 32GB 서버
expr: process_resident_memory_bytes{job=~"l2-geth|l2-node|l2-batcher"} > 24e9
```

### 4. BatcherChannelQueueHigh
```yaml
Threshold: > 10 channels
Duration: 5분
```
**설명**: Batcher 채널 큐에 데이터 누적
**원인**: 배치 제출 속도 < 트랜잭션 생성 속도
**조치**:
- L1 가스비 확인
- Batcher 설정 조정

### 5. HighCPUUsage
```yaml
Threshold: > 80%
Duration: 10분
```
**설명**: 프로세스 CPU 사용률 높음
**조치**: 리소스 모니터링, 필요시 서버 증설

## ℹ️ Info 알림 (2개)

### 1. NoRecentBatchSubmission
```yaml
Threshold: 30분간 배치 제출 없음
Duration: 5분
```
**설명**: 최근 배치 제출 활동 없음
**원인**:
- 트랜잭션 활동 없음 (정상)
- Batcher 문제 (비정상)

### 2. LowTransactionActivity
```yaml
Threshold: pending_txs == 0
Duration: 1시간
```
**설명**: 트랜잭션 활동 매우 낮음
**조치**: 네트워크 활동 모니터링

## 🔧 제거된 알림

### LowPeerCount (제거됨)
**이유**: BEGA L2는 시퀀서 모드로 운영되며 P2P 피어가 필요 없음
**향후**: 검증자 노드 추가 시 재활성화

## 📝 알림 규칙 커스터마이징

### 실제 메트릭 확인
```bash
# 사용 가능한 모든 메트릭 조회
curl http://localhost:9090/api/v1/label/__name__/values | python3 -m json.tool

# Batcher 관련 메트릭만 조회
curl http://localhost:9090/api/v1/label/__name__/values | \
  python3 -c "import sys, json; [print(m) for m in json.load(sys.stdin)['data'] if 'batcher' in m.lower()]"

# 특정 메트릭 값 조회
curl 'http://localhost:9090/api/v1/query?query=op_batcher_default_balance'
```

### 새로운 알림 추가

```yaml
# monitoring/alert_rules.yml에 추가

groups:
  - name: bega_l2_custom
    rules:
      - alert: CustomAlert
        expr: your_metric > threshold
        for: duration
        labels:
          severity: warning
          component: component-name
        annotations:
          summary: "Alert summary"
          description: "Detailed description with {{ $value }}"
```

### 알림 규칙 테스트

```bash
# 규칙 문법 검사
promtool check rules monitoring/alert_rules.yml

# Prometheus 재시작
docker compose restart prometheus

# 규칙 로드 확인
curl http://localhost:9090/api/v1/rules | python3 -m json.tool

# 현재 알림 상태 확인
curl http://localhost:9090/api/v1/alerts | python3 -m json.tool
```

## 🎯 환경별 권장 Threshold

### Sepolia Testnet (현재 설정)
```yaml
BatcherLowETH: < 0.05 ETH
HighL1GasPrice: > 20 gwei
```

### Ethereum Mainnet
```yaml
BatcherLowETH: < 0.5 ETH
HighL1GasPrice: > 50 gwei
HighMemoryUsage: > 12e9  # 12GB
```

### 고가용성 환경
```yaml
BatcherLowETH: < 1.0 ETH  # 더 높은 안전 마진
L2GethDown: for 30s  # 더 빠른 감지
HighL1GasPrice: > 100 gwei  # 정말 높을 때만 알림
```

## 📊 알림 통계 확인

```bash
# 최근 24시간 알림 발생 횟수
curl 'http://localhost:9090/api/v1/query?query=ALERTS' | python3 -m json.tool

# Alertmanager에서 확인
curl http://localhost:9093/api/v1/alerts | python3 -m json.tool
```

## 🔄 알림 규칙 업데이트 절차

1. **백업 생성**
   ```bash
   cp monitoring/alert_rules.yml monitoring/alert_rules.yml.backup
   ```

2. **규칙 수정**
   ```bash
   nano monitoring/alert_rules.yml
   ```

3. **문법 검사** (선택사항, promtool 설치 필요)
   ```bash
   promtool check rules monitoring/alert_rules.yml
   ```

4. **Prometheus 재시작**
   ```bash
   docker compose restart prometheus
   ```

5. **로드 확인**
   ```bash
   curl http://localhost:9090/api/v1/rules | python3 -m json.tool
   ```

## 💡 운영 팁

1. **알림 피로도 방지**
   - `for` 기간을 적절히 설정하여 일시적 이슈로 인한 오탐 방지
   - `repeat_interval`을 12시간 이상으로 설정 (alertmanager.yml)

2. **우선순위 기반 대응**
   - Critical: 즉시 대응 필요
   - Warning: 모니터링 및 계획된 조치
   - Info: 트렌드 분석용

3. **정기적인 검토**
   - 월 1회 알림 발생 통계 검토
   - False positive 발생 시 threshold 조정
   - 새로운 메트릭 발견 시 알림 추가
