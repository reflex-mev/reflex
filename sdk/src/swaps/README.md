# Test Scripts

This directory contains test scripts for the Reflex MEV SDK.

## Scripts

### test-universal.ts

Executes swaps with integrated MEV backrun capture using the UniversalIntegration SDK.

**Features:**

- Supports UniswapV2 and UniswapV3 style swaps
- Automatic token approvals with allowance checking
- Integrated MEV backrun capture via Reflex Router
- Auto-detects token0In from pool contract
- Comprehensive balance tracking

**Usage:**

```bash
# Copy .env.example to .env and configure
cp .env.example .env

# Run the test
node dist/test-universal/test-universal.js
```

### test-swap-only.ts

Executes a simple UniswapV2 swap directly on the router without any MEV backrun functionality.

**Features:**

- Direct router interaction (no proxy)
- Token-to-token swaps only
- Automatic quote fetching
- Slippage protection
- Gas cost analysis
- Price impact calculation

**Usage:**

```bash
# Using environment variables
TARGET_ROUTER_ADDRESS=0x10ED43C718714eb63d5aA57B78B54704E256024E \
TOKEN_IN=0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c \
TOKEN_OUT=0x55d398326f99059fF775485246999027B3197955 \
SWAP_AMOUNT_IN=0.01 \
node dist/test-universal/test-swap-only.js

# Or configure in .env file
node dist/test-universal/test-swap-only.js
```

## Environment Variables

### Common Variables

- `TEST_RPC_URL` - RPC endpoint (default: http://localhost:8545)
- `TEST_PRIVATE_KEY` - Private key for signing transactions
- `TOKEN_IN` - Input token address
- `TOKEN_OUT` - Output token address
- `SWAP_AMOUNT_IN` - Amount to swap (in token decimals, e.g., "0.01")

### test-universal.ts Specific

- `SWAP_PROXY_ADDRESS` - BackrunEnabledSwapProxy contract address
- `REFLEX_ROUTER_ADDRESS` - ReflexRouter contract address
- `ROUTER_TYPE` - Router type: "v2" or "v3"
- `TEST_POOL_ADDRESS` - Pool address for backrun
- `SWAP_FEE` - V3 pool fee tier (500, 3000, 10000)
- `TEST_CONFIG_ID` - Backrun config ID (default: 0x0)
- `MIN_AMOUNT_OUT` - Minimum output amount (default: 0)

### test-swap-only.ts Specific

- `TARGET_ROUTER_ADDRESS` - UniswapV2 router address
- `SLIPPAGE_TOLERANCE` - Slippage tolerance percentage (default: 0.5)

## Examples

### BSC Mainnet - Swap with Backrun

```bash
# .env configuration
TEST_RPC_URL=https://bsc-dataseed.binance.org/
TEST_PRIVATE_KEY=0x...
SWAP_PROXY_ADDRESS=0x0189D64B45f88380F8d2247963F8c571110Cc33b
REFLEX_ROUTER_ADDRESS=0x0f84F220C793Ac9A9b703a337432DFC073B16FFB
ROUTER_TYPE=v2
TOKEN_IN=0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c  # WBNB
TOKEN_OUT=0x55d398326f99059fF775485246999027B3197955  # USDT
TEST_POOL_ADDRESS=0xC0D3eeAae73b8A63C46E78059C667ECf72938c35
SWAP_AMOUNT_IN=0.01
```

### BSC Mainnet - Simple Swap

```bash
# .env configuration
TEST_RPC_URL=https://bsc-dataseed.binance.org/
TEST_PRIVATE_KEY=0x...
TARGET_ROUTER_ADDRESS=0x10ED43C718714eb63d5aA57B78B54704E256024E  # PancakeSwap V2
TOKEN_IN=0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c  # WBNB
TOKEN_OUT=0x55d398326f99059fF775485246999027B3197955  # USDT
SWAP_AMOUNT_IN=0.01
SLIPPAGE_TOLERANCE=0.5
```

## Comparison

Use both scripts to compare the performance difference:

1. First, run the simple swap to see baseline performance:

   ```bash
   node dist/test-universal/test-swap-only.js
   ```

2. Then run the same swap with MEV backrun capture:
   ```bash
   node dist/test-universal/test-universal.js
   ```

The backrun-enabled version should capture MEV opportunities and potentially provide better net results despite the additional complexity.
