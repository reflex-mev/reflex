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

**Gas Usage:** ~150,000 gas (varies by route complexity)

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
- `4` - Curve
- `5` - Balancer
- `6` - Algebra (Quickswap)

## 💰 ConfigurableRevenueDistributor

Manages profit distribution across multiple stakeholders.

### Core Functions

#### configureRevenue

```solidity
function configureRevenue(
    bytes32 configId,
    address[] calldata recipients,
    uint256[] calldata shares
) external onlyFundsAdmin
```

Configures profit distribution for a specific configuration ID.

**Parameters:**

- `configId` - Unique identifier for the configuration
- `recipients` - Array of recipient addresses
- `shares` - Array of share percentages (must sum to 100)

**Constraints:**

- Maximum 10 recipients per configuration
- Shares must sum to exactly 100
- Recipients must be non-zero addresses

#### distributeRevenue

```solidity
function distributeRevenue(
    bytes32 configId,
    address token,
    uint256 amount,
    address dustRecipient
) external returns (uint256[] memory distributed)
```

Distributes revenue according to the specified configuration.

**Parameters:**

- `configId` - Configuration to use for distribution
- `token` - ERC20 token to distribute
- `amount` - Total amount to distribute
- `dustRecipient` - Address to receive any remaining dust

**Returns:**

- `distributed` - Array of amounts distributed to each recipient

#### getRevenueConfig

```solidity
function getRevenueConfig(bytes32 configId)
    external view returns (
        address[] memory recipients,
        uint256[] memory shares,
        bool isActive
    )
```

Retrieves the revenue configuration for a given ID.

### Events

#### RevenueConfigured

```solidity
event RevenueConfigured(
    bytes32 indexed configId,
    address[] recipients,
    uint256[] shares
);
```

#### RevenueDistributed

```solidity
event RevenueDistributed(
    bytes32 indexed configId,
    address indexed token,
    uint256 totalAmount,
    uint256[] amounts
);
```

## 🔌 ReflexAfterSwap (Base Plugin)

Abstract base contract for DEX plugin integration.

### Constructor

```solidity
constructor(address _reflexRouter, address _pool)
```

**Parameters:**

- `_reflexRouter` - Address of the ReflexRouter contract
- `_pool` - Address of the target pool to monitor

### Abstract Functions

#### afterSwap

```solidity
function afterSwap(
    address sender,
    uint256 amount0,
    uint256 amount1,
    bytes calldata data
) external virtual
```

Called after each swap to trigger MEV capture. Must be implemented by derived contracts.

**Implementation Example:**

```solidity
function afterSwap(
    address sender,
    uint256 amount0,
    uint256 amount1,
    bytes calldata data
) external override onlyPool {
    uint256 swapAmount = amount0 > 0 ? amount0 : amount1;
    bool token0In = amount0 > 0;

    if (swapAmount >= minBackrunThreshold) {
        reflexRouter.triggerBackrun(
            bytes32(uint256(uint160(pool))),
            uint112(swapAmount / 10), // 10% of swap size
            token0In,
            sender, // Give profits to swapper
            defaultConfigId
        );
    }
}
```

### Modifiers

#### onlyPool

```solidity
modifier onlyPool() {
    require(msg.sender == pool, "Only pool can call");
    _;
}
```

## 📊 Gas Usage Reference

| Function            | Typical Gas                    | Max Gas | Notes                     |
| ------------------- | ------------------------------ | ------- | ------------------------- |
| `triggerBackrun`    | 150,000                        | 300,000 | Varies by route length    |
| `backrunedExecute`  | 200,000                        | 500,000 | Base + execution costs    |
| `configureRevenue`  | 80,000                         | 120,000 | One-time setup            |
| `distributeRevenue` | 50,000 + (recipients × 20,000) | 250,000 | Scales with recipients    |
| `getQuote`          | 30,000                         | 100,000 | View function (off-chain) |

## 🔍 Error Codes

### ReflexRouter Errors

```solidity
error InsufficientProfit(uint256 required, uint256 available);
error InvalidPoolId(bytes32 poolId);
error UnauthorizedCallback(address caller);
error InvalidSwapAmount(uint256 amount);
error CallbackTypeMismatch(uint8 expected, uint8 actual);
```

### RevenueDistributor Errors

```solidity
error InvalidConfiguration(bytes32 configId);
error SharesSumError(uint256 sum);
error TooManyRecipients(uint256 count);
error ZeroAddress();
error InsufficientBalance(uint256 required, uint256 available);
```

## 🔗 Contract Addresses

### Mainnet

```
ReflexRouter:     0x742d35Cc6634C0532925a3b8D598C4B4B3A3A3A3
ReflexQuoter:     0x9E545E3C0baAB3E08CdfD552C960A1050f373042
```

### Goerli Testnet

```
ReflexRouter:     0x1234567890123456789012345678901234567890
ReflexQuoter:     0x0987654321098765432109876543210987654321
```

### Polygon

```
ReflexRouter:     0xABCDEF1234567890ABCDEF1234567890ABCDEF12
ReflexQuoter:     0x1234567890ABCDEF1234567890ABCDEF12345678
```

## 📖 Integration Examples

### Basic Integration

```solidity
pragma solidity ^0.8.19;

import "@reflex/contracts/ReflexAfterSwap.sol";

contract MyDEXPlugin is ReflexAfterSwap {
    uint256 public constant MIN_BACKRUN_AMOUNT = 1e18;
    bytes32 public constant CONFIG_ID = keccak256("MY_DEX_CONFIG");

    constructor(address _reflexRouter, address _pool)
        ReflexAfterSwap(_reflexRouter, _pool) {}

    function afterSwap(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override onlyPool {
        uint256 swapAmount = amount0 > 0 ? amount0 : amount1;

        if (swapAmount >= MIN_BACKRUN_AMOUNT) {
            try reflexRouter.triggerBackrun(
                bytes32(uint256(uint160(pool))),
                uint112(swapAmount / 20), // 5% of swap
                amount0 > 0,
                sender,
                CONFIG_ID
            ) returns (uint256 profit, address profitToken) {
                emit BackrunSuccess(sender, profit, profitToken);
            } catch Error(string memory reason) {
                emit BackrunFailed(sender, reason);
            }
        }
    }

    event BackrunSuccess(address indexed user, uint256 profit, address token);
    event BackrunFailed(address indexed user, string reason);
}
```

### Advanced Revenue Configuration

```solidity
// Configure 4-way profit split
address[] memory recipients = new address[](4);
recipients[0] = protocolTreasury;    // 40%
recipients[1] = userAddress;         // 30%
recipients[2] = lpProviders;         // 20%
recipients[3] = validatorTips;       // 10%

uint256[] memory shares = new uint256[](4);
shares[0] = 40;
shares[1] = 30;
shares[2] = 20;
shares[3] = 10;

reflexRouter.configureRevenue(
    keccak256("ADVANCED_CONFIG"),
    recipients,
    shares
);
```

---

For more implementation details and examples, see our [Integration Guide](../integration/overview) and [Examples](../examples/basic-backrun).
