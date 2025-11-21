---
sidebar_position: 1
---

# UniversalIntegration

TypeScript SDK for integrating Reflex MEV capture with any DEX using the BackrunEnabledSwapProxy pattern.

## Installation

```bash
npm install @reflex-mev/sdk ethers
# or
yarn add @reflex-mev/sdk ethers
```

## Constructor

```typescript
class UniversalIntegration {
  constructor(
    provider: ethers.Provider,
    signer: ethers.Signer,
    swapProxyAddress: string,
    reflexRouterAddress: string
  );
}
```

**Parameters:**

- `provider` - ethers.js Provider instance for blockchain interaction
- `signer` - ethers.js Signer for signing transactions
- `swapProxyAddress` - Address of deployed BackrunEnabledSwapProxy contract
- `reflexRouterAddress` - Address of Reflex Router contract

**Example:**

```typescript
import { UniversalIntegration } from "@reflex-mev/sdk/integrations";
import { ethers } from "ethers";

const provider = new ethers.JsonRpcProvider("https://rpc.url");
const signer = new ethers.Wallet("PRIVATE_KEY", provider);

const integration = new UniversalIntegration(
  provider,
  signer,
  "0xSwapProxyAddress",
  "0xReflexRouterAddress"
);
```

## Methods

### swapWithBackrun()

Execute a swap through the target DEX with automatic MEV backrun capture.

```typescript
async swapWithBackrun(
  swapMetadata: SwapMetadata,
  backrunParams: BackrunParams[],
  overrides?: ethers.Overrides
): Promise<SwapWithBackrunResult>
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `swapMetadata` | `SwapMetadata` | Metadata about the swap transaction (including swapTxCallData) |
| `backrunParams` | `BackrunParams[]` | Array of backrun configurations (supports multi-pool backruns) |
| `overrides` | `ethers.Overrides` | Optional transaction overrides (gasLimit, maxFeePerGas, etc.) |

**Returns:** `Promise<SwapWithBackrunResult>`

**Example:**

```typescript
const result = await integration.swapWithBackrun(
  {
    swapTxCallData: swapCalldata,
    tokenIn: "0xTokenInAddress",
    amountIn: ethers.parseEther("1.0"),
    tokenOut: "0xTokenOutAddress",
    recipient: "0xUserAddress"
  },
  [
    {
      triggerPoolId: "0xPoolAddress",
      swapAmountIn: ethers.parseEther("1.0"),
      token0In: true,
      recipient: "0xUserAddress",
      configId: ethers.ZeroHash
    }
  ],
  { gasLimit: 1500000n }
);
```

### approveTokens()

Approve tokens for spending by the SwapProxy contract.

```typescript
async approveTokens(
  approvals: TokenApproval[]
): Promise<ethers.TransactionReceipt[]>
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `approvals` | `TokenApproval[]` | Array of token approvals to execute |

**Returns:** `Promise<ethers.TransactionReceipt[]>` - Array of approval transaction receipts

**Example:**

```typescript
// Approve unlimited
await integration.approveTokens([
  {
    tokenAddress: "0xUSDC",
    amount: ethers.MaxUint256
  }
]);

// Approve multiple tokens
await integration.approveTokens([
  { tokenAddress: "0xUSDC", amount: ethers.MaxUint256 },
  { tokenAddress: "0xWETH", amount: ethers.MaxUint256 }
]);
```

### isTokenApproved()

Check if a token has sufficient approval for the SwapProxy.

```typescript
async isTokenApproved(
  tokenAddress: string,
  amount: bigint
): Promise<boolean>
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `tokenAddress` | `string` | Address of the token to check |
| `amount` | `bigint` | Amount to check approval for |

**Returns:** `Promise<boolean>` - true if approved for at least the specified amount

**Example:**

```typescript
const isApproved = await integration.isTokenApproved(
  "0xUSDC",
  ethers.parseUnits("100", 6)
);

if (!isApproved) {
  await integration.approveTokens([
    { tokenAddress: "0xUSDC", amount: ethers.MaxUint256 }
  ]);
}
```

### estimateGas()

Estimate gas required for a swap with backrun operation.

```typescript
async estimateGas(
  swapMetadata: SwapMetadata,
  backrunParams: BackrunParams[]
): Promise<bigint>
```

**Parameters:** Same as `swapWithBackrun()` (minus overrides)

**Returns:** `Promise<bigint>` - Estimated gas with 50% buffer included

**Example:**

```typescript
const estimatedGas = await integration.estimateGas(
  swapMetadata,
  backrunParams
);

console.log("Estimated gas:", estimatedGas.toString());

// Use estimate in transaction
await integration.swapWithBackrun(
  swapMetadata,
  backrunParams,
  { gasLimit: estimatedGas }
);
```

### getSwapProxyAddress()

Get the SwapProxy contract address.

```typescript
getSwapProxyAddress(): string
```

**Returns:** `string` - Address of the BackrunEnabledSwapProxy contract

### getReflexRouterAddress()

Get the ReflexRouter contract address.

```typescript
getReflexRouterAddress(): string
```

**Returns:** `string` - Address of the ReflexRouter contract

### getTargetRouterAddress()

Get the target DEX router address from the SwapProxy.

```typescript
async getTargetRouterAddress(): Promise<string>
```

**Returns:** `Promise<string>` - Address of the target DEX router

## Type Definitions

### SwapMetadata

Metadata about the swap transaction.

```typescript
interface SwapMetadata {
  swapTxCallData: string;  // Hex-encoded calldata for DEX router
  tokenIn: string;          // Address of input token
  amountIn: bigint;         // Amount of input token (full swap amount)
  tokenOut: string;         // Address of output token
  recipient: string;        // Address to receive swap output and MEV profits
}
```

**Field Details:**

- `swapTxCallData` - Must be valid calldata for the target DEX router
- `tokenIn` - ERC20 token address or zero address for ETH
- `amountIn` - Full swap amount (backrun sizing handled by Router based on configId)
- `tokenOut` - ERC20 token address or zero address for ETH
- `recipient` - Receives both swap output tokens and any MEV profits

### BackrunParams

Configuration for a single backrun operation.

```typescript
interface BackrunParams {
  triggerPoolId: string;   // Address of the pool being traded on
  swapAmountIn: bigint;    // Full swap amount (same as SwapMetadata.amountIn)
  token0In: boolean;       // Swap direction (true = token0→token1, false = token1→token0)
  recipient: string;       // Address to receive MEV profits
  configId: string;        // Configuration ID (use ethers.ZeroHash for default)
}
```

**Field Details:**

- `triggerPoolId` - Pool address that the swap trades through
- `swapAmountIn` - Always the full swap amount; Router handles backrun sizing internally
- `token0In` - Determined by token address comparison (tokenIn < tokenOut = true)
- `recipient` - Can differ from swap recipient for profit routing
- `configId` - Hash identifying backrun configuration (default = ethers.ZeroHash)

### TokenApproval

Token approval parameters.

```typescript
interface TokenApproval {
  tokenAddress: string;  // Address of token to approve
  amount: bigint;        // Amount to approve
}
```

### SwapWithBackrunResult

Result of a swap with backrun operation.

```typescript
interface SwapWithBackrunResult {
  transactionHash: string;     // Transaction hash
  blockNumber: number;         // Block number where tx was mined
  gasUsed: bigint;            // Actual gas used
  swapReturnData: string;     // Return data from DEX swap call
  profits: bigint[];          // MEV profits captured (one per backrun)
  profitTokens: string[];     // Token addresses for each profit
}
```

**Field Details:**

- `transactionHash` - Use for block explorer links and tracking
- `blockNumber` - Useful for event filtering and confirmations
- `gasUsed` - Actual gas consumed (for analytics)
- `swapReturnData` - Raw return data from the DEX router call
- `profits` - Array of profit amounts (indexed by BackrunParams order)
- `profitTokens` - Array of token addresses for each profit

## Complete Example

```typescript
import { UniversalIntegration } from "@reflex-mev/sdk/integrations";
import { ethers } from "ethers";

// Initialize provider and signer
const provider = new ethers.JsonRpcProvider("https://rpc.url");
const signer = new ethers.Wallet("PRIVATE_KEY", provider);

// Create integration instance
const integration = new UniversalIntegration(
  provider,
  signer,
  "0xSwapProxyAddress",
  "0xReflexRouterAddress"
);

// Encode swap for target DEX (e.g., Uniswap V2)
const targetDexInterface = new ethers.Interface([
  "function swapExactTokensForTokens(uint,uint,address[],address,uint)"
]);

const swapCalldata = targetDexInterface.encodeFunctionData(
  "swapExactTokensForTokens",
  [
    ethers.parseEther("1.0"),      // amountIn
    ethers.parseEther("0.95"),     // amountOutMin
    [tokenInAddress, tokenOutAddress], // path
    userAddress,                    // to
    Math.floor(Date.now() / 1000) + 60 * 20 // deadline
  ]
);

// Prepare swap metadata
const swapMetadata = {
  swapTxCallData: swapCalldata,
  tokenIn: tokenInAddress,
  amountIn: ethers.parseEther("1.0"),
  tokenOut: tokenOutAddress,
  recipient: userAddress
};

// Prepare backrun parameters
const backrunParams = [
  {
    triggerPoolId: poolAddress,
    swapAmountIn: ethers.parseEther("1.0"),
    token0In: tokenInAddress < tokenOutAddress,
    recipient: userAddress,
    configId: ethers.ZeroHash
  }
];

// Check and handle token approval
const isApproved = await integration.isTokenApproved(
  tokenInAddress,
  ethers.parseEther("1.0")
);

if (!isApproved) {
  await integration.approveTokens([
    {
      tokenAddress: tokenInAddress,
      amount: ethers.MaxUint256
    }
  ]);
}

// Execute swap with MEV capture
const result = await integration.swapWithBackrun(
  swapMetadata,
  backrunParams,
  { gasLimit: 1500000n }
);

console.log("Transaction:", result.transactionHash);
console.log("Gas used:", result.gasUsed.toString());

// Check if MEV was captured
if (result.profits.length > 0 && result.profits[0] > 0n) {
  console.log("MEV Captured:", ethers.formatEther(result.profits[0]));
  console.log("Profit Token:", result.profitTokens[0]);
}
```

## Usage Guides

For detailed integration guides and patterns, see:

- [Universal DEX Integration Guide](../../integration/universal-dex) - Complete guide with React hooks and DApp examples
- [BackrunEnabledSwapProxy Contract](../backrun-enabled-swap-proxy) - Contract API reference
