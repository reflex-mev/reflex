---
sidebar_position: 3
---

# SDK Integration

Integrate Reflex MEV capture into your client applications, DApps, and custom trading strategies using the TypeScript SDK.

## Overview

The Reflex SDK provides a powerful and easy-to-use interface for building MEV-enabled applications. Whether you're building a trading bot, integrating MEV capture into a DApp frontend, or creating custom arbitrage strategies, the SDK handles the complexity of interacting with Reflex smart contracts.

## Installation

```bash
npm install @reflex/sdk ethers
# or
yarn add @reflex/sdk ethers
```

## Quick Start

### Basic Setup

```typescript
import { ReflexSDK } from '@reflex/sdk';
import { ethers } from 'ethers';

// Initialize provider and signer
const provider = new ethers.JsonRpcProvider('https://mainnet.infura.io/v3/YOUR_KEY');
const signer = new ethers.Wallet('YOUR_PRIVATE_KEY', provider);

// Create SDK instance
const reflex = new ReflexSDK({
    provider,
    signer,
    chainId: 1, // Mainnet
    options: {
        gasLimit: 300000,
        slippageTolerance: 0.005, // 0.5%
    }
});
```

### Monitor and Execute MEV

```typescript
// Start monitoring for MEV opportunities
async function startMEVBot() {
    console.log('Starting MEV monitoring...');
    
    // Listen for swap events across multiple pools
    const pools = [
        '0xPool1Address',
        '0xPool2Address',
        '0xPool3Address'
    ];
    
    for (const poolAddress of pools) {
        const poolContract = new ethers.Contract(poolAddress, POOL_ABI, provider);
        
        poolContract.on('Swap', async (sender, amount0In, amount1In, amount0Out, amount1Out, event) => {
            const swapAmount = amount0In > 0n ? amount0In : amount1In;
            
            // Only process significant swaps
            if (swapAmount > ethers.parseEther('1')) {
                await processMEVOpportunity({
                    poolAddress,
                    swapAmount,
                    token0In: amount0In > 0n,
                    originalSwapper: sender,
                    txHash: event.transactionHash
                });
            }
        });
    }
}

async function processMEVOpportunity(opportunity) {
    try {
        // Check if opportunity is still profitable
        const quote = await reflex.getQuote({
            triggerPoolId: opportunity.poolAddress,
            swapAmountIn: opportunity.swapAmount / 10n, // Use 10% for backrun
            token0In: opportunity.token0In,
        });
        
        if (quote.expectedProfit > ethers.parseEther('0.01')) {
            console.log('Executing MEV opportunity:', {
                pool: opportunity.poolAddress,
                expectedProfit: ethers.formatEther(quote.expectedProfit)
            });
            
            // Execute the backrun
            const result = await reflex.triggerBackrun({
                triggerPoolId: opportunity.poolAddress,
                swapAmountIn: opportunity.swapAmount / 10n,
                token0In: opportunity.token0In,
                recipient: opportunity.originalSwapper, // Share profit with user
                configId: ethers.ZeroHash, // Use default config
            });
            
            if (result.success) {
                console.log('MEV captured successfully:', {
                    txHash: result.txHash,
                    profit: ethers.formatEther(result.profit),
                    gasUsed: result.gasUsed.toString()
                });
            }
        }
    } catch (error) {
        console.error('MEV opportunity failed:', error.message);
    }
}
```

## DApp Integration

### Frontend Integration

```typescript
// React hook for MEV integration
import { useState, useEffect, useCallback } from 'react';
import { ReflexSDK } from '@reflex/sdk';

export function useReflexMEV(provider, signer) {
    const [reflex, setReflex] = useState(null);
    const [mevStats, setMevStats] = useState({
        totalCaptured: 0n,
        userRewards: 0n,
        successRate: 0
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
            reflexInstance.on('BackrunExecuted', (event) => {
                setMevStats(prev => ({
                    ...prev,
                    totalCaptured: prev.totalCaptured + event.profit,
                    userRewards: prev.userRewards + (event.profit * 3n / 10n) // 30% to users
                }));
            });
        }
    }, [provider, signer]);
    
    const executeSwapWithMEV = useCallback(async (swapParams) => {
        if (!reflex) return null;
        
        try {
            // Execute the user's swap first
            const swapTx = await executeUserSwap(swapParams);
            await swapTx.wait();
            
            // Then trigger MEV capture
            const mevResult = await reflex.triggerBackrun({
                triggerPoolId: swapParams.poolAddress,
                swapAmountIn: swapParams.amountIn / 20n, // 5% of swap
                token0In: swapParams.token0In,
                recipient: swapParams.user,
                configId: swapParams.configId || ethers.ZeroHash,
            });
            
            return {
                swapTx,
                mevResult,
                totalProfit: mevResult.profit
            };
        } catch (error) {
            console.error('Swap with MEV failed:', error);
            throw error;
        }
    }, [reflex]);
    
    return {
        reflex,
        mevStats,
        executeSwapWithMEV,
        isReady: !!reflex
    };
}
```

### Trading Interface Component

```typescript
// MEV-enabled trading component
import React, { useState } from 'react';

export function MEVTradingInterface({ useReflexMEV }) {
    const { executeSwapWithMEV, mevStats, isReady } = useReflexMEV(provider, signer);
    const [swapAmount, setSwapAmount] = useState('');
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
                token0In: selectedTokenIn.address < selectedTokenOut.address
            });
            
            if (result.mevResult.success) {
                showNotification({
                    type: 'success',
                    title: 'Swap Completed with MEV Bonus!',
                    message: `You received an additional ${ethers.formatEther(result.totalProfit)} ETH from MEV capture`
                });
            }
        } catch (error) {
            showNotification({
                type: 'error',
                title: 'Swap Failed',
                message: error.message
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
                <div>Total Captured: {ethers.formatEther(mevStats.totalCaptured)} ETH</div>
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
                    {isSwapping ? 'Swapping...' : 'Swap with MEV Protection'}
                </button>
            </div>
        </div>
    );
}
```

## Advanced Trading Strategies

### Arbitrage Bot

```typescript
class ReflexArbitrageBot {
    private reflex: ReflexSDK;
    private pools: string[];
    private isRunning = false;
    
    constructor(config: BotConfig) {
        this.reflex = new ReflexSDK(config.sdkConfig);
        this.pools = config.monitoredPools;
    }
    
    async start() {
        this.isRunning = true;
        console.log('Starting arbitrage bot...');
        
        // Monitor multiple pools simultaneously
        await Promise.all(
            this.pools.map(poolAddress => this.monitorPool(poolAddress))
        );
    }
    
    private async monitorPool(poolAddress: string) {
        const poolContract = new ethers.Contract(poolAddress, POOL_ABI, this.reflex.provider);
        
        poolContract.on('Swap', async (sender, ...args) => {
            if (!this.isRunning) return;
            
            // Quick profitability check
            const opportunity = await this.analyzeOpportunity(poolAddress, args);
            
            if (opportunity.profitable) {
                await this.executeArbitrage(opportunity);
            }
        });
    }
    
    private async analyzeOpportunity(poolAddress: string, swapData: any) {
        // Calculate potential arbitrage across multiple DEXs
        const quotes = await Promise.all([
            this.reflex.getQuote({ /* params for DEX A */ }),
            this.getExternalQuote('uniswap', /* params */),
            this.getExternalQuote('sushiswap', /* params */),
        ]);
        
        // Find best arbitrage route
        const bestRoute = this.findBestArbitrageRoute(quotes);
        
        return {
            profitable: bestRoute.profit > ethers.parseEther('0.02'),
            route: bestRoute,
            poolAddress,
            estimatedGas: bestRoute.gasEstimate
        };
    }
    
    private async executeArbitrage(opportunity) {
        try {
            // Execute multi-hop arbitrage using Reflex
            const result = await this.reflex.executeComplexArbitrage({
                route: opportunity.route,
                maxGasPrice: ethers.parseUnits('50', 'gwei'),
                deadline: Math.floor(Date.now() / 1000) + 300 // 5 minutes
            });
            
            console.log('Arbitrage executed:', {
                profit: ethers.formatEther(result.profit),
                gasUsed: result.gasUsed.toString(),
                route: opportunity.route.path
            });
        } catch (error) {
            console.error('Arbitrage failed:', error);
        }
    }
}
```

### MEV Protection for Users

```typescript
// Protect users from sandwich attacks
class MEVProtectionService {
    private reflex: ReflexSDK;
    
    constructor(config: ReflexSDKConfig) {
        this.reflex = new ReflexSDK(config);
    }
    
    async protectedSwap(swapParams: SwapParams) {
        // 1. Pre-analyze for sandwich risk
        const riskAnalysis = await this.analyzeSandwichRisk(swapParams);
        
        if (riskAnalysis.highRisk) {
            // 2. Use Reflex to preemptively capture MEV
            await this.preemptiveMEVCapture(swapParams);
        }
        
        // 3. Execute user swap
        const swapResult = await this.executeSwap(swapParams);
        
        // 4. Trigger backrun to capture remaining MEV
        const backrunResult = await this.reflex.triggerBackrun({
            triggerPoolId: swapParams.poolAddress,
            swapAmountIn: swapParams.amountIn / 10n,
            token0In: swapParams.token0In,
            recipient: swapParams.user,
            configId: swapParams.configId
        });
        
        return {
            swapResult,
            backrunResult,
            totalMEVCaptured: backrunResult.profit,
            protectionApplied: riskAnalysis.highRisk
        };
    }
    
    private async analyzeSandwichRisk(params: SwapParams) {
        // Analyze mempool for potential sandwich attacks
        const pendingTxs = await this.reflex.getPendingTransactions(params.poolAddress);
        
        // Check for suspicious patterns
        const suspiciousTxs = pendingTxs.filter(tx => 
            this.isSuspiciousSandwichSetup(tx, params)
        );
        
        return {
            highRisk: suspiciousTxs.length > 0,
            riskScore: this.calculateRiskScore(suspiciousTxs),
            recommendations: this.generateProtectionRecommendations(suspiciousTxs)
        };
    }
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
            type: 'dynamic',
            priorityFeeMultiplier: 1.1,
            maxFeePerGasMultiplier: 1.2,
            gasLimitMultiplier: 1.1
        },
        mevSettings: {
            maxSlippage: 0.005,
            minProfitThreshold: ethers.parseEther('0.01'),
            maxGasPrice: ethers.parseUnits('100', 'gwei')
        }
    }
});
```

### Event Monitoring

```typescript
// Comprehensive event monitoring
reflex.on('BackrunExecuted', (event) => {
    analytics.track('MEV_Captured', {
        profit: event.profit,
        pool: event.triggerPoolId,
        recipient: event.recipient,
        timestamp: event.timestamp
    });
});

reflex.on('BackrunFailed', (event) => {
    console.warn('MEV capture failed:', event.reason);
    
    // Implement retry logic or alerts
    if (event.reason === 'INSUFFICIENT_PROFIT') {
        adjustProfitThreshold(event.triggerPoolId);
    }
});
```

## Testing

### Mock Environment

```typescript
// Test your integration
import { createMockProvider, createTestWallet } from '@reflex/sdk/testing';

describe('MEV Integration', () => {
    let reflex: ReflexSDK;
    
    beforeEach(() => {
        const provider = createMockProvider();
        const wallet = createTestWallet();
        
        reflex = new ReflexSDK({
            provider,
            signer: wallet,
            chainId: 31337, // Hardhat
            options: { mockMode: true }
        });
    });
    
    it('should capture MEV successfully', async () => {
        const result = await reflex.triggerBackrun({
            triggerPoolId: '0x123...',
            swapAmountIn: ethers.parseEther('1'),
            token0In: true,
            recipient: '0xUser...',
            configId: ethers.ZeroHash
        });
        
        expect(result.success).toBe(true);
        expect(result.profit).toBeGreaterThan(0n);
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

For smart contract integration, see the [Smart Contract Integration Guide](./smart-contract).
For complete examples, check out the [Basic Backrun Example](../examples/basic-backrun).
