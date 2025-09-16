---
sidebar_position: 3
---

# SDK Integration

Integrate Reflex MEV capture into your client applications, DApps, and custom trading strategies using the TypeScript SDK.

## Overview

The Reflex SDK provides a powerful and easy-to-use interface for building MEV-enabled DApps. Whether you're integrating MEV capture into a DApp frontend or creating custom trading interfaces, the SDK handles the complexity of interacting with Reflex smart contracts.

## Installation

```bash
npm install @reflex/sdk ethers
# or
yarn add @reflex/sdk ethers
```

## Quick Start

### Basic Setup

```typescript
import { ReflexSDK } from "@reflex/sdk";
import { ethers } from "ethers";

// Initialize provider and signer
const provider = new ethers.JsonRpcProvider(
  "https://mainnet.infura.io/v3/YOUR_KEY"
);
const signer = new ethers.Wallet("YOUR_PRIVATE_KEY", provider);

// Create SDK instance
const reflex = new ReflexSDK({
  provider,
  signer,
  chainId: 1, // Mainnet
  options: {
    gasLimit: 300000,
    slippageTolerance: 0.005, // 0.5%
  },
});
```

## DApp Integration

### Frontend Integration

```typescript
// React hook for MEV integration
import { useState, useEffect, useCallback } from "react";
import { ReflexSDK } from "@reflex/sdk";

export function useReflexMEV(provider, signer) {
  const [reflex, setReflex] = useState(null);
  const [mevStats, setMevStats] = useState({
    totalCaptured: 0n,
    userRewards: 0n,
    successRate: 0,
  });

  useEffect(() => {
    if (provider && signer) {
      const reflexInstance = new ReflexSDK({
        provider,
        signer,
        chainId: 1,
      });

      setReflex(reflexInstance);

      // Listen for MEV events
      reflexInstance.on("BackrunExecuted", (event) => {
        setMevStats((prev) => ({
          ...prev,
          totalCaptured: prev.totalCaptured + event.profit,
          userRewards: prev.userRewards + (event.profit * 3n) / 10n, // 30% to users
        }));
      });
    }
  }, [provider, signer]);

  const executeSwapWithMEV = useCallback(
    async (swapParams) => {
      if (!reflex) return null;

      try {
        // Prepare the user's swap transaction as executeParams
        const executeParams = {
          target: swapParams.poolAddress,
          value: swapParams.value || 0n,
          callData: swapParams.swapCallData,
        };

        // Prepare backrun parameters
        const backrunParams = [
          {
            triggerPoolId: swapParams.poolAddress,
            swapAmountIn: swapParams.amountIn / 20n, // 5% of swap
            token0In: swapParams.token0In,
            recipient: swapParams.user,
            configId: swapParams.configId || ethers.ZeroHash,
          },
        ];

        // Execute swap + MEV capture atomically
        const result = await reflex.backrunedExecute(
          executeParams,
          backrunParams
        );

        return {
          success: result.success,
          transactionHash: result.transactionHash,
          swapExecuted: result.success,
          mevProfit: result.profits[0] || 0n,
          profitToken: result.profitTokens[0],
        };
      } catch (error) {
        console.error("Swap with MEV failed:", error);
        throw error;
      }
    },
    [reflex]
  );

  return {
    reflex,
    mevStats,
    executeSwapWithMEV,
    isReady: !!reflex,
  };
}
```

### Trading Interface Component

```typescript
// MEV-enabled trading component
import React, { useState } from "react";

export function MEVTradingInterface({ useReflexMEV }) {
  const { executeSwapWithMEV, mevStats, isReady } = useReflexMEV(
    provider,
    signer
  );
  const [swapAmount, setSwapAmount] = useState("");
  const [isSwapping, setIsSwapping] = useState(false);

  const handleSwap = async () => {
    setIsSwapping(true);

    try {
      const result = await executeSwapWithMEV({
        tokenIn: selectedTokenIn.address,
        tokenOut: selectedTokenOut.address,
        amountIn: ethers.parseEther(swapAmount),
        poolAddress: poolAddress,
        user: userAddress,
        token0In: selectedTokenIn.address < selectedTokenOut.address,
        swapCallData: encodedSwapData, // Pre-encoded swap transaction
      });

      if (result.success && result.mevProfit > 0n) {
        showNotification({
          type: "success",
          title: "Swap Completed with MEV Bonus!",
          message: `You received an additional ${ethers.formatEther(
            result.mevProfit
          )} ETH from MEV capture`,
        });
      }
    } catch (error) {
      showNotification({
        type: "error",
        title: "Swap Failed",
        message: error.message,
      });
    } finally {
      setIsSwapping(false);
    }
  };

  return (
    <div className="trading-interface">
      {/* MEV Stats Display */}
      <div className="mev-stats">
        <h3>MEV Benefits</h3>
        <div>
          Total Captured: {ethers.formatEther(mevStats.totalCaptured)} ETH
        </div>
        <div>Your Rewards: {ethers.formatEther(mevStats.userRewards)} ETH</div>
        <div>Success Rate: {(mevStats.successRate * 100).toFixed(1)}%</div>
      </div>

      {/* Trading Interface */}
      <div className="swap-form">
        <input
          type="number"
          value={swapAmount}
          onChange={(e) => setSwapAmount(e.target.value)}
          placeholder="Amount to swap"
        />

        <button
          onClick={handleSwap}
          disabled={!isReady || isSwapping}
          className="swap-button"
        >
          {isSwapping ? "Swapping..." : "Swap with MEV Protection"}
        </button>
      </div>
    </div>
  );
}
```

## Configuration and Optimization

### Gas Management

```typescript
// Advanced gas optimization
const reflex = new ReflexSDK({
  provider,
  signer,
  chainId: 1,
  options: {
    gasStrategy: {
      type: "dynamic",
      priorityFeeMultiplier: 1.1,
      maxFeePerGasMultiplier: 1.2,
      gasLimitMultiplier: 1.1,
    },
    mevSettings: {
      maxSlippage: 0.005,
      minProfitThreshold: ethers.parseEther("0.01"),
      maxGasPrice: ethers.parseUnits("100", "gwei"),
    },
  },
});
```

### Event Monitoring

```typescript
// Comprehensive event monitoring
reflex.on("BackrunExecuted", (event) => {
  analytics.track("MEV_Captured", {
    profit: event.profit,
    pool: event.triggerPoolId,
    recipient: event.recipient,
    timestamp: event.timestamp,
  });
});

reflex.on("BackrunFailed", (event) => {
  console.warn("MEV capture failed:", event.reason);

  // Implement retry logic or alerts
  if (event.reason === "INSUFFICIENT_PROFIT") {
    adjustProfitThreshold(event.triggerPoolId);
  }
});
```

## Testing

### Mock Environment

```typescript
// Test your integration
import { createMockProvider, createTestWallet } from "@reflex/sdk/testing";

describe("MEV Integration", () => {
  let reflex: ReflexSDK;

  beforeEach(() => {
    const provider = createMockProvider();
    const wallet = createTestWallet();

    reflex = new ReflexSDK({
      provider,
      signer: wallet,
      chainId: 31337, // Hardhat
      options: { mockMode: true },
    });
  });

  it("should capture MEV successfully", async () => {
    const executeParams = {
      to: "0xTokenContract...",
      value: 0,
      data: "0x123...", // encoded swap data
    };

    const backrunParams = {
      triggerPoolId: "0x123...",
      swapAmountIn: ethers.parseEther("1"),
      token0In: true,
      recipient: "0xUser...",
      configId: ethers.ZeroHash,
    };

    const result = await reflex.backrunedExecute(executeParams, backrunParams);

    expect(result.success).toBe(true);
    expect(result.mevProfit).toBeGreaterThan(0n);
  });
});
```

## Best Practices

### Error Handling

1. **Always handle SDK errors gracefully**
2. **Implement retry logic for network issues**
3. **Use try/catch for all async operations**
4. **Monitor and log all MEV attempts**

### Performance

1. **Cache frequently used data**
2. **Use batch operations when possible**
3. **Implement connection pooling**
4. **Monitor gas usage patterns**

### Security

1. **Never expose private keys in frontend code**
2. **Validate all user inputs**
3. **Use secure RPC endpoints**
4. **Implement rate limiting**

---

For revenue configuration details, see the [Revenue Configuration Guide](./revenue-configuration).
For smart contract integration, see the [Smart Contract Integration Guide](./smart-contract).
For complete examples, check out the [Basic Backrun Example](../examples/basic-backrun).
