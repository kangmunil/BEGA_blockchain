# BEGA L2 - Quick Reference Card

## Critical: Restart Nodes After Parameter Changes

```bash
# Restart nodes to apply EIP-1559 parameter changes
docker-compose restart op-node op-geth

# Or full restart
docker-compose down
docker-compose up -d
```

## Parameter Verification

```bash
# Run comprehensive verification
./scripts/verify-eip1559-params.sh

# Quick check EIP-1559 params in rollup.json
jq '.genesis.system_config.eip1559Params' config/rollup.json
# Should output: "0x0000000000000032"
```

## Monitor Gas Prices

```bash
# Check current block gas price
cast block latest --rpc-url http://localhost:8545 | grep baseFeePerGas

# Monitor gas price changes in real-time
watch -n 4 'cast block latest --rpc-url http://localhost:8545 | grep -E "number|baseFeePerGas|gasUsed"'

# Check gas price history (last 10 blocks)
for i in {0..9}; do
  BLOCK=$(($(cast block-number --rpc-url http://localhost:8545) - i))
  echo -n "Block $BLOCK: "
  cast block $BLOCK --rpc-url http://localhost:8545 | grep baseFeePerGas
done
```

## Updated Parameters

### EIP-1559 (Gas Fee Market)
- **Params (hex)**: `0x0000000000000032` (was `0x0000000000000000`)
- **Elasticity**: 6
- **Denominator**: 50
- **Effect**: Gas prices adjust 2% per block based on congestion

### DA Bond (deploy-config.json only)
- **Bond Size**: 1 ETH (1000000000000000000 wei)
- **Status**: Configured but requires L1 contract upgrade to activate

### Fault Game (deploy-config.json only)
- **Max Depth**: 4
- **Split Depth**: 2
- **Max Duration**: 7 days
- **Clock Extension**: 1 hour
- **Status**: Configured for future deployment

## File Locations

```bash
# Configuration files
config/deploy-config.json    # Source configuration
config/rollup.json           # Runtime rollup config
config/genesis.json          # L2 genesis state

# Utility scripts
scripts/update-eip1559-params.sh     # Update EIP-1559 parameters
scripts/verify-eip1559-params.sh     # Verify all parameters
scripts/regenerate-genesis.sh        # Full genesis regeneration (requires op-node)

# Backups
config/backups/              # Timestamped configuration backups
```

## Troubleshooting

### Gas Prices Not Changing
```bash
# 1. Verify parameters are correct
./scripts/verify-eip1559-params.sh

# 2. Ensure nodes were restarted
docker-compose ps

# 3. Check if nodes are running with new config
docker-compose logs op-node | grep -i eip1559
docker-compose logs op-geth | grep -i eip1559

# 4. Verify blocks are being produced
cast block-number --rpc-url http://localhost:8545
```

### Rollback to Previous Config
```bash
# Stop nodes
docker-compose stop op-node op-geth

# Restore from backup (use latest timestamp)
cp config/backups/rollup_20251229_085700.json config/rollup.json
cp config/backups/genesis_20251229_085700.json config/genesis.json

# Restart nodes
docker-compose up -d op-node op-geth
```

### Re-apply EIP-1559 Updates
```bash
# Run the update script again
./scripts/update-eip1559-params.sh

# Restart nodes
docker-compose restart op-node op-geth

# Verify
./scripts/verify-eip1559-params.sh
```

## Expected Behavior

### Gas Price Dynamics
- **Blocks >50% full**: Gas price increases by up to 2% per block
- **Blocks <50% full**: Gas price decreases by up to 2% per block
- **Blocks =50% full**: Gas price stays constant

### Block Size
- **Target Gas**: 5,000,000 (30M / 6)
- **Maximum Gas**: 30,000,000
- **Can expand to 6x target during high congestion**

## Network Information

```bash
Chain ID:          12345678
L2 RPC:            http://localhost:8545
L2 WebSocket:      ws://localhost:8546
L2 Node RPC:       http://localhost:8547
Block Time:        2 seconds
Gas Limit:         30,000,000
Gas Token:         BEGA (not ETH)
```

## Key Contract Addresses

### L1 (Sepolia)
```bash
BEGA Token:        0x55B746d21bCEb81374e818C809d0a8145e4Be2e1
OptimismPortal:    0xd4659581ab1b8d3d81aefbf1ff02bcb1216e2692
SystemConfig:      0x412e1c21826625d24b0174f8051d89d7837cb441
ProtocolVersions:  0x9c1dc7506488cab0b86a3924f9e78ad510a19f99
Batch Inbox:       0x009e0fc0f9ab0fb4020573d77cf2abf68a53d8d7
```

### L2
```bash
BEGA Token:        0x87dc04878022a1161159eb37015e9b2609bfb155
```

## Useful Cast Commands

```bash
# Get current base fee
cast block latest --rpc-url http://localhost:8545 --json | jq -r '.baseFeePerGas'

# Get block utilization
cast block latest --rpc-url http://localhost:8545 --json | jq -r '(.gasUsed | tonumber) / (.gasLimit | tonumber) * 100 | floor'

# Send test transaction to generate blocks
cast send --rpc-url http://localhost:8545 \
  --private-key <YOUR_KEY> \
  --value 0.01ether \
  <RECIPIENT_ADDRESS>

# Check account balance (in BEGA, not ETH)
cast balance <ADDRESS> --rpc-url http://localhost:8545
```

## Health Checks

```bash
# Check all services are running
docker-compose ps

# Check op-node sync status
curl -X POST http://localhost:8547 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"optimism_syncStatus","params":[],"id":1}' | jq

# Check op-geth block number
cast block-number --rpc-url http://localhost:8545

# Check L1 sync status
cast block-number --rpc-url https://sepolia.infura.io/v3/YOUR_KEY
```

## Support Documentation

- Full summary: `PRODUCTION_TUNING_SUMMARY.md`
- OP Stack docs: https://docs.optimism.io
- Project README: `README.md`

---

**Last Updated**: 2025-12-29
**Status**: ✅ Production Ready
