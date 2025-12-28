# 🎯 다음 단계 - Phase 1 진행

## 현재 상태

✅ **완료된 작업**:
- 프로젝트 구조 생성 완료
- Docker Compose 설정 완료
- Gas Price Updater Bot 구현 완료
- OP Stack 저장소 클론 및 op-deployer 빌드 완료
- ERC-20 토큰 컨트랙트 템플릿 생성 완료
- 모든 설정 파일 템플릿 준비 완료

## 📝 지금 바로 해야 할 일

상세한 가이드는 [SETUP_GUIDE.md](SETUP_GUIDE.md)를 참조하세요.

### 1. L1 RPC 엔드포인트 획득 (5분)

```bash
# Alchemy 가입
https://www.alchemy.com/

# Sepolia Testnet App 생성
# API Key 복사
```

### 2. 테스트 지갑 준비 (10분)

```bash
# MetaMask에서 3개 계정 생성:
# 1. Deployer (0.5 ETH 필요)
# 2. Batcher (0.2 ETH 필요)
# 3. Proposer (0.1 ETH 필요)

# Sepolia Faucet에서 테스트 ETH 받기:
# https://sepoliafaucet.com/
# https://www.infura.io/faucet/sepolia
```

### 3. BEGA 토큰 L1 배포 (5분)

**Remix IDE 사용** (가장 쉬움):

1. https://remix.ethereum.org/ 접속
2. `contracts/BEGAToken.sol` 파일 내용 복사
3. Remix에서 새 파일 생성 후 붙여넣기
4. Compile
5. Deploy to Sepolia (MetaMask 연결)
6. **배포된 주소 복사해서 저장!**

### 4. 환경 설정 (5분)

```bash
cd /Users/kangmunil/Project/BEGA

# .env 파일 생성
cp .env.example .env

# .env 편집 (VS Code 또는 원하는 에디터)
code .env
```

필수 입력 항목:
```bash
L1_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
DEPLOYER_PRIVATE_KEY=your_key_without_0x
BATCHER_PRIVATE_KEY=your_key_without_0x
PROPOSER_PRIVATE_KEY=your_key_without_0x
CUSTOM_GAS_TOKEN_ADDRESS=0xYourDeployedTokenAddress
```

### 5. deploy-config.json 설정 (3분)

```bash
cp config/deploy-config.template.json config/deploy-config.json
code config/deploy-config.json
```

수정할 항목:
- `customGasTokenAddress`: Step 3에서 배포한 토큰 주소
- 모든 주소 필드: 본인의 MetaMask 주소로 변경

### 6. L1 컨트랙트 배포 (10분)

```bash
# op-deployer 실행
/Users/kangmunil/Project/optimism/op-deployer/bin/op-deployer bootstrap \
  --l1-rpc-url $L1_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --config /Users/kangmunil/Project/BEGA/config/deploy-config.json \
  --workdir /Users/kangmunil/Project/BEGA/config \
  --artifacts-dir /Users/kangmunil/Project/BEGA/config
```

**성공 확인**:
```bash
ls config/
# genesis.json, rollup.json 파일이 생성되어 있어야 함
```

### 7. 시크릿 생성 (2분)

```bash
./scripts/setup-secrets.sh
```

### 8. L2 시작! (1분)

```bash
docker compose up -d

# 로그 확인
docker compose logs -f l2-geth
```

### 9. 상태 확인 (1분)

```bash
# 헬스 체크
./scripts/check-health.sh

# 또는 수동으로:
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### 10. MetaMask 연결

```
Network Name: BEGA L2 Local
RPC URL: http://localhost:8545
Chain ID: 12345678
Currency Symbol: BEGA
```

## 🎉 성공했다면?

블록이 생성되고 있다면 성공입니다!

**다음으로 할 수 있는 것**:

1. **브릿지 테스트**: L1 → L2 토큰 입출금
2. **스마트 컨트랙트 배포**: CLOB 또는 Prediction Market
3. **탐색기 설치**: Blockscout 설정
4. **모니터링**: Prometheus + Grafana 구축

## 🐛 문제 발생 시

1. [SETUP_GUIDE.md](SETUP_GUIDE.md)의 "문제 해결" 섹션 참조
2. 로그 확인: `docker compose logs -f [서비스명]`
3. 데이터 초기화: `docker compose down && rm -rf data/* && docker compose up -d`

## 📚 참고 문서

- [README.md](README.md) - 프로젝트 전체 개요
- [SETUP_GUIDE.md](SETUP_GUIDE.md) - 상세한 단계별 가이드
- [QUICK_START.md](QUICK_START.md) - 30분 빠른 시작
- [PROJECT_STRUCTURE.md](PROJECT_STRUCTURE.md) - 프로젝트 구조 설명
- [Docs/LoadMap.md](Docs/LoadMap.md) - 전체 로드맵

## ⏱️ 예상 소요 시간

| 단계 | 시간 |
|------|------|
| RPC 엔드포인트 획득 | 5분 |
| 지갑 준비 & Faucet | 10분 |
| L1 토큰 배포 | 5분 |
| 환경 설정 | 8분 |
| L1 컨트랙트 배포 | 10분 |
| L2 실행 | 5분 |
| **총계** | **약 43분** |

---

**준비되셨나요? [SETUP_GUIDE.md](SETUP_GUIDE.md)를 열고 시작하세요!** 🚀
