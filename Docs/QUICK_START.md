# Quick Start Guide

30분 안에 로컬 테스트넷을 실행하는 방법입니다.

## 사전 준비 (15분)

### 1. 필수 도구 설치

```bash
# Docker Desktop 설치
# https://www.docker.com/products/docker-desktop

# Go 1.22+ 설치 (Gas Bot용)
# https://go.dev/dl/

# pnpm 설치 (OP Stack용)
npm install -g pnpm
```

### 2. OP Stack 모노레포 클론 및 빌드

```bash
# 적절한 위치에 클론
cd ~/Projects
git clone https://github.com/ethereum-optimism/optimism.git
cd optimism

# 의존성 설치
pnpm install

# 필요한 바이너리 빌드 (5-10분 소요)
make op-deployer
```

### 3. Celestia Light Node 실행 (선택사항)

Celestia 없이 테스트하려면 이 단계를 건너뛰고 docker-compose.yml에서 batcher 서비스를 주석 처리하세요.

```bash
# Celestia CLI 설치
# https://docs.celestia.org/nodes/light-node

# Mocha 테스트넷에서 Light Node 시작
celestia light start --core.ip consensus-full.celestia-mocha.com --p2p.network mocha
```

## L1 설정 (5분)

### 1. L1 RPC 엔드포인트 확보

- Alchemy 또는 Infura에서 Sepolia RPC URL 발급
- https://www.alchemy.com/ 또는 https://www.infura.io/

### 2. 테스트 지갑 준비

최소 3개의 지갑이 필요합니다 (같은 지갑을 재사용 가능):

```bash
# MetaMask에서 새 계정 3개 생성
# 1. Deployer (0.5 ETH 필요)
# 2. Batcher (0.2 ETH 필요)
# 3. Proposer (0.1 ETH 필요)

# Sepolia Faucet에서 테스트 ETH 받기
# https://sepoliafaucet.com/
# https://www.infura.io/faucet/sepolia
```

### 3. L1에 ERC-20 토큰 배포

Remix IDE 사용 (https://remix.ethereum.org/):

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract BEGAToken is ERC20 {
    constructor() ERC20("BEGA Token", "BEGA") {
        _mint(msg.sender, 1000000 * 10**18); // 1M tokens
    }
}
```

**중요**: 배포된 토큰 컨트랙트 주소를 기록하세요!

## L2 설정 (10분)

### 1. 환경 변수 설정

```bash
cd ~/Projects/BEGA

# .env 파일 생성
cp .env.example .env

# .env 파일 편집
nano .env  # 또는 code .env
```

필수 항목:
```bash
L1_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
DEPLOYER_PRIVATE_KEY=your_deployer_key_without_0x
BATCHER_PRIVATE_KEY=your_batcher_key_without_0x
PROPOSER_PRIVATE_KEY=your_proposer_key_without_0x
CUSTOM_GAS_TOKEN_ADDRESS=0xYOUR_DEPLOYED_TOKEN_ADDRESS
```

### 2. Deploy Config 생성

```bash
cp config/deploy-config.template.json config/deploy-config.json

# deploy-config.json 편집
nano config/deploy-config.json
```

최소한 다음 항목을 업데이트:
- `customGasTokenAddress`: L1 토큰 주소
- `finalSystemOwner`: Deployer 주소
- `batchSenderAddress`: Batcher 주소
- `l2OutputOracleProposer`: Proposer 주소

### 3. L1 컨트랙트 배포

```bash
cd ~/Projects/optimism

./bin/op-deployer bootstrap \
  --l1-rpc-url $L1_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --config ~/Projects/BEGA/config/deploy-config.json \
  --workdir ~/Projects/BEGA/config \
  --artifacts-dir ~/Projects/BEGA/config
```

성공하면 `config/` 폴더에 다음 파일들이 생성됩니다:
- `genesis.json`
- `rollup.json`
- `artifacts.json` (또는 유사한 이름)

### 4. .env 업데이트

`artifacts.json`에서 다음 주소들을 찾아 `.env`에 추가:

```bash
L2OO_ADDRESS=0x...  # L2OutputOracleProxy
SYSTEM_CONFIG_ADDRESS=0x...  # SystemConfigProxy
```

### 5. 시크릿 생성

```bash
cd ~/Projects/BEGA

# 자동 스크립트 사용
./scripts/setup-secrets.sh

# 또는 수동 생성
openssl rand -hex 32 > secrets/jwt.txt
echo "SEQUENCER_PRIVATE_KEY" > secrets/sequencer.key
echo "BATCHER_PRIVATE_KEY" > secrets/batcher.key
echo "PROPOSER_PRIVATE_KEY" > secrets/proposer.key
```

## 실행 및 테스트

### 1. L2 체인 시작

```bash
cd ~/Projects/BEGA

# 모든 서비스 시작
docker compose up -d

# 로그 확인
docker compose logs -f
```

### 2. 상태 확인

```bash
# 자동 헬스 체크
./scripts/check-health.sh

# 또는 수동 확인
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

정상 응답 예시:
```json
{"jsonrpc":"2.0","id":1,"result":"0x1a"}
```

### 3. MetaMask 연결

MetaMask에서 네트워크 추가:

```
Network Name: BEGA L2 Local
RPC URL: http://localhost:8545
Chain ID: 12345678
Currency Symbol: BEGA
```

### 4. 첫 트랜잭션 테스트

MetaMask에서:
1. BEGA L2 Local 네트워크 선택
2. 브릿지를 통해 L1에서 BEGA 토큰 입금
3. L2에서 테스트 전송 수행

## 문제 해결

### "Genesis block mismatch" 에러

```bash
docker compose down
rm -rf data/*
docker compose up -d
```

### Batcher 연결 실패

```bash
# Celestia 노드 확인
curl http://localhost:26658

# 또는 docker-compose.yml에서 batcher 주석 처리 후 재시작
docker compose up -d
```

### Gas Oracle Bot 실행 안됨

```bash
# SystemConfig 주소 확인
grep SYSTEM_CONFIG_ADDRESS .env

# Bot 로그 확인
docker compose logs -f gas-oracle
```

## 다음 단계

축하합니다! 로컬 L2가 실행 중입니다.

이제 다음을 진행하세요:

1. **탐색기 설치**: Blockscout을 설치하여 트랜잭션 확인
2. **브릿지 UI**: 사용자 친화적인 입출금 인터페이스 구축
3. **스마트 컨트랙트**: CLOB 또는 Prediction Market 컨트랙트 배포
4. **모니터링**: Grafana/Prometheus 설정

자세한 내용은 [README.md](README.md)를 참조하세요.
