# docker-compose.yml

앞서 작성한 쉘 스크립트들을 하나로 통합 관리할 수 있는 **`docker-compose.yml`** 및 환경 설정 파일입니다.

이 구성을 사용하면 명령어 하나(`docker compose up -d`)로 시퀀서, 노드, 배처, 프로포저를 모두 실행하고 네트워크로 연결할 수 있습니다.

---

### 📂 프로젝트 폴더 구조

도커 볼륨 마운트를 위해 파일 위치를 아래와 같이 맞춰주세요.

Plaintext

# 

`/my-l2-chain
├── docker-compose.yml       # (생성할 파일)
├── .env                     # (환경 변수 파일)
├── config/
│   ├── genesis.json         # (op-deployer로 생성됨)
│   └── rollup.json          # (op-deployer로 생성됨)
├── secrets/
│   ├── jwt.txt              # (openssl rand -hex 32 > secrets/jwt.txt)
│   ├── sequencer.key        # (Private Key 파일들)
│   ├── batcher.key
│   └── proposer.key
└── data/                    # (Geth DB 저장소 - 자동 생성됨)`

---

### 1. `.env` 파일 작성

비밀키나 RPC URL 같은 민감 정보는 `.env` 파일에 모아서 관리합니다.

Ini, TOML

# 

`# .env 파일 내용

# L1 (Sepolia) RPC URL
L1_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY

# Celestia Light Node URL (호스트 머신에서 실행 중인 경우)
# Mac/Windows Docker Desktop: http://host.docker.internal:26658
# Linux: http://172.17.0.1:26658 (또는 호스트 IP)
DA_SERVER_URL=http://host.docker.internal:26658

# L2 Output Oracle Address (배포 결과 artifacts.json에서 확인)
L2OO_ADDRESS=0x1234...

# Docker 이미지 태그 (필요시 버전 고정)
OP_GETH_TAG=latest
OP_NODE_TAG=latest
OP_BATCHER_TAG=latest
OP_PROPOSER_TAG=latest`

---

### 2. `docker-compose.yml` 작성

OP Stack의 표준 컴포넌트들을 정의합니다. **Geth 초기화(Init)** 과정을 자동화하기 위해 `l2-geth-init` 컨테이너를 추가했습니다.

YAML

# 

`version: '3.8'

services:
  # 1. Geth 초기화 (Genesis 블록 생성 - 최초 1회 실행 후 종료됨)
  l2-geth-init:
    image: us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:${OP_GETH_TAG}
    command: >
      init --datadir=/db /config/genesis.json
    volumes:
      - ./data:/db
      - ./config:/config
    user: "root" # 권한 문제 방지

  # 2. 실행 클라이언트 (Execution Client)
  l2-geth:
    image: us-docker.pkg.dev/oplabs-tools-artifacts/images/op-geth:${OP_GETH_TAG}
    restart: unless-stopped
    depends_on:
      l2-geth-init:
        condition: service_completed_successfully
    ports:
      - "8545:8545" # HTTP RPC
      - "8546:8546" # WS
    volumes:
      - ./data:/db
      - ./secrets:/secrets
    command: >
      --datadir=/db
      --http --http.addr=0.0.0.0 --http.port=8545 --http.corsdomain="*" --http.vhosts="*" --http.api=web3,debug,eth,txpool,net,engine
      --ws --ws.addr=0.0.0.0 --ws.port=8546 --ws.api=debug,eth,txpool,net,engine
      --authrpc.addr=0.0.0.0 --authrpc.port=8551 --authrpc.vhosts="*" --authrpc.jwtsecret=/secrets/jwt.txt
      --syncmode=full --gcmode=archive --nodiscover --maxpeers=0
      --rollup.sequencerhttp=http://localhost:8545
      --rollup.disabletxpoolgossip=true

  # 3. 합의 클라이언트 (Consensus Client / Node)
  l2-node:
    image: us-docker.pkg.dev/oplabs-tools-artifacts/images/op-node:${OP_NODE_TAG}
    restart: unless-stopped
    depends_on:
      - l2-geth
    ports:
      - "8547:8547" # Node RPC
      - "9003:9003" # P2P
    volumes:
      - ./config:/config
      - ./secrets:/secrets
    environment:
      - L1_RPC_URL=${L1_RPC_URL}
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

  # 4. Batcher (트랜잭션 제출 -> Celestia/L1)
  l2-batcher:
    image: us-docker.pkg.dev/oplabs-tools-artifacts/images/op-batcher:${OP_BATCHER_TAG}
    restart: unless-stopped
    depends_on:
      - l2-node
    volumes:
      - ./secrets:/secrets
    extra_hosts:
      - "host.docker.internal:host-gateway" # 호스트의 Celestia 노드 접근용
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

  # 5. Proposer (상태 루트 제출 -> L1)
  l2-proposer:
    image: us-docker.pkg.dev/oplabs-tools-artifacts/images/op-proposer:${OP_PROPOSER_TAG}
    restart: unless-stopped
    depends_on:
      - l2-node
    volumes:
      - ./secrets:/secrets
    command: >
      op-proposer
      --poll-interval=12s
      --rpc.port=8560
      --rollup-rpc=http://l2-node:8547
      --l2oo-address=${L2OO_ADDRESS}
      --private-key=/secrets/proposer.key
      --l1-eth-rpc=${L1_RPC_URL}`

---

### 3. 실행 및 검증 방법

이제 터미널에서 아래 명령어로 전체 시스템을 실행합니다.

### 실행

Bash

# 

`docker compose up -d`

1. `l2-geth-init`가 먼저 실행되어 `./data` 폴더에 제네시스 블록을 생성하고 종료됩니다.
2. 그 후 `l2-geth`, `l2-node` 등이 순차적으로 실행됩니다.

### 로그 확인 (디버깅)

전체 로그를 보거나 특정 서비스의 로그를 확인합니다.

Bash

# 

`# 전체 로그 (실시간)
docker compose logs -f

# Batcher가 Celestia와 잘 통신하는지 확인
docker compose logs -f l2-batcher

# Node가 L1과 잘 동기화되는지 확인
docker compose logs -f l2-node`

### 중지 및 재시작

Bash

# 

`docker compose down  # 컨테이너 종료 (데이터는 보존됨)
docker compose restart l2-node # 특정 서비스만 재시작`

### 💡 주의사항: Celestia 연결

위 설정에서 `l2-batcher`는 `host.docker.internal`을 통해 **호스트 머신에 띄워진 Celestia Light Node(포트 26658)**에 접근하려고 시도합니다.

- **Linux 사용자:** `extra_hosts` 설정이 있어도 방화벽 설정에 따라 접근이 안 될 수 있습니다. 만약 연결 에러가 난다면 `.env`의 `DA_SERVER_URL`을 `http://172.17.0.1:26658` (Docker 브릿지 게이트웨이 IP)로 변경해보세요.
- **Celestia 노드가 다른 서버에 있다면:** 해당 IP 주소를 `.env`에 적어주면 됩니다.

이제 모든 인프라가 Docker로 컨테이너화 되었습니다. **다음으로 운영 모니터링을 위한 Grafana/Prometheus 구성을 추가해 드릴까요?**