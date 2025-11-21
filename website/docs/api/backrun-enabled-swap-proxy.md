---
sidebar_position: 3
---

# BackrunEnabledSwapProxy

Proxy contract that wraps any DEX router to add MEV capture functionality through the UniversalIntegration pattern.

## Constructor

```solidity
constructor(address _targetRouter)
```

**Parameters:**

- `_targetRouter` - Address of the target DEX router to wrap (e.g., Uniswap V2 Router, SushiSwap Router)

**Validation:**

- Target router address must be non-zero

## State Variables

```solidity
address public immutable targetRouter;  // The wrapped DEX router address
```

## Core Functions

### swapWithBackrun

```solidity
function swapWithBackrun(
    SwapMetadata calldata swapMetadata,
    address reflexRouter,
    BackrunParams[] calldata backrunParams
) external payable returns (
    bytes memory swapReturnData,
    uint256[] memory profits,
    address[] memory profitTokens
)
```

Executes a swap through the target DEX router and triggers MEV backrun(s).

**Parameters:**

```solidity
struct SwapMetadata {
    bytes swapTxCallData;  // Encoded calldata for the target router
    address tokenIn;       // Input token address
    uint256 amountIn;      // Input token amount
    address tokenOut;      // Output token address
    address recipient;     // Recipient of swap output and profits
}

struct BackrunParams {
    bytes32 triggerPoolId;  // Pool identifier
    uint112 swapAmountIn;   // Full swap amount
    bool token0In;          // Swap direction
    address recipient;      // Profit recipient
    bytes32 configId;       // Configuration ID
}
```

**Returns:**

- `swapReturnData` - Return data from the DEX router swap call
- `profits` - Array of profit amounts from each backrun
- `profitTokens` - Array of profit token addresses

**Process:**

1. Transfers `tokenIn` from caller to proxy
2. Approves `tokenIn` to target router
3. Executes swap via target router using `swapTxCallData`
4. Triggers backrun(s) via ReflexRouter
5. Returns leftover tokens and ETH to recipient
6. Returns profits to recipient

**Example:**

```solidity
// Encode swap for Uniswap V2
bytes memory swapCalldata = abi.encodeWithSignature(
    "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)",
    amountIn,
    amountOutMin,
    path,
    recipient,
    deadline
);

// Prepare metadata
SwapMetadata memory metadata = SwapMetadata({
    swapTxCallData: swapCalldata,
    tokenIn: USDC,
    amountIn: 1000e6,
    tokenOut: WETH,
    recipient: msg.sender
});

// Prepare backrun params
BackrunParams[] memory backrunParams = new BackrunParams[](1);
backrunParams[0] = BackrunParams({
    triggerPoolId: bytes32(uint256(uint160(poolAddress))),
    swapAmountIn: 1000e6,
    token0In: true,
    recipient: msg.sender,
    configId: bytes32(0)
});

// Execute
(bytes memory returnData, uint256[] memory profits, address[] memory profitTokens) =
    swapProxy.swapWithBackrun(metadata, reflexRouterAddress, backrunParams);
```

## Features

- ✅ **Universal Compatibility** - Works with any DEX router
- ✅ **Atomic Execution** - Swap and backrun in single transaction
- ✅ **Multi-Pool Support** - Execute backruns on multiple pools
- ✅ **Token Recovery** - Returns leftover tokens and ETH to recipient
- ✅ **Reentrancy Protection** - Secured against reentrancy attacks
- ✅ **ETH Support** - Handles native ETH swaps

## Deployment

Deploy one proxy per target DEX router:

```solidity
// Deploy for Uniswap V2
BackrunEnabledSwapProxy uniswapProxy = new BackrunEnabledSwapProxy(
    0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D  // Uniswap V2 Router
);

// Deploy for SushiSwap
BackrunEnabledSwapProxy sushiProxy = new BackrunEnabledSwapProxy(
    0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F  // SushiSwap Router
);
```

Or using Foundry script:

```bash
forge script script/deploy-swap-proxy/DeployBackrunEnabledSwapProxy.s.sol \
    --rpc-url $RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast
```

## Usage with SDK

The BackrunEnabledSwapProxy is designed to work seamlessly with the UniversalIntegration SDK:

```typescript
import { UniversalIntegration } from "@reflex-mev/sdk/integrations";

const integration = new UniversalIntegration(
  provider,
  signer,
  swapProxyAddress, // BackrunEnabledSwapProxy address
  reflexRouterAddress
);

await integration.swapWithBackrun(swapMetadata, backrunParams);
```

See [Universal DEX Integration](../integration/universal-dex) for complete SDK documentation.

## Security Considerations

- **Token Approvals** - Users must approve tokens to the SwapProxy contract
- **Slippage Protection** - Set appropriate slippage in the swap calldata
- **Valid Calldata** - Ensure `swapTxCallData` is valid for the target router
- **Recipient Address** - Verify recipient addresses to prevent fund loss
- **Gas Limits** - Allow sufficient gas for swap + backrun execution

## Error Messages

- `"Invalid target router address"` - Target router is zero address in constructor
- `"Token transfer failed"` - Failed to transfer input tokens from caller
- `"Swap execution failed"` - Target router call reverted
