- *자체 토큰(Native Gas Token)**을 사용하는 L2에서 시퀀서의 파산을 막기 위한 **"Gas Price Updater Bot"**의 설계 및 구현 가이드입니다.

OP Stack 생태계가 Go 언어 기반이므로, 호환성과 성능을 위해 **Go (Golang)**로 작성하는 것을 강력히 추천합니다.

---

### 1. 봇의 핵심 로직 (Logic Flow)

이 봇의 목표는 **"L1(ETH) 대비 자체 토큰의 가치 하락분을 L2 가스비(Scalar) 인상으로 상쇄"**하는 것입니다.

핵심 공식:

$$TargetScalar = \frac{Price_{ETH}}{Price_{Token}} \times \text{SafetyMargin}$$

- **L1 SystemConfig Contract:** L2의 가스비 정책(Scalar, Overhead)을 관리하는 컨트랙트는 **L1(이더리움/Sepolia)**에 배포되어 있습니다. 따라서 봇은 **L1 RPC**와 통신해야 합니다.

### 워크플로우

1. **Price Fetch:** CEX(Upbit, Binance) 또는 DEX API에서 `ETH`와 `Token`의 현재가($)를 가져옵니다.
2. **Calculate Ratio:** `ETH 가격 / Token 가격` 비율을 계산합니다.
3. **Read On-chain Data:** L1 SystemConfig 컨트랙트에서 현재 설정된 `Scalar` 값을 조회합니다.
4. **Compare & Threshold:**
    - `(새로 계산된 Scalar - 현재 Scalar) / 현재 Scalar` 가 임계값(예: 5%) 이상일 때만 업데이트합니다. (가스비 낭비 방지)
5. **Execute Transaction:** L1 SystemConfig 컨트랙트의 `setGasConfig` 함수를 호출하여 값을 업데이트합니다.

---

### 2. 구현 코드 (Golang)

이 코드는 `go-ethereum` 라이브러리를 사용하며, 실제 환경에서는 OP Stack의 `SystemConfig` ABI 바인딩이 필요합니다.

### 사전 준비

- `bindings/SystemConfig.go`: `abigen`으로 생성된 SystemConfig 컨트랙트 바인딩 파일.
- `.env`: RPC URL 및 Private Key 관리.

### `main.go` 예시

Go

# 

`package main

import (
	"context"
	"fmt"
	"log"
	"math/big"
	"os"
	"time"

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
    // "your-project/bindings" // SystemConfig 바인딩 임포트
)

// 설정 상수
const (
    UpdateThresholdPercent = 5.0  // 5% 이상 변동 시 업데이트
    SafetyMargin           = 1.1  // 10% 안전마진 (시퀀서 수익 보장)
    CheckInterval          = 30 * time.Second
)

// 시뮬레이션용 가격 조회 함수 (실제로는 CEX/DEX API 연동)
func getPrices() (float64, float64, error) {
    // TODO: Coingecko or Binance API 호출
    ethPrice := 3000.0   // 예: $3000
    tokenPrice := 1.5    // 예: $1.5
    return ethPrice, tokenPrice, nil
}

func main() {
    // 1. L1 클라이언트 연결 (Sepolia 등)
    l1RpcUrl := os.Getenv("L1_RPC_URL")
    client, err := ethclient.Dial(l1RpcUrl)
    if err != nil {
        log.Fatalf("Failed to connect to L1 RPC: %v", err)
    }

    // 2. 지갑 로드 (SystemConfig의 Owner 또는 GasConfig 권한자)
    privateKey, err := crypto.HexToECDSA(os.Getenv("OPERATOR_PRIVATE_KEY"))
    if err != nil {
        log.Fatal(err)
    }

    // 3. SystemConfig 컨트랙트 바인딩
    sysConfigAddr := common.HexToAddress(os.Getenv("SYSTEM_CONFIG_ADDRESS"))
    // sysConfig, err := bindings.NewSystemConfig(sysConfigAddr, client) // 실제 바인딩 사용 시
    // if err != nil { log.Fatal(err) }

    log.Println("Gas Price Updater Bot Started...")

    // 4. 메인 루프
    ticker := time.NewTicker(CheckInterval)
    for range ticker.C {
        // A. 가격 조회
        ethPrice, tokenPrice, err := getPrices()
        if err != nil {
            log.Println("Error fetching prices:", err)
            continue
        }

        // B. 목표 Scalar 계산 (ETH가 비싸거나 토큰이 싸지면 Scalar는 커져야 함)
        // 공식: (ETH Price / Token Price) * 1,000,000 (Decimals 보정) * SafetyMargin
        // *OP Stack의 Scalar는 보통 6자리 소수점을 가집니다 (1 = 1,000,000)
        ratio := ethPrice / tokenPrice
        targetScalarFloat := ratio * 1000000 * SafetyMargin
        targetScalar := big.NewInt(int64(targetScalarFloat))

        // C. 현재 온체인 Scalar 조회
        // currentGasConfig, _ := sysConfig.GasConfig(&bind.CallOpts{})
        // currentScalar := currentGasConfig.Scalar
        currentScalar := big.NewInt(2000000000) // Mock value for logic demonstration

        // D. 변동폭 계산 (Threshold 체크)
        diff := new(big.Int).Sub(targetScalar, currentScalar)
        diffAbs := new(big.Int).Abs(diff)
        
        // 변동률 = (Diff / Current) * 100
        changeRate := new(big.Float).Quo(new(big.Float).SetInt(diffAbs), new(big.Float).SetInt(currentScalar))
        changeRateFloat, _ := changeRate.Float64()

        if changeRateFloat*100 < UpdateThresholdPercent {
            log.Printf("Scalar stable. Current: %s, Target: %s, Change: %.2f%%", currentScalar, targetScalar, changeRateFloat*100)
            continue
        }

        // E. 트랜잭션 전송 (업데이트)
        log.Printf("Updating Scalar! Current: %s -> Target: %s", currentScalar, targetScalar)
        
        chainId, _ := client.ChainID(context.Background())
        auth, _ := bind.NewKeyedTransactorWithChainID(privateKey, chainId)
        
        // 실제 트랜잭션 전송
        // tx, err := sysConfig.SetGasConfig(auth, currentGasConfig.Overhead, targetScalar)
        // if err != nil {
        //     log.Printf("Failed to update scalar: %v", err)
        // } else {
        //     log.Printf("Tx Sent: %s", tx.Hash().Hex())
        // }
    }
}`

---

### 3. 주요 고려사항 및 안전장치

봇이 오작동하면 L2 전체가 멈추거나(수수료 과다), 시퀀서가 파산할 수 있습니다. 다음 안전장치를 코드에 반드시 추가하세요.

1. **Circuit Breaker (상한/하한 설정):**
    - API 오류로 `TokenPrice`가 0에 수렴하면 `Scalar`가 무한대로 치솟습니다.
    - `MinScalar`와 `MaxScalar` 하드코딩된 제한을 두어, 봇이 터무니없는 값으로 설정을 변경하지 못하게 막으세요.
2. **가스비(ETH) 관리:**
    - 이 봇은 L1 트랜잭션을 발생시킵니다. 즉, 봇 운영 지갑(Operator Wallet)에 ETH가 항상 있어야 합니다.
    - 업데이트 빈도가 너무 잦으면 L1 가스비 낭비가 심합니다. `UpdateThresholdPercent`를 5~10% 정도로 넉넉하게 잡으세요.
3. **Celestia(Alt-DA) 고려:**
    - 위 공식은 **ETH에 데이터를 올릴 때** 기준입니다.
    - Celestia를 쓰면 데이터 저장 비용은 TIA로 나가거나 저렴하지만, **데이터 커밋(Hash) 비용**은 여전히 ETH로 나갑니다.
    - 따라서 `Overhead` 값은 낮추되, `Scalar`는 여전히 ETH 가격 변동에 민감하게 반응하도록 설계해야 합니다.

### 4. 배포 환경 (Infrastructure)

- **Docker:** 이 봇을 Docker 컨테이너로 패키징하여 K8s 클러스터에 배포하세요.
- **Prometheus/Grafana:** 봇이 계산한 `TargetScalar`와 실제 `OnChainScalar`를 메트릭으로 내보내서, 봇이 제대로 돌고 있는지 시각화해야 합니다.

### 


---

### 1. Dockerfile 추가 (경로: `gas-bot/Dockerfile`)

봇을 도커 이미지로 만들기 위한 명세서입니다. HTTPS 요청(가격 조회)을 위해 인증서(`ca-certificates`) 설치가 필수입니다.

```dockerfile
# Build Stage
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN go build -o gas-bot main.go

# Run Stage (가벼운 Alpine 리눅스 사용)
FROM alpine:latest
WORKDIR /app
# API 호출을 위한 SSL 인증서 설치 (필수)
RUN apk --no-cache add ca-certificates
COPY --from=builder /app/gas-bot .

CMD ["./gas-bot"]

```

---

### 2. Docker Compose에 서비스 추가 (`docker-compose.yml`)

L2 노드들이 실행될 때 이 봇도 같이 실행되도록 `services` 섹션 맨 아래에 추가합니다.

```yaml
  # ... (기존 l2-geth, l2-node 등) ...

  # [추가] Gas Price Updater Bot (경제적 안전장치)
  gas-oracle:
    build: ./gas-bot         # gas-bot 폴더에 Dockerfile이 있어야 함
    restart: unless-stopped
    environment:
      - L1_RPC_URL=${L1_RPC_URL}
      - OPERATOR_PRIVATE_KEY=${OPERATOR_PRIVATE_KEY} # .env에 추가 필요
      - SYSTEM_CONFIG_ADDRESS=${SYSTEM_CONFIG_ADDRESS} # 배포 후 .env에 주소 입력
    depends_on:
      - l2-node # (선택사항) 논리적 그룹핑

```

---

### 3. 실제 가격 조회 코드 (Go)

`bot.md`에 있던 가짜 함수(`getPrices`) 대신, **Binance 공용 API**를 통해 실제 시세를 가져오는 코드로 대체하는 예시입니다.

```go
import (
    "encoding/json"
    "net/http"
    "strconv"
    // ... 기존 import
)

type TickerResponse struct {
    Symbol string `json:"symbol"`
    Price  string `json:"price"`
}

// 실제 거래소(Binance) API를 호출하여 가격 조회
func getPrices() (float64, float64, error) {
    // 1. ETH 가격 조회 (Binance)
    ethPrice, err := fetchBinancePrice("ETHUSDT")
    if err != nil {
        return 0, 0, err
    }

    // 2. 자체 토큰 가격 조회 (예: 상장된 거래소 API 사용)
    // 상장 전이라면 고정값(예: $0.5)을 리턴하거나, DEX Pool 컨트랙트를 조회해야 함
    tokenPrice := 0.5 

    return ethPrice, tokenPrice, nil
}

// 보조 함수: URL에서 JSON 파싱
func fetchBinancePrice(symbol string) (float64, error) {
    url := "https://api.binance.com/api/v3/ticker/price?symbol=" + symbol
    resp, err := http.Get(url)
    if err != nil {
        return 0, err
    }
    defer resp.Body.Close()

    var ticker TickerResponse
    if err := json.NewDecoder(resp.Body).Decode(&ticker); err != nil {
        return 0, err
    }

    return strconv.ParseFloat(ticker.Price, 64)
}

```
