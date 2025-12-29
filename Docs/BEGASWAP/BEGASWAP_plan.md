**BEGASwap(Uniswap V2 Fork) 구축 및 연동 작업 계획서**입니다.

이 계획은 단순한 토큰 스왑 기능을 넘어, **"시장 가격 형성(Price Discovery)"** 기능을 L2에 내재화하여 **Gas Oracle Bot**이 스스로 합리적인 가스비를 결정하게 만드는 고도화 작업입니다.

---

# 📑 Project: BEGASwap Integration Plan

## 1. 프로젝트 개요 (Overview)

* **목표:** BEGA L2 체인 위에 Uniswap V2 프로토콜을 포크하여 배포하고, **BEGA/ETH 유동성 풀(LP)**을 생성하여 실시간 시장 가격을 형성함.
* **용도:** Gas Oracle Bot이 이 풀의 가격을 참조하여 L2 Scalar(가스비)를 동적으로 조절.
* **기술 스택:**
* **Protocol:** Uniswap V2 (Core + Periphery)
* **Native Token Wrapper:** WBEGA (Canonical WETH9 Fork)
* **Tooling:** Foundry (Forge, Cast)
* **Language:** Solidity, TypeScript(Interface), Go(Bot Integration)



## 2. 핵심 구성 요소 (Components)

| 컴포넌트 | 역할 | 비고 |
| --- | --- | --- |
| **WBEGA** | Native Coin(BEGA)을 ERC-20으로 래핑 (WETH9 포크) | 스왑을 위해 필수 |
| **Factory** | 유동성 풀(Pair)을 생성하고 관리 | Uniswap V2 Core |
| **Router02** | 스왑 및 유동성 공급을 위한 프론트엔드용 관문 | Uniswap V2 Periphery |
| **BEGA/ETH Pair** | 실제 가격이 형성되는 유동성 풀 | **Gas Bot의 참조 대상** |

---

## 3. 단계별 상세 작업 계획 (Step-by-Step)

### Phase 1: 컨트랙트 준비 및 수정 (Preparation)

Uniswap V2는 오래된 Solidity 버전을 사용하므로, 최신 Foundry 환경에 맞게 조정이 필요합니다.

1. **Repository Setup:**
* `BEGASwap` 폴더 생성 및 Foundry 초기화.
* `uniswap-v2-core`, `uniswap-v2-periphery` 서브모듈 추가.


2. **Code Adaptation:**
* **WETH9.sol** → **WBEGA.sol**로 이름 변경 (심볼: WBEGA).
* **UniswapV2Factory.sol**: `feeToSetter` 설정 (관리자 주소).
* **UniswapV2Library.sol**: **가장 중요!** Factory에서 컴파일된 **Pair Contract의 Init Code Hash**를 직접 계산하여 하드코딩 교체해야 함 (이거 안 하면 Router가 작동 안 함).



### Phase 2: 배포 (Deployment)

로컬 L2(`localhost:8545`)에 순서대로 배포합니다.

1. **배포 순서:**
1. `WBEGA` 배포.
2. `UniswapV2Factory` 배포 → **Init Code Hash 추출**.
3. (라이브러리 수정: 추출한 Hash 값 업데이트).
4. `UniswapV2Router02` 배포 (WBEGA 주소, Factory 주소 주입).
5. `Multicall3` (이미 배포됨, 확인만).


2. **검증:**
* Blockscout(BEGAScan)에서 배포된 컨트랙트 코드 확인.



### Phase 3: 유동성 공급 (Liquidity Provision)

UI를 만들지 않고 스크립트(`cast`)로 초기 유동성을 공급하여 가격을 세팅합니다.

1. **자산 준비:**
* **Native BEGA**: Deployer 지갑에 있음.
* **Bridged ETH**: L1(Sepolia)에서 L2로 ETH를 브릿징하여 **L2상의 ETH(ERC-20)** 확보.


2. **유동성 추가 (Add Liquidity):**
* `WBEGA`에 Native BEGA 입금 (Deposit).
* `Router02.addLiquidity` 호출.
* **비율 설정:** 예) `1 ETH` : `2000 BEGA` (초기 가격 $1.5 설정).



### Phase 4: Gas Oracle Bot 연동 (Integration)

봇이 더 이상 랜덤값이 아닌, 이 풀의 데이터를 읽도록 업그레이드합니다.

1. **Go Binding 생성:** `UniswapV2Pair` 컨트랙트의 ABI로 Go 바인딩 생성.
2. **봇 로직 수정 (`gas-bot/main.go`):**
* `getReserves()` 함수 호출.
* `Reserve0` / `Reserve1` 비율 계산.
* 최종 가격 산출 → Scalar 업데이트.



---

## 4. 예상 소요 시간 및 리소스

* **Phase 1 & 2 (배포):** 2~3시간 (Init Code Hash 이슈 해결 포함)
* **Phase 3 (유동성):** 1시간 (브릿징 시간 포함)
* **Phase 4 (봇 연동):** 2시간
* **총 예상 시간:** 약 1일

---

### 💡 아키텍트의 조언 (Tips)

1. **Frontend는 나중에:** "BEGASwap"이라는 거창한 이름이지만, 당장 웹사이트(React)까지 만들 필요는 없습니다. **가격 데이터 생성**이 목적이므로 컨트랙트만 배포하면 됩니다.
2. **Init Code Hash 주의:** Uniswap 포크 시 99%가 여기서 실패합니다. Factory 배포 후 `pairCodeHash()`를 조회해서 라이브러리에 박아넣는 과정을 꼭 거쳐야 합니다.
3. **L2 ETH:** L2에서 "ETH"는 Native Token이 아니라 **"Optimism Mintable ERC20"** 형태입니다. 브릿지를 통해 넘어온 ETH의 컨트랙트 주소를 정확히 알아야 Pair를 만들 수 있습니다.

---

###  다음 작업 지시 (Action Item)

use agent dapp-develper

System Context: BEGASwap (Uniswap V2 Fork) Deployment
1. Project Identity
Project Name: BEGASwap (On-chain Price Source for Gas Oracle)

Target Network: BEGA L2 Local Testnet (http://localhost:8545)

Chain ID: 12345678

Native Currency: BEGA (Custom Gas Token)

Goal: Deploy Uniswap V2 contracts to create a WBEGA/ETH liquidity pool, enabling the Gas Oracle Bot to fetch real-time market prices.

2. Technical Constraints & Requirements
Tooling: Foundry (Forge, Cast)

Solidity Version: Must handle version compatibility (Uniswap V2 uses older versions, 0.5.16 / 0.6.6).

Critical Issue (The "Init Code Hash"):

Uniswap V2 Library calculates pair addresses using a hardcoded Init Code Hash.

Since we are deploying a fresh Factory, the Pair Init Code Hash will differ from Mainnet.

Requirement: The deployment process MUST calculate the new Init Code Hash from the deployed Factory and update the UniswapV2Library (or Router) before deploying the Router.

3. Required Contracts
WBEGA.sol: A canonical WETH9 implementation, but renamed to WBEGA. Wraps the native gas token (BEGA).

UniswapV2Factory.sol: Core factory contract.

UniswapV2Router02.sol: Periphery router contract (Needs correct Factory address and WBEGA address).

Multicall3: Already deployed at 0xcA11... (Skip deployment, just verify).

4. Execution Directory
Path: /Users/kangmunil/Project/BEGASwap (New directory to be created).