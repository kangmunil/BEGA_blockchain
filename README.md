# BEGA Prediction Market L2

High-performance Ethereum L2 blockchain for prediction markets and CLOB (Central Limit Order Book) applications, built on OP Stack with custom gas token and Celestia DA.

## 🎉 Current Status: **DEPLOYED & OPERATIONAL**

- ✅ L1 Contracts deployed on Sepolia
- ✅ L2 Chain running (Chain ID: 12345678)
- ✅ Custom Gas Token (BEGA) active
- ✅ Celestia DA integration operational
- ✅ Block Explorer (BEGAScan) running
- ✅ RPC accepting transactions

## Architecture Overview

- **Execution Layer**: op-geth (standard EVM)
- **Consensus Layer**: op-node (sequencer)
- **Data Availability**: Celestia (Alt-DA for 90% cost reduction)
- **Gas Token**: BEGA (Custom ERC-20 token, not ETH)
- **Settlement**: Ethereum Sepolia Testnet
- **Block Explorer**: Blockscout (BEGAScan)

## Key Features

- **Custom Gas Token**: Users pay transaction fees with BEGA token
- **Celestia DA**: Dramatically reduced data storage costs
- **No Fork Policy**: Uses standard OP Stack without modifications
- **Economic Safety**: Automated gas price adjustment bot (optional)
- **Fast Block Time**: 2-second blocks
- **Full EVM Compatibility**: Deploy any Ethereum smart contract

## Deployed Addresses

### L1 Contracts (Sepolia Testnet)
```bash
L1 BEGA Token:     0x55B746d21bCEb81374e818C809d0a8145e4Be2e1
L1 Bridge:         0xe07c38a86d385298813dfbf1c4572b3ee941923d
SystemConfig:      0x412e1c21826625d24b0174f8051d89d7837cb441
Batch Inbox:       0x009e0fc0f9ab0fb4020573d77cf2abf68a53d8d7
```

### L2 Contracts
```bash
L2 BEGA Token:     0x87dc04878022a1161159eb37015e9b2609bfb155
Chain ID:          12345678
```

### Service Endpoints
```bash
L2 RPC:            http://localhost:8545
L2 WebSocket:      ws://localhost:8546
L2 Node RPC:       http://localhost:8547
BEGAScan API:      http://localhost:4000
BEGAScan UI:       http://localhost:3000
```

## Project Structure

```
BEGA/
├── config/                    # Deployment configurations
│   ├── genesis.json          # L2 genesis state (9.0MB, 2370 accounts)
│   ├── rollup.json           # Rollup configuration
│   └── deploy-config.json    # Deployment parameters
├── secrets/                   # Private keys (never commit!)
│   ├── jwt.txt               # Engine API authentication
│   ├── sequencer.key         # Sequencer private key
│   ├── batcher.key           # Batcher private key
│   └── proposer.key          # Proposer private key
├── data/                      # op-geth database
├── scripts/                   # Utility scripts
│   ├── deploy-l2-bega.sh     # Deploy L2 token
│   ├── bridge-bega-to-l2.sh  # Bridge tokens L1→L2
│   ├── check-l2-balance.sh   # Monitor L2 balance
│   └── check-deposit-status.sh
├── gas-bot/                   # Gas price updater bot
├── Docs/                      # Architecture documentation
├── docker-compose.yml         # Full stack orchestration
└── .env                       # Environment configuration
```

## Quick Start Guide

### Prerequisites

1. **Install Required Tools**
   ```bash
   # Docker & Docker Compose
   brew install docker docker-compose  # macOS
   # or apt-get install docker.io docker-compose  # Linux

   # Foundry (for cast/forge commands)
   curl -L https://foundry.paradigm.xyz | bash
   foundryup
   ```

2. **Clone OP Stack Repository** (for op-deployer)
   ```bash
   git clone https://github.com/ethereum-optimism/optimism.git ~/optimism
   cd ~/optimism
   pnpm install
   make op-deployer
   ```

3. **Set Up Celestia Light Node**
   ```bash
   # Follow: https://docs.celestia.org/nodes/light-node
   # Start on Mocha testnet (port 26658)
   celestia light start --core.ip consensus-full.celestia-mocha.com
   ```

### Launch Existing L2 (Already Deployed)

If the L2 is already deployed (as in this project), simply start the services:

```bash
# Navigate to project directory
cd /Users/kangmunil/Project/BEGA

# Start core L2 services
docker compose up -d l2-geth l2-node l2-batcher

# Start block explorer (optional)
docker compose up -d --no-deps begascan begascan-frontend explorer-db explorer-redis

# Check logs
docker compose logs -f l2-node

# Verify L2 is producing blocks
cast block-number --rpc-url http://localhost:8545
```

### Deploy from Scratch

<details>
<summary>Click to expand full deployment guide</summary>

#### Phase 1: Deploy L1 Custom Gas Token

1. **Deploy ERC-20 Token to Sepolia**
   ```bash
   # Use your preferred method (Remix, Hardhat, Foundry)
   # IMPORTANT: Must use 18 decimals
   # Example: OpenZeppelin ERC20 template
   ```

2. **Fund Accounts**
   - Deployer wallet: 0.5+ ETH (for contract deployment)
   - Batcher wallet: 0.2+ ETH (for ongoing L1 submissions)
   - Operator wallet: 0.1+ ETH (for gas oracle updates)

#### Phase 2: Configure & Deploy L2

1. **Set Up Environment**
   ```bash
   cp .env.example .env
   # Edit .env with your private keys and addresses
   ```

2. **Deploy L1 Contracts**
   ```bash
   cd ~/optimism
   ./bin/op-deployer apply \
     --l1-rpc-url $L1_RPC_URL \
     --private-key $DEPLOYER_PRIVATE_KEY \
     --intent-config /path/to/BEGA/intent.toml \
     --workdir /path/to/BEGA/state
   ```

3. **Generate Genesis & Rollup Config**
   ```bash
   ./bin/op-deployer inspect genesis \
     --workdir /path/to/BEGA/state \
     --outfile /path/to/BEGA/config/genesis.json

   ./bin/op-deployer inspect rollup \
     --workdir /path/to/BEGA/state \
     --outfile /path/to/BEGA/config/rollup.json
   ```

4. **Generate Secrets**
   ```bash
   # JWT secret for engine API
   openssl rand -hex 32 > secrets/jwt.txt

   # Use your existing private keys (without 0x prefix)
   echo "your_sequencer_private_key" > secrets/sequencer.key
   echo "your_batcher_private_key" > secrets/batcher.key
   echo "your_proposer_private_key" > secrets/proposer.key
   ```

5. **Update .env with Deployed Addresses**
   ```bash
   # Extract from state.json and update:
   # - SYSTEM_CONFIG_ADDRESS
   # - BATCH_INBOX_ADDRESS
   # - L2OO_ADDRESS (may be 0x0 for dispute game based systems)
   ```

6. **Launch L2**
   ```bash
   docker compose up -d l2-geth l2-node l2-batcher
   ```

</details>

## Important Configuration Notes

### ⚠️ Critical: Sequencer Configuration

When running op-geth as the **sequencer node** (single-node setup), do NOT use `--rollup.sequencerhttp`:

```yaml
# ❌ WRONG - Causes self-request timeout loop
--rollup.sequencerhttp=http://localhost:8545

# ✅ CORRECT - For sequencer node
--rollup.disabletxpoolgossip=true
# (no sequencerhttp flag)
```

The `--rollup.sequencerhttp` flag is only for **follower nodes** that need to forward transactions to a separate sequencer.

### Verified Working Configuration

```yaml
# docker-compose.yml - l2-geth service
command: >
  --datadir=/db
  --http --http.addr=0.0.0.0 --http.port=8545
  --http.corsdomain="*" --http.vhosts="*"
  --http.api=web3,debug,eth,txpool,net,engine,miner,admin,personal
  --ws --ws.addr=0.0.0.0 --ws.port=8546
  --ws.api=debug,eth,txpool,net,engine --ws.origins="*"
  --authrpc.addr=0.0.0.0 --authrpc.port=8551
  --authrpc.vhosts="*" --authrpc.jwtsecret=/secrets/jwt.txt
  --syncmode=full --gcmode=archive
  --nodiscover --maxpeers=0
  --networkid=12345678
  --rollup.disabletxpoolgossip=true
```

## MetaMask Setup

Add BEGA L2 network to MetaMask:

```
Network Name:        BEGA L2 Mainnet
RPC URL:             http://localhost:8545
Chain ID:            12345678
Currency Symbol:     BEGA
Currency Decimals:   18
Block Explorer:      http://localhost:3000
```

## Usage Examples

### Check L2 Status

```bash
# Get current block number
cast block-number --rpc-url http://localhost:8545

# Get chain ID
cast chain-id --rpc-url http://localhost:8545

# Check your balance
cast balance YOUR_ADDRESS --rpc-url http://localhost:8545 --ether
```

### Send Transactions

```bash
# Send BEGA tokens
cast send RECIPIENT_ADDRESS \
  --value 10ether \
  --rpc-url http://localhost:8545 \
  --private-key YOUR_PRIVATE_KEY
```

### Deploy Contracts

```bash
# Using Foundry
forge create MyContract \
  --rpc-url http://localhost:8545 \
  --private-key YOUR_PRIVATE_KEY

# Using Hardhat - update hardhat.config.js:
networks: {
  bega: {
    url: "http://localhost:8545",
    chainId: 12345678,
    accounts: ["YOUR_PRIVATE_KEY"]
  }
}
```

### Bridge Tokens L1 → L2

```bash
# Bridge 1000 BEGA from L1 to L2
./scripts/bridge-bega-to-l2.sh

# Monitor L2 balance (auto-updates every 10s)
./scripts/check-l2-balance.sh

# Check L1 deposit transaction status
./scripts/check-deposit-status.sh
```

## Testing Checklist

- [x] L2 is producing blocks
- [x] RPC accepting transactions (`eth_sendRawTransaction` works)
- [x] Custom gas token (BEGA) deducted for transactions
- [x] Batcher posting to Celestia DA
- [x] L2 BEGA token deployed via OptimismMintableERC20Factory
- [x] Block explorer (BEGAScan) accessible
- [ ] Proposer posting state roots to L1 (optional, not critical)
- [ ] Gas oracle bot running (optional)
- [ ] Bridge deposits work (L1 → L2)
- [ ] Bridge withdrawals work (L2 → L1)

## Monitoring

### View Service Status
```bash
docker compose ps
```

### Real-time Logs
```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f l2-geth
docker compose logs -f l2-node
docker compose logs -f l2-batcher
```

### Check L2 Chain Health
```bash
# Latest block
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Chain ID
curl -X POST http://localhost:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}'

# Node sync status (op-node)
curl -X POST http://localhost:8547 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"optimism_syncStatus","params":[],"id":1}'
```

## Common Issues & Solutions

### Issue: `eth_sendRawTransaction` timeout after 30 seconds

**Cause**: Using `--rollup.sequencerhttp=http://localhost:8545` when geth IS the sequencer creates a self-request loop.

**Solution**: Remove the flag from docker-compose.yml:
```yaml
# Remove this line if present:
--rollup.sequencerhttp=http://localhost:8545
```

### Issue: `service 'l2-geth-init' didn't complete successfully: exit 1`

**Cause**: Docker Compose trying to restart init service which should only run once.

**Solution**: Use `--no-deps` flag when restarting services:
```bash
docker compose restart l2-geth  # This will trigger init dependency check

# Instead use:
docker compose stop l2-geth
docker compose rm -f l2-geth
docker compose up -d --no-deps l2-geth
```

### Issue: Batcher error - "connection refused to DA server"

**Solution**: Ensure Celestia Light Node is running and accessible:
```bash
# Check Celestia node status
curl http://localhost:26658

# For Docker Desktop (Mac/Windows), use in .env:
DA_SERVER_URL=http://host.docker.internal:26658

# For Linux, use:
DA_SERVER_URL=http://172.17.0.1:26658
```

### Issue: Genesis block mismatch after restart

**Solution**:
```bash
# Clean data and let init service regenerate
docker compose down
rm -rf data/geth
docker compose up -d l2-geth l2-node l2-batcher
```

## Service Ports Reference

| Service | Internal Port | Exposed Port | Purpose |
|---------|--------------|--------------|---------|
| l2-geth | 8545 | 8545 | HTTP RPC |
| l2-geth | 8546 | 8546 | WebSocket |
| l2-geth | 8551 | - | Engine API (authrpc) |
| l2-node | 8547 | 8547 | Rollup Node RPC |
| l2-node | 9003 | 9003 | P2P |
| begascan | 4000 | 4000 | Blockscout API |
| begascan-frontend | 3000 | 3000 | Blockscout UI |
| explorer-db | 5432 | - | PostgreSQL |
| explorer-redis | 6379 | - | Redis |

## Performance Tuning

### Recommended System Requirements

**Minimum**:
- 4 CPU cores
- 8 GB RAM
- 100 GB SSD

**Recommended**:
- 8 CPU cores
- 16 GB RAM
- 500 GB NVMe SSD
- 100 Mbps network

### Docker Resource Limits

Edit `docker-compose.yml` to add resource limits:

```yaml
services:
  l2-geth:
    # ... existing config
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 4G
        reservations:
          cpus: '1'
          memory: 2G
```

## Next Steps

### Production Deployment

1. **Infrastructure Setup**
   - Deploy to cloud (AWS, GCP, Azure)
   - Set up load balancers for RPC endpoints
   - Configure auto-scaling for peak traffic

2. **Security Hardening**
   - Migrate private keys to KMS (AWS KMS, HashiCorp Vault)
   - Set up multisig for admin operations
   - Enable firewall rules (only expose necessary ports)
   - Use TLS/SSL for all RPC endpoints

3. **Monitoring & Alerting**
   - Set up Prometheus + Grafana dashboards
   - Configure alerts for:
     - Block production stopped
     - Batcher failing to submit
     - Low ETH balance in operator accounts
     - High transaction failure rate

4. **Backup & Disaster Recovery**
   - Regular snapshots of geth database
   - Backup private keys (encrypted)
   - Document recovery procedures
   - Test failover scenarios

### Additional Services

1. **Gas Oracle Bot**
   ```bash
   docker compose up -d gas-oracle
   ```

2. **Additional Proposer** (if using L2OutputOracle)
   ```bash
   # First fix the missing image or use a specific tag
   docker compose up -d l2-proposer
   ```

3. **Public RPC Endpoint**
   - Set up Nginx reverse proxy
   - Add rate limiting
   - Configure CORS properly
   - Add DDoS protection (Cloudflare)

## Resources

- **OP Stack Documentation**: https://docs.optimism.io/
- **Celestia Documentation**: https://docs.celestia.org/
- **Blockscout Documentation**: https://docs.blockscout.com/
- **Project Architecture**: [Docs/checklist.md](Docs/checklist.md)
- **Operation Guide**: [Docs/operate/operate.md](Docs/operate/operate.md)

## Support

For issues and questions:
1. Check [Docs/](Docs/) directory for detailed guides
2. Review [Common Issues](#common-issues--solutions) section above
3. Check OP Stack GitHub issues: https://github.com/ethereum-optimism/optimism/issues
4. Join Celestia Discord for DA-related questions

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Test your changes thoroughly
4. Submit a pull request with clear description

## License

[Add your license here]

---

**⚠️ IMPORTANT SECURITY NOTICE**

This is a **TESTNET** configuration. Before deploying to mainnet:

1. ✅ Complete security audit of all configurations
2. ✅ Use hardware wallets or KMS for private keys
3. ✅ Enable monitoring and alerting
4. ✅ Set up proper backup procedures
5. ✅ Test disaster recovery
6. ✅ Review and harden all exposed endpoints
7. ✅ Implement rate limiting and DDoS protection

**DO NOT** use testnet private keys, configurations, or infrastructure for mainnet deployment.

---

**Last Updated**: 2025-12-28
**Version**: 1.0.0 (Testnet)
**Status**: Operational ✅
