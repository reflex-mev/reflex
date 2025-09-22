---
sidebar_position: 2
---

# Smart Contract Integration

Integrate Reflex MEV capture directly into your smart contracts using either router direct access or plugin-based architecture.

## Router Direct Access

### Overview

Direct integration with the Reflex Router gives you complete control over MEV capture timing and logic. This approach is ideal for new protocols or when you want tight integration with your core contract logic.

### Implementation

#### 1. Import Reflex Interface

```solidity
pragma solidity ^0.8.19;

import "@reflex/contracts/interfaces/IReflexRouter.sol";

contract YourProtocol {
    IReflexRouter public immutable reflexRouter;

    constructor(address _reflexRouter) {
        reflexRouter = IReflexRouter(_reflexRouter);
    }
}
```

#### 2. Trigger Backruns

```solidity
function executeSwapWithMEV(
    address tokenIn,
    address tokenOut,
    uint256 amountIn,
    bytes32 configId
) external {
    // Execute your core swap logic
    uint256 amountOut = _executeSwap(tokenIn, tokenOut, amountIn);

    // Trigger MEV capture
    try reflexRouter.triggerBackrun(
        bytes32(uint256(uint160(address(this)))), // Pool identifier
        uint112(amountIn / 20), // 5% of swap for backrun
        tokenIn < tokenOut, // Token order
        msg.sender, // Profit recipient
        configId // Revenue sharing config
    ) returns (uint256 profit, address profitToken) {
        emit MEVCaptured(msg.sender, profit, profitToken);
    } catch {
        // MEV capture failed, continue normal operation
        emit MEVCaptureFailed(msg.sender, amountIn);
    }
}
```

#### 3. Revenue Configuration

Revenue sharing configurations are managed by the Reflex team. For detailed information on how to set up custom revenue sharing, see the [Revenue Configuration Guide](./revenue-configuration).

#### Setting Up Custom Revenue Sharing
1. **Contact Reflex** with your desired revenue sharing structure

```solidity
contract YourProtocol {
    // ConfigId provided by Reflex team
    bytes32 public immutable CONFIG_ID;

    constructor(address _reflexRouter, bytes32 _configId) {
        reflexRouter = IReflexRouter(_reflexRouter);
        CONFIG_ID = _configId;
    }

    function executeSwapWithCustomConfig(
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) external {
        // Execute your core swap logic
        uint256 amountOut = _executeSwap(tokenIn, tokenOut, amountIn);

        // Use your custom configId
        reflexRouter.triggerBackrun(
            bytes32(uint256(uint160(address(this)))),
            uint112(amountIn / 20),
            tokenIn < tokenOut,
            msg.sender,
            CONFIG_ID // Your custom config provided by Reflex
        );
    }
}
```

## Plugin-Based Access

### Overview

Plugin-based integration uses lightweight contracts that hook into your existing DEX architecture. This is perfect for protocols that already have callback systems or want minimal changes to existing code.

### Algebra-Based Plugin

```solidity
pragma solidity ^0.8.19;

import "@reflex/contracts/ReflexAfterSwap.sol";

contract AlgebraReflexPlugin is ReflexAfterSwap {
    struct PluginConfig {
        uint256 minThreshold;
        uint256 backrunRatio; // Basis points
        bool enabled;
        mapping(address => bool) excludedUsers;
    }

    PluginConfig public config;
    bytes32 public immutable CONFIG_ID;

    constructor(
        address _reflexRouter,
        address _pool,
        bytes32 _configId
    ) ReflexAfterSwap(_reflexRouter, _pool) {
        config.minThreshold = 1e18;
        config.backrunRatio = 500; // 5%
        config.enabled = true;
        CONFIG_ID = _configId;
    }

    function afterSwap(
        address sender,
        int256 amount0,
        int256 amount1,
        uint160 currentPrice,
        uint128 currentLiquidity,
        int24 currentTick,
        bytes calldata data
    ) external override onlyPool {
        if (!config.enabled || config.excludedUsers[sender]) {
            return;
        }

        uint256 swapAmount = amount0 > 0 ? uint256(amount0) : uint256(-amount1);

        if (swapAmount >= config.minThreshold) {
            uint256 backrunAmount = (swapAmount * config.backrunRatio) / 10000;

            try reflexRouter.triggerBackrun(
                bytes32(uint256(uint160(pool))),
                uint112(backrunAmount),
                amount0 > 0,
                sender,
                CONFIG_ID
            ) returns (uint256 profit, address profitToken) {
                emit MEVCaptured(sender, profit, profitToken);
            } catch {
                emit MEVCaptureFailed(sender, backrunAmount);
            }
        }
    }

    // Admin functions
    function updateConfig(
        uint256 _minThreshold,
        uint256 _backrunRatio,
        bool _enabled
    ) external onlyOwner {
        config.minThreshold = _minThreshold;
        config.backrunRatio = _backrunRatio;
        config.enabled = _enabled;
    }

    function excludeUser(address user, bool excluded) external onlyOwner {
        config.excludedUsers[user] = excluded;
    }

    // Events
    event MEVCaptured(address indexed user, uint256 profit, address profitToken);
    event MEVCaptureFailed(address indexed user, uint256 attemptedAmount);
}
```

### Integration with Existing Pools

#### Modify Pool Contract

```solidity
contract YourPool {
    address public reflexPlugin;

    modifier withMEVCapture() {
        _;
        if (reflexPlugin != address(0)) {
            try IReflexPlugin(reflexPlugin).afterSwap(
                msg.sender,
                amount0Out,
                amount1Out,
                ""
            ) {} catch {
                // Plugin failed, continue normal operation
            }
        }
    }

    function swap(
        uint256 amount0Out,
        uint256 amount1Out,
        address to,
        bytes calldata data
    ) external withMEVCapture {
        // Your existing swap logic
        _swap(amount0Out, amount1Out, to, data);
    }

    function setReflexPlugin(address _plugin) external onlyOwner {
        reflexPlugin = _plugin;
    }
}
```

#### Factory Integration

```solidity
contract YourPoolFactory {
    address public immutable reflexRouter;
    mapping(address => address) public poolPlugins;
    bytes32 public immutable defaultConfigId;

    constructor(address _reflexRouter, bytes32 _defaultConfigId) {
        reflexRouter = _reflexRouter;
        defaultConfigId = _defaultConfigId;
    }

    function createPoolWithMEV(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool, address plugin) {
        // Create pool
        pool = _createPool(tokenA, tokenB, fee);

        // Deploy Algebra plugin with default config
        plugin = new AlgebraReflexPlugin(
            reflexRouter,
            pool,
            defaultConfigId
        );

        // Configure pool to use plugin
        IYourPool(pool).setReflexPlugin(plugin);

        poolPlugins[pool] = plugin;

        emit PoolCreatedWithMEV(pool, plugin);
    }

    function createPoolWithCustomConfig(
        address tokenA,
        address tokenB,
        uint24 fee,
        bytes32 customConfigId
    ) external returns (address pool, address plugin) {
        // Create pool
        pool = _createPool(tokenA, tokenB, fee);

        // Deploy plugin with custom config (provided by Reflex team)
        plugin = new AlgebraReflexPlugin(
            reflexRouter,
            pool,
            customConfigId
        );

        // Configure pool to use plugin
        IYourPool(pool).setReflexPlugin(plugin);

        poolPlugins[pool] = plugin;

        emit PoolCreatedWithMEV(pool, plugin);
    }
}
```

## Best Practices

### Security Considerations

1. **Always use try/catch** when calling Reflex functions
2. **Validate all inputs** before triggering MEV capture
3. **Set reasonable thresholds** to prevent spam
4. **Implement access controls** for configuration functions

### Gas Optimization

1. **Cache frequently used values** like config IDs
2. **Use appropriate data types** (uint112 for amounts)
3. **Minimize external calls** in hot paths
4. **Consider batch operations** for multiple triggers

### Monitoring

1. **Emit events** for all MEV capture attempts
2. **Track success/failure rates** in your analytics
3. **Monitor gas usage** patterns
4. **Set up alerts** for unusual activity

---

For revenue configuration details, see the [Revenue Configuration Guide](./revenue-configuration).
For SDK integration, see the [SDK Integration Guide](./sdk-integration).
For SDK integration details, see the [SDK Integration Guide](./sdk-integration).
