---
sidebar_position: 3
---

# Troubleshooting

Common issues and solutions when working with Reflex Protocol.

## 🚨 Common Issues

### Transaction Failures

#### "Transaction Reverted"

**Symptoms:**

- Backrun transactions fail with revert error
- No specific error message

**Possible Causes:**

1. **Insufficient MEV profit**: The arbitrage opportunity disappeared before execution
2. **Slippage exceeded**: Price moved beyond tolerance
3. **Gas limit too low**: Transaction ran out of gas

**Solutions:**

```typescript
// Increase slippage tolerance
const reflex = new ReflexSDK({
  // ...config
  options: {
    slippageTolerance: 0.01, // Increase to 1%
  },
});

// Increase gas limit
await reflex.backrunedExecute(
  executeParams,
  backrunParams,
  {
    gasLimit: 500000, // Increase gas limit
  }
);

// Check minimum swap threshold before execution
const minSwapThreshold = ethers.parseEther("1"); // 1 ETH equivalent
if (swapAmount < minSwapThreshold) {
  console.log("Swap amount too low, skipping");
  return;
}
```

#### "Insufficient Funds"

**Symptoms:**

- Transactions fail with "insufficient funds for gas"

**Solutions:**

```typescript
// Check balance before transaction
const balance = await provider.getBalance(wallet.address);
const gasRequired = gasLimit * gasPrice;

if (balance < gasRequired) {
  console.error("Insufficient ETH for gas");
  return;
}

// Or add automatic balance checking
await reflex.setOptions({
  autoCheckBalance: true,
  minimumBalance: ethers.parseEther("0.1"), // Keep 0.1 ETH minimum
});
```

### Configuration Issues

#### "Invalid Configuration ID"

**Symptoms:**

- Revenue distribution fails
- Configuration not found errors

**Solutions:**

```typescript
// Verify configuration exists
const config = await reflex.getRevenueConfig(configId);
if (!config) {
  console.error("Configuration not found");
  // Create new configuration
  const newConfigId = await reflex.createRevenueConfig({
    protocolShare: 5000,
    userShare: 3000,
    validatorShare: 2000,
  });
}

// Always validate configuration before use
function validateConfig(config) {
  const total = config.protocolShare + config.userShare + config.validatorShare;
  if (total !== 10000) {
    throw new Error("Share percentages must sum to 100%");
  }
}
```

### Network Issues

#### "Network Connection Failed"

**Symptoms:**

- RPC calls timeout
- Intermittent connection issues

**Solutions:**

```typescript
// Use multiple RPC endpoints
const providers = [
  new ethers.JsonRpcProvider("https://mainnet.infura.io/v3/KEY1"),
  new ethers.JsonRpcProvider("https://eth-mainnet.alchemyapi.io/v2/KEY2"),
  new ethers.JsonRpcProvider("https://cloudflare-eth.com"),
];

// Implement fallback logic
async function callWithFallback(method, ...args) {
  for (const provider of providers) {
    try {
      return await provider[method](...args);
    } catch (error) {
      console.warn(`Provider failed: ${provider.connection.url}`);
    }
  }
  throw new Error("All providers failed");
}

// Add retry logic
const reflex = new ReflexSDK({
  provider,
  options: {
    retries: 3,
    retryDelay: 1000, // 1 second
  },
});
```

## 🔧 Performance Issues

### High Gas Costs

**Problem:** Transactions using too much gas or failing due to gas estimation.

**Solutions:**

1. **Optimize Gas Settings:**

```typescript
// Use EIP-1559 for better gas management
await reflex.setGasStrategy({
  type: "eip1559",
  maxFeePerGas: ethers.parseUnits("30", "gwei"),
  maxPriorityFeePerGas: ethers.parseUnits("2", "gwei"),
});

// Or use legacy gas pricing
await reflex.setGasStrategy({
  type: "legacy",
  gasPrice: ethers.parseUnits("25", "gwei"),
});
```

2. **Gas Estimation:**

```typescript
// Get accurate gas estimates
const gasEstimate = await reflex.estimateGas(params);
const safeGasLimit = (gasEstimate * 120n) / 100n; // Add 20% buffer

await reflex.executeBackrun({
  ...params,
  gasLimit: safeGasLimit,
});
```

### Slow Transaction Processing

**Problem:** Transactions taking too long to confirm.

**Solutions:**

1. **Increase Gas Price:**

```typescript
// Monitor network congestion
const feeData = await provider.getFeeData();
const recommendedGasPrice = (feeData.gasPrice * 110n) / 100n; // 10% above current

await reflex.setGasStrategy({
  gasPrice: recommendedGasPrice,
});
```

2. **Transaction Replacement:**

```typescript
// Enable transaction replacement
await reflex.setOptions({
  enableReplacement: true,
  replacementMultiplier: 1.1, // 10% gas price increase
});
```

## 🐛 Debugging

### Enable Debug Logging

```typescript
import { ReflexSDK } from "@reflex/sdk";

const reflex = new ReflexSDK({
  // ...config
  options: {
    debug: true,
    logLevel: "verbose", // 'error', 'warn', 'info', 'debug', 'verbose'
  },
});

// Custom logger
reflex.setLogger({
  error: (msg, data) => console.error(`[ERROR] ${msg}`, data),
  warn: (msg, data) => console.warn(`[WARN] ${msg}`, data),
  info: (msg, data) => console.info(`[INFO] ${msg}`, data),
  debug: (msg, data) => console.debug(`[DEBUG] ${msg}`, data),
});
```

### Transaction Tracing

```typescript
// Enable transaction tracing
const result = await reflex.executeBackrun({
  ...params,
  trace: true, // Enable detailed tracing
});

if (!result.success) {
  console.log("Trace data:", result.trace);
}
```

### Memory Pool Analysis

```typescript
// Analyze failed opportunities
reflex.on("OpportunityMissed", (event) => {
  console.log("Missed opportunity:", {
    reason: event.reason,
    targetTx: event.targetTx,
    estimatedProfit: ethers.formatEther(event.estimatedProfit),
    competitorTx: event.competitorTx,
  });
});
```

## 📊 Monitoring

### Health Checks

```typescript
// Implement health monitoring
async function healthCheck() {
  try {
    // Check provider connection
    const blockNumber = await provider.getBlockNumber();
    console.log("Latest block:", blockNumber);

    // Check contract status
    const routerStatus = await reflex.getRouterStatus();
    console.log("Router status:", routerStatus);

    // Check balance
    const balance = await provider.getBalance(wallet.address);
    console.log("Wallet balance:", ethers.formatEther(balance));

    return true;
  } catch (error) {
    console.error("Health check failed:", error);
    return false;
  }
}

// Run health checks periodically
setInterval(healthCheck, 60000); // Every minute
```

### Performance Metrics

```typescript
// Track performance metrics
const metrics = {
  totalTransactions: 0,
  successfulTransactions: 0,
  totalGasUsed: 0n,
  totalProfit: 0n,
};

reflex.on("TransactionComplete", (event) => {
  metrics.totalTransactions++;
  if (event.success) {
    metrics.successfulTransactions++;
    metrics.totalGasUsed += event.gasUsed;
    metrics.totalProfit += event.profit;
  }

  // Calculate success rate
  const successRate =
    metrics.successfulTransactions / metrics.totalTransactions;
  console.log("Success rate:", (successRate * 100).toFixed(2) + "%");
});
```

## 🆘 Getting Help

### Error Reporting

When reporting issues, please include:

1. **SDK Version:**

```bash
npm list @reflex/sdk
```

2. **Network Details:**

```typescript
console.log("Chain ID:", await provider.getNetwork().then((n) => n.chainId));
console.log("Block number:", await provider.getBlockNumber());
```

3. **Transaction Details:**

```typescript
// For failed transactions
console.log("Transaction hash:", txHash);
console.log("Error message:", error.message);
console.log("Error code:", error.code);
```

4. **Configuration:**

```typescript
// Sanitized configuration (remove private keys!)
console.log("SDK config:", {
  chainId: config.chainId,
  options: config.options,
  // DON'T include private keys or sensitive data
});
```

### Support Channels

- **GitHub Issues**: [Report bugs](https://github.com/reflex-mev/reflex/issues)
- **Discord**: [Real-time support](https://discord.gg/reflex)
- **Email**: support@reflex-protocol.io
- **Documentation**: [Full docs](https://docs.reflex-protocol.io)

### Community Resources

- **FAQ**: Common questions and answers
- **Examples**: Working code examples
- **Best Practices**: Community-driven guidelines
- **Tutorials**: Step-by-step guides

---

_Still having issues? Don't hesitate to reach out to our community for help!_
