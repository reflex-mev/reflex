---
sidebar_position: 1
---

# ReflexRouter

The core contract that orchestrates MEV capture and execution.

## Constructor

```solidity
constructor()
```

Sets the deployer (`msg.sender`) as the contract owner.

## Core Functions

### triggerBackrun

```solidity
function triggerBackrun(
    bytes32 triggerPoolId,
    uint112 swapAmountIn,
    bool token0In,
    address recipient,
    bytes32 configId
) external override gracefulNonReentrant
  returns (uint256 profit, address profitToken)
```

Executes a backrun arbitrage opportunity.

**Parameters:**

- `triggerPoolId` - Unique identifier of the triggering pool (cast from pool address)
- `swapAmountIn` - Amount of tokens for arbitrage swap (uint112 for gas optimization)
- `token0In` - Whether to use token0 (true) or token1 (false) as input token
- `recipient` - Address to receive arbitrage profit (used as dust recipient)
- `configId` - Configuration ID for profit splitting (uses default if `bytes32(0)`)

**Returns:**

- `profit` - Amount of profit generated from the arbitrage
- `profitToken` - Address of the token in which profit was generated

**Events Emitted:**

- `BackrunExecuted(triggerPoolId, swapAmountIn, token0In, profit, profitToken, recipient)`

**Example:**

```solidity
uint256 profit, address profitToken = reflexRouter.triggerBackrun(
    bytes32(uint256(uint160(poolAddress))),
    1000000, // 1 USDC (6 decimals)
    true,    // Use token0 as input
    msg.sender,
    bytes32(0) // Use default config
);
```

## Events

### BackrunExecuted

```solidity
event BackrunExecuted(
    bytes32 indexed triggerPoolId,
    uint112 swapAmountIn,
    bool token0In,
    uint256 profit,
    address profitToken,
    address recipient
);
```

Emitted when a backrun is successfully executed.

**Event Parameters:**

- `triggerPoolId` - Pool identifier where the backrun was triggered
- `swapAmountIn` - Amount of tokens used in the arbitrage
- `token0In` - Swap direction flag
- `profit` - Amount of profit captured
- `profitToken` - Token address in which profit was received
- `recipient` - Address that received the profit
