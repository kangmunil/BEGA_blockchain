# Celestia를 쓸 때 Overhead와 Scalar 값을 초기 세팅하는 경제적 계산법

- *Celestia(Alt-DA)**와 **자체 가스 토큰**을 사용할 때, `SystemConfig`의 `Overhead`와 `Scalar` 값을 결정하는 것은 단순한 설정이 아니라 **"L2의 수익성(적자 방지)"과 "사용자 경험(저렴한 가스비)"의 균형을 맞추는 경제 모델링**입니다.

이더리움 DA를 쓸 때와 달리, **"데이터 비용은 TIA로, 정산 비용은 ETH로, 수입은 자체 토큰으로"** 발생하므로 계산식이 달라져야 합니다.

초기 세팅을 위한 **실전 계산 공식**을 정리해 드립니다.

---

### 1. 기본 개념 잡기

OP Stack의 L1 데이터 수수료(L1 Data Fee) 계산 공식은 다음과 같습니다.

$$Fee_{Data} = (\text{TxSize} \times 16 + \text{Overhead}) \times \text{L1\_BaseFee} \times \text{Scalar}$$

- **Overhead (고정비):** 트랜잭션 당 붙는 기본 가스량 (배처 트랜잭션 비용의 N분할).
- **Scalar (변동비 계수):** L1 가스비에 곱해지는 가중치. **이 값을 조절하여 환율과 DA 비용 절감분을 반영**해야 합니다.

---

### 2. 값 산출 공식 (The Math)

### A. Overhead: "배처 트랜잭션의 기본 비용"

Celestia를 써도 배처(Batcher)는 이더리움 L1에 **"데이터 해시(Commitment)"**를 기록하는 트랜잭션을 날립니다.

- **배처 Tx 기본 가스:** 약 21,000 (기본) + 50,000 (컨트랙트 호출 및 로직) ≈ **70,000 Gas**
- **배치 당 트랜잭션 수:** 초기에는 적으므로 보수적으로 10~50개 가정.
- **계산:** $70,000 \div 50 = 1,400$
- **추천 설정값:** **2,100** (OP Stack 기본값)
    - *이유:* 초기엔 트랜잭션이 적어 배치 효율이 떨어지므로 기본값을 유지하여 안전마진을 확보하세요.

### B. Scalar: "환율 보정 + DA 할인율" (핵심)

Scalar는 다음 두 가지 요소를 곱해서 결정합니다.

1. **환율 비율 (Price Ratio):** ETH 대비 자체 토큰이 얼마나 싼가?
    - $\text{Ratio} = \frac{\text{ETH Price}}{\text{Token Price}}$
    - *예:* ETH 300만원, 토큰 300원 → 10,000배 차이.
2. **DA 할인율 (DA Factor):** Celestia가 이더리움보다 얼마나 싼가?
    - 이더리움 Blob 대비 Celestia 비용은 보통 **1/100 ~ 1/1000** 수준입니다.
    - 초기에는 너무 싸게 받으면 위험하므로 **0.05 (95% 할인)** 정도로 보수적으로 잡습니다.

$$TargetScalar = 1,000,000 \times \left( \frac{\text{Price}_{ETH}}{\text{Price}_{Token}} \right) \times \text{DA\_Factor}$$

(참고: OP Stack의 Scalar 기본 단위는 6자리 소수점(1,000,000 = 1.0)입니다.)

---

### 3. 실전 시뮬레이션 (Example)

가정을 해보겠습니다.

- **ETH 가격:** $2,500
- **자체 토큰(MYT) 가격:** $0.5
- **DA 할인 목표:** 이더리움 대비 95% 저렴하게 제공 (Factor = 0.05)

### 1) 환율 비율 계산

$$Ratio = \frac{2500}{0.5} = 5,000$$

(즉, 1 ETH 가치를 채우려면 5,000 MYT를 받아야 함)

### 2) 최종 Scalar 계산

$$Scalar = 1,000,000 \times 5,000 \times 0.05$$

$$Scalar = 250,000,000,000$$

- **해석:**
    - 만약 Celestia를 안 썼다면 Scalar는 $1,000,000 \times 5,000 = 5,000,000,000$ 이어야 합니다.
    - Celestia 덕분에 비용이 줄었으므로, 사용자에게 50억 대신 **2.5억**의 Scalar만 적용하여 가스비를 1/20로 깎아주는 것입니다.

---

### 4. `deploy-config.json` 초기 세팅값 추천

초기 런칭 시에는 **"적자를 보지 않는 것"**이 최우선입니다. 따라서 DA 할인율을 0.1(90% 할인) 정도로 보수적으로 잡고 시작하세요.

**가정: ETH $2,500 / Token $0.5**

JSON

# 

`{
  "gasPriceOracleOverhead": 2100,
  "gasPriceOracleScalar": 500000000000 
}`

- **Overhead:** 2100 (고정)
- **Scalar:** 500,000,000,000
    - 계산: $1M \times (2500/0.5) \times 0.1$
    - 의미: 이더리움 메인넷 가스비 로직을 따르되, **토큰 가격 차이를 보정**하고 **Celestia 효과로 90% 할인**된 가격을 청구함.

---

### 5. 운영 중 조정 전략 (Bot 활용)

이 초기값은 고정불변이 아닙니다. 앞서 만든 **Gas Price Updater 봇**이 이 공식을 실시간으로 수행해야 합니다.

**봇에 들어갈 로직 수정:**

Python

# 

`# Python 슈도코드

ETH_PRICE = get_price("ETH")
TOKEN_PRICE = get_price("MY_TOKEN")

# 상수: 1.0 = 1,000,000 (OP Stack Decimals)
BASE_DECIMALS = 1000000 

# 정책: Celestia 비용이 ETH의 5%라고 가정 (안전마진 포함)
DA_DISCOUNT_FACTOR = 0.05 

# 환율에 따른 기본 비율
price_ratio = ETH_PRICE / TOKEN_PRICE

# 최종 Scalar 계산
target_scalar = int(BASE_DECIMALS * price_ratio * DA_DISCOUNT_FACTOR)

# 만약 target_scalar가 너무 낮으면(최소 수익 보장), 하한선 적용
MIN_SCALAR = 1000000 # 최소 1배수
if target_scalar < MIN_SCALAR:
    target_scalar = MIN_SCALAR

update_on_chain(target_scalar)`

### 💡 요약

1. **Overhead:** **2100** (초기에 건드리지 마세요)
2. **Scalar:** $\frac{\text{ETH가격}}{\text{토큰가격}} \times 0.1 \times 1,000,000$ (초기값)
3. **전략:** 처음엔 비싸게(할인율 10%) 시작하고, 배처(Batcher)의 실제 ETH 지출과 Celestia TIA 지출을 일주일간 모니터링한 뒤, 수익이 남으면 할인율을 더 적용(0.05 -> 0.01)해서 가스비를 낮추세요.

