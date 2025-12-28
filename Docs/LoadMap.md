## 📅 Prediction Market L2 개발 로드맵

### Phase 1: 로컬 개발 및 PoC (Proof of Concept)

**목표:** 내 컴퓨터(Localhost)에서 모든 구성 요소가 연결되어 정상 작동함을 검증.
**기간:** 1주

1. **L1 환경 준비**
* Sepolia 테스트넷에 **자체 토큰(ERC-20)** 배포.
* Celestia Light Node (Mocha Testnet) 로컬 실행 및 지갑 동기화.


2. **L2 인프라 구성 (Docker Compose)**
* `deploy-config.json` 작성 (Native Token + Alt-DA 설정).
* `op-deployer`로 L1 컨트랙트 배포 (Bootstrap).
* `op-node`, `op-geth`, `op-batcher` 실행 및 로그 확인.


3. **기능 검증**
* **가스비 테스트:** 메타마스크에서 자체 토큰으로 트랜잭션 전송 시 가스비가 정상 차감되는지 확인.
* **DA 테스트:** Celestia Explorer에서 Batcher가 올린 데이터 확인.



---

### Phase 2: 퍼블릭 테스트넷 (Alpha Testnet)

**목표:** 외부 사용자가 접속 가능한 안정적인 테스트 환경 구축.
**기간:** 2~3주

1. **클라우드/서버 배포**
* AWS EC2 또는 고성능 온프레미스 서버에 Docker Compose 배포.
* Nginx/Cloudflare를 통해 RPC 엔드포인트(HTTPS) 외부 개방.


2. **사용자 도구 배포**
* **Blockscout (탐색기):** 트랜잭션 및 컨트랙트 검증 기능 제공.
* **Bridge UI:** Sepolia(L1) ↔ Custom L2 간 자체 토큰 입출금 웹페이지 배포.


3. **경제 모델 적용 (Gas Bot)**
* **Gas Price Updater Bot** 배포.
* CEX/DEX 가격 변동 시 `SystemConfig`의 Scalar 값이 자동 조절되는지 모니터링.



---

### Phase 3: 보안 강화 및 운영 고도화 (Hardening)

**목표:** 해킹 방지 및 무중단 운영을 위한 시스템 견고화.
**기간:** 2주

1. **키 관리 시스템(KMS) 도입**
* 로컬 파일(`secrets/*.key`) 삭제.
* **HashiCorp Vault + Web3Signer** 컨트랙트 구축 및 연동.
* 관리자 키(Owner)를 **Ledger/Safe(Multisig)**로 이관.


2. **모니터링 체계 구축**
* Prometheus/Grafana 대시보드 구축.
* **Alertmanager 설정:** "Batcher ETH 잔고 부족", "Celestia 연결 끊김" 시 Slack/Discord 알림 발송.


3. **부하 테스트 (Stress Test)**
* 대량의 트랜잭션(Spam)을 발생시켜 시퀀서 메모리 누수 및 재구성(Reorg) 여부 확인.



---

### Phase 4: 애플리케이션 통합 (App Integration)

**목표:** 예측 시장 서비스(CLOB)가 L2 위에서 원활하게 돌아가는지 확인.
**기간:** 3~4주

1. **CLOB 컨트랙트 배포**
* 예측 시장용 Orderbook 컨트랙트 배포 및 가스비 최적화.


2. **데이터 인덱싱**
* **The Graph** 또는 **Subsquid** 노드 구축 (호가창 및 체결 내역 고속 조회용).


3. **Oracle 연동**
* 예측 결과 정산을 위한 UMA 또는 Pyth 오라클 연동 테스트.



---

### Phase 5: 메인넷 런칭 (Mainnet Launch)

**목표:** 실제 자산이 오가는 프로덕션 환경 오픈.
**기간:** (준비 완료 시)

1. **최종 감사 (Audit)**
* 스마트 컨트랙트 및 인프라 설정 보안 감사.


2. **제네시스 배포**
* 메인넷(Ethereum Mainnet + Celestia Mainnet) 환경에서 `op-deployer` 실행.


3. **커뮤니티 오픈**
* 브릿지 및 탐색기 오픈, 초기 유동성 공급.
