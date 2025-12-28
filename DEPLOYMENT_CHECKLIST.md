# BEGA L2 배포 체크리스트

## ✅ 완료된 단계

### Phase 0: 환경 준비
- [x] Docker Desktop 설치
- [x] Go 1.22+ 설치
- [x] Node.js & pnpm 설치
- [x] Foundry 설치
- [x] OP Stack 저장소 클론
- [x] op-deployer 빌드

### Phase 1: L1 준비
- [x] Alchemy Sepolia RPC 획득
- [x] 테스트 지갑 생성 (3개)
- [x] Sepolia ETH 확보
  - Deployer: 0.498 ETH ✅
  - Batcher: (필요)
  - Proposer: (필요)
- [x] BEGA 토큰 L1 배포
  - 주소: `0x55B746d21bCEb81374e818C809d0a8145e4Be2e1`
  - 이름: BEGA
  - 심볼: BEGA
  - Decimals: 18

### Phase 2: 설정
- [x] .env 파일 설정
- [x] deploy-config.json 설정
- [x] intent.toml 설정
- [x] 시크릿 파일 생성
  - [x] jwt.txt
  - [x] sequencer.key
  - [x] batcher.key
  - [x] proposer.key

### Phase 3: 컨트랙트 빌드
- [ ] OP Stack 컨트랙트 빌드 (진행 중...)

## 🔄 진행 중인 단계

- OP Stack 컨트랙트 컴파일 중 (527+ 파일)
- 예상 완료 시간: 10-15분

## 📋 다음 단계

### 1. L1 컨트랙트 배포 (op-deployer)
```bash
op-deployer apply \
  --l1-rpc-url $L1_RPC_URL \
  --private-key $DEPLOYER_PRIVATE_KEY \
  --workdir /Users/kangmunil/Project/BEGA/config
```

**예상 소요 시간**: 5-10분

**생성되는 파일**:
- genesis.json
- rollup.json
- state.json (업데이트)

### 2. 배포 결과 검증
```bash
./scripts/verify-deployment.sh
```

### 3. .env 업데이트
state.json에서 배포된 컨트랙트 주소들을 찾아 .env에 추가:
- L2OO_ADDRESS (L2 Output Oracle)
- SYSTEM_CONFIG_ADDRESS (System Config)

### 4. L2 노드 실행
```bash
docker compose up -d
```

### 5. L2 상태 확인
```bash
./scripts/check-health.sh
./scripts/test-l2-transaction.sh
```

### 6. MetaMask 연결
```bash
./scripts/metamask-network-info.sh
```

## 🎯 성공 기준

- [ ] genesis.json 생성됨
- [ ] rollup.json 생성됨
- [ ] L2 노드가 블록 생성 중
- [ ] eth_blockNumber > 0
- [ ] MetaMask 연결 성공
- [ ] L1 → L2 브릿지 테스트 성공
- [ ] L2에서 트랜잭션 전송 성공

## 🐛 문제 해결

### 컨트랙트 빌드 실패
```bash
cd /Users/kangmunil/Project/optimism/packages/contracts-bedrock
forge clean
forge build
```

### L2 노드 시작 안 됨
```bash
docker compose down
rm -rf data/*
# genesis.json, rollup.json 재생성 후
docker compose up -d
```

### Gas Oracle Bot 오류
```bash
# SYSTEM_CONFIG_ADDRESS 확인
grep SYSTEM_CONFIG_ADDRESS .env

# 로그 확인
docker compose logs -f gas-oracle
```

## 📚 유용한 명령어

```bash
# 전체 서비스 상태 확인
docker compose ps

# 특정 서비스 로그
docker compose logs -f l2-geth
docker compose logs -f l2-node
docker compose logs -f l2-batcher

# 서비스 재시작
docker compose restart [service-name]

# 전체 중지
docker compose down

# 데이터 초기화 후 재시작
docker compose down && rm -rf data/* && docker compose up -d
```

## 🎉 배포 완료 후

1. Blockscout 탐색기 설치
2. Bridge UI 구축
3. CLOB/Prediction Market 컨트랙트 배포
4. 모니터링 설정 (Prometheus + Grafana)
5. 보안 강화 (KMS, Multisig)

---

**현재 진행률**: Phase 3 진행 중 (약 70% 완료)
