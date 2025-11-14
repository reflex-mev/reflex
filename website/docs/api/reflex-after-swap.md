---
sidebar_position: 2
---

# ReflexAfterSwap

Abstract base contract for DEX plugin integration with failsafe mechanisms.

## Constructor

```solidity
constructor(address _router, bytes32 _configId)
```

**Parameters:**

- `_router` - Address of the ReflexRouter contract
- `_configId` - Configuration ID for profit distribution

**Validation:**

- Router address must be non-zero
- Fetches admin address from the router contract

## State Variables

```solidity
address reflexRouter;      // Address of the Reflex router contract
address reflexAdmin;       // Address of the reflex admin (authorized controller)
bytes32 reflexConfigId;    // Configuration ID for profit distribution
```

## Administrative Functions

### setReflexRouter

```solidity
function setReflexRouter(address _router) external onlyReflexAdmin
```

Updates the Reflex router address and refreshes admin.

**Parameters:**

- `_router` - New router address to set

**Access:** Reflex admin only

### setReflexConfigId

```solidity
function setReflexConfigId(bytes32 _configId) external onlyReflexAdmin
```

Updates the configuration ID for profit distribution.

**Parameters:**

- `_configId` - New configuration ID to set

**Access:** Reflex admin only

## View Functions

### getRouter

```solidity
function getRouter() public view returns (address)
```

Returns the current router address.

### getReflexAdmin

```solidity
function getReflexAdmin() external view returns (address)
```

Returns the current reflex admin address.

### getConfigId

```solidity
function getConfigId() external view returns (bytes32)
```

Returns the current configuration ID for profit distribution.

## Internal Functions

### _reflexAfterSwap

```solidity
function _reflexAfterSwap(
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

## Modifiers

### onlyReflexAdmin

```solidity
modifier onlyReflexAdmin() {
    require(msg.sender == reflexAdmin, "Caller is not the reflex admin");
    _;
}
```

Restricts access to reflex admin only.

## Implementation Example

```solidity
pragma solidity ^0.8.20;

import "@reflex/contracts/base/ReflexAfterSwap.sol";

contract AlgebraPlugin is ReflexAfterSwap {
    address public immutable pool;

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

    function afterSwap(
        address,
        address,
        bool zeroForOne,
        int256 amount0Delta,
        int256 amount1Delta,
        uint160,
        uint128,
        int24,
        bytes calldata hookData
    ) external override onlyPool returns (bytes4) {
        // Extract recipient from hook data
        address recipient = abi.decode(hookData, (address));

        // Trigger backrun using base contract's internal function
        _reflexAfterSwap(
            bytes32(uint256(uint160(pool))),
            amount0Delta,
            amount1Delta,
            zeroForOne,
            recipient
        );

        return this.afterSwap.selector;
    }
}
```

## Error Messages

- `"Invalid router address"` - Router address is zero in constructor or setReflexRouter
- `"Caller is not the reflex admin"` - Access control for admin-only functions
