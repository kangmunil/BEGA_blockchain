package main

import (
	"context"
	"crypto/ecdsa"
	"encoding/json"
	"fmt"
	"log"
	"math/big"
	"net/http"
	"os"
	"strconv"
	"time"

	"github.com/bega/gas-oracle-bot/bindings"
	"github.com/ethereum/go-ethereum/accounts/abi/bind"
	"github.com/ethereum/go-ethereum/common"
	"github.com/ethereum/go-ethereum/crypto"
	"github.com/ethereum/go-ethereum/ethclient"
)

// Configuration constants
const (
	DefaultUpdateThreshold = 5.0  // 5% change threshold
	DefaultDaFactor        = 0.1  // Celestia DA cost is 10% of Ethereum (90% discount)
	DefaultSafetyMargin    = 1.1  // 10% safety margin for sequencer profit
	DefaultCheckInterval   = 30   // seconds
	MinScalar              = 100000
	MaxScalar              = 10000000000
)

// BinanceTickerResponse represents the response from Binance API
type BinanceTickerResponse struct {
	Symbol string `json:"symbol"`
	Price  string `json:"price"`
}

// Config holds bot configuration
type Config struct {
	L1RpcURL           string
	OperatorPrivateKey string
	SystemConfigAddr   common.Address
	UpdateThreshold    float64
	DaFactor           float64 // Celestia DA discount factor (0.1 = 10% of ETH cost)
	SafetyMargin       float64 // Sequencer profit margin (1.1 = 10% profit)
	CheckInterval      time.Duration
}

func main() {
	log.Println("🚀 BEGA Gas Price Updater Bot Starting...")

	// Load configuration
	config, err := loadConfig()
	if err != nil {
		log.Fatalf("Failed to load config: %v", err)
	}

	// Connect to L1
	client, err := ethclient.Dial(config.L1RpcURL)
	if err != nil {
		log.Fatalf("Failed to connect to L1 RPC: %v", err)
	}
	defer client.Close()

	// Load operator wallet
	privateKey, err := crypto.HexToECDSA(config.OperatorPrivateKey)
	if err != nil {
		log.Fatalf("Failed to load private key: %v", err)
	}

	// Get chain ID
	chainID, err := client.ChainID(context.Background())
	if err != nil {
		log.Fatalf("Failed to get chain ID: %v", err)
	}

	log.Printf("✅ Connected to L1 (Chain ID: %s)", chainID.String())
	log.Printf("📍 SystemConfig Address: %s", config.SystemConfigAddr.Hex())
	log.Printf("⚙️  Update Threshold: %.2f%%", config.UpdateThreshold)
	log.Printf("💎 DA Factor (Celestia): %.2fx (%.0f%% discount)", config.DaFactor, (1-config.DaFactor)*100)
	log.Printf("🛡️  Safety Margin: %.2fx", config.SafetyMargin)
	log.Printf("⏱️  Check Interval: %v", config.CheckInterval)

	// Main loop
	ticker := time.NewTicker(config.CheckInterval)
	defer ticker.Stop()

	// Run immediately on startup
	runUpdate(client, privateKey, chainID, config)

	// Then run on interval
	for range ticker.C {
		runUpdate(client, privateKey, chainID, config)
	}
}

func loadConfig() (*Config, error) {
	config := &Config{
		L1RpcURL:           getEnv("L1_RPC_URL", ""),
		OperatorPrivateKey: getEnv("OPERATOR_PRIVATE_KEY", ""),
		UpdateThreshold:    getEnvFloat("UPDATE_THRESHOLD", DefaultUpdateThreshold),
		DaFactor:           getEnvFloat("DA_FACTOR", DefaultDaFactor),
		SafetyMargin:       getEnvFloat("SAFETY_MARGIN", DefaultSafetyMargin),
		CheckInterval:      time.Duration(getEnvInt("CHECK_INTERVAL", DefaultCheckInterval)) * time.Second,
	}

	systemConfigStr := getEnv("SYSTEM_CONFIG_ADDRESS", "")
	if systemConfigStr == "" {
		return nil, fmt.Errorf("SYSTEM_CONFIG_ADDRESS not set")
	}
	config.SystemConfigAddr = common.HexToAddress(systemConfigStr)

	if config.L1RpcURL == "" {
		return nil, fmt.Errorf("L1_RPC_URL not set")
	}
	if config.OperatorPrivateKey == "" {
		return nil, fmt.Errorf("OPERATOR_PRIVATE_KEY not set")
	}

	return config, nil
}

func runUpdate(client *ethclient.Client, privateKey interface{}, chainID *big.Int, config *Config) {
	ctx := context.Background()

	// Create SystemConfig contract binding
	systemConfig, err := bindings.NewSystemConfig(config.SystemConfigAddr, client)
	if err != nil {
		log.Printf("❌ Failed to create contract binding: %v", err)
		return
	}

	// Fetch current prices
	ethPrice, tokenPrice, err := getPrices()
	if err != nil {
		log.Printf("⚠️  Error fetching prices: %v", err)
		return
	}

	log.Printf("💰 Current Prices - ETH: $%.2f, Token: $%.4f", ethPrice, tokenPrice)

	// Calculate target scalar
	if tokenPrice <= 0 {
		log.Printf("⚠️  Invalid token price (%.4f), skipping update", tokenPrice)
		return
	}

	ratio := ethPrice / tokenPrice
	targetScalarFloat := ratio * 1000000 * config.SafetyMargin
	targetScalar := big.NewInt(int64(targetScalarFloat))

	// Apply circuit breaker
	if targetScalar.Cmp(big.NewInt(MinScalar)) < 0 {
		log.Printf("⚠️  Target scalar %s below minimum %d, using minimum", targetScalar.String(), MinScalar)
		targetScalar = big.NewInt(MinScalar)
	}
	if targetScalar.Cmp(big.NewInt(MaxScalar)) > 0 {
		log.Printf("⚠️  Target scalar %s above maximum %d, using maximum", targetScalar.String(), MaxScalar)
		targetScalar = big.NewInt(MaxScalar)
	}

	// Read current gas config from SystemConfig contract
	currentOverhead, err := systemConfig.Overhead(&bind.CallOpts{Context: ctx})
	if err != nil {
		log.Printf("❌ Failed to read overhead from contract: %v", err)
		return
	}

	currentScalar, err := systemConfig.Scalar(&bind.CallOpts{Context: ctx})
	if err != nil {
		log.Printf("❌ Failed to read scalar from contract: %v", err)
		return
	}

	// Calculate change rate
	diff := new(big.Int).Sub(targetScalar, currentScalar)
	diffAbs := new(big.Int).Abs(diff)

	changeRate := new(big.Float).Quo(
		new(big.Float).SetInt(diffAbs),
		new(big.Float).SetInt(currentScalar),
	)
	changeRateFloat, _ := changeRate.Float64()
	changeRatePercent := changeRateFloat * 100

	log.Printf("📊 Scalar Analysis - Current: %s, Target: %s, Change: %.2f%%",
		currentScalar.String(), targetScalar.String(), changeRatePercent)

	// Check if update is needed
	if changeRatePercent < config.UpdateThreshold {
		log.Printf("✅ Scalar is stable, no update needed")
		return
	}

	log.Printf("🔄 Update required! Preparing transaction...")

	// Create authorized transactor
	auth, err := bind.NewKeyedTransactorWithChainID(privateKey.(*ecdsa.PrivateKey), chainID)
	if err != nil {
		log.Printf("❌ Failed to create transactor: %v", err)
		return
	}

	// Send transaction to update gas config
	tx, err := systemConfig.SetGasConfig(auth, currentOverhead, targetScalar)
	if err != nil {
		log.Printf("❌ Failed to send transaction: %v", err)
		return
	}

	log.Printf("✅ Transaction sent: %s", tx.Hash().Hex())
	log.Printf("⏳ Waiting for confirmation...")

	// Wait for transaction confirmation
	receipt, err := bind.WaitMined(ctx, client, tx)
	if err != nil {
		log.Printf("❌ Transaction failed: %v", err)
		return
	}

	if receipt.Status == 1 {
		log.Printf("✅ Transaction confirmed! Block: %d, Gas Used: %d", receipt.BlockNumber, receipt.GasUsed)
		log.Printf("🎉 Scalar successfully updated to: %s", targetScalar.String())
	} else {
		log.Printf("❌ Transaction reverted!")
	}
}

func getPrices() (float64, float64, error) {
	// Fetch ETH price from Binance
	ethPrice, err := fetchBinancePrice("ETHUSDT")
	if err != nil {
		return 0, 0, fmt.Errorf("failed to fetch ETH price: %w", err)
	}

	// TODO: Fetch actual token price
	// For now, using a mock value
	// You would fetch this from:
	// 1. Coingecko API if token is listed
	// 2. DEX pool contract (Uniswap/Sushiswap)
	// 3. Internal price oracle
	tokenPrice := 0.5 // Mock: $0.50

	return ethPrice, tokenPrice, nil
}

func fetchBinancePrice(symbol string) (float64, error) {
	url := "https://api.binance.com/api/v3/ticker/price?symbol=" + symbol

	resp, err := http.Get(url)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return 0, fmt.Errorf("binance API returned status %d", resp.StatusCode)
	}

	var ticker BinanceTickerResponse
	if err := json.NewDecoder(resp.Body).Decode(&ticker); err != nil {
		return 0, err
	}

	price, err := strconv.ParseFloat(ticker.Price, 64)
	if err != nil {
		return 0, err
	}

	return price, nil
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvFloat(key string, defaultValue float64) float64 {
	if value := os.Getenv(key); value != "" {
		if f, err := strconv.ParseFloat(value, 64); err == nil {
			return f
		}
	}
	return defaultValue
}

func getEnvInt(key string, defaultValue int) int {
	if value := os.Getenv(key); value != "" {
		if i, err := strconv.Atoi(value); err == nil {
			return i
		}
	}
	return defaultValue
}
