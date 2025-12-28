# 📘 Project: Prediction Market L2 Architecture Guide

**Stack:** OP Stack (Bedrock) | **DA:** Celestia | **Gas:** Native ERC-20

## 1. 개요 (Overview)

본 문서는 예측 시장(Prediction Market) 및 CLOB(주문 대장) 애플리케이션을 위한 고성능, 저비용 이더리움 L2 블록체인 구축 가이드입니다.
사용자 경험(UX) 강화를 위해 **자체 토큰을 가스비로 사용**하며, 운영 비용 절감을 위해 **Celestia를 데이터 가용성(DA) 계층으로 활용**합니다.

### 핵심 설계 원칙

1. **No-Fork Policy:** 유지보수 및 보안을 위해 `go-ethereum` 코드를 수정하지 않고, **OP Stack의 표준 설정(Configuration)**만을 사용하여 기능을 구현합니다.
2. **Alt-DA:** 이더리움 Blob 대신 Celestia를 사용하여 데이터 비용을 90% 이상 절감합니다.
3. **Economic Safety:** 자체 토큰 가격 변동에 따른 시퀀서 손실을 방지하기 위해 **자동 가스비 조정 봇**을 운영합니다.

---

## 2. 시스템 아키텍처 (System Architecture)

### 2.1. 구성 요소 (Components)

| 구분 | 컴포넌트 | 역할 | 비고 |
| --- | --- | --- | --- |
| **Execution** | **op-geth** | 트랜잭션 처리, EVM 실행, 상태 저장 | 표준 바이너리 사용 (Custom Config 적용) |
| **Consensus** | **op-node** | L2 블록 생성(Sequencing), L1 데이터 동기화 | P2P 네트워크 형성 |
| **Data Avail.** | **op-batcher** | L2 트랜잭션을 압축하여 **Celestia**에 업로드 | **ETH 잔고 필수 (L1 수수료)** |
| **Settlement** | **op-proposer** | L2 상태 루트(State Root)를 L1에 기록 | 출금 및 검증 용도 |
| **L1** | **Ethereum** | Sepolia (Testnet) / Mainnet | SystemConfig, Portal 등 컨트랙트 상주 |
| **DA Layer** | **Celestia** | Transaction Data 저장소 | Light Node 실행 필요 |

### 2.2. 폴더 구조 (Directory Structure)

```text
/project-root
├── .env                        # 환경 변수 (RPC URL, Private Keys)
├── deploy-config.json          # 배포 설정 (자체토큰, Alt-DA 정의)
├── docker-compose.yml          # 전체 인프라 실행 스크립트
├── config/                     # Genesis 및 Rollup 설정 (op-deployer 생성)
├── secrets/                    # 보안 키 (JWT, Sequencer Key, Batcher Key)
├── monitoring/                 # Prometheus, Grafana, Alertmanager 설정
└── gas-bot/                    # (별도) 가스비 자동 조정 봇 (Go)

```

---

## 3. 배포 및 설정 (Configuration)

### 3.1. `deploy-config.json` 핵심 설정

`op-deployer`를 통해 L1 컨트랙트를 배포할 때 사용하는 핵심 설정입니다.

```json
{
  "l1ChainID": 11155111,
  "l2ChainID": 12345678,
  "l2BlockTime": 2,
  
  "useCustomGasToken": true,
  "customGasTokenAddress": "0xYOUR_L1_ERC20_TOKEN_ADDRESS",
  
  "useAltDA": true,
  "daCommitmentType": "Generic"
}

```

### 3.2. 인프라 실행 (Docker Compose)

* **Celestia 연동:** `op-batcher` 컨테이너 실행 시 `--altda.da-server` 플래그로 Celestia Light Node와 연결합니다.
* **보안:** `op-geth`와 `op-node` 간 통신은 JWT Secret으로 암호화됩니다.

---

## 4. 경제 모델 및 가스비 정책 (Economics)

### 4.1. 문제 정의

* **User:** 자체 토큰(Token)으로 수수료 지불.
* **Sequencer:** 이더리움(ETH)으로 L1 수수료 지불 + Celestia(TIA)로 데이터 비용 지불.
* **Risk:** 토큰 가격 하락 or ETH 가격 상승 시 시퀀서 적자 발생.

### 4.2. 해결책: 동적 Scalar 조정

L1 `SystemConfig` 컨트랙트의 `Scalar` 값을 조정하여 환율 및 DA 비용 절감분을 반영합니다.

**공식:**


* **DA_Factor:** Celestia 사용에 따른 할인율 (초기 추천값: **0.1** = 90% 할인)
* **Overhead:** **2,100** (초기 고정값)

### 4.3. Gas Price Updater Bot (Go)

* **기능:** 주기적으로 CEX/DEX에서 ETH와 Token 가격을 조회하여 적정 Scalar 값을 계산하고 L1 컨트랙트를 업데이트합니다.
* **안전장치:** 급격한 변동 방지(Threshold), 최소/최대 Scalar 제한(Circuit Breaker).

---

## 5. 운영 및 모니터링 (Operations)

### 5.1. 모니터링 스택

* **Prometheus:** 각 노드(`op-node`, `op-batcher`)의 메트릭 수집.
* **Grafana:** 대시보드 시각화 (TPS, 블록 높이, P2P 상태).
* **Alertmanager:** 장애 발생 시 Slack/Discord 알림 전송.

### 5.2. 필수 알림 규칙 (Critical Alerts)

1. **Batcher ETH Low:** 시퀀서 지갑 잔고가 0.5 ETH 미만일 때 (즉시 충전 필요).
2. **DA Submission Failed:** Celestia 업로드 실패 시.
3. **L2 Reorg:** 체인 재구성이 감지될 때.

---

## 6. 최종 런칭 체크리스트 (Launch Checklist)

### Phase 1: 인프라 준비

* [ ] L1(Sepolia)에 ERC-20 토큰 배포 및 주소 확보.
* [ ] 배처(Batcher) 지갑에 ETH 충전 (Token 아님).
* [ ] Celestia Light Node 동기화 완료 및 RPC 확보.

### Phase 2: 배포

* [ ] `op-deployer`로 L1 컨트랙트 배포 (Bootstrap).
* [ ] `genesis.json`, `rollup.json` 생성 확인.
* [ ] Docker Compose로 L2 노드 전체 구동.

### Phase 3: 서비스 연동

* [ ] **Gas Bot** 실행 및 로그 확인 (Scalar 업데이트 정상 여부).
* [ ] **Blockscout** 탐색기 연결.
* [ ] **Bridge UI** 배포 (입출금 테스트).

---

## 7. 부록: 초기 경제 파라미터 추천값

| 파라미터 | 초기 설정값 | 설명 |
| --- | --- | --- |
| **Overhead** | `2100` | 배치 트랜잭션 기본 가스량 |
| **DA Factor** | `0.1` | ETH 대비 90% 저렴하게 책정 (안전마진 확보) |
| **Block Time** | `2초` | CLOB 성능 필요 시 1초 고려 (테스트 필수) |

