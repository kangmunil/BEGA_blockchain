# op-deployer로 L1에 컨트랙트를 배포하고, L2 제네시스 파일까지 생성하는 터미널 명령어 시퀀스 (1)

`deploy-config.json` 파일을 사용하여 `op-deployer`로 L1에 컨트랙트를 배포하고, L2 제네시스 파일까지 생성하는 **터미널 명령어 시퀀스**입니다.

이 과정은 **"준비 → 빌드 → 환경변수 설정 → 배포(Bootstrap) → 결과 확인"** 순서로 진행됩니다.

---

### 1. 사전 준비 및 도구 설치

먼저 OP Stack 모노레포를 클론하고, 배포 도구인 `op-deployer`를 빌드해야 합니다.

Bash

# 

`# 1. OP Stack 레포지토리 클론 (이미 했다면 생략)
git clone https://github.com/ethereum-optimism/optimism.git
cd optimism

# 2. 의존성 설치 및 Go 툴체인 준비
pnpm install
make install-tools

# 3. op-deployer 빌드
# (bin/op-deployer 바이너리가 생성됩니다)
make op-deployer`

---

### 2. 작업 디렉토리 및 설정 파일 배치

배포 관련 파일들이 섞이지 않도록 별도 디렉토리를 만들고, 앞서 작성한 `deploy-config.json`을 저장합니다.

Bash

# 

`# 1. 배포 작업용 디렉토리 생성
mkdir -p my-chain-deployment
cd my-chain-deployment

# 2. deploy-config.json 파일 생성
# (앞서 작성한 JSON 내용을 이 파일에 복사/저장하세요)
touch deploy-config.json`

---

### 3. 환경 변수 설정 (필수)

보안을 위해 Private Key와 RPC URL은 환경 변수로 주입합니다.

주의: DEPLOYER_KEY 지갑에는 L1(Sepolia) ETH가 넉넉히 있어야 합니다. (최소 0.5 ETH 권장)

Bash

# 

`# [Sepolia RPC URL] (Infura, Alchemy, QuickNode 등)
export L1_RPC_URL="https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY"

# [배포자 지갑 개인키] (0x 제외)
export DEPLOYER_PRIVATE_KEY="YOUR_PRIVATE_KEY_WITHOUT_0X"

# [L1 배포 가스비용 Private Key] (보통 배포자와 동일하게 설정)
export ETHERSCAN_API_KEY="YOUR_ETHERSCAN_API_KEY" # 검증을 위해 필요 (선택)`

---

### 4. 실제 배포 실행 (Bootstrap)

`op-deployer`의 `bootstrap` 명령어를 사용하면, `deploy-config.json`을 읽어 L1 컨트랙트를 배포하고 필요한 아티팩트를 생성합니다.

Bash

# 

`# 루트 디렉토리(optimism/)로 돌아가서 실행하거나 경로를 맞춰주세요.
# 아래는 optimism/ 루트에서 실행한다고 가정합니다.

./bin/op-deployer bootstrap \
  --l1-rpc-url $L1_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --config ./my-chain-deployment/deploy-config.json \
  --workdir ./my-chain-deployment \
  --artifacts-dir ./my-chain-deployment/artifacts`

> 💡 명령어 실행 중 발생하는 일:
> 
> 1. `deploy-config.json` 유효성 검사.
> 2. OptimismPortal, SystemConfig 등 핵심 L1 컨트랙트 순차 배포.
> 3. **L1 Block Number** 기록 (L2 노드가 여기서부터 데이터를 읽기 시작함).
> 4. `genesis.json` 및 `rollup.json` 파일 생성.

---

### 5. 배포 결과물 확인 및 검증

명령어가 성공적으로 끝나면 `--workdir`로 지정한 폴더에 중요한 파일들이 생성됩니다.

Bash

# 

`ls -F ./my-chain-deployment/
# 출력 예시:
# artifacts/        <-- 배포된 컨트랙트 주소 목록
# genesis.json      <-- op-geth 실행용
# rollup.json       <-- op-node 실행용
# deploy-config.json`

### 중요 파일 확인: `rollup.json`

이 파일은 `op-node`가 실행될 때 필수적입니다. 내용 중 `genesis.l2.chain_id`와 `genesis.system_config.token_address`(커스텀 가스 토큰 주소)가 맞는지 확인하세요.

Bash

# 

`cat ./my-chain-deployment/rollup.json | jq .genesis.system_config`

---

### 6. 다음 단계: L2 노드 실행 (연결)

이제 생성된 파일들을 사용하여 로컬에서 L2 노드를 띄울 차례입니다.

Bash

# 

`# 1. op-geth 초기화 (Genesis 블록 생성)
./bin/op-geth init --datadir=./l2-data ./my-chain-deployment/genesis.json

# 2. op-geth 실행
./bin/op-geth \
  --datadir=./l2-data \
  --http --ws --authrpc.jwtsecret=./jwt.txt \
  --rollup.sequencerhttp=https://localhost:8545 \
  # ... (나머지 옵션)

# 3. op-node 실행 (rollup.json 연결)
./bin/op-node \
  --l1=$L1_RPC_URL \
  --rollup.config=./my-chain-deployment/rollup.json \
  --rpc.addr=0.0.0.0 \
  --p2p.sequencer.key=$SEQUENCER_KEY \
  # ... (나머지 옵션)`

### ⚠️ 주의사항 (Troubleshooting)

1. **가스비 오류:** `insufficient funds` 에러가 나면 `DEPLOYER_PRIVATE_KEY` 지갑에 Sepolia ETH를 더 충전하세요.
2. **Nonce 오류:** 배포 도중 멈췄다가 다시 실행할 때 Nonce 꼬임이 발생하면, `-workdir`을 비우고 다시 시작하는 것이 깔끔합니다.
3. **Custom Gas Token:** 배포 스크립트는 **L1에 있는 토큰 컨트랙트가 실제로 존재하는지** 체크하지 않을 수 있습니다. `deploy-config.json`에 넣은 주소가 정확한지 두 번 확인하세요.