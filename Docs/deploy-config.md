OP Stack에서 **자체 가스 토큰(Custom Gas Token)**과 **Celestia DA(Alt-DA)**를 동시에 적용하기 위한 `deploy-config.json`의 전체 템플릿입니다.

이 설정 파일은 **Geth 코드를 수정하지 않고**, 배포 스크립트(`op-deployer` 또는 Monorepo의 `deploy-config`)가 읽어들여 L2 제네시스 설정과 컨트랙트 배포 방식을 결정하는 핵심 파일입니다.

### 📝 deploy-config.json 템플릿

이 파일은 `optimism/packages/contracts-bedrock/deploy-config/` 경로 등에 위치하게 되며, 실제 배포 시 `--configPath`로 지정합니다.

**주의:** 주석(`//`)은 JSON 표준이 아니므로 실제 파일 저장 시에는 제거해야 합니다.

JSON

# 

`{
  "comment": "Prediction Market L2 Configuration with Custom Gas Token & Celestia DA",
  
  "l1ChainID": 11155111,  
  "l2ChainID": 12345678, 
  "l2BlockTime": 2, 
  "l2GenesisBlockGasLimit": "0x1c9c380", 
  "l2GenesisBlockBaseFeePerGas": "0x3b9aca00", 

  "finalSystemOwner": "0xYourAdminAddressHere", 
  "superchainConfigGuardian": "0xYourAdminAddressHere", 
  "l1SmartContractOwner": "0xYourAdminAddressHere", 
  "proxyAdminOwner": "0xYourAdminAddressHere", 
  "baseFeeVaultRecipient": "0xYourFeeReceiverAddress", 
  "l1FeeVaultRecipient": "0xYourFeeReceiverAddress", 
  "sequencerFeeVaultRecipient": "0xYourFeeReceiverAddress", 

  "gasPriceOracleOverhead": 2100, 
  "gasPriceOracleScalar": 1000000, 

  "governanceTokenSymbol": "OP", 
  "governanceTokenName": "Optimism", 
  "governanceTokenOwner": "0xYourAdminAddressHere", 

  "p2pSequencerAddress": "0xYourSequencerAddress", 
  "batchInboxAddress": "0xYourBatchInboxAddress", 
  "batchSenderAddress": "0xYourBatchSenderAddress", 
  "l2OutputOracleProposer": "0xYourProposerAddress", 
  "l2OutputOracleChallenger": "0xYourChallengerAddress", 

  "l1BlockTime": 12, 

  "l2GenesisDeltaTimeOffset": "0x0", 
  "l2GenesisEip1559Elasticity": 6, 
  "l2GenesisEip1559Denominator": 50, 

  "systemConfigStartBlock": 0, 

  "requiredProtocolVersion": "0x0000000000000000000000000000000000000000000000000000000000000000", 
  "recommendedProtocolVersion": "0x0000000000000000000000000000000000000000000000000000000000000000", 

  "fundDevAccounts": true, 

  "useCustomGasToken": true, 
  "customGasTokenAddress": "0xYOUR_L1_ERC20_TOKEN_ADDRESS", 

  "useAltDA": true, 
  "daCommitmentType": "Generic", 
  "daChallengeWindow": 100, 
  "daResolveWindow": 100, 
  "daBondSize": 0, 
  "daResolverRefundPercentage": 0 
}`

---

### 🔑 핵심 설정 필드 상세 설명

위 템플릿에서 **예측 시장 L2 개발**을 위해 반드시 수정/확인해야 할 부분입니다.

### 1. 자체 가스 토큰 설정 (Native Gas Token)

이 부분이 설정되면, L2의 `OptimismPortal` 컨트랙트가 ETH 대신 지정된 ERC-20 토큰을 입금받고, L2에서 네이티브 코인(Gas)으로 발행합니다.

- `"useCustomGasToken": true`
    - 배포 스크립트에게 이 체인이 커스텀 가스 토큰 모드임을 알립니다.
- `"customGasTokenAddress": "0xYOUR_L1_ERC20_TOKEN_ADDRESS"`
    - **중요:** L1(Sepolia 등)에 미리 배포된 **ERC-20 토큰의 컨트랙트 주소**를 넣어야 합니다.
    - **조건:** 해당 토큰은 표준 ERC-20 구현체여야 하며, `18 decimals`를 사용하는 것이 권장됩니다 (EVM 산술 호환성 때문).

### 2. Celestia DA 설정 (Alt-DA)

Celestia를 사용하기 위해 OP Stack의 **Alt-DA 모드**를 활성화합니다.

- `"useAltDA": true`
    - 데이터 가용성(DA) 계층을 이더리움 calldata/blobs 대신 외부 솔루션으로 돌립니다.
- `"daCommitmentType": "Generic"`
    - 이더리움 L1에는 데이터 본문 대신 **데이터에 대한 포인터(Commitment/Hash)**만 저장하겠다는 의미입니다.
    - Celestia의 경우 데이터는 Celestia에 저장되고, 그 증명(Commitment)만 L1의 `BatchInbox`로 전송됩니다.

### 3. 네트워크 및 운영자 설정

- `"l2ChainID"`: 메타마스크에 추가할 고유 Chain ID입니다. (충돌 방지를 위해 Chainlist.org 등 확인)
- `"l2BlockTime"`: **2** (초). CLOB 등 빠른 반응이 필요하면 1초로 줄일 수 있으나, P2P 전파 안정성을 충분히 테스트해야 합니다.
- `"xxxAddress"`:
    - `finalSystemOwner`: 모든 권한을 가진 관리자 지갑.
    - `batchSenderAddress`: Celestia 및 L1에 데이터를 올릴 주체(op-batcher). **ETH가 충분히 있어야 합니다.** (L1 수수료 지불용)

---

### ⚙️ 배포 전 체크리스트

1. **L1 토큰 배포:** `customGasTokenAddress`에 들어갈 토큰이 L1(Sepolia)에 배포되어 있어야 합니다.
2. **Decimals 확인:** 가스 토큰의 소수점(Decimals)이 18이 아닐 경우, `op-node` 설정에서 변환 로직이 복잡해질 수 있으므로 **반드시 18 Decimals**로 만드세요.
3. **L1 수수료 준비:**
    - 사용자는 **자체 토큰**으로 가스비를 내지만,
    - `BatchSender`(시퀀서)는 L1에 데이터를 기록할 때 **ETH**를 씁니다.
    - 따라서 운영자 지갑(`batchSenderAddress`)에는 항상 ETH가 충전되어 있어야 합니다.