# ReflexRouter Deployment Script

This directory contains the deployment script for the ReflexRouter contract.

## Overview

The ReflexRouter is the core contract that handles flash loan arbitrage trades across multiple DEX protocols. It can execute profitable arbitrage opportunities without requiring upfront capital using flash loans from UniswapV2, UniswapV3, and other protocols.

## Files

- `DeployReflexRouter.s.sol` - Main deployment script
- `.env.example` - Example environment variables
- `README.md` - This documentation

## Quick Start

1. **Copy environment file:**

   ```bash
   cp script/deploy-reflex-router/.env.example script/deploy-reflex-router/.env
   ```

2. **Edit configuration:**

   ```bash
   # Optional: Set ReflexQuoter address if available
   REFLEX_QUOTER_ADDRESS=0x...

   # Optional: Enable contract verification
   VERIFY_CONTRACT=true
   ETHERSCAN_API_KEY=your_api_key_here
   ```

3. **Deploy:**
   ```bash
   forge script script/deploy-reflex-router/DeployReflexRouter.s.sol \
     --rpc-url $RPC_URL \
     --private-key $PRIVATE_KEY \
     --broadcast \
     --verify
   ```

## Environment Variables

### Required (via command line)

- `RPC_URL` - RPC endpoint for the target network
- `PRIVATE_KEY` - Private key of the deployer account

### Optional (via .env file)

- `REFLEX_QUOTER_ADDRESS` - Address of ReflexQuoter contract (can be set later)
- `VERIFY_CONTRACT` - Set to "true" to verify on Etherscan (default: false)
- `ETHERSCAN_API_KEY` - Required if VERIFY_CONTRACT is true
- `GAS_PRICE` - Gas price in gwei (optional, auto-estimated)
- `GAS_LIMIT` - Gas limit (optional, auto-estimated)

## Deployment Process

The script performs the following steps:

1. **Validation:** Checks deployer balance and configuration
2. **Deployment:** Deploys ReflexRouter contract
3. **Configuration:** Sets ReflexQuoter address (if provided)
4. **Verification:** Optionally verifies contract on Etherscan
5. **Documentation:** Saves deployment info to JSON file

## Contract Details

### Constructor

The ReflexRouter constructor is simple:

- Sets `tx.origin` as the contract owner
- No parameters required

### Initial Configuration

After deployment, the owner can:

- Set ReflexQuoter address via `setReflexQuoter(address)`
- The contract is immediately functional for basic operations

## Network Examples

### Ethereum Mainnet

```bash
forge script script/deploy-reflex-router/DeployReflexRouter.s.sol \
  --rpc-url https://mainnet.infura.io/v3/YOUR-PROJECT-ID \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

### Polygon

```bash
forge script script/deploy-reflex-router/DeployReflexRouter.s.sol \
  --rpc-url https://polygon-rpc.com \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

### Arbitrum One

```bash
forge script script/deploy-reflex-router/DeployReflexRouter.s.sol \
  --rpc-url https://arb1.arbitrum.io/rpc \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

### Local Development (Anvil)

```bash
# Start anvil
anvil

# Deploy (use anvil's test private key)
forge script script/deploy-reflex-router/DeployReflexRouter.s.sol \
  --rpc-url http://localhost:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --broadcast
```

## Post-Deployment

After successful deployment:

1. **Verify Contract** (if not done automatically):

   ```bash
   forge verify-contract <CONTRACT_ADDRESS> \
     --chain-id <CHAIN_ID> \
     --constructor-args $(cast abi-encode "constructor()") \
     src/ReflexRouter.sol:ReflexRouter \
     --etherscan-api-key $ETHERSCAN_API_KEY
   ```

2. **Set ReflexQuoter** (if not set during deployment):

   ```bash
   cast send <ROUTER_ADDRESS> \
     "setReflexQuoter(address)" <QUOTER_ADDRESS> \
     --rpc-url $RPC_URL \
     --private-key $PRIVATE_KEY
   ```

3. **Verify Configuration:**

   ```bash
   # Check owner
   cast call <ROUTER_ADDRESS> "owner()" --rpc-url $RPC_URL

   # Check quoter
   cast call <ROUTER_ADDRESS> "reflexQuoter()" --rpc-url $RPC_URL
   ```

## Security Considerations

- The deployer becomes the contract owner via `tx.origin`
- Only the owner can set the ReflexQuoter address
- Ensure the deployer account is secure and properly managed
- Consider using a multisig wallet for production deployments

## Troubleshooting

### Common Issues

1. **Insufficient balance:**

   ```
   Error: Deployer has insufficient ETH balance
   ```

   Solution: Fund the deployer account with ETH for gas costs

2. **RPC connection issues:**

   ```
   Error: Failed to get response from RPC
   ```

   Solution: Check RPC URL and network connectivity

3. **Verification failed:**
   ```
   Error: Contract verification failed
   ```
   Solution: Check Etherscan API key and wait a few minutes before retrying

### Debug Mode

Run with `-vvvv` for detailed debugging:

```bash
forge script script/deploy-reflex-router/DeployReflexRouter.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  -vvvv
```

## Integration

After deployment, the ReflexRouter can be:

- Set as the router address in AlgebraBasePlugin contracts
- Used directly for arbitrage operations
- Integrated with other MEV capture strategies

For plugin integration, see the plugin deployment scripts in:

- `script/deploy-v1-factory/`
- `script/deploy-v3-plugin/`
