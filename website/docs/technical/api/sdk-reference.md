---
sidebar_position: 2
---

# SDK Reference

Complete reference for the Reflex TypeScript SDK, providing easy integration with Reflex Protocol smart contracts.

## 📦 Installation

```bash
npm install @reflex/sdk
# or
yarn add @reflex/sdk
```

## 🚀 Quick Start

```typescript
import { ReflexSDK } from '@reflex/sdk';
import { ethers } from 'ethers';

// Initialize provider
const provider = new ethers.JsonRpcProvider('https://mainnet.infura.io/v3/YOUR_KEY');
const signer = new ethers.Wallet('YOUR_PRIVATE_KEY', provider);

// Create SDK instance
const reflex = new ReflexSDK({
    provider,
    signer,
    chainId: 1, // Mainnet
});

// Start monitoring for MEV opportunities
await reflex.startMonitoring();
```

## 🔧 Configuration

### Constructor Options

```typescript
interface ReflexSDKConfig {
    provider: ethers.Provider;
    signer?: ethers.Signer;
    chainId: number;
    routerAddress?: string;
    quoterAddress?: string;
    options?: {
        gasLimit?: number;
        maxFeePerGas?: bigint;
        maxPriorityFeePerGas?: bigint;
        slippageTolerance?: number;
    };
}
```

### Example Configuration

```typescript
const config: ReflexSDKConfig = {
    provider: new ethers.JsonRpcProvider('https://mainnet.infura.io/v3/YOUR_KEY'),
    signer: wallet,
    chainId: 1,
    options: {
        gasLimit: 300000,
        slippageTolerance: 0.005, // 0.5%
        maxFeePerGas: ethers.parseUnits('30', 'gwei'),
        maxPriorityFeePerGas: ethers.parseUnits('2', 'gwei'),
    }
};
```

## 📋 Core Methods

### `startMonitoring()`

Start monitoring the mempool for MEV opportunities.

```typescript
await reflex.startMonitoring({
    protocols: ['uniswap-v2', 'uniswap-v3', 'sushiswap'],
    minProfitThreshold: ethers.parseEther('0.01'), // 0.01 ETH
    maxGasPrice: ethers.parseUnits('100', 'gwei'),
});
```

**Parameters:**
- `protocols`: Array of supported DEX protocols
- `minProfitThreshold`: Minimum profit to execute backrun
- `maxGasPrice`: Maximum gas price for transactions

### `executeBackrun()`

Execute a backrun transaction for detected arbitrage.

```typescript
const result = await reflex.executeBackrun({
    targetTx: '0x123...', // Target transaction hash
    tokens: [tokenA, tokenB],
    amounts: [amountIn, amountOut],
    pools: [poolAddress],
    configId: '0xabc...', // Revenue sharing config ID
});
```

**Returns:**
```typescript
interface BackrunResult {
    success: boolean;
    txHash?: string;
    profit?: bigint;
    gasUsed?: bigint;
    error?: string;
}
```

## 💰 Revenue Distribution

### Create Configuration

```typescript
const configId = await reflex.createRevenueConfig({
    protocolShare: 5000, // 50%
    userShare: 3000,     // 30%
    validatorShare: 2000, // 20%
    minProfitThreshold: ethers.parseEther('0.01'),
});
```

### Update Configuration

```typescript
await reflex.updateRevenueConfig(configId, {
    protocolShare: 6000, // 60%
    userShare: 2500,     // 25%
    validatorShare: 1500, // 15%
});
```

### Query Configuration

```typescript
const config = await reflex.getRevenueConfig(configId);
console.log('Protocol Share:', config.protocolShare);
console.log('User Share:', config.userShare);
console.log('Validator Share:', config.validatorShare);
```

## 📊 Monitoring & Events

### Listen to Events

```typescript
// Listen for successful backruns
reflex.on('BackrunExecuted', (event) => {
    console.log('Backrun executed:', {
        txHash: event.txHash,
        profit: ethers.formatEther(event.profit),
        tokens: event.tokens,
    });
});

// Listen for revenue distributions
reflex.on('RevenueDistributed', (event) => {
    console.log('Revenue distributed:', {
        configId: event.configId,
        totalAmount: ethers.formatEther(event.totalAmount),
        recipients: event.recipients,
    });
});

// Listen for errors
reflex.on('Error', (error) => {
    console.error('SDK Error:', error.message);
});
```

### Get Statistics

```typescript
const stats = await reflex.getStatistics({
    timeframe: '24h', // '1h', '24h', '7d', '30d'
    configId: '0x123...', // Optional: filter by config
});

console.log('Statistics:', {
    totalBackruns: stats.totalBackruns,
    totalProfit: ethers.formatEther(stats.totalProfit),
    averageProfit: ethers.formatEther(stats.averageProfit),
    successRate: stats.successRate,
});
```

## 🔍 Utilities

### Address Validation

```typescript
import { isValidAddress, isContractAddress } from '@reflex/sdk/utils';

// Check if address is valid
if (isValidAddress(address)) {
    console.log('Valid address');
}

// Check if address is a contract
if (await isContractAddress(address, provider)) {
    console.log('Contract address');
}
```

### Token Information

```typescript
const tokenInfo = await reflex.getTokenInfo('0x6B175474E89094C44Da98b954EedeAC495271d0F');
console.log('Token:', {
    name: tokenInfo.name,
    symbol: tokenInfo.symbol,
    decimals: tokenInfo.decimals,
    totalSupply: ethers.formatUnits(tokenInfo.totalSupply, tokenInfo.decimals),
});
```

### Format Amounts

```typescript
import { formatTokenAmount, parseTokenAmount } from '@reflex/sdk/utils';

// Format for display
const formatted = formatTokenAmount(
    ethers.parseUnits('1500.123456', 18), 
    18, 
    4 // decimal places
); // "1,500.1235"

// Parse user input
const parsed = parseTokenAmount('1,500.12', 18);
// Returns: 1500120000000000000000n
```

## ⚠️ Error Handling

```typescript
try {
    const result = await reflex.executeBackrun(params);
    if (!result.success) {
        console.error('Backrun failed:', result.error);
    }
} catch (error) {
    if (error.code === 'INSUFFICIENT_FUNDS') {
        console.error('Insufficient funds for transaction');
    } else if (error.code === 'NETWORK_ERROR') {
        console.error('Network connection issue');
    } else {
        console.error('Unexpected error:', error.message);
    }
}
```

### Common Error Codes

| Code | Description | Solution |
|------|-------------|----------|
| `INSUFFICIENT_FUNDS` | Not enough ETH for gas | Add more ETH to wallet |
| `SLIPPAGE_EXCEEDED` | Price moved too much | Increase slippage tolerance |
| `TRANSACTION_FAILED` | Transaction reverted | Check transaction parameters |
| `NETWORK_ERROR` | RPC connection issue | Check network connection |
| `INVALID_CONFIG` | Invalid configuration | Verify config parameters |

## 🧪 Testing

### Mock Mode

For testing, use mock mode to simulate transactions:

```typescript
const reflex = new ReflexSDK({
    provider,
    chainId: 1,
    options: {
        mockMode: true, // Enable mock mode
    }
});

// All transactions will be simulated
const result = await reflex.executeBackrun(params);
console.log('Simulated result:', result);
```

### Test Helpers

```typescript
import { createMockProvider, createTestWallet } from '@reflex/sdk/testing';

// Create test environment
const provider = createMockProvider();
const wallet = createTestWallet();
const reflex = new ReflexSDK({ provider, signer: wallet, chainId: 31337 });
```

## 📝 TypeScript Types

### Core Types

```typescript
// Export all types
export interface BackrunParams {
    targetTx: string;
    tokens: string[];
    amounts: bigint[];
    pools: string[];
    configId: string;
    deadline?: number;
}

export interface RevenueConfig {
    protocolShare: number;
    userShare: number;
    validatorShare: number;
    minProfitThreshold: bigint;
    isActive: boolean;
}

export interface TokenInfo {
    address: string;
    name: string;
    symbol: string;
    decimals: number;
    totalSupply: bigint;
}
```

## 🔗 Chain Support

| Chain | Chain ID | Status | Router Address |
|-------|----------|--------|----------------|
| Ethereum Mainnet | 1 | ✅ Live | `0x742d35Cc...` |
| Polygon | 137 | ✅ Live | `0x742d35Cc...` |
| Arbitrum | 42161 | ✅ Live | `0x742d35Cc...` |
| Optimism | 10 | 🔄 Coming Soon | - |
| Base | 8453 | 🔄 Coming Soon | - |

---

*For more examples and advanced usage, check out our [Examples](../examples/basic-backrun) section.*
