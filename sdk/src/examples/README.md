# Reflex SDK Examples

This directory contains comprehensive examples demonstrating how to use the Reflex SDK for MEV backrunning using the `backrunedExecute` method.

## Available Examples

### 1. Basic Example (`basic.ts`)
Demonstrates fundamental SDK usage including:
- SDK initialization
- Backruned execute operations (execute transaction + backrun in one call)
- Gas estimation
- Event listening
- Admin functions
- Function encoding for batch transactions

**Run:** `npx tsx examples/basic.ts`

### 2. Uniswap V2 Example (`uniswapv2.ts`)
Shows advanced V2-specific backrunning strategies:
- Monitoring Uniswap V2 swaps
- Executing combined transactions + backrun on V2 pools
- Cross-DEX arbitrage opportunities using backrunedExecute
- Batch operations across multiple V2 pairs

**Features:**
- WETH/USDC and WETH/USDT pair integration
- V2 Router transaction execution with immediate backrun
- Pair address calculation
- Swap calldata generation

**Run:** `npx tsx examples/uniswapv2.ts`

### 3. Uniswap V3 Example (`uniswapv3.ts`)
Demonstrates V3-specific concentrated liquidity strategies:
- V3 exact input/output swaps with backrun
- Cross-tier arbitrage (0.05%, 0.3%, 1% fee pools)
- Multi-hop swap backrunning
- Tick-based liquidity analysis
- Fee tier optimization

**Features:**
- Multiple fee tier integration
- V3 Router transaction execution with immediate backrun
- Path encoding for multi-hop swaps
- Pool address computation
- Advanced gas estimation

**Run:** `npx tsx examples/uniswapv3.ts`

## Getting Started

### Prerequisites
```bash
# Install dependencies
npm install

# Set up environment variables
cp .env.example .env
# Edit .env with your RPC URL, private key, and contract addresses
```

### Environment Variables
Create a `.env` file with:
```env
RPC_URL=https://eth-mainnet.alchemyapi.io/v2/YOUR_API_KEY
PRIVATE_KEY=your_private_key_here
REFLEX_ROUTER=0x1234567890123456789012345678901234567890
```

### Running Examples

```bash
# Run individual examples
npx tsx examples/basic.ts
npx tsx examples/uniswapv2.ts
npx tsx examples/uniswapv3.ts

# Run all examples in sequence
npx tsx examples/index.ts
```

## Example Structure

Each example follows a consistent structure:

```typescript
import { ethers } from "ethers";
import { ReflexSDK } from "../src/ReflexSDK";
import { ExecuteParams, BackrunParams } from "../src/types";

async function exampleFunction() {
  // 1. Setup provider and signer
  const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
  const wallet = new ethers.Wallet(process.env.PRIVATE_KEY, provider);

  // 2. Initialize Reflex SDK
  const reflexSDK = new ReflexSDK(provider, wallet, config);

  // 3. Execute operations
  const result = await reflexSDK.backrunedExecute(executeParams, backrunParams);
  
  // 4. Handle results
  console.log("Result:", result);
}
```

## Common Patterns

### Gas Configuration
```typescript
const reflexSDK = new ReflexSDK(provider, wallet, {
  routerAddress: "0x...",
  defaultGasLimit: 800000n,     // Higher for complex operations
  gasPriceMultiplier: 1.2,      // 20% above current gas price
});
```

### Event Monitoring
```typescript
const unsubscribe = reflexSDK.watchBackrunExecuted(
  (event) => {
    console.log("Backrun executed:", event);
  },
  {
    triggerPoolId: "0x...",      // Filter by specific pool
    recipient: wallet.address,   // Filter by recipient
  }
);
```

### Error Handling
```typescript
try {
  const result = await reflexSDK.backrunedExecute(executeParams, backrunParams);
  console.log("Success:", result);
} catch (error) {
  console.error("Backrun failed:", error.message);
}
```

## Best Practices

1. **Gas Management**: Always estimate gas before executing transactions
2. **Event Filtering**: Use specific filters to reduce noise in event monitoring
3. **Error Handling**: Implement proper try-catch blocks for all operations
4. **Batch Operations**: Use function encoding for efficient batch transactions
5. **Pool Selection**: Monitor multiple pools/fee tiers for better opportunities

## Troubleshooting

### Common Issues

1. **Transaction Fails**: Check gas limits and ensure sufficient balance
2. **Events Not Detected**: Verify contract addresses and event filters
3. **High Gas Costs**: Consider adjusting gas price multiplier
4. **RPC Limits**: Use premium RPC providers for high-frequency operations

### Debug Mode
Set environment variable for detailed logging:
```bash
DEBUG=reflex:* npx tsx examples/basic.ts
```

## Contributing

When adding new examples:

1. Follow the existing naming convention
2. Include comprehensive comments
3. Add helper functions for reusable logic
4. Export main functions and utilities
5. Update this README with new example details

## Resources

- [Reflex SDK Documentation](../README.md)
- [Uniswap V2 Documentation](https://docs.uniswap.org/protocol/V2/introduction)
- [Uniswap V3 Documentation](https://docs.uniswap.org/protocol/introduction)
- [Ethers.js Documentation](https://docs.ethers.org/)
