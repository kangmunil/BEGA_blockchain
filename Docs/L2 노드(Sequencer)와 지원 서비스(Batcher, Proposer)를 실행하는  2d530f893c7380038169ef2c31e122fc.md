# L2 노드(Sequencer)와 지원 서비스(Batcher, Proposer)를 실행하는 쉘 스크립트

배포된 설정 파일(`genesis.json`, `rollup.json`)과 바이너리를 사용하여 **L2 노드(Sequencer)와 지원 서비스(Batcher, Proposer)**를 실행하는 쉘 스크립트 세트입니다.

- *Celestia DA(Alt-DA)**와 **자체 가스 토큰** 환경에 맞춰진 설정입니다.

### 📂 디렉토리 구조 가정

작업을 편하게 하기 위해 아래와 같은 폴더 구조라고 가정하고 스크립트를 작성했습니다.

Plaintext

# 

`/my-l2-chain
├── bin/              # op-geth, op-node, op-batcher, op-proposer 바이너리
├── config/           # genesis.json, rollup.json, deploy-config.json
├── secrets/          # jwt.txt, sequencer.key, batcher.key, proposer.key
├── data/             # geth 데이터 저장소
└── scripts/          # 아래 작성할 실행 스크립트들`

---

### 1. 사전 준비 (Initial Setup)

먼저 실행 권한과 JWT 시크릿, 데이터 초기화가 필요합니다.

Bash

# 

`# 1. JWT 시크릿 생성 (Geth와 Node 간 통신 보안용)
mkdir -p secrets data
openssl rand -hex 32 > secrets/jwt.txt

# 2. op-geth 초기화 (Genesis 블록 생성)
./bin/op-geth init \
  --datadir=./data \
  ./config/genesis.json`

---

### 2. 실행 스크립트 작성

각 파일은 `scripts/` 폴더 내에 `.sh` 파일로 저장하고 `chmod +x`로 실행 권한을 주세요.

### ① start-geth.sh (실행 클라이언트)

사용자의 트랜잭션을 받고 EVM을 실행합니다.

Bash

# 

`#!/bin/bash
export DATADIR=./data
export JWT_SECRET=./secrets/jwt.txt

./bin/op-geth \
  --datadir="$DATADIR" \
  --http \
  --http.corsdomain="*" \
  --http.vhosts="*" \
  --http.addr=0.0.0.0 \
  --http.port=8545 \
  --http.api=web3,debug,eth,txpool,net,engine \
  --ws \
  --ws.addr=0.0.0.0 \
  --ws.port=8546 \
  --ws.api=debug,eth,txpool,net,engine \
  --authrpc.addr=0.0.0.0 \
  --authrpc.port=8551 \
  --authrpc.vhosts="*" \
  --authrpc.jwtsecret="$JWT_SECRET" \
  --syncmode=full \
  --gcmode=archive \
  --nodiscover \
  --maxpeers=0 \
  --networkid=12345678 \
  --rollup.sequencerhttp=http://localhost:8545 \
  --rollup.disabletxpoolgossip=true`

- `-gcmode=archive`: 디버깅 및 인덱서(Blockscout) 연동을 위해 아카이브 모드 추천.
- `-networkid`: `deploy-config.json`의 `l2ChainID`와 일치해야 합니다.

### ② start-node.sh (합의 클라이언트)

L1에서 데이터를 읽어오고 `op-geth`를 제어하며, P2P 네트워크를 형성합니다.

Bash

# 

`#!/bin/bash
export L1_RPC_URL="https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY"
export ROLLUP_CONFIG=./config/rollup.json
export JWT_SECRET=./secrets/jwt.txt
export SEQUENCER_KEY=./secrets/sequencer.key # 0x 제외한 Private Key

./bin/op-node \
  --l1="$L1_RPC_URL" \
  --l1.rpckind=alchemy \
  --l2=http://localhost:8551 \
  --l2.jwt-secret="$JWT_SECRET" \
  --rollup.config="$ROLLUP_CONFIG" \
  --rpc.addr=0.0.0.0 \
  --rpc.port=8547 \
  --p2p.sequencer.key="$SEQUENCER_KEY" \
  --sequencer.enabled \
  --sequencer.l1-confs=3 \
  --verifier.l1-confs=3`

- `-sequencer.enabled`: 시퀀서 노드이므로 필수입니다.
- Alt-DA 설정은 `rollup.json` 파일 내에 정의되어 있으므로 별도 플래그가 필요 없습니다.

### ③ start-batcher.sh (Celestia DA 연동 핵심)

**가장 중요한 부분입니다.** L2 데이터를 압축하여 Celestia로 보냅니다.

Bash

# 

`#!/bin/bash
export L1_RPC_URL="https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY"
export ROLLUP_CONFIG=./config/rollup.json
export BATCHER_KEY=./secrets/batcher.key # L1 ETH가 있는 지갑

# Celestia Light Node 주소 (로컬 실행 가정)
export DA_RPC="http://localhost:26658" 

./bin/op-batcher \
  --l1-eth-rpc="$L1_RPC_URL" \
  --rollup-rpc=http://localhost:8547 \
  --poll-interval=1s \
  --sub-safety-margin=6 \
  --num-confirmations=1 \
  --safe-abort-nonce-too-low-count=3 \
  --resubmission-timeout=30s \
  --private-key="$BATCHER_KEY" \
  --altda.enabled=true \
  --altda.da-service=true \
  --altda.da-server="$DA_RPC"`

- **`-altda.enabled=true`**: Alt-DA 모드 활성화.
- **`-altda.da-server`**: 실행 중인 **Celestia Light Node**의 RPC 주소를 가리켜야 합니다.

### ④ start-proposer.sh (상태 루트 제출)

L2 실행 결과(State Root)를 L1 컨트랙트에 기록합니다.

Bash

# 

`#!/bin/bash
export L1_RPC_URL="https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY"
export ROLLUP_CONFIG=./config/rollup.json
export PROPOSER_KEY=./secrets/proposer.key
export L2OO_ADDRESS="0x..." # artifacts.json에서 L2OutputOracleProxy 주소 확인 후 입력

./bin/op-proposer \
  --poll-interval=12s \
  --rpc.port=8560 \
  --rollup-rpc=http://localhost:8547 \
  --l2oo-address="$L2OO_ADDRESS" \
  --private-key="$PROPOSER_KEY" \
  --l1-eth-rpc="$L1_RPC_URL"`

---

### 3. 전체 실행 순서 (Process Manager 사용 권장)

터미널 창을 여러 개 띄우거나 `tmux` 등을 사용하여 아래 순서대로 실행하세요.

1. **Celestia Light Node 실행:** (먼저 실행되어 있어야 Batcher가 에러를 뱉지 않습니다.)
2. **`start-geth.sh`**: 실행 엔진 구동.
3. **`start-node.sh`**: 합의 엔진 구동 (여기서부터 로그가 올라가기 시작해야 함).
4. **`start-batcher.sh`**: 트랜잭션이 발생하면 데이터를 Celestia로 보내기 시작.
5. **`start-proposer.sh`**: 주기적으로 L1에 상태 기록.

### 💡 팁: Supervisor 또는 Docker Compose 활용

운영 환경에서는 위 스크립트들을 `systemd` 서비스로 등록하거나 `docker-compose`로 묶는 것이 좋습니다.

**Docker Compose로 변환해 드릴까요?** (로컬 테스트 및 배포 관리가 훨씬 쉬워집니다.)