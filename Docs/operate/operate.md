# 운영 관리

운영 환경에서 **L2 체인의 건강 상태, 시퀀서의 잔고(ETH), Celestia DA 전송 상태**를 한눈에 파악하기 위해 Prometheus와 Grafana를 기존 Docker Compose에 통합하는 구성입니다.

OP Stack의 컴포넌트(`op-node`, `op-batcher` 등)는 이미 메트릭 서버를 내장하고 있으므로, 이를 활성화하고 수집하기만 하면 됩니다.

---

### 📂 업데이트된 디렉토리 구조

모니터링 설정 파일을 관리하기 위해 `monitoring` 폴더를 추가합니다.

Plaintext

# 

`/my-l2-chain
├── docker-compose.yml       # (수정 예정)
├── monitoring/
│   ├── prometheus.yml       # (Prometheus 수집 설정)
│   └── grafana/
│       └── provision/
│           └── datasources/
│               └── datasource.yml  # (Grafana-Prometheus 자동연동)
└── ... (기존 파일들)`

---

### 1. Prometheus 설정 파일 (`monitoring/prometheus.yml`)

OP Stack의 각 서비스(`l2-geth`, `l2-node`, `l2-batcher`, `l2-proposer`)에서 메트릭을 긁어오도록 정의합니다. Docker Service Name을 호스트 주소로 사용합니다.

YAML

# 

`global:
  scrape_interval: 15s # 15초마다 수집

scrape_configs:
  - job_name: 'op-geth'
    static_configs:
      - targets: ['l2-geth:6060']
    metrics_path: /debug/metrics/prometheus

  - job_name: 'op-node'
    static_configs:
      - targets: ['l2-node:7300']

  - job_name: 'op-batcher'
    static_configs:
      - targets: ['l2-batcher:7301']

  - job_name: 'op-proposer'
    static_configs:
      - targets: ['l2-proposer:7302']`

---

### 2. Grafana 프로비저닝 설정 (`monitoring/grafana/provision/datasources/datasource.yml`)

Grafana 로그인 후 매번 Prometheus를 수동으로 등록할 필요 없이, 시작 시 자동으로 연결해주는 설정입니다.

YAML

# 

`apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true`

---

### 3. `docker-compose.yml` 수정 및 추가

기존 파일에 두 가지 작업을 해야 합니다.

1. **OP Stack 서비스들:** 메트릭 활성화 플래그(`-metrics.enabled` 등) 추가.
2. **모니터링 서비스:** Prometheus와 Grafana 컨테이너 추가.

아래는 **수정된 전체 `docker-compose.yml`**의 핵심 부분입니다.

YAML

# 

`version: '3.8'

services:
  # ... (l2-geth-init 은 기존과 동일)

  l2-geth:
    # ... (기존 설정)
    command: >
      --datadir=/db
      --http --http.addr=0.0.0.0 --http.port=8545 --http.corsdomain="*" --http.vhosts="*" --http.api=web3,debug,eth,txpool,net,engine
      --ws --ws.addr=0.0.0.0 --ws.port=8546 --ws.api=debug,eth,txpool,net,engine
      --authrpc.addr=0.0.0.0 --authrpc.port=8551 --authrpc.vhosts="*" --authrpc.jwtsecret=/secrets/jwt.txt
      --syncmode=full --gcmode=archive --nodiscover --maxpeers=0
      --rollup.sequencerhttp=http://localhost:8545
      --rollup.disabletxpoolgossip=true
      --metrics --metrics.addr=0.0.0.0 --metrics.port=6060 # [추가됨] 메트릭 활성화

  l2-node:
    # ... (기존 설정)
    command: >
      op-node
      --l1=$L1_RPC_URL
      --l1.rpckind=alchemy
      --l2=http://l2-geth:8551
      --l2.jwt-secret=/secrets/jwt.txt
      --rollup.config=/config/rollup.json
      --rpc.addr=0.0.0.0 --rpc.port=8547
      --p2p.sequencer.key=/secrets/sequencer.key
      --sequencer.enabled
      --sequencer.l1-confs=3
      --metrics.enabled --metrics.addr=0.0.0.0 --metrics.port=7300 # [추가됨]

  l2-batcher:
    # ... (기존 설정)
    command: >
      op-batcher
      --l1-eth-rpc=${L1_RPC_URL}
      --rollup-rpc=http://l2-node:8547
      --poll-interval=1s
      --sub-safety-margin=6
      --num-confirmations=1
      --safe-abort-nonce-too-low-count=3
      --resubmission-timeout=30s
      --private-key=/secrets/batcher.key
      --altda.enabled=true
      --altda.da-service=true
      --altda.da-server=${DA_SERVER_URL}
      --metrics.enabled --metrics.addr=0.0.0.0 --metrics.port=7301 # [추가됨]

  l2-proposer:
    # ... (기존 설정)
    command: >
      op-proposer
      --poll-interval=12s
      --rpc.port=8560
      --rollup-rpc=http://l2-node:8547
      --l2oo-address=${L2OO_ADDRESS}
      --private-key=/secrets/proposer.key
      --l1-eth-rpc=${L1_RPC_URL}
      --metrics.enabled --metrics.addr=0.0.0.0 --metrics.port=7302 # [추가됨]

  # ---------------- [모니터링 섹션 추가] ----------------

  prometheus:
    image: prom/prometheus:latest
    restart: unless-stopped
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'

  grafana:
    image: grafana/grafana:latest
    restart: unless-stopped
    depends_on:
      - prometheus
    ports:
      - "3000:3000"
    volumes:
      - ./monitoring/grafana/provision:/etc/grafana/provisioning
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin # 운영 시 변경 필수`

---

### 4. 대시보드 설정 및 핵심 모니터링 지표

모든 컨테이너를 재시작(`docker compose up -d`)한 후, 브라우저에서 `http://localhost:3000`으로 접속합니다 (ID/PW: admin/admin).

OP Stack은 커뮤니티에서 잘 만들어진 대시보드 JSON 파일들이 있습니다. 이를 Import 하면 바로 화려한 차트를 볼 수 있습니다.

### 1) 대시보드 Import 방법

1. Grafana 접속 -> Left Menu -> **Dashboards** -> **New** -> **Import**.
2. Optimism 공식 레포지토리의 [op-node/metrics/doc/grafana](https://www.google.com/search?q=https://github.com/ethereum-optimism/optimism/tree/develop/op-node/metrics/doc/grafana) 등의 JSON 내용을 복사해 붙여넣습니다. (또는 ID 입력)

### 2) 반드시 확인해야 할 3가지 핵심 지표 (자체 토큰 + Celestia 환경)

1. **Batcher Balance (ETH):**
    - **중요도: ⭐⭐⭐⭐⭐**
    - **이유:** 사용자는 자체 토큰으로 수수료를 내지만, Batcher는 L1에 ETH를 냅니다. 이 잔고가 떨어지면 L2가 멈춥니다.
    - **Query:** `batcher_balance_eth` (메트릭 이름은 버전에 따라 다를 수 있음, 보통 `go_wallet_balance` 등의 형태)
2. **L1 Data Submission Failures:**
    - **중요도: ⭐⭐⭐⭐**
    - **이유:** Celestia DA 노드와의 통신 실패나 L1 트랜잭션 실패를 감지해야 합니다.
    - **Query:** `op_batcher_batch_submitter_batch_submission_failures_total`
3. **L2 Reorg Depth:**
    - **중요도: ⭐⭐⭐**
    - **이유:** P2P 네트워크 불안정이나 시퀀서 문제로 체인이 재구성(Reorg)되는지 확인합니다.
    - **Query:** `op_node_p2p_reorgs_total`

---

