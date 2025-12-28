KMS를 사용하지 않고 로컬(On-Premise) 환경에서 보안을 구축하려면, **"소프트웨어 기반의 금고(Vault)"**를 도커로 띄워서 키를 관리하는 것이 정석입니다.

로컬 환경 보안의 핵심은 **"개인키 파일(.key)을 디스크에 평문으로 두지 않는 것"**입니다. 이를 위해 HashiCorp Vault와 Web3Signer를 조합하는 아키텍처를 추천합니다.

1. 보안 아키텍처: 로컬 KMS 구성
AWS KMS를 대체하기 위해 오픈소스 툴 두 가지를 추가로 실행합니다.

HashiCorp Vault: 키를 암호화해서 저장하는 **"디지털 금고"**입니다. (AWS KMS 역할)

Web3Signer (Consensys): op-batcher와 Vault 사이의 **"통역사"**입니다. op-batcher의 서명 요청을 받아 Vault에서 서명한 뒤 결과만 돌려줍니다.

데이터 흐름:

op-batcher (서명 요청) ➡️ Web3Signer (권한 확인) ➡️ HashiCorp Vault (개인키로 서명)

2. 구현 가이드 (Docker Compose)
기존 docker-compose.yml에 보안 서비스 두 개(vault, web3signer)를 추가하고, op-batcher 설정을 변경합니다.

단계 1: Docker Compose 서비스 추가
YAML

version: '3.8'

services:
  # ... (기존 l2-geth, l2-node 등) ...

  # 1. [신규] HashiCorp Vault (로컬 KMS)
  vault:
    image: hashicorp/vault:latest
    restart: unless-stopped
    ports:
      - "8200:8200"
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: "my-root-token" # 초기 설정용 (운영 시 변경 필수)
      VAULT_ADDR: "http://0.0.0.0:8200"
    cap_add:
      - IPC_LOCK # 메모리 스왑 방지 (보안)

  # 2. [신규] Web3Signer (서명 프록시)
  web3signer:
    image: consensys/web3signer:latest
    restart: unless-stopped
    ports:
      - "9000:9000"
    command:
      - --http-listen-port=9000
      - --http-listen-host=0.0.0.0
      - --metrics-enabled=true
      - eth2
      - --network=sepolia
      - --key-store-path=/key-files # 키 설정 파일 경로
    volumes:
      - ./security/web3signer:/key-files
    depends_on:
      - vault

  # 3. [수정] Batcher (원격 서명 사용)
  l2-batcher:
    # ... (이미지 등)
    command: >
      op-batcher
      --l1-eth-rpc=${L1_RPC_URL}
      --rollup-rpc=http://l2-node:8547
      # [변경] 개인키 파일 옵션 삭제 (--private-key)
      # [추가] 원격 서명 활성화
      --signer.enabled=true
      --signer.endpoint=http://web3signer:9000
      --signer.address=0xYourBatcherAddress
      # ... (나머지 옵션)
3. 키 생성 및 연동 절차 (최초 1회)
로컬 서버에서 Vault를 초기화하고 키를 생성하는 과정입니다. 이 과정은 서버 내부에서만 수행하며, 키는 절대 밖으로 나오지 않습니다.

1) Vault 설정 (터미널)
Bash

# Vault 컨테이너 접속
docker exec -it my-l2-chain-vault-1 sh

# 1. 로그인
vault login my-root-token

# 2. 이더리움용 시크릿 엔진 활성화 (Transit Engine)
vault secrets enable transit

# 3. Batcher용 키 생성 (키 이름: batcher-key)
# type=ecdsa-p256 (이더리움 호환 곡선)
vault write -f transit/keys/batcher-key type=ecdsa-p256

# 4. 생성된 키 확인 (Public Key만 보임)
vault read transit/keys/batcher-key
2) Web3Signer 설정 파일 작성
Web3Signer가 Vault에 접속할 수 있도록 설정 파일(security/web3signer/batcher.yaml)을 만듭니다.

YAML

type: "hashicorp-vault"
keyPath: "/transit/keys/batcher-key"
keyName: "batcher-key"
serverHost: "vault"
serverPort: 8200
token: "my-root-token" # 실제 운영에선 제한된 권한의 토큰 사용 권장
tlsEnabled: false
4. 관리자 키 (Admin Keys) 보안: 하드웨어 월렛
Deployer나 SystemOwner 같은 관리자 키는 서버(Vault)에도 두지 않는 것이 원칙입니다. **Ledger(하드웨어 월렛)**를 당신의 PC에 연결해서 사용하세요.

로컬 PC에서 명령어를 날리는 방법 (Foundry/Cast 사용):

Bash

# 예: 가스비 설정 변경 트랜잭션 (서버가 아닌 내 PC에서 실행)
# --ledger 옵션을 주면 USB로 연결된 Ledger에서 서명 승인을 요청함
cast send --ledger --rpc-url $L1_RPC_URL \
  --from 0xYourLedgerAddress \
  0xSystemConfigAddress \
  "setGasConfig(uint256,uint256)" 2100 500000
요약: 로컬 보안 강화 체크리스트
자동화 키 (Batcher/Proposer):

평문 파일 삭제 (rm secrets/*.key).

HashiCorp Vault + Web3Signer 도커 컨테이너 구동.

op-batcher가 Web3Signer를 바라보도록 --signer.endpoint 설정.

관리자 키 (Owner):

서버에 저장 금지.

Ledger 하드웨어 월렛 사용.

서버 물리 보안:

디스크 암호화 (Full Disk Encryption): 서버를 누가 훔쳐가도 하드디스크를 읽을 수 없게 리눅스 설치 시 LUKS 암호화를 적용하세요.

방화벽 (UFW): 8545(RPC), 8200(Vault) 포트는 외부에서 접속 불가능하게 막고 localhost나 VPN만 허용하세요.