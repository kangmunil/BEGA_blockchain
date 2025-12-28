# Gas Price Updater Bot

Automatically adjusts L2 gas prices based on ETH/Token exchange rate to maintain sequencer profitability.

## Overview

This bot monitors the price ratio between ETH and your custom gas token (BEGA), then updates the `scalar` parameter in the L1 SystemConfig contract to ensure the sequencer doesn't operate at a loss when using a native custom gas token.

## How It Works

1. Fetches current ETH price from Binance API
2. Uses configured BEGA token price (currently mocked at $0.50)
3. Calculates optimal scalar: `(ETH Price / Token Price) × 1,000,000 × SafetyMargin`
4. Reads current scalar from L1 SystemConfig contract
5. Updates if change exceeds threshold (default 5%)
6. Sends transaction to L1 to update gas config

## Configuration

Set these environment variables in `.env`:

```bash
# L1 Connection
L1_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY

# Operator Wallet (needs L1 ETH for gas)
OPERATOR_PRIVATE_KEY=your_key_without_0x

# SystemConfig Contract Address (on L1)
SYSTEM_CONFIG_ADDRESS=0x412e1c21826625d24b0174f8051d89d7837cb441

# Bot Configuration
UPDATE_THRESHOLD=5.0        # Update if change > 5%
SAFETY_MARGIN=1.1          # 10% safety margin for sequencer profit
CHECK_INTERVAL=30          # Check every 30 seconds
```

## Building

```bash
# Install dependencies
go mod download

# Generate SystemConfig contract binding (already done)
abigen --abi=SystemConfig.abi --pkg=bindings --type=SystemConfig --out=bindings/SystemConfig.go

# Build binary
go build -o gas-bot main.go
```

## Running Locally

```bash
# Make sure .env is properly configured
source ../.env

# Run the bot
./gas-bot
```

## Running with Docker

The bot is already configured in the main `docker-compose.yml`:

```bash
# Start the gas oracle bot
docker compose up -d gas-oracle

# View logs
docker compose logs -f gas-oracle

# Stop the bot
docker compose stop gas-oracle
```

## Implementation Status

- [x] SystemConfig contract binding (using abigen)
- [x] Read current scalar from L1 contract
- [x] Actual transaction sending logic
- [x] Circuit breaker (min/max scalar limits)
- [x] Threshold-based updates
- [ ] Custom token price fetching (currently mocked at $0.50)
- [ ] Prometheus metrics export
- [ ] Health check endpoint
- [ ] Graceful shutdown
- [ ] Unit tests

## Safety Features

- **Circuit Breaker**: Min (100,000) and Max (10,000,000,000) scalar limits prevent extreme values
- **Threshold Check**: Only updates if change exceeds configured threshold (default 5%)
- **Safety Margin**: Built-in 10% profit margin for sequencer
- **Gas Management**: Operator wallet needs L1 ETH for transaction fees
- **Transaction Confirmation**: Waits for and verifies transaction receipt

## Formula

The bot uses the following formula to calculate the target scalar:

```
TargetScalar = (ETH_Price / BEGA_Price) × 1,000,000 × SafetyMargin
```

**Example:**
- ETH = $3,300
- BEGA = $0.50
- SafetyMargin = 1.1
- TargetScalar = (3300 / 0.5) × 1,000,000 × 1.1 = 7,260,000,000

This ensures that when users pay for gas in BEGA, the sequencer receives enough value to cover L1 posting costs (paid in ETH).

## Important Notes

1. **Operator Wallet**: The OPERATOR_PRIVATE_KEY wallet must have L1 ETH to pay for gas when updating the SystemConfig contract
2. **Token Price**: Currently using a mocked price of $0.50. In production, implement actual price feeds from:
   - Centralized exchanges (Upbit, Binance) if BEGA is listed
   - DEX pools (Uniswap, Sushiswap) via on-chain oracle
   - Custom price oracle service
3. **Update Frequency**: The bot checks every 30 seconds but only sends transactions if the change exceeds the threshold, minimizing L1 gas costs
4. **Celestia DA**: When using Celestia for data availability, the L1 costs are primarily for posting commitment hashes, not full transaction data

## Testing

To test the bot without sending actual transactions, you can:

1. **Dry Run Mode**: Modify the code to skip transaction sending and just log what would be done
2. **Check Price Fetching**:
   ```bash
   curl "https://api.binance.com/api/v3/ticker/price?symbol=ETHUSDT"
   ```
3. **Verify SystemConfig Read**: The bot will attempt to read from the L1 contract on startup

## Troubleshooting

### Bot fails to connect to L1 RPC
- Check that `L1_RPC_URL` is correct and API key is valid
- Verify network connectivity

### Failed to read from SystemConfig contract
- Ensure `SYSTEM_CONFIG_ADDRESS` is correct
- Verify the contract exists on the network

### Transaction reverted
- Check that OPERATOR_PRIVATE_KEY wallet has enough L1 ETH for gas
- Verify the operator wallet has permission to call `setGasConfig`
- Check L1 gas prices aren't too high

### Price fetching fails
- Binance API might be rate limited
- Check internet connectivity
- Consider implementing backup price sources
