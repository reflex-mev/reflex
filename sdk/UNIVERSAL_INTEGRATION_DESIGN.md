# UniversalIntegration SDK Design

**Version:** 1.0  
**Date:** November 14, 2025  
**Status:** Design Complete - Ready for Implementation

## Overview

The `UniversalIntegration` class provides a TypeScript SDK for integrating Reflex MEV capture with any DEX using the `BackrunEnabledSwapProxy` contract pattern. This enables DApps, wallets, and aggregators to add MEV protection to swaps on legacy DEXes without requiring router modifications.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    UniversalIntegration                     │
│                     (TypeScript SDK)                        │
├─────────────────────────────────────────────────────────────┤
│  • swapWithBackrun()                                        │
│  • approveTokens()                                          │
│  • isTokenApproved()                                        │
│  • estimateGas()                                            │
│  • getAddresses()                                           │
└────────────────┬────────────────────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────────────────────┐
│              BackrunEnabledSwapProxy                        │
│                  (Solidity Contract)                        │
├─────────────────────────────────────────────────────────────┤
│  function swapWithBackrun(                                  │
│    bytes calldata swapTxCallData,                           │
│    SwapMetadata calldata swapMetadata,                      │
│    BackrunParams[] calldata backrunParams                   │
│  )                                                          │
└─────────────────────────────────────────────────────────────┘
```

## Class Definition

### Constructor

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
const integration = new UniversalIntegration(
  provider,
  signer,
  "0xSwapProxyAddress",
  "0xReflexRouterAddress"
);
```

## Core Methods

### 1. swapWithBackrun()

Execute a swap through the target DEX with automatic MEV backrun capture.

```typescript
async swapWithBackrun(
  swapTxCallData: string,
  swapMetadata: SwapMetadata,
  backrunParams: BackrunParams[],
  overrides?: ethers.Overrides
): Promise<SwapWithBackrunResult>
```

**Parameters:**

| Parameter | Type | Description |
|-----------|------|-------------|
| `swapTxCallData` | `string` | Hex-encoded calldata for the target DEX router call |
| `swapMetadata` | `SwapMetadata` | Metadata about the swap transaction |
| `backrunParams` | `BackrunParams[]` | Array of backrun configurations (supports multi-pool backruns) |
| `overrides` | `ethers.Overrides` (optional) | Standard ethers transaction overrides (gasLimit, maxFeePerGas, etc.) |

**Returns:** `Promise<SwapWithBackrunResult>`

**Example:**
```typescript
const result = await integration.swapWithBackrun(
  swapCalldata,
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

### 2. approveTokens()

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

// Approve exact amount
await integration.approveTokens([
  {
    tokenAddress: "0xUSDC",
    amount: ethers.parseUnits("100", 6)
  }
]);

// Approve multiple tokens
await integration.approveTokens([
  { tokenAddress: "0xUSDC", amount: ethers.MaxUint256 },
  { tokenAddress: "0xWETH", amount: ethers.MaxUint256 }
]);
```

### 3. isTokenApproved()

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

### 4. estimateGas()

Estimate gas required for a swap with backrun operation.

```typescript
async estimateGas(
  swapTxCallData: string,
  swapMetadata: SwapMetadata,
  backrunParams: BackrunParams[]
): Promise<bigint>
```

**Parameters:** Same as `swapWithBackrun()` (minus overrides)

**Returns:** `Promise<bigint>` - Estimated gas with 20% buffer included

**Example:**
```typescript
const estimatedGas = await integration.estimateGas(
  swapCalldata,
  swapMetadata,
  backrunParams
);

console.log("Estimated gas:", estimatedGas.toString());

// Use estimate in transaction
await integration.swapWithBackrun(
  swapCalldata,
  swapMetadata,
  backrunParams,
  { gasLimit: estimatedGas }
);
```

### 5. Address Getters

```typescript
getSwapProxyAddress(): string
getReflexRouterAddress(): string
async getTargetRouterAddress(): Promise<string>
```

**Example:**
```typescript
const swapProxy = integration.getSwapProxyAddress();
const reflexRouter = integration.getReflexRouterAddress();
const targetRouter = await integration.getTargetRouterAddress();

console.log("SwapProxy:", swapProxy);
console.log("Reflex Router:", reflexRouter);
console.log("Target DEX Router:", targetRouter);
```

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

**Multi-Pool Backruns:**
Multiple BackrunParams can be provided to execute backruns on multiple pools in a single transaction:

```typescript
const backrunParams = [
  {
    triggerPoolId: "0xPool1",
    swapAmountIn: ethers.parseEther("1.0"),
    token0In: true,
    recipient: userAddress,
    configId: ethers.ZeroHash
  },
  {
    triggerPoolId: "0xPool2",
    swapAmountIn: ethers.parseEther("1.0"),
    token0In: false,
    recipient: userAddress,
    configId: ethers.ZeroHash
  }
];
```

### TokenApproval

Token approval parameters.

```typescript
interface TokenApproval {
  tokenAddress: string;  // Address of token to approve
  amount: bigint;        // Amount to approve
}
```

**Recommended Values:**
- Production DApps: `ethers.MaxUint256` (unlimited approval for better UX)
- Security-focused: Exact amount needed for each swap

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

**Example Usage:**
```typescript
const result = await integration.swapWithBackrun(...);

console.log("TX:", result.transactionHash);
console.log("Gas:", result.gasUsed.toString());

// Check if any MEV was captured
if (result.profits.length > 0 && result.profits[0] > 0n) {
  console.log("MEV Captured:", ethers.formatEther(result.profits[0]));
  console.log("Profit Token:", result.profitTokens[0]);
}
```

## Usage Patterns

### Pattern 1: Simple Frontend Integration

```typescript
import { UniversalIntegration } from "@reflex-mev/sdk/integrations";
import { ethers } from "ethers";

// Initialize
const integration = new UniversalIntegration(
  provider,
  signer,
  swapProxyAddress,
  reflexRouterAddress
);

// Encode swap for target DEX
const iface = new ethers.Interface([
  "function swapExactTokensForTokens(uint,uint,address[],address,uint)"
]);

const swapCalldata = iface.encodeFunctionData("swapExactTokensForTokens", [
  amountIn,
  amountOutMin,
  [tokenIn, tokenOut],
  recipient,
  deadline
]);

// Prepare parameters
const swapMetadata = {
  swapTxCallData: swapCalldata,
  tokenIn,
  amountIn,
  tokenOut,
  recipient
};

const backrunParams = [{
  triggerPoolId: poolAddress,
  swapAmountIn: amountIn,
  token0In: tokenIn < tokenOut,
  recipient,
  configId: ethers.ZeroHash
}];

// Check approval
const isApproved = await integration.isTokenApproved(tokenIn, amountIn);
if (!isApproved) {
  await integration.approveTokens([
    { tokenAddress: tokenIn, amount: ethers.MaxUint256 }
  ]);
}

// Execute
const result = await integration.swapWithBackrun(
  swapCalldata,
  swapMetadata,
  backrunParams,
  { gasLimit: 1500000n }
);
```

### Pattern 2: Aggregator Integration

```typescript
// Execute multi-hop route with MEV capture on each hop
async function executeRoute(route) {
  for (const hop of route.hops) {
    const integration = new UniversalIntegration(
      provider,
      signer,
      hop.swapProxyAddress,
      reflexRouterAddress
    );

    await integration.swapWithBackrun(
      hop.swapCalldata,
      {
        swapTxCallData: hop.swapCalldata,
        tokenIn: hop.tokenIn,
        amountIn: hop.amountIn,
        tokenOut: hop.tokenOut,
        recipient: userAddress
      },
      [{
        triggerPoolId: hop.poolId,
        swapAmountIn: hop.amountIn,
        token0In: hop.tokenIn < hop.tokenOut,
        recipient: userAddress,
        configId: ethers.ZeroHash
      }]
    );
  }
}
```

### Pattern 3: React Hook

```typescript
export function useReflexSwap(
  provider,
  signer,
  swapProxyAddress,
  reflexRouterAddress
) {
  const [integration, setIntegration] = useState(null);

  useEffect(() => {
    if (provider && signer) {
      setIntegration(
        new UniversalIntegration(
          provider,
          signer,
          swapProxyAddress,
          reflexRouterAddress
        )
      );
    }
  }, [provider, signer, swapProxyAddress, reflexRouterAddress]);

  const executeSwap = useCallback(async (swapParams) => {
    // Encode swap calldata
    const swapCalldata = encodeSwapCall(swapParams);

    // Prepare metadata
    const swapMetadata = {
      swapTxCallData: swapCalldata,
      tokenIn: swapParams.tokenIn,
      amountIn: swapParams.amountIn,
      tokenOut: swapParams.tokenOut,
      recipient: swapParams.recipient
    };

    // Prepare backrun params
    const backrunParams = [{
      triggerPoolId: swapParams.poolAddress,
      swapAmountIn: swapParams.amountIn,
      token0In: swapParams.tokenIn < swapParams.tokenOut,
      recipient: swapParams.recipient,
      configId: ethers.ZeroHash
    }];

    // Check approval
    const isApproved = await integration.isTokenApproved(
      swapParams.tokenIn,
      swapParams.amountIn
    );

    if (!isApproved) {
      await integration.approveTokens([
        {
          tokenAddress: swapParams.tokenIn,
          amount: ethers.MaxUint256
        }
      ]);
    }

    // Execute
    return await integration.swapWithBackrun(
      swapCalldata,
      swapMetadata,
      backrunParams
    );
  }, [integration]);

  return { integration, executeSwap };
}
```

## Implementation Notes

### Dependencies

```json
{
  "dependencies": {
    "ethers": "^6.0.0"
  }
}
```

### Required ABIs

The SDK needs access to the following contract ABIs:

1. **BackrunEnabledSwapProxy ABI** - For calling swapWithBackrun()
2. **ERC20 ABI** - For token approvals and balance checks
3. **ReflexRouter ABI** - For event monitoring (optional)

```typescript
// Example ABI imports
import { SWAP_PROXY_ABI } from "@reflex-mev/sdk/abi";
import { ERC20_ABI } from "@reflex-mev/sdk/abi";
import { REFLEX_ROUTER_ABI } from "@reflex-mev/sdk/abi";
```

### Error Handling

The SDK should throw descriptive errors for common failure cases:

```typescript
class SwapProxyError extends Error {
  constructor(message: string, public code: string) {
    super(message);
    this.name = "SwapProxyError";
  }
}

// Usage in SDK
if (insufficient balance) {
  throw new SwapProxyError(
    "Insufficient token balance",
    "INSUFFICIENT_BALANCE"
  );
}
```

**Error Codes:**
- `INSUFFICIENT_BALANCE` - User doesn't have enough tokens
- `INSUFFICIENT_ALLOWANCE` - Token approval needed
- `INVALID_CALLDATA` - Invalid swapTxCallData format
- `SWAP_FAILED` - DEX swap reverted
- `BACKRUN_FAILED` - Backrun execution failed
- `GAS_ESTIMATION_FAILED` - Could not estimate gas

### Gas Estimation Strategy

```typescript
async estimateGas(...): Promise<bigint> {
  const gasEstimate = await swapProxyContract.swapWithBackrun.estimateGas(...);
  
  // Add 20% buffer for safety
  return (gasEstimate * 120n) / 100n;
}
```

### Event Monitoring (Optional Feature)

```typescript
class UniversalIntegration {
  // Listen for BackrunExecuted events
  onBackrunExecuted(
    callback: (event: BackrunExecutedEvent) => void
  ): () => void {
    const filter = reflexRouter.filters.BackrunExecuted();
    
    const handler = (log) => {
      const event = reflexRouter.interface.parseLog(log);
      callback({
        profit: event.args.profit,
        profitToken: event.args.profitToken,
        triggerPoolId: event.args.triggerPoolId,
        recipient: event.args.recipient
      });
    };
    
    provider.on(filter, handler);
    
    // Return cleanup function
    return () => provider.off(filter, handler);
  }
}
```

## Testing Considerations

### Unit Tests
- Mock ethers Provider and Signer
- Test parameter validation
- Test error handling
- Test gas estimation calculations

### Integration Tests
- Deploy test SwapProxy on local fork
- Execute real swaps on forked mainnet
- Verify token transfers
- Verify MEV profit distribution
- Test multi-pool backruns

### Test Data
```typescript
const TEST_SWAP_PARAMS = {
  swapCalldata: "0x...",
  swapMetadata: {
    swapTxCallData: "0x...",
    tokenIn: USDC_ADDRESS,
    amountIn: ethers.parseUnits("100", 6),
    tokenOut: WETH_ADDRESS,
    recipient: TEST_USER
  },
  backrunParams: [{
    triggerPoolId: USDC_WETH_POOL,
    swapAmountIn: ethers.parseUnits("100", 6),
    token0In: true,
    recipient: TEST_USER,
    configId: ethers.ZeroHash
  }]
};
```

## Migration from Previous Designs

If upgrading from an earlier SDK design:

### Breaking Changes
- `SwapTransactionOptions` removed - use ethers native `Overrides`
- `swapTxCallData` type changed from `BytesLike` to `string`
- All methods now use `BackrunParams[]` array (supports multi-pool)
- `amountIn` must be full swap amount (not partial)

### Migration Example
```typescript
// Old API
await sdk.swap(params, {
  gasLimit: 1500000,
  nonce: 10
});

// New API  
await integration.swapWithBackrun(
  swapCalldata,
  swapMetadata,
  backrunParams,
  { 
    gasLimit: 1500000n,
    nonce: 10
  }
);
```

## Security Considerations

1. **Private Key Management** - Never expose private keys in frontend code
2. **Input Validation** - Validate all user inputs before encoding calldata
3. **RPC Endpoints** - Use secure, authenticated RPC endpoints in production
4. **Rate Limiting** - Implement rate limiting to prevent abuse
5. **Slippage** - Set reasonable slippage tolerances in swap calldata
6. **Address Verification** - Verify contract addresses match expected deployments

## Performance Optimizations

1. **Batch Approvals** - Approve multiple tokens in parallel
2. **Unlimited Approvals** - Use `MaxUint256` to avoid repeated approvals
3. **Gas Caching** - Cache gas estimates for similar swaps
4. **Connection Pooling** - Reuse provider connections
5. **Event Filtering** - Use indexed event parameters for efficient filtering

## Future Enhancements

Potential features for future versions:

- **Multicall Support** - Batch multiple swaps in one transaction
- **Quote Integration** - Built-in profit estimation via ReflexQuoter
- **Flash Loan Support** - Enable flash loan backruns
- **Cross-Chain** - Support for L2s and sidechains
- **Advanced Routing** - Optimal pool selection for backruns
- **Analytics** - Built-in MEV capture tracking and reporting

## Resources

- **Contract Source**: `core/src/integrations/router/BackrunEnabledSwapProxy.sol`
- **Documentation**: `website/docs/integration/universal-dex.md`
- **Examples**: `sdk/src/examples/universal-integration.ts`
- **Tests**: `sdk/tests/integration.test.ts`

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Nov 14, 2025 | Initial design - matches BackrunEnabledSwapProxy contract exactly |

---

**Status**: ✅ Design Complete - Ready for Implementation

This design document should be used as the reference specification when implementing the `UniversalIntegration` class in the Reflex SDK.
