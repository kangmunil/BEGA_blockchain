# SystemConfig 컨트랙트와 통신을 위한 ABI(Application Binary Interface)

**Gas Price Updater 봇**을 개발하기 위해 `SystemConfig` 컨트랙트와 통신하려면 **ABI(Application Binary Interface)**가 반드시 필요합니다.

OP Stack 모노레포를 이미 클론하셨으므로, 소스코드에서 직접 빌드하여 추출하는 것이 가장 정확하고 안전합니다. Go 언어 봇을 만드시므로 **ABI 파일 추출** 방법과 **Go 바인딩(Binding) 생성** 방법 두 가지를 모두 알려드립니다.

---

### 방법 1. 모노레포에서 직접 빌드하여 추출 (가장 권장)

OP Stack의 스마트 컨트랙트는 `Foundry` 프레임워크를 사용합니다.

### 1. 빌드 실행

터미널에서 `optimism` 프로젝트 폴더로 이동하여 컨트랙트 패키지를 빌드합니다.

Bash

# 

`cd optimism/packages/contracts-bedrock

# Foundry(forge)가 없다면 설치 (이미 설치되어 있다면 생략)
# curl -L https://foundry.paradigm.xyz | bash
# foundryup

# 컨트랙트 빌드
forge build`

### 2. ABI JSON 파일 위치 확인

빌드가 완료되면 `forge-artifacts` 폴더에 결과물이 생성됩니다.

- 파일 위치:
    
    packages/contracts-bedrock/forge-artifacts/SystemConfig.sol/SystemConfig.json
    

### 3. 순수 ABI만 추출하기 (jq 사용)

위 `SystemConfig.json` 파일에는 바이트코드, 메타데이터 등이 섞여 있습니다. `abi` 필드만 깔끔하게 뽑아내려면 `jq`를 사용하거나 텍스트 에디터에서 복사하세요.

Bash

# 

`# abi 부분만 추출해서 SystemConfig.abi 파일로 저장
jq .abi ./forge-artifacts/SystemConfig.sol/SystemConfig.json > SystemConfig.abi`

> 팁: 이제 이 SystemConfig.abi 파일을 봇 프로젝트 폴더로 복사해서 사용하면 됩니다.
> 

---

### 방법 2. Go 개발자를 위한 `abigen` 바인딩 생성 (봇 개발용)

Go(Golang)로 봇을 만들 때는 ABI JSON 파일을 직접 로드하는 것보다, **Go 코드로 변환(Binding)**해서 함수처럼 호출하는 것이 훨씬 편하고 강력합니다. (Type-safe)

### 1. abigen 도구 설치

`go-ethereum`에 포함된 도구입니다.

Bash

# 

`go install github.com/ethereum/go-ethereum/cmd/abigen@latest`

### 2. Go 바인딩 파일 생성

위에서 추출한 ABI를 가지고 Go 파일을 만듭니다.

Bash

# 

`# 1. ABI 파일이 있는 곳에서 실행
# --pkg: Go 패키지 이름 (bindings)
# --type: 생성할 Go 구조체 이름 (SystemConfig)
# --out: 저장할 파일명 (SystemConfig.go)

abigen --abi=SystemConfig.abi --pkg=bindings --type=SystemConfig --out=SystemConfig.go`

### 3. 프로젝트에 적용

생성된 `SystemConfig.go` 파일을 봇 프로젝트의 `bindings` 폴더 등에 넣으면, 아까 보여드린 코드 예시처럼 바로 사용할 수 있습니다.

Go

# 

`// 예시: 생성된 바인딩 사용
import "my-bot/bindings"

// ...
sysConfig, err := bindings.NewSystemConfig(address, client)`

---

### 방법 3. 귀찮다면? (표준 ABI 복사)

만약 빌드 과정이 번거롭다면, OP Stack의 표준 `SystemConfig` ABI는 거의 변하지 않으므로 아래 내용을 그대로 `SystemConfig.abi` 파일로 저장해서 쓰셔도 됩니다. (핵심 함수인 `setGasConfig`, `scalar` 등만 포함된 축약본입니다.)

**SystemConfig.abi (축약본)**

JSON

# 

`[
  {
    "inputs": [],
    "name": "scalar",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "overhead",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "gasConfig",
    "outputs": [
      {"internalType": "uint256", "name": "overhead", "type": "uint256"},
      {"internalType": "uint256", "name": "scalar", "type": "uint256"}
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "uint256", "name": "_overhead", "type": "uint256"},
      {"internalType": "uint256", "name": "_scalar", "type": "uint256"}
    ],
    "name": "setGasConfig",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
]`

###