---
sidebar_position: 2
---

# SDK Reference

Complete reference for the Reflex TypeScript SDK, providing easy integration with Reflex smart contracts.

## 📦 Installation

```bash
npm install @reflex-mev/sdk
# or
yarn ad### Token Amount Fo### Profit Calculations

```typescript
import { calculateProfitPercentage } from '@reflex-mev/sdk/utils';ting

```typescript
import { formatTokenAmount, parseTokenAmount } from '@reflex-mev/sdk/utils';eflex-mev/sdk
```

## 🚀 Quick Start

```typescript
import { ReflexSDK } from '@reflex-mev/sdk';
import { ethers } from 'ethers';

// Initialize provider and signer
const provider = new ethers.JsonRpcProvider('https://mainnet.infura.io/v3/YOUR_KEY');
const signer = new ethers.Wallet('YOUR_PRIVATE_KEY', provider);

// Configuration
const config = {
    routerAddress: '0x742d35Cc6634C0532925a3b8D598C4B4B3A3A3A3',
    defaultGasLimit: 500000n,
    gasPriceMultiplier: 1.1,
};

// Create SDK instance
const reflex = new ReflexSDK(provider, signer, config);
```

## 🔧 Configuration

### ReflexConfig Interface

```typescript
interface ReflexConfig {
    /** Address of the deployed Reflex Router contract */
    routerAddress: string;
    /** Optional address of the Reflex Quoter contract */
    quoterAddress?: string;
    /** Default gas limit for transactions (default: 500000) */
    defaultGasLimit?: bigint;
    /** Multiplier for gas price estimation (default: 1.1) */
    gasPriceMultiplier?: number;
}
```

### Constructor

```typescript
constructor(
    provider: Provider, 
    signer: Signer, 
    config: ReflexConfig
)
```

**Parameters:**
- `provider` - Ethers provider for reading blockchain data
- `signer` - Ethers signer for sending transactions  
- `config` - Configuration for the Reflex Router

## 📋 Core Methods

### `backrunedExecute()`

Executes arbitrary calldata on a target contract and then triggers multiple backruns.

```typescript
const result = await reflex.backrunedExecute(
    executeParams,
    backrunParams,
    options
);
```

**Parameters:**

```typescript
interface ExecuteParams {
    target: string;     // Target contract address to call
    value: bigint;      // ETH value to send with the call (in wei)
    callData: BytesLike; // Encoded calldata to execute
}

interface BackrunParams {
    triggerPoolId: string;    // Pool ID that triggered the opportunity
    swapAmountIn: BigNumberish; // Input swap amount
    token0In: boolean;        // Whether token0 is used as input
    recipient: string;        // Address to receive profits
    configId?: string;        // Configuration ID for profit splitting
}

interface TransactionOptions {
    gasLimit?: bigint;
    gasPrice?: bigint;
    maxFeePerGas?: bigint;
    maxPriorityFeePerGas?: bigint;
    nonce?: number;
}
```

**Returns:**

```typescript
interface BackrunedExecuteResult {
    success: boolean;           // Whether the initial call succeeded
    returnData: string;         // Return data from the initial call
    profits: bigint[];          // Array of profits from each backrun
    profitTokens: string[];     // Array of profit token addresses
    transactionHash: string;    // Transaction hash
}
```

### `estimateBackrunedExecuteGas()`

Estimates gas for a backruned execute operation.

```typescript
const gasEstimate = await reflex.estimateBackrunedExecuteGas(
    executeParams,
    backrunParams
);
```

**Returns:** `bigint` - Estimated gas limit

## � Contract Information

### `getAdmin()`

Gets the current owner/admin of the Reflex Router.

```typescript
const adminAddress = await reflex.getAdmin();
```

**Returns:** `string` - The address of the current admin

### `getQuoter()`

Gets the current ReflexQuoter address.

```typescript
const quoterAddress = await reflex.getQuoter();
```

**Returns:** `string` - The address of the ReflexQuoter contract

## 📊 Events & Monitoring

### `watchBackrunExecuted()`

Listens for BackrunExecuted events from the contract.

```typescript
const unsubscribe = reflex.watchBackrunExecuted(
    (event) => {
        console.log('Backrun executed:', {
            triggerPoolId: event.triggerPoolId,
            profit: event.profit,
            profitToken: event.profitToken,
            recipient: event.recipient,
        });
    },
    {
        triggerPoolId: '0x123...', // Optional filter
        profitToken: '0x456...',   // Optional filter  
        recipient: '0x789...',     // Optional filter
    }
);

// Unsubscribe when done
unsubscribe();
```

**Event Structure:**

```typescript
interface BackrunExecutedEvent {
    triggerPoolId: string;  // Pool ID that triggered the backrun
    swapAmountIn: bigint;   // Input swap amount
    token0In: boolean;      // Whether token0 was used as input
    profit: bigint;         // Profit amount generated
    profitToken: string;    // Token address in which profit was generated
    recipient: string;      // Address that received the profit
}
```

## 🔧 Utilities

### `encodeBackrunedExecute()`

Encodes function data for backruned execute (useful for batch transactions).

```typescript
const encodedData = reflex.encodeBackrunedExecute(
    executeParams,
    backrunParams
);
```

**Returns:** `string` - Encoded function data
**Returns:** `string` - Encoded function data

## 🧰 Utility Functions

### Address Validation

```typescript
import { isValidAddress, isValidBytes32 } from '@reflex-mev/sdk/utils';

// Check if address is valid
if (isValidAddress('0x742d35Cc6634C0532925a3b8D598C4B4B3A3A3A3')) {
    console.log('Valid address');
}

// Check if bytes32 value is valid (e.g., pool ID)
if (isValidBytes32('0x1234567890abcdef...')) {
    console.log('Valid bytes32');
}
```

### Token Amount Formatting

```typescript
import { formatTokenAmount, parseTokenAmount } from '@reflex/sdk/utils';

// Format BigInt to human-readable string
const formatted = formatTokenAmount(
    1500123456789012345678n, // BigInt value
    18 // decimals
); // "1500.123456789012345678"

// Parse string to BigInt
const parsed = parseTokenAmount('1500.123456', 18);
// Returns: 1500123456000000000000n
```

### Profit Calculations

```typescript
import { calculateProfitPercentage } from '@reflex/sdk/utils';

// Calculate profit percentage
const profitPercent = calculateProfitPercentage(
    150000000000000000n, // 0.15 ETH profit
    1000000000000000000n // 1 ETH investment
); // Returns: 15 (15%)
```

## ⚠️ Error Handling

```typescript
try {
    const result = await reflex.backrunedExecute(
        executeParams,
        backrunParams
    );
    
    if (!result.success) {
        console.error('Backrun execution failed');
    } else {
        console.log('Profits:', result.profits);
    }
} catch (error) {
    console.error('SDK Error:', error.message);
}
```

### Common Error Types

| Error Type | Description | Solution |
|------------|-------------|----------|
| `Gas estimation failed` | Cannot estimate gas for transaction | Check parameters and network connection |
| `Transaction failed` | Transaction reverted on-chain | Verify contract state and parameters |
| `Backruned execute failed` | Execute + backrun operation failed | Check target contract and backrun parameters |

## 📝 TypeScript Types

### Core Interfaces

```typescript
// Available imports
import {
    ReflexSDK,
    ExecuteParams,
    BackrunParams,
    BackrunedExecuteResult,
    ReflexConfig,
    TransactionOptions,
    BackrunExecutedEvent,
} from '@reflex-mev/sdk';

// Type definitions
interface ExecuteParams {
    target: string;
    value: bigint;
    callData: BytesLike;
}

interface BackrunParams {
    triggerPoolId: string;
    swapAmountIn: BigNumberish;
    token0In: boolean;
    recipient: string;
    configId?: string;
}

interface BackrunedExecuteResult {
    success: boolean;
    returnData: string;
    profits: bigint[];
    profitTokens: string[];
    transactionHash: string;
}

interface BackrunExecutedEvent {
    triggerPoolId: string;
    swapAmountIn: bigint;
    token0In: boolean;
    profit: bigint;
    profitToken: string;
    recipient: string;
}
```

## 💡 Example Usage

### Basic Backrun Execution

```typescript
import { ReflexSDK } from '@reflex-mev/sdk';
import { ethers } from 'ethers';

async function executeBackrun() {
    const provider = new ethers.JsonRpcProvider(RPC_URL);
    const signer = new ethers.Wallet(PRIVATE_KEY, provider);
    
    const reflex = new ReflexSDK(provider, signer, {
        routerAddress: '0x742d35Cc6634C0532925a3b8D598C4B4B3A3A3A3',
        defaultGasLimit: 500000n,
    });

    // Prepare execute parameters (e.g., Uniswap swap)
    const executeParams = {
        target: '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D', // Uniswap V2 Router
        value: 0n,
        callData: '0x...' // Encoded swap function call
    };

    // Prepare backrun parameters
    const backrunParams = [{
        triggerPoolId: '0x1234...', // Pool that will be affected by the swap
        swapAmountIn: ethers.parseEther('1'), // 1 ETH backrun
        token0In: true,
        recipient: await signer.getAddress(),
        configId: '0x0000...', // Use default config
    }];

    try {
        const result = await reflex.backrunedExecute(
            executeParams,
            backrunParams
        );

        console.log('Transaction hash:', result.transactionHash);
        console.log('Profits:', result.profits.map(p => ethers.formatEther(p)));
    } catch (error) {
        console.error('Error:', error.message);
    }
}
```

### Event Monitoring

```typescript
// Monitor all backrun events
const unsubscribe = reflex.watchBackrunExecuted((event) => {
    console.log(`Backrun executed on pool ${event.triggerPoolId}`);
    console.log(`Profit: ${ethers.formatEther(event.profit)} ${event.profitToken}`);
});

// Monitor events for specific pool
const unsubscribePool = reflex.watchBackrunExecuted(
    (event) => {
        console.log('Our pool backrun:', event);
    },
    { triggerPoolId: '0x1234...' }
);
```

---

*For more detailed integration guidance, see our [SDK Integration Guide](../integration/sdk-integration) and [Smart Contract Integration](../integration/smart-contract).*
