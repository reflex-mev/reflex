# Reflex Trading Agent (MVP)

A TypeScript-based MEV trading agent that monitors Uniswap V3 swap events and executes backrun transactions via the Reflex Router.

## Features (MVP)

- ✅ Dual event listening (WebSocket + Block Polling)
- ✅ In-memory pool cache with automatic pruning
- ✅ Slippage calculation from swap events
- ✅ Interval-based execution
- ✅ Environment-based configuration
- ✅ Direct Reflex Router contract interaction (no SDK dependency)

## Quick Start

### 1. Install Dependencies

```bash
npm install
```

### 2. Configure Environment

```bash
cp .env.example .env
# Edit .env with your configuration
```

Required variables:
- `RPC_URL` - Your Ethereum RPC endpoint
- `RPC_WS_URL` - WebSocket RPC endpoint (optional but recommended)
- `REFLEX_ROUTER_ADDRESS` - Deployed Reflex Router contract address
- `PRIVATE_KEY` - Your wallet private key (keep secure!)

### 3. Run the Agent

```bash
# Development mode (with hot reload)
npm run dev

# Production mode
npm run build
npm start
```

## Configuration

All configuration is done via environment variables. See `.env.example` for all available options.

### Key Settings

- `EXECUTION_INTERVAL_MS` - How often to check for opportunities (default: 30s)
- `TOP_POOLS_COUNT` - Number of top pools to consider (default: 10)
- `MIN_PROFIT_THRESHOLD_USD` - Minimum profit to execute (default: $10)
- `MAX_GAS_PRICE_GWEI` - Maximum gas price willing to pay (default: 100 gwei)

## Architecture

```
Event Collection (Background)     Execution (Interval Timer)
─────────────────────────         ────────────────────────
WebSocket Events ─┐               Every 30s:
                  ├──▶ Cache ───▶ Query Top 10 Pools ──▶ Execute Backruns
Block Polling ────┘               Filter by Profit         via Reflex SDK
```

## Safety

- Gas price protection
- Profit threshold filtering
- Concurrent transaction limits
- Automatic error handling and retry

## Monitoring

Watch the logs for:
- `✅ Backrun successful` - Profitable executions
- `❌ Backrun failed` - Failed attempts
- `🔄 Starting backrun execution cycle` - Regular execution cycles

## Development

```bash
# Run in development mode
npm run dev

# Build
npm run build

# Clean build artifacts
npm run clean
```

## License

MIT
