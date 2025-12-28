# 체크리스트 - SystemConfig.go 바인딩 파일을 프로젝트에 올바르게 Import하고, 실제 함수를 호출하는 방법

생성된 `SystemConfig.go` 바인딩 파일을 프로젝트에 올바르게 **Import**하고, 실제 **함수를 호출**하는 방법을 단계별로 체크해 드립니다.

Go 언어는 패키지 경로 설정이 중요하므로 폴더 구조부터 확인하겠습니다.

---

### 1. 폴더 구조 확인 (Directory Structure)

`abigen`으로 생성한 파일은 별도의 하위 폴더(패키지)에 두는 것이 관리에 좋습니다.

Plaintext

# 

`gas-bot/
├── go.mod                  # (go mod init gas-bot 으로 생성)
├── go.sum
├── main.go                 # 메인 로직
└── bindings/               # 하위 패키지 폴더
    └── SystemConfig.go     # (생성된 바인딩 파일)`

**체크 포인트:**

- `SystemConfig.go` 파일의 첫 줄이 `package bindings`로 되어 있는지 확인하세요. (abigen 명령어를 칠 때 `-pkg bindings` 옵션을 줬다면 맞게 되어 있을 겁니다.)

---

### 2. 프로젝트 초기화 (Go Modules)

아직 `go.mod` 파일이 없다면 터미널에서 아래 명령어를 실행하세요.

Bash

# 

`# 프로젝트 루트(gas-bot)에서 실행
go mod init gas-bot

# go-ethereum 등 의존성 다운로드
go get github.com/ethereum/go-ethereum
go mod tidy`

---

### 3. 코드 구현: Import 및 함수 호출 (`main.go`)

이제 `main.go`에서 `SystemConfig` 컨트랙트의 함수(`Scalar` 조회, `setGasConfig` 실행)를 호출하는 완성된 코드입니다.

Go

# 

`package main

import (
	"context"
	"log"
	"math/big"
	"os"

	// 👇 [중요] 생성한 바인딩 패키지 Import
	// "모듈명/폴더명" 형식입니다.
	"gas-bot/bindings" 

	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

func main() {
	// 1. 설정값 로드
	l1RpcUrl := "https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY"
	sysConfigAddrHex := "0xYourSystemConfigAddress" // L1 배포 주소
	privateKeyHex := "YOUR_PRIVATE_KEY_WITHOUT_0X" // Owner 권한 필요

	// 2. 클라이언트 연결
	client, err := ethclient.Dial(l1RpcUrl)
	if err != nil {
		log.Fatalf("RPC 연결 실패: %v", err)
	}

	// 3. [핵심] SystemConfig 바인딩 인스턴스 생성
	// bindings 패키지의 NewSystemConfig 함수가 자동 생성되어 있습니다.
	sysConfigAddress := common.HexToAddress(sysConfigAddrHex)
	sysConfig, err := bindings.NewSystemConfig(sysConfigAddress, client)
	if err != nil {
		log.Fatalf("바인딩 생성 실패: %v", err)
	}

	// ==========================================
	// A. 데이터 조회 (Call: 가스비 안 듦)
	// ==========================================
	// CallOpts는 nil로 두면 기본값(최신 블록)을 사용합니다.
	currentScalar, err := sysConfig.Scalar(nil) 
	if err != nil {
		log.Fatalf("Scalar 조회 실패: %v", err)
	}
	log.Printf("현재 Scalar 값: %s", currentScalar.String())

	// ==========================================
	// B. 데이터 변경 (Transact: 가스비 듦)
	// ==========================================
	
	// B-1. 트랜잭션 서명자(Auth) 생성
	privateKey, _ := crypto.HexToECDSA(privateKeyHex)
	chainID, _ := client.ChainID(context.Background())
	
	auth, err := bind.NewKeyedTransactorWithChainID(privateKey, chainID)
	if err != nil {
		log.Fatal(err)
	}
    // 필요 시 가스비 설정 (없으면 자동 추정)
	// auth.GasLimit = 300000 
	// auth.GasPrice = big.NewInt(20000000000) 

	// B-2. 함수 호출 (setGasConfig)
	// SystemConfig 컨트랙트는 setGasConfig(overhead, scalar) 형태입니다.
	newOverhead := big.NewInt(2100)       // 예: 고정값
	newScalar := big.NewInt(1500000)      // 예: 업데이트할 값

	tx, err := sysConfig.SetGasConfig(auth, newOverhead, newScalar)
	if err != nil {
		log.Fatalf("트랜잭션 전송 실패: %v", err)
	}

	log.Printf("업데이트 트랜잭션 전송 완료! Hash: %s", tx.Hash().Hex())
}`

---

### ✅ 4. 최종 체크리스트 (Troubleshooting)

코드를 실행하기 전, 다음 사항을 확인해보세요.

1. **함수 이름 대소문자:**
    - Solidity의 함수가 `scalar()` (소문자)여도, `abigen`이 생성한 Go 함수는 **대문자** `Scalar()`로 시작합니다. (Go에서는 대문자여야 외부에서 접근 가능하기 때문)
    - IDE(VS Code 등)에서 `sysConfig.` 뒤에 점을 찍었을 때 자동 완성이 뜨면 성공입니다.
2. **SystemConfig 주소:**
    - `deploy-config.json`을 통해 배포 후 생성된 `artifacts` 폴더 안의 파일이나, 배포 로그에서 **SystemConfigProxy** 주소를 정확히 가져왔는지 확인하세요. (Proxy 주소를 써야 합니다.)
3. **Owner 권한:**
    - `setGasConfig` 함수는 아무나 호출할 수 없습니다. `deploy-config.json`의 `finalSystemOwner` 지갑의 프라이빗 키를 사용해야 합니다.

**성공적으로 컴파일(`go build`) 되셨나요?** 혹시 `undefined: bindings.NewSystemConfig` 같은 에러가 나면 폴더 구조가 잘못된 것이니 다시 말씀해 주세요.