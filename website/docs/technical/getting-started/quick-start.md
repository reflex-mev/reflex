---
sidebar_position: 2
---

# Quick Start

Get up and running with Reflex Protocol in under 10 minutes. This guide will walk you through creating your first MEV capture integration.

## 🎯 Overview

In this quick start, you'll:

1. Set up a basic Reflex integration
2. Deploy a simple plugin contract
3. Execute your first backrun
4. Configure revenue sharing

## 🛠️ Prerequisites

Make sure you've completed the [Installation](installation) guide and have:

- ✅ Foundry installed
- ✅ Node.js v18+
- ✅ Reflex SDK installed
- ✅ Test network access (we'll use Goerli)

## Step 1: Initialize Your Project

Create a new directory for your Reflex integration:

```bash
mkdir my-reflex-integration
cd my-reflex-integration
npm init -y
```

Install the Reflex SDK:

```bash
npm install @reflex/sdk ethers dotenv
npm install -D @types/node typescript ts-node
```

Create a basic TypeScript configuration:

```json title="tsconfig.json"
{
  "compilerOptions": {
    "target": "es2020",
    "module": "commonjs",
    "lib": ["es2020"],
    "outDir": "./dist",
    "rootDir": "./src",
    "strict": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "forceConsistentCasingInFileNames": true,
    "resolveJsonModule": true
  },
  "include": ["src/**/*"],
  "exclude": ["node_modules", "dist"]
}
```

## Step 2: Environment Setup

Create a `.env` file:

```bash title=".env"
# Network Configuration
RPC_URL=https://goerli.infura.io/v3/YOUR_PROJECT_ID
PRIVATE_KEY=your_private_key_here

# Reflex Contract Addresses (Goerli Testnet)
REFLEX_ROUTER=0x742d35Cc6634C0532925a3b8D598C4B4B3A3A3A3
REFLEX_QUOTER=0x9E545E3C0baAB3E08CdfD552C960A1050f373042

# Your Configuration
MY_ADDRESS=0xYourAddressHere
CONFIG_ID=0x0000000000000000000000000000000000000000000000000000000000000001
```

## Step 3: Create Your First Integration

Create the main integration file:

```typescript title="src/index.ts"
import { ethers } from "ethers";
import { ReflexSDK } from "@reflex/sdk";
import * as dotenv from "dotenv";

dotenv.config();

async function main() {
  // Initialize provider and signer
  const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
  const signer = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

  // Initialize Reflex SDK
  const reflex = new ReflexSDK(
    provider,
    process.env.REFLEX_ROUTER!,
    process.env.REFLEX_QUOTER
  );

  console.log("🚀 Reflex SDK initialized");
  console.log("📊 Router:", process.env.REFLEX_ROUTER);
  console.log("💡 Quoter:", process.env.REFLEX_QUOTER);

  // Example: Trigger a backrun
  await triggerExampleBackrun(reflex, signer);

  // Example: Listen for events
  await listenForBackrunEvents(reflex);
}

async function triggerExampleBackrun(reflex: ReflexSDK, signer: ethers.Signer) {
  try {
    console.log("\n🎯 Triggering example backrun...");

    const params = {
      triggerPoolId: "0x742d35Cc6634C0532925a3b8D598C4B4B3A3A3A3", // Example pool
      swapAmountIn: ethers.parseEther("0.1"),
      token0In: true,
      recipient: process.env.MY_ADDRESS!,
      configId: process.env.CONFIG_ID!,
    };

    // Estimate gas first
    const gasEstimate = await reflex.estimateBackrunGas(params);
    console.log("⛽ Estimated gas:", gasEstimate.toString());

    // Execute the backrun
    const result = await reflex.triggerBackrun(signer, params, {
      gasLimit: gasEstimate + BigInt(50000), // Add buffer
    });

    console.log("✅ Backrun executed!");
    console.log("💰 Profit:", ethers.formatEther(result.profit), "ETH");
    console.log("🪙 Profit token:", result.profitToken);
    console.log("🧾 Transaction:", result.transaction.hash);
  } catch (error) {
    console.error("❌ Backrun failed:", error);
  }
}

async function listenForBackrunEvents(reflex: ReflexSDK) {
  console.log("\n👂 Listening for backrun events...");

  reflex.onBackrunExecuted((event) => {
    console.log("🔥 New backrun executed:");
    console.log("  Pool:", event.triggerPoolId);
    console.log("  Profit:", ethers.formatEther(event.profit));
    console.log("  Token:", event.profitToken);
    console.log("  Block:", event.blockNumber);
  });

  // Keep the process running
  process.stdin.resume();
}

main().catch(console.error);
```

## Step 4: Configure Revenue Sharing

Create a revenue configuration script:

```typescript title="src/configure-revenue.ts"
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
      process.env.MY_ADDRESS!, // Your address: 50%
      "0x742d35Cc6634C0532925a3b8D598C4B4B3A3A3A3", // Protocol: 30%
      "0x9E545E3C0baAB3E08CdfD552C960A1050f373042", // Users: 20%
    ],
    shares: [50, 30, 20], // Must sum to 100
  };

  try {
    const tx = await reflex.configureRevenue(signer, config);
    await tx.wait();

    console.log("✅ Revenue configuration set!");
    console.log("🧾 Transaction:", tx.hash);

    // Verify configuration
    const storedConfig = await reflex.getRevenueConfig(config.configId);
    console.log("📋 Stored configuration:", storedConfig);
  } catch (error) {
    console.error("❌ Configuration failed:", error);
  }
}

configureRevenue().catch(console.error);
```

## Step 5: Build and Run

Add scripts to your `package.json`:

```json title="package.json" {6-9}
{
  "name": "my-reflex-integration",
  "version": "1.0.0",
  "main": "dist/index.js",
  "scripts": {
    "build": "tsc",
    "start": "node dist/index.js",
    "dev": "ts-node src/index.ts",
    "configure": "ts-node src/configure-revenue.ts"
  },
  "dependencies": {
    "@reflex/sdk": "^1.0.0",
    "ethers": "^6.0.0",
    "dotenv": "^16.0.0"
  },
  "devDependencies": {
    "@types/node": "^20.0.0",
    "typescript": "^5.0.0",
    "ts-node": "^10.0.0"
  }
}
```

Build and run your integration:

```bash
# Configure revenue sharing first
npm run configure

# Run the main integration
npm run dev
```

## Step 6: Smart Contract Plugin (Optional)

For automatic MEV capture, create a simple plugin contract:

```solidity title="contracts/MyReflexPlugin.sol"
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@reflex/contracts/ReflexAfterSwap.sol";

contract MyReflexPlugin is ReflexAfterSwap {
    constructor(
        address _reflexRouter,
        address _pool
    ) ReflexAfterSwap(_reflexRouter, _pool) {}

    function afterSwap(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override onlyPool {
        // Calculate swap amount for backrun
        uint256 swapAmount = amount0 > 0 ? amount0 : amount1;
        bool token0In = amount0 > 0;

        // Only trigger for swaps above threshold
        if (swapAmount >= 1e18) { // 1 token minimum
            try reflexRouter.triggerBackrun(
                bytes32(uint256(uint160(pool))), // Use pool as trigger ID
                uint112(swapAmount / 10),        // Use 10% for backrun
                token0In,
                sender,                          // Give profits to original swapper
                bytes32(0)                       // Use default config
            ) returns (uint256 profit, address profitToken) {
                // Backrun succeeded
                emit BackrunTriggered(sender, profit, profitToken);
            } catch {
                // Backrun failed, continue normally
            }
        }
    }

    event BackrunTriggered(address indexed user, uint256 profit, address profitToken);
}
```

Deploy script:

```typescript title="scripts/deploy-plugin.ts"
import { ethers } from "ethers";
import * as dotenv from "dotenv";

dotenv.config();

async function deployPlugin() {
  const provider = new ethers.JsonRpcProvider(process.env.RPC_URL);
  const signer = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

  const factory = new ethers.ContractFactory(
    [], // ABI would go here
    "0x", // Bytecode would go here
    signer
  );

  const plugin = await factory.deploy(
    process.env.REFLEX_ROUTER!,
    "0x742d35Cc6634C0532925a3b8D598C4B4B3A3A3A3" // Target pool
  );

  await plugin.waitForDeployment();

  console.log("🚀 Plugin deployed to:", await plugin.getAddress());
}

deployPlugin().catch(console.error);
```

## 🎉 Success!

You've successfully:

- ✅ Set up Reflex SDK
- ✅ Configured revenue sharing
- ✅ Executed your first backrun
- ✅ Created event listeners
- ✅ Built a plugin contract

## 📊 Expected Output

When you run your integration, you should see:

```
🚀 Reflex SDK initialized
📊 Router: 0x742d35Cc6634C0532925a3b8D598C4B4B3A3A3A3
💡 Quoter: 0x9E545E3C0baAB3E08CdfD552C960A1050f373042

🎯 Triggering example backrun...
⛽ Estimated gas: 150000
✅ Backrun executed!
💰 Profit: 0.0123 ETH
🪙 Profit token: 0xA0b86a33E6a42E64d4C2a7f95F8b7E3b2C8d9E0f
🧾 Transaction: 0xabc123...

👂 Listening for backrun events...
🔥 New backrun executed:
  Pool: 0x742d35Cc6634C0532925a3b8D598C4B4B3A3A3A3
  Profit: 0.0089
  Token: 0xA0b86a33E6a42E64d4C2a7f95F8b7E3b2C8d9E0f
  Block: 8123456
```

## 🚀 Next Steps

Now that you have a working integration:

1. **[Explore Examples](examples)** - See more advanced use cases
2. **[Integration Guide](../integration/overview)** - Learn advanced integration patterns
3. **[API Reference](../api/smart-contracts)** - Dive deep into the API
4. **[Architecture](../architecture/overview)** - Understand the system design

## 🆘 Troubleshooting

### Common Issues

**Gas estimation fails:**

```bash
Error: execution reverted: Insufficient profit
```

- Check that the pool has sufficient liquidity
- Ensure the swap amount is reasonable
- Verify the pool address is correct

**Transaction reverts:**

```bash
Error: execution reverted: Only admin can manage revenue configurations
```

- Make sure you're using the correct private key
- Verify you're the owner of the configuration

**No events received:**

- Check that you're connected to the correct network
- Verify the contract addresses
- Ensure your RPC provider supports event subscriptions

### Getting Help

- 💬 **Discord**: [Join our community](https://discord.gg/reflex)
- 🐛 **GitHub Issues**: [Report bugs](https://github.com/reflex-mev/reflex/issues)
- 📚 **Documentation**: Browse more guides in this documentation

---

**Congratulations!** You've completed the Reflex Quick Start. You're now ready to build sophisticated MEV capture strategies. 🎉
