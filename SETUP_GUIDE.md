# BEGA L2 Setup Guide - Step by Step

이 가이드는 Phase 1 (로컬 PoC)을 완료하기 위한 상세한 단계별 안내입니다.

## 📋 사전 준비 체크리스트

- [x] Docker Desktop 설치 완료
- [x] Go 1.22+ 설치 완료
- [x] Node.js & pnpm 설치 완료
- [x] OP Stack 저장소 클론 완료
- [x] op-deployer 빌드 완료

## 🎯 현재 단계: L1 토큰 배포

### Step 1: L1 RPC 엔드포인트 획득

1. **Alchemy 계정 생성** (https://www.alchemy.com/)
   - 회원가입 후 대시보드 접속
   - "Create App" 클릭
   - Network: `Ethereum Sepolia` 선택
   - App 생성 후 API Key 복사

2. **RPC URL 형식**
   ```
   https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
   ```

### Step 2: 테스트 지갑 생성

다음 역할을 위한 지갑 주소가 필요합니다 (같은 지갑을 여러 역할에 사용 가능):

| 역할 | 필요 ETH | 용도 |
|------|----------|------|
| Deployer | 0.5 ETH | L1 컨트랙트 배포 |
| Batcher | 0.2 ETH | L1에 배치 데이터 제출 (지속적) |
| Proposer | 0.1 ETH | L1에 상태 루트 제출 (지속적) |
| Admin | 0 ETH | 관리자 권한 (트랜잭션 없음) |

#### MetaMask에서 지갑 생성

1. MetaMask 설치
2. "Create Account" 클릭하여 3개 계정 생성
3. 각 계정의 **Private Key** 내보내기:
   - 계정 선택 → 점 3개 메뉴 → "Account Details" → "Export Private Key"
   - **주의**: Private Key를 안전하게 보관 (절대 공유 금지)

#### Sepolia Testnet ETH 받기

다음 Faucet에서 테스트 ETH를 받으세요:

- https://sepoliafaucet.com/
- https://www.infura.io/faucet/sepolia
- https://faucet.quicknode.com/ethereum/sepolia

각 지갑에 최소 금액:
- Deployer: 0.5 ETH
- Batcher: 0.2 ETH
- Proposer: 0.1 ETH

### Step 3: L1에 BEGA 토큰 배포

#### Option A: Remix IDE 사용 (추천)

1. **Remix 접속**: https://remix.ethereum.org/

2. **컨트랙트 파일 생성**:
   - 좌측 파일 탐색기에서 "contracts" 폴더 클릭
   - 새 파일 생성: `BEGAToken.sol`
   - [contracts/BEGAToken.sol](contracts/BEGAToken.sol) 내용 복사

3. **컴파일**:
   - 좌측 "Solidity Compiler" 탭 클릭
   - Compiler version: `0.8.20` 이상 선택
   - "Compile BEGAToken.sol" 클릭

4. **배포**:
   - 좌측 "Deploy & Run Transactions" 탭 클릭
   - Environment: `Injected Provider - MetaMask` 선택
   - MetaMask에서 Sepolia 네트워크 연결 확인
   - Contract: `BEGAToken` 선택
   - Constructor 파라미터:
     - `initialSupply`: `1000000` (100만 토큰)
   - "Deploy" 클릭
   - MetaMask에서 트랜잭션 승인

5. **배포 주소 확인**:
   - 배포 완료 후 "Deployed Contracts" 섹션에서 주소 복사
   - **중요**: 이 주소를 메모장에 저장! (예: `0x1234...abcd`)

#### Option B: Hardhat 사용

```bash
# BEGA 프로젝트 디렉토리에서
npx hardhat init
# "Create a JavaScript project" 선택

# 컨트랙트 배포 스크립트 작성 후
npx hardhat run scripts/deploy.js --network sepolia
```

### Step 4: 환경 변수 설정

```bash
cd /Users/kangmunil/Project/BEGA

# .env 파일 생성
cp .env.example .env
```

`.env` 파일을 열고 다음 항목을 채워넣으세요:

```bash
# L1 Configuration
L1_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY

# Private Keys (0x 제외)
DEPLOYER_PRIVATE_KEY=your_deployer_private_key_here
BATCHER_PRIVATE_KEY=your_batcher_private_key_here
PROPOSER_PRIVATE_KEY=your_proposer_private_key_here
OPERATOR_PRIVATE_KEY=your_operator_private_key_here

# Admin Addresses (0x 포함)
ADMIN_ADDRESS=0xYourAdminAddress
FINAL_SYSTEM_OWNER=0xYourAdminAddress
PROXY_ADMIN_OWNER=0xYourAdminAddress

# Fee Recipients (0x 포함)
BASE_FEE_VAULT_RECIPIENT=0xYourFeeReceiverAddress
L1_FEE_VAULT_RECIPIENT=0xYourFeeReceiverAddress
SEQUENCER_FEE_VAULT_RECIPIENT=0xYourFeeReceiverAddress

# L1 Custom Gas Token (Step 3에서 배포한 주소)
CUSTOM_GAS_TOKEN_ADDRESS=0xYourDeployedTokenAddress
```

### Step 5: deploy-config.json 설정

```bash
# 템플릿 복사
cp config/deploy-config.template.json config/deploy-config.json
```

`config/deploy-config.json` 파일을 열고 다음 항목을 수정:

```json
{
  "customGasTokenAddress": "0xYourDeployedTokenAddress",

  "finalSystemOwner": "0xYourAdminAddress",
  "superchainConfigGuardian": "0xYourAdminAddress",
  "l1SmartContractOwner": "0xYourAdminAddress",
  "proxyAdminOwner": "0xYourAdminAddress",

  "baseFeeVaultRecipient": "0xYourFeeReceiverAddress",
  "l1FeeVaultRecipient": "0xYourFeeReceiverAddress",
  "sequencerFeeVaultRecipient": "0xYourFeeReceiverAddress",

  "p2pSequencerAddress": "0xYourSequencerAddress",
  "batchSenderAddress": "0xYourBatcherAddress",
  "l2OutputOracleProposer": "0xYourProposerAddress",
  "l2OutputOracleChallenger": "0xYourChallengerAddress"
}
```

**팁**: 모든 주소에 같은 주소를 사용해도 됩니다 (테스트 목적).

### Step 6: L1 컨트랙트 배포

```bash
/Users/kangmunil/Project/optimism/op-deployer/bin/op-deployer bootstrap \
  --l1-rpc-url $L1_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --config /Users/kangmunil/Project/BEGA/config/deploy-config.json \
  --workdir /Users/kangmunil/Project/BEGA/config \
  --artifacts-dir /Users/kangmunil/Project/BEGA/config
```

**예상 소요 시간**: 5-10분

**성공 시 생성되는 파일**:
- `config/genesis.json` - L2 제네시스 블록
- `config/rollup.json` - Rollup 설정
- `config/artifacts.json` - 배포된 L1 컨트랙트 주소들

### Step 7: .env 업데이트 (배포 후)

`config/artifacts.json` (또는 유사한 파일)을 열고 다음 주소를 찾아 `.env`에 추가:

```bash
L2OO_ADDRESS=0x...  # L2OutputOracleProxy
SYSTEM_CONFIG_ADDRESS=0x...  # SystemConfigProxy
BATCH_INBOX_ADDRESS=0x...  # BatchInbox 또는 Batcher 주소
```

### Step 8: 시크릿 파일 생성

```bash
cd /Users/kangmunil/Project/BEGA

# 자동 스크립트 사용
./scripts/setup-secrets.sh
```

스크립트가 요청하는 정보:
- Sequencer Private Key (0x 제외)
- Batcher Private Key (0x 제외)
- Proposer Private Key (0x 제외)

### Step 9: L2 체인 시작

```bash
# Docker Compose로 전체 스택 실행
docker compose up -d

# 로그 확인 (모든 서비스)
docker compose logs -f

# 특정 서비스 로그만 보기
docker compose logs -f l2-geth
docker compose logs -f l2-node
docker compose logs -f l2-batcher
```

### Step 10: 헬스 체크

```bash
# 자동 헬스 체크
./scripts/check-health.sh

# 수동 확인 - 블록 번호 조회
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# 정상 응답 예시:
# {"jsonrpc":"2.0","id":1,"result":"0x1a"}
```

### Step 11: MetaMask 연결

MetaMask에 네트워크 추가:

```
Network Name: BEGA L2 Local
RPC URL: http://localhost:8545
Chain ID: 12345678
Currency Symbol: BEGA
Block Explorer URL: (비워두기)
```

## 🐛 문제 해결

### Genesis Block Mismatch

```bash
docker compose down
rm -rf data/*
docker compose up -d
```

### Batcher "connection refused"

Celestia 없이 테스트하려면:

1. `docker-compose.yml`에서 `l2-batcher` 서비스 주석 처리
2. `docker compose up -d` 재실행

### "Insufficient funds"

Deployer/Batcher/Proposer 지갑에 Sepolia ETH가 충분한지 확인

## ✅ 완료 체크리스트

- [ ] L1 RPC URL 획득
- [ ] 테스트 지갑 생성 및 ETH 확보
- [ ] BEGA 토큰 L1 배포 완료
- [ ] .env 파일 설정 완료
- [ ] deploy-config.json 설정 완료
- [ ] L1 컨트랙트 배포 완료 (op-deployer)
- [ ] genesis.json, rollup.json 생성 확인
- [ ] 시크릿 파일 생성 완료
- [ ] Docker Compose 실행 성공
- [ ] L2 블록 생성 확인 (eth_blockNumber)
- [ ] MetaMask 연결 성공

## 🎉 다음 단계

모든 체크리스트 완료 시:

1. **브릿지 테스트**: L1 → L2 토큰 입금
2. **첫 트랜잭션**: L2에서 테스트 전송
3. **탐색기 설치**: Blockscout 설정
4. **스마트 컨트랙트 배포**: CLOB 또는 Prediction Market 컨트랙트

자세한 내용은 [README.md](README.md)를 참조하세요!
