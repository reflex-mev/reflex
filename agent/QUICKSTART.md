# Reflex Trading Agent - Quick Start Guide

## 🎉 Congratulations!

Your Reflex Trading Agent MVP is now set up! Here's what's been created:

## 📁 Project Structure

```
agent/
├── package.json              ✅ Created
├── tsconfig.json            ✅ Created
├── .env                     ✅ Created (configure this!)
├── .env.example             ✅ Created
├── README.md                ✅ Created
├── src/
│   ├── index.ts             ✅ Entry point
│   ├── Agent.ts             ✅ Main orchestrator
│   ├── config.ts            ✅ Configuration loader
│   ├── types.ts             ✅ TypeScript types
│   ├── services/
│   │   ├── DualEventListener.ts  ✅ WebSocket + Polling
│   │   └── PoolCache.ts         ✅ In-memory cache
│   ├── execution/
│   │   └── ReflexExecutor.ts    ✅ Reflex SDK integration
│   ├── utils/
│   │   ├── logger.ts            ✅ Winston logger
│   │   ├── slippage.ts          ✅ Slippage calculations
│   │   └── poolId.ts            ✅ Pool ID helpers
│   └── constants/
│       └── uniswapV3.ts         ✅ Uniswap V3 constants
└── node_modules/            ✅ Dependencies installed
```

## 🚀 Next Steps

### 1. Configure Your Environment

Edit `.env` file with your actual values:

```bash
# REQUIRED - Get from Alchemy, Infura, or your RPC provider
RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_ACTUAL_API_KEY

# OPTIONAL but recommended for real-time events
RPC_WS_URL=wss://eth-mainnet.g.alchemy.com/v2/YOUR_ACTUAL_API_KEY

# REQUIRED - Your Reflex Router deployment address
REFLEX_ROUTER_ADDRESS=0xYOUR_ROUTER_ADDRESS_HERE

# REQUIRED - Your wallet private key (KEEP THIS SECURE!)
PRIVATE_KEY=0xYOUR_PRIVATE_KEY_HERE
```

### 2. Test the Configuration

```bash
npm run dev
```

You should see output like:
```
🚀 Starting Reflex Trading Agent (MVP Mode)
✅ Configuration validated
Initializing services...
✅ Services initialized
Starting event collection...
✅ Polling started (interval: 12000ms)
Starting execution timer...
⏰ Execution interval: 60000ms (60s)
✅ Trading Agent started successfully
```

### 3. Monitor the Logs

The agent will:
- ✅ Poll for Uniswap V3 swap events every 12 seconds
- ✅ Cache swap data in memory
- ✅ Analyze pools every 60 seconds
- ✅ Execute backruns on profitable opportunities

Look for these log messages:
- `Swap event cached` - Event successfully collected
- `🔄 Starting backrun execution cycle` - Analysis cycle starting
- `Found X pools in cache` - Pools being tracked
- `✅ Backrun successful` - Profitable execution!

## 🛠️ Configuration Tips

### For Testing/Development

```bash
# Use testnet
CHAIN_ID=11155111  # Sepolia
RPC_URL=https://sepolia.infura.io/v3/YOUR_KEY

# Conservative settings
EXECUTION_INTERVAL_MS=120000  # 2 minutes
MIN_PROFIT_THRESHOLD_USD=50   # Higher threshold
MAX_CONCURRENT_TXS=1          # One at a time
```

### For Production

```bash
# Enable WebSocket for real-time events
USE_WEBSOCKET=true
RPC_WS_URL=wss://eth-mainnet.g.alchemy.com/v2/YOUR_KEY

# More aggressive
EXECUTION_INTERVAL_MS=30000   # 30 seconds
TOP_POOLS_COUNT=20            # Track more pools
MIN_PROFIT_THRESHOLD_USD=10   # Lower threshold
```

## 📊 Understanding the Output

### Cache Stats
```
Cache stats { pools: 15, totalSwaps: 234, memoryUsageMB: 0.23 }
```
- `pools`: Number of active pools being tracked
- `totalSwaps`: Total swap events in memory
- `memoryUsageMB`: Approximate memory usage

### Top Opportunities
```
Top 1: {
  pool: '0x88e6A0c2...',
  score: '75.50',
  volume: '$125000',
  slippage: '2.35%',
  estimatedProfit: '$8.81'
}
```
- `score`: Opportunity score (0-100, higher is better)
- `volume`: Total volume in recent blocks
- `slippage`: Average slippage (higher = more MEV)
- `estimatedProfit`: Estimated profit in USD

### Execution Results
```
✅ Backrun successful {
  pool: '0x88e6A0c2...',
  txHash: '0x1234abcd...',
  profit: '0.005',
  profitToken: '0xC02aaA...',
  gasUsed: '250000',
  executionTime: '2500ms'
}
```

## ⚠️ Important Notes

### Security
- **Never commit your `.env` file** (it's in `.gitignore`)
- **Store private keys securely** - consider using environment variables or a secrets manager
- **Test on testnet first** before using real funds

### Gas Costs
- Monitor gas prices - set `MAX_GAS_PRICE_GWEI` appropriately
- Backruns cost gas - ensure profitability after gas costs
- Start with a small amount of ETH for testing

### Expected Behavior
- The agent will start with **0 pools** in cache
- It takes **10-20 minutes** to collect enough data
- **Not all executions will be profitable** - that's normal
- The agent learns over time which pools are most profitable

## 🐛 Troubleshooting

### "No pools in cache yet"
- **Wait**: Agent is collecting data
- **Check RPC**: Ensure RPC_URL is working
- **Check network**: Are there active swaps on-chain?

### "Cannot find module '@reflex-mev/sdk'"
```bash
cd ../sdk && npm run build
cd ../agent && npm install ../sdk
```

### "Configuration validation failed"
- Check all REQUIRED fields in `.env`
- Ensure RPC_URL starts with `https://` or `http://`
- Ensure PRIVATE_KEY starts with `0x`

### High memory usage
- Reduce `STATISTICS_WINDOW_BLOCKS`
- Reduce `TOP_POOLS_COUNT`
- Restart the agent periodically

## 📈 Optimization Tips

### To increase profit opportunities:
1. Lower `MIN_PROFIT_THRESHOLD_USD`
2. Increase `TOP_POOLS_COUNT`
3. Decrease `EXECUTION_INTERVAL_MS`
4. Enable `USE_WEBSOCKET=true`

### To reduce costs:
1. Increase `MIN_PROFIT_THRESHOLD_USD`
2. Decrease `MAX_GAS_PRICE_GWEI`
3. Decrease `MAX_CONCURRENT_TXS`
4. Increase `EXECUTION_INTERVAL_MS`

## 🎯 Success Metrics

Monitor these to gauge performance:
- **Cache growth**: Should reach 10-20 pools within 30 minutes
- **Execution attempts**: Should see attempts every execution cycle
- **Success rate**: Aim for >50% of executions to be profitable
- **Profit > Gas**: Ensure profit exceeds gas costs

## 📚 Next Steps After MVP

Once the MVP is working:
1. Add USD price feeds for accurate volume calculation
2. Implement more sophisticated opportunity scoring
3. Add transaction simulation before execution
4. Build a simple dashboard for monitoring
5. Add more DEX support (Sushiswap, Curve, etc.)

## 🆘 Need Help?

Check the logs:
- Use `LOG_LEVEL=debug` for more detailed output
- Logs show exactly what the agent is doing
- Look for error messages and stack traces

Happy hunting! 🎯💰
