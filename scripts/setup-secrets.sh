#!/bin/bash
# Setup script for generating secrets

set -e

SECRETS_DIR="./secrets"

echo "🔐 Setting up secrets for BEGA L2..."

# Create secrets directory if it doesn't exist
mkdir -p "$SECRETS_DIR"

# Generate JWT secret
echo "Generating JWT secret..."
openssl rand -hex 32 > "$SECRETS_DIR/jwt.txt"
echo "✅ JWT secret created: $SECRETS_DIR/jwt.txt"

# Check if private keys are provided
echo ""
echo "Please provide private keys (WITHOUT 0x prefix):"
echo ""

# Sequencer key
read -p "Sequencer Private Key: " SEQUENCER_KEY
echo "$SEQUENCER_KEY" > "$SECRETS_DIR/sequencer.key"
echo "✅ Sequencer key saved"

# Batcher key
read -p "Batcher Private Key: " BATCHER_KEY
echo "$BATCHER_KEY" > "$SECRETS_DIR/batcher.key"
echo "✅ Batcher key saved"

# Proposer key
read -p "Proposer Private Key: " PROPOSER_KEY
echo "$PROPOSER_KEY" > "$SECRETS_DIR/proposer.key"
echo "✅ Proposer key saved"

# Set proper permissions
chmod 600 "$SECRETS_DIR"/*.key "$SECRETS_DIR"/*.txt

echo ""
echo "✅ All secrets have been set up!"
echo ""
echo "⚠️  IMPORTANT: Never commit the secrets/ directory to git!"
echo "   The .gitignore file already excludes it."
echo ""
