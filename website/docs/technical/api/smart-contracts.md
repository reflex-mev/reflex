---
sidebar_position: 1
---

# Smart Contracts API

Complete API reference for Reflex Protocol smart contracts, covering all functions, events, and data structures.

## 📋 Contract Overview

| Contract                           | Address     | Description                               |
| ---------------------------------- | ----------- | ----------------------------------------- |
| **ReflexRouter**                   | `0x742d...` | Main router for MEV capture and execution |
| **ReflexQuoter**                   | `0x9E54...` | Price quoter and route optimizer          |
| **ConfigurableRevenueDistributor** | `0x1A2B...` | Revenue sharing management                |

## 🎯 ReflexRouter

The core contract that orchestrates MEV capture and execution.

### Constructor

```solidity
constructor()
```

Sets the deployer (`tx.origin`) as the contract owner.

### State Variables

```solidity
address public owner;
address public reflexQuoter;
uint8 private loanCallbackType;
```

### Core Functions

#### triggerBackrun

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

#### backrunedExecute

```solidity
function backrunedExecute(
    ExecuteParams calldata executeParams,
    BackrunParams[] calldata backrunParams
) external payable override gracefulNonReentrant
  returns (
    bool success,
    bytes memory returnData,
    uint256[] memory profits,
    address[] memory profitTokens
  )
```

Executes arbitrary calldata and then triggers multiple backruns with failsafe mechanisms.

**Parameters:**

```solidity
struct ExecuteParams {
    address target;   // Target contract to call
    uint256 value;    // ETH value to send
    bytes callData;   // Encoded function call
}

struct BackrunParams {
    bytes32 triggerPoolId;
    uint112 swapAmountIn;
    bool token0In;
    address recipient;
    bytes32 configId;
}
```

**Returns:**

- `success` - Whether the initial call succeeded
- `returnData` - Return data from the initial call
- `profits` - Array of profits from each backrun (0 if failed)
- `profitTokens` - Array of profit tokens (address(0) if failed)

**Features:**

- ✅ Atomic execution with rollback protection
- ✅ Individual backrun failure isolation
- ✅ Batch profit optimization
- ✅ ETH value forwarding support

### Administrative Functions

#### setReflexQuoter

```solidity
function setReflexQuoter(address _reflexQuoter) public isAdmin
```

Sets the ReflexQuoter contract address.

**Access:** Admin only

#### getReflexAdmin

```solidity
function getReflexAdmin() public view returns (address)
```

Returns the contract admin address.

#### withdrawToken

```solidity
function withdrawToken(address token, uint256 amount, address _to) public isAdmin
```

Withdraws ERC20 tokens from the contract.

**Access:** Admin only

#### withdrawEth

```solidity
function withdrawEth(uint256 amount, address payable _to) public isAdmin
```

Withdraws ETH from the contract.

**Access:** Admin only

### Internal Functions

#### decodeIsZeroForOne

```solidity
function decodeIsZeroForOne(uint256 b) public pure returns (bool zeroForOne)
```

Decodes swap direction from metadata byte using bitwise operations.

**Implementation:**

```solidity
// 1 byte - <1 bit zeroForOne><7 bits other data>
function decodeIsZeroForOne(uint256 b) public pure returns (bool zeroForOne) {
    assembly {
        zeroForOne := and(b, 0x80)
    }
}
```

### Events

#### BackrunExecuted

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

## 💡 ReflexQuoter

Interface for the price quoter and route optimizer.

### Core Functions

#### getQuote

```solidity
function getQuote(
    address triggerPool,
    uint8 tokenInIndex,
    uint256 amountIn
) external view returns (
    uint256 profit,
    SwapDecodedData memory decoded,
    uint256[] memory amountsOut,
    uint256 initialHopIndex
)
```

Analyzes arbitrage opportunities and returns optimal execution parameters.

**Parameters:**

- `triggerPool` - Address of the pool that triggered the opportunity
- `tokenInIndex` - Index of input token (0 for token0, 1 for token1)
- `amountIn` - Amount of input tokens for the arbitrage

**Returns:**

- `profit` - Estimated profit from the arbitrage (0 if not profitable)
- `decoded` - Swap route data structure
- `amountsOut` - Token amounts for each hop in the route
- `initialHopIndex` - Starting index for the swap route

### Data Structures

#### SwapDecodedData

```solidity
struct SwapDecodedData {
    address[] pools;     // Array of pool addresses in the route
    uint8[] dexType;     // DEX type for each pool (UniV2, UniV3, etc.)
    uint8[] dexMeta;     // Metadata for each pool (swap direction, etc.)
    address[] tokens;    // Token addresses involved in the route
}
```

**DEX Types:**

- `1` - UniswapV2 (with callback)
- `2` - UniswapV2 (without callback)
- `3` - UniswapV3
- `6` - Algebra (Quickswap)

## 💰 ConfigurableRevenueDistributor

Manages profit distribution across multiple stakeholders.

### Core Functions

#### updateShares

```solidity
function updateShares(
    bytes32 configId,
    address[] calldata recipients,
    uint256[] calldata sharesBps,
    uint256 dustShareBps
) external
```

Configures profit distribution for a specific configuration ID using basis points.

**Parameters:**

- `configId` - Unique identifier for the configuration
- `recipients` - Array of recipient addresses
- `sharesBps` - Array of share amounts in basis points (1% = 100 bps)
- `dustShareBps` - Dust recipient's share in basis points

**Constraints:**

- Recipients and shares arrays must have equal length
- All recipients must be non-zero addresses
- All shares must be greater than 0
- Total shares (including dust) must equal 10,000 bps (100%)

#### getConfig

```solidity
function getConfig(bytes32 configId)
    external view returns (SplitConfig memory config)
```

Retrieves the complete revenue configuration for a given ID.

#### getRecipients

```solidity
function getRecipients(bytes32 configId)
    external view returns (
        address[] memory recipients,
        uint256[] memory sharesBps,
        uint256 dustShareBps
    )
```

Retrieves the revenue configuration details for a given ID.

### Events

#### SharesUpdated

```solidity
event SharesUpdated(
    bytes32 indexed configId,
    address[] recipients,
    uint256[] sharesBps,
    uint256 dustShareBps
);
```

#### SplitExecuted

```solidity
event SplitExecuted(
    bytes32 indexed configId,
    address indexed token,
    uint256 totalAmount,
    address[] recipients,
    uint256[] amounts,
    address dustRecipient,
    uint256 dustAmount
);
```

Emitted when revenue is successfully distributed.

## 🔌 ReflexAfterSwap (Base Plugin)

Abstract base contract for DEX plugin integration with failsafe mechanisms.

### Constructor

```solidity
constructor(address _router, bytes32 _configId)
```

**Parameters:**

- `_router` - Address of the ReflexRouter contract
- `_configId` - Configuration ID for profit distribution

**Validation:**

- Router address must be non-zero
- Fetches admin address from the router contract

### State Variables

```solidity
address reflexRouter;      // Address of the Reflex router contract
address reflexAdmin;       // Address of the reflex admin (authorized controller)
bytes32 reflexConfigId;    // Configuration ID for profit distribution
```

### Administrative Functions

#### setReflexRouter

```solidity
function setReflexRouter(address _router) external onlyReflexAdmin
```

Updates the Reflex router address and refreshes admin.

**Parameters:**

- `_router` - New router address to set

**Access:** Reflex admin only

#### setReflexConfigId

```solidity
function setReflexConfigId(bytes32 _configId) external onlyReflexAdmin
```

Updates the configuration ID for profit distribution.

**Parameters:**

- `_configId` - New configuration ID to set

**Access:** Reflex admin only

### View Functions

#### getRouter

```solidity
function getRouter() public view returns (address)
```

Returns the current router address.

#### getReflexAdmin

```solidity
function getReflexAdmin() external view returns (address)
```

Returns the current reflex admin address.

#### getConfigId

```solidity
function getConfigId() external view returns (bytes32)
```

Returns the current configuration ID for profit distribution.

### Internal Functions

#### reflexAfterSwap

```solidity
function reflexAfterSwap(
    bytes32 triggerPoolId,
    int256 amount0Delta,
    int256 amount1Delta,
    bool zeroForOne,
    address recipient
) internal gracefulNonReentrant returns (uint256 profit, address profitToken)
```

Main entry point for post-swap profit extraction via backrunning.

**Parameters:**

- `triggerPoolId` - Unique identifier for the pool that triggered the swap
- `amount0Delta` - The change in token0 balance from the original swap
- `amount1Delta` - The change in token1 balance from the original swap
- `zeroForOne` - Direction of the original swap (true if token0 → token1)
- `recipient` - Address that should receive the extracted profits

**Returns:**

- `profit` - Amount of profit extracted (0 if router call fails)
- `profitToken` - Address of the token in which profit was extracted (address(0) if failed)

**Features:**

- ✅ Failsafe operation with try-catch mechanism
- ✅ Router failures won't break main swap operations
- ✅ Reentrancy protection via graceful reentrancy guard
- ✅ Automatic profit distribution using configured settings

### Modifiers

#### onlyReflexAdmin

```solidity
modifier onlyReflexAdmin() {
    require(msg.sender == reflexAdmin, "Caller is not the reflex admin");
    _;
}
```

Restricts access to reflex admin only.

### Implementation Example

```solidity
pragma solidity ^0.8.20;

import "@reflex/contracts/ReflexAfterSwap.sol";

contract UniswapV3Plugin is ReflexAfterSwap {
    address public immutable pool;
    uint256 public constant MIN_BACKRUN_THRESHOLD = 1000e6; // 1000 USDC minimum

    constructor(
        address _reflexRouter,
        address _pool,
        bytes32 _configId
    ) ReflexAfterSwap(_reflexRouter, _configId) {
        pool = _pool;
    }

    modifier onlyPool() {
        require(msg.sender == pool, "Only pool can call");
        _;
    }

    // This would be called by the Uniswap V3 pool after each swap
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata data
    ) external onlyPool {
        // Extract swap information
        uint256 swapAmount = uint256(amount0Delta > 0 ? amount0Delta : -amount0Delta);
        if (amount1Delta < 0) {
            swapAmount = uint256(-amount1Delta);
        }

        // Only trigger backrun for significant swaps
        if (swapAmount >= MIN_BACKRUN_THRESHOLD) {
            // Determine swap direction
            bool zeroForOne = amount0Delta > 0;

            // Extract recipient from callback data (implementation specific)
            address recipient = abi.decode(data, (address));

            // Trigger backrun using ReflexAfterSwap's internal function
            (uint256 profit, address profitToken) = reflexAfterSwap(
                bytes32(uint256(uint160(pool))), // Pool ID from pool address
                amount0Delta,
                amount1Delta,
                zeroForOne,
                recipient
            );

            // Emit event if profit was extracted
            if (profit > 0) {
                emit BackrunExecuted(recipient, profit, profitToken);
            }
        }
    }

    // Admin function to update configuration
    function updateConfig(bytes32 newConfigId) external {
        // This will call ReflexAfterSwap's setReflexConfigId with admin check
        setReflexConfigId(newConfigId);
    }

    event BackrunExecuted(
        address indexed recipient,
        uint256 profit,
        address profitToken
    );
}
```

## Error Messages

### ReflexRouter Error Messages

The ReflexRouter uses `require` statements with descriptive error messages:

- `"Only admin can manage revenue configurations"` - Access control for admin functions
- `"Only self-call allowed"` - Internal function access restriction
- `"Initial call failed"` - When the executed call in `backrunedExecute` fails

### ConfigurableRevenueDistributor Error Messages

- `"ETH transfer failed"` - ETH transfer to recipient failed
- `"ETH dust transfer failed"` - ETH dust transfer failed
- `"Recipients and shares length mismatch"` - Array length mismatch
- `"No recipients provided"` - Empty recipients array
- `"Invalid recipient address"` - Zero address recipient
- `"Invalid share amount"` - Zero share amount
- `"Total shares must equal 100%"` - Share distribution doesn't sum to 10,000 bps

### ReflexAfterSwap Error Messages

- `"Invalid router address"` - Router address is zero in constructor or setReflexRouter
- `"Caller is not the reflex admin"` - Access control for admin-only functions
