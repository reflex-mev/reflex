---
sidebar_position: 1
---

# Basic Backrun Example

Learn how to implement a basic MEV backrun using Reflex Protocol. This example demonstrates the fundamental concepts of MEV capture and profit distribution.

## 🎯 Overview

In this example, we'll:

1. Set up a simple MEV monitoring system
2. Detect arbitrage opportunities
3. Execute profitable backruns
4. Distribute profits to users

## 🛠️ Prerequisites

- ✅ Node.js v18+
- ✅ Ethers.js v6
- ✅ Reflex SDK installed
- ✅ Access to Ethereum testnet (Goerli)

## 📦 Setup

Create a new project and install dependencies:

```bash
mkdir reflex-backrun-example
cd reflex-backrun-example
npm init -y
npm install @reflex/sdk ethers dotenv
npm install -D typescript @types/node ts-node
```

Create environment configuration:

```bash title=".env"
# Network
RPC_URL=https://goerli.infura.io/v3/YOUR_PROJECT_ID
PRIVATE_KEY=your_private_key_here

# Reflex Contracts (Goerli)
REFLEX_ROUTER=0x742d35Cc6634C0532925a3b8D598C4B4B3A3A3A3
REFLEX_QUOTER=0x9E545E3C0baAB3E08CdfD552C960A1050f373042

# Configuration
CONFIG_ID=0x1234567890123456789012345678901234567890123456789012345678901234
```

## 💡 Basic Implementation

### Step 1: Initialize SDK

```typescript title="src/reflex-client.ts"
import { ethers } from "ethers";
import { ReflexSDK } from "@reflex/sdk";
import * as dotenv from "dotenv";

dotenv.config();

export class ReflexClient {
  private provider: ethers.Provider;
  private signer: ethers.Signer;
  private reflex: ReflexSDK;

  constructor() {
    this.provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
    this.signer = new ethers.Wallet(process.env.PRIVATE_KEY!, this.provider);

    this.reflex = new ReflexSDK(
      this.provider,
      process.env.REFLEX_ROUTER!,
      process.env.REFLEX_QUOTER
    );
  }

  async getBalance(): Promise<bigint> {
    return await this.provider.getBalance(this.signer.address);
  }

  async triggerBackrun(params: {
    poolId: string;
    swapAmount: bigint;
    token0In: boolean;
    recipient: string;
  }) {
    try {
      console.log("🎯 Attempting backrun...");
      console.log("Pool:", params.poolId);
      console.log("Amount:", ethers.formatEther(params.swapAmount));

      // Estimate gas first
      const gasEstimate = await this.reflex.estimateBackrunGas({
        triggerPoolId: params.poolId,
        swapAmountIn: params.swapAmount,
        token0In: params.token0In,
        recipient: params.recipient,
        configId: process.env.CONFIG_ID!,
      });

      console.log("⛽ Estimated gas:", gasEstimate.toString());

      // Execute backrun
      const result = await this.reflex.triggerBackrun(
        this.signer,
        {
          triggerPoolId: params.poolId,
          swapAmountIn: params.swapAmount,
          token0In: params.token0In,
          recipient: params.recipient,
          configId: process.env.CONFIG_ID!,
        },
        {
          gasLimit: gasEstimate + BigInt(50000), // Add buffer
        }
      );

      console.log("✅ Backrun executed successfully!");
      console.log("💰 Profit:", ethers.formatEther(result.profit));
      console.log("🪙 Token:", result.profitToken);
      console.log("🧾 TX:", result.transaction.hash);

      return result;
    } catch (error) {
      console.error("❌ Backrun failed:", error);
      throw error;
    }
  }

  startEventListener() {
    console.log("👂 Starting event listener...");

    this.reflex.onBackrunExecuted((event) => {
      console.log("🔥 Backrun executed:", {
        pool: event.triggerPoolId,
        profit: ethers.formatEther(event.profit),
        token: event.profitToken,
        user: event.recipient,
        block: event.blockNumber,
        tx: event.transactionHash,
      });
    });

    this.reflex.onRevenueDistributed((event) => {
      console.log("💸 Revenue distributed:", {
        config: event.configId,
        token: event.token,
        amount: ethers.formatEther(event.totalAmount),
        block: event.blockNumber,
      });
    });
  }
}
```

### Step 2: Pool Monitor

```typescript title="src/pool-monitor.ts"
import { ethers } from "ethers";
import { ReflexClient } from "./reflex-client";

export class PoolMonitor {
  private reflex: ReflexClient;
  private provider: ethers.Provider;
  private monitoredPools: Set<string> = new Set();

  // Uniswap V2 Pair ABI (minimal)
  private readonly PAIR_ABI = [
    "event Swap(address indexed sender, uint amount0In, uint amount1In, uint amount0Out, uint amount1Out, address indexed to)",
    "function token0() external view returns (address)",
    "function token1() external view returns (address)",
    "function getReserves() external view returns (uint112, uint112, uint32)",
  ];

  constructor() {
    this.reflex = new ReflexClient();
    this.provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
  }

  async addPool(poolAddress: string) {
    if (this.monitoredPools.has(poolAddress)) {
      console.log("⚠️ Pool already monitored:", poolAddress);
      return;
    }

    console.log("🔍 Adding pool to monitor:", poolAddress);

    const poolContract = new ethers.Contract(
      poolAddress,
      this.PAIR_ABI,
      this.provider
    );

    try {
      // Verify it's a valid pool
      const token0 = await poolContract.token0();
      const token1 = await poolContract.token1();
      const reserves = await poolContract.getReserves();

      console.log("✅ Pool verified:", {
        token0,
        token1,
        reserve0: ethers.formatEther(reserves[0]),
        reserve1: ethers.formatEther(reserves[1]),
      });

      // Start monitoring swaps
      poolContract.on("Swap", this.handleSwap.bind(this, poolAddress));
      this.monitoredPools.add(poolAddress);
    } catch (error) {
      console.error("❌ Failed to add pool:", error);
    }
  }

  private async handleSwap(
    poolAddress: string,
    sender: string,
    amount0In: bigint,
    amount1In: bigint,
    amount0Out: bigint,
    amount1Out: bigint,
    to: string,
    event: ethers.EventLog
  ) {
    console.log("🔄 Swap detected in pool:", poolAddress);
    console.log("📊 Swap details:", {
      sender,
      amount0In: ethers.formatEther(amount0In),
      amount1In: ethers.formatEther(amount1In),
      amount0Out: ethers.formatEther(amount0Out),
      amount1Out: ethers.formatEther(amount1Out),
      to,
      block: event.blockNumber,
      tx: event.transactionHash,
    });

    // Determine swap direction and amount
    const isToken0In = amount0In > 0;
    const swapAmountIn = isToken0In ? amount0In : amount1In;

    // Check if swap is large enough for backrun
    const minBackrunThreshold = ethers.parseEther("0.1"); // 0.1 ETH equivalent

    if (swapAmountIn >= minBackrunThreshold) {
      console.log("💡 Large swap detected, attempting backrun...");

      try {
        await this.reflex.triggerBackrun({
          poolId: poolAddress,
          swapAmount: swapAmountIn / BigInt(10), // Use 10% for backrun
          token0In: isToken0In,
          recipient: sender, // Give profit back to original swapper
        });
      } catch (error) {
        console.log("⚠️ Backrun not profitable or failed");
      }
    } else {
      console.log("📏 Swap too small for backrun");
    }
  }

  getMonitoredPools(): string[] {
    return Array.from(this.monitoredPools);
  }

  removePool(poolAddress: string) {
    if (this.monitoredPools.has(poolAddress)) {
      // Remove event listeners
      const poolContract = new ethers.Contract(
        poolAddress,
        this.PAIR_ABI,
        this.provider
      );
      poolContract.removeAllListeners("Swap");

      this.monitoredPools.delete(poolAddress);
      console.log("🗑️ Removed pool from monitoring:", poolAddress);
    }
  }
}
```

### Step 3: Main Application

```typescript title="src/index.ts"
import { ReflexClient } from "./reflex-client";
import { PoolMonitor } from "./pool-monitor";

// Example pool addresses (Goerli testnet)
const EXAMPLE_POOLS = [
  "0x742d35Cc6634C0532925a3b8D598C4B4B3A3A3A3", // Example WETH/USDC
  "0x9E545E3C0baAB3E08CdfD552C960A1050f373042", // Example WETH/DAI
];

async function main() {
  console.log("🚀 Starting Reflex Backrun Example");

  // Initialize components
  const reflexClient = new ReflexClient();
  const poolMonitor = new PoolMonitor();

  // Check balance
  const balance = await reflexClient.getBalance();
  console.log("💰 Account balance:", ethers.formatEther(balance), "ETH");

  if (balance < ethers.parseEther("0.1")) {
    console.warn("⚠️ Low balance! You might not have enough ETH for gas fees.");
  }

  // Start event listeners
  reflexClient.startEventListener();

  // Add pools to monitor
  console.log("📡 Setting up pool monitoring...");
  for (const poolAddress of EXAMPLE_POOLS) {
    await poolMonitor.addPool(poolAddress);
  }

  console.log(
    "✅ Monitoring started for",
    poolMonitor.getMonitoredPools().length,
    "pools"
  );
  console.log("👀 Watching for swap events...");

  // Keep the process running
  process.stdin.resume();

  // Graceful shutdown
  process.on("SIGINT", () => {
    console.log("\n🛑 Shutting down gracefully...");

    // Clean up
    for (const pool of poolMonitor.getMonitoredPools()) {
      poolMonitor.removePool(pool);
    }

    console.log("👋 Goodbye!");
    process.exit(0);
  });
}

// Example: Manual backrun trigger
async function triggerManualBackrun() {
  const reflexClient = new ReflexClient();

  try {
    await reflexClient.triggerBackrun({
      poolId: EXAMPLE_POOLS[0],
      swapAmount: ethers.parseEther("1.0"),
      token0In: true,
      recipient: "0xYourAddressHere",
    });
  } catch (error) {
    console.error("Manual backrun failed:", error);
  }
}

// Run the main application
if (require.main === module) {
  main().catch(console.error);
}

export { main, triggerManualBackrun };
```

### Step 4: Configuration Script

```typescript title="scripts/configure.ts"
import { ethers } from "ethers";
import { ReflexSDK } from "@reflex/sdk";
import * as dotenv from "dotenv";

dotenv.config();

async function configureRevenue() {
  const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
  const signer = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

  const reflex = new ReflexSDK(provider, process.env.REFLEX_ROUTER!);

  console.log("⚙️ Configuring revenue sharing...");

  const config = {
    configId: process.env.CONFIG_ID!,
    recipients: [
      await signer.getAddress(), // Your address: 60%
      "0x742d35Cc6634C0532925a3b8D598C4B4B3A3A3A3", // Protocol fund: 25%
      "0x9E545E3C0baAB3E08CdfD552C960A1050f373042", // Community: 15%
    ],
    shares: [60, 25, 15], // Must sum to 100
  };

  try {
    const tx = await reflex.configureRevenue(signer, config);
    await tx.wait();

    console.log("✅ Revenue configuration complete!");
    console.log("🧾 Transaction:", tx.hash);
    console.log("🆔 Config ID:", config.configId);

    // Verify configuration
    const storedConfig = await reflex.getRevenueConfig(config.configId);
    console.log("📋 Stored configuration:", {
      recipients: storedConfig.recipients,
      shares: storedConfig.shares,
      isActive: storedConfig.isActive,
    });
  } catch (error) {
    console.error("❌ Configuration failed:", error);
  }
}

configureRevenue().catch(console.error);
```

## 🚀 Running the Example

### 1. Configure Revenue Sharing

```bash
npx ts-node scripts/configure.ts
```

Expected output:

```
⚙️ Configuring revenue sharing...
✅ Revenue configuration complete!
🧾 Transaction: 0xabc123...
🆔 Config ID: 0x1234567890123456789012345678901234567890123456789012345678901234
```

### 2. Start Monitoring

```bash
npx ts-node src/index.ts
```

Expected output:

```
🚀 Starting Reflex Backrun Example
💰 Account balance: 0.5 ETH
📡 Setting up pool monitoring...
🔍 Adding pool to monitor: 0x742d35Cc6634C0532925a3b8D598C4B4B3A3A3A3
✅ Pool verified: {
  token0: '0xA0b86a33E6a42E64d4C2a7f95F8b7E3b2C8d9E0f',
  token1: '0xB7f8BC63BbcAD2c3b3C3d4e5F6e7d8E9f0A1B2c3',
  reserve0: '1000.0',
  reserve1: '2000000.0'
}
👂 Starting event listener...
✅ Monitoring started for 2 pools
👀 Watching for swap events...
```

### 3. When a Swap Occurs

```
🔄 Swap detected in pool: 0x742d35Cc6634C0532925a3b8D598C4B4B3A3A3A3
📊 Swap details: {
  sender: '0xUser123...',
  amount0In: '1.0',
  amount1In: '0.0',
  amount0Out: '0.0',
  amount1Out: '1950.0',
  to: '0xUser123...',
  block: 8123456,
  tx: '0xdef456...'
}
💡 Large swap detected, attempting backrun...
🎯 Attempting backrun...
Pool: 0x742d35Cc6634C0532925a3b8D598C4B4B3A3A3A3
Amount: 0.1
⛽ Estimated gas: 150000
✅ Backrun executed successfully!
💰 Profit: 0.0123
🪙 Token: 0xA0b86a33E6a42E64d4C2a7f95F8b7E3b2C8d9E0f
🧾 TX: 0x789abc...
```

## 📊 Understanding the Results

When a backrun is successful, you'll see:

1. **Swap Detection**: The monitor detects a swap in a monitored pool
2. **Opportunity Analysis**: Checks if the swap is large enough for backrun
3. **Gas Estimation**: Estimates the cost of executing the backrun
4. **Execution**: Executes the backrun if profitable
5. **Profit Distribution**: Distributes profits according to configuration

### Profit Calculation

```
Original Swap: 1.0 ETH → 1950 USDC
Price Impact: Created arbitrage opportunity
Backrun Amount: 0.1 ETH (10% of original)
Arbitrage Profit: 0.0123 ETH
Gas Cost: ~0.005 ETH
Net Profit: 0.0073 ETH

Distribution (based on config):
- Your share (60%): 0.0044 ETH
- Protocol (25%): 0.0018 ETH
- Community (15%): 0.0011 ETH
```

## 🔧 Customization

### Adjust Backrun Parameters

```typescript
// In pool-monitor.ts, modify these values:
const minBackrunThreshold = ethers.parseEther("0.5"); // Larger threshold
const backrunRatio = 20; // Use 5% instead of 10%

// Use different ratio:
swapAmount: swapAmountIn / BigInt(backrunRatio);
```

### Add More Pools

```typescript
// Add more pools to monitor
const MORE_POOLS = ["0xYourPool1", "0xYourPool2", "0xYourPool3"];

for (const pool of MORE_POOLS) {
  await poolMonitor.addPool(pool);
}
```

### Custom Profit Sharing

```typescript
// In configure.ts, modify the revenue config:
const config = {
  configId: ethers.keccak256(ethers.toUtf8Bytes("MY_CUSTOM_CONFIG")),
  recipients: [
    await signer.getAddress(), // You: 40%
    "0xProtocolTreasury", // Protocol: 30%
    "0xLPProviders", // LPs: 20%
    "0xCommunityFund", // Community: 10%
  ],
  shares: [40, 30, 20, 10],
};
```

## 🐛 Troubleshooting

### Common Issues

**No swaps detected:**

- Check pool addresses are correct
- Verify pools have active trading
- Ensure RPC connection is stable

**Backruns always fail:**

- Check gas price settings
- Verify account has sufficient ETH
- Ensure pools have adequate liquidity

**No profit distribution:**

- Verify revenue configuration is set
- Check config ID matches in code
- Ensure recipients are valid addresses

### Debug Mode

Add debug logging:

```typescript
// Add to .env
DEBUG = true;

// In your code:
if (process.env.DEBUG === "true") {
  console.log("🐛 Debug info:", {
    poolReserves: reserves,
    gasPrice: await provider.getFeeData(),
    accountNonce: await signer.getNonce(),
  });
}
```

## 🎯 Next Steps

Now that you have a basic backrun system working:

1. **[Advanced Examples](uniswap-v3)** - Learn V3 integration
2. **[Custom Strategies](custom-dex)** - Build custom MEV strategies
3. **[Production Deployment](../integration/testing)** - Deploy to mainnet
4. **[Monitoring & Analytics](../api/events)** - Track performance

## 📚 Additional Resources

- [Reflex SDK Documentation](../api/typescript-sdk)
- [Smart Contracts API](../api/smart-contracts)
- [Integration Guide](../integration/overview)
- [Security Best Practices](../security/best-practices)

---

This example provides a solid foundation for MEV capture. The modular design allows you to easily extend and customize the system for your specific needs.
