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

```solidity
function setupRevenueSharing() external onlyOwner {
    bytes32 configId = keccak256("YOUR_PROTOCOL_CONFIG");
    
    address[] memory recipients = new address[](3);
    recipients[0] = protocolTreasury;
    recipients[1] = userRewardsPool;
    recipients[2] = validatorTips;
    
    uint256[] memory shares = new uint256[](3);
    shares[0] = 40; // 40% to protocol
    shares[1] = 50; // 50% to users
    shares[2] = 10; // 10% to validators
    
    reflexRouter.configureRevenue(configId, recipients, shares);
}
```

## Plugin-Based Access

### Overview

Plugin-based integration uses lightweight contracts that hook into your existing DEX architecture. This is perfect for protocols that already have callback systems or want minimal changes to existing code.

### UniswapV2-Style Plugin

```solidity
pragma solidity ^0.8.19;

import "@reflex/contracts/ReflexAfterSwap.sol";

contract UniV2ReflexPlugin is ReflexAfterSwap {
    uint256 public constant MIN_THRESHOLD = 1e18;
    bytes32 public immutable CONFIG_ID;
    
    constructor(
        address _reflexRouter,
        address _pool,
        bytes32 _configId
    ) ReflexAfterSwap(_reflexRouter, _pool) {
        CONFIG_ID = _configId;
    }
    
    function afterSwap(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override onlyPool {
        uint256 swapAmount = amount0 > 0 ? amount0 : amount1;
        
        if (swapAmount >= MIN_THRESHOLD) {
            reflexRouter.triggerBackrun(
                bytes32(uint256(uint160(pool))),
                uint112(swapAmount / 20), // 5% of swap
                amount0 > 0,
                sender,
                CONFIG_ID
            );
        }
    }
}
```

### UniswapV3-Style Plugin

```solidity
pragma solidity ^0.8.19;

import "@reflex/contracts/ReflexAfterSwap.sol";

contract UniV3ReflexPlugin is ReflexAfterSwap {
    struct PluginConfig {
        uint256 minThreshold;
        uint256 backrunRatio; // Basis points
        bool enabled;
        mapping(address => bool) excludedUsers;
    }
    
    PluginConfig public config;
    
    constructor(
        address _reflexRouter,
        address _pool
    ) ReflexAfterSwap(_reflexRouter, _pool) {
        config.minThreshold = 1e18;
        config.backrunRatio = 500; // 5%
        config.enabled = true;
    }
    
    function afterSwap(
        address sender,
        uint256 amount0,
        uint256 amount1,
        bytes calldata data
    ) external override onlyPool {
        if (!config.enabled || config.excludedUsers[sender]) {
            return;
        }
        
        uint256 swapAmount = amount0 > 0 ? amount0 : amount1;
        
        if (swapAmount >= config.minThreshold) {
            uint256 backrunAmount = (swapAmount * config.backrunRatio) / 10000;
            
            reflexRouter.triggerBackrun(
                bytes32(uint256(uint160(pool))),
                uint112(backrunAmount),
                amount0 > 0,
                sender,
                bytes32(0) // Use default config
            );
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
    
    constructor(address _reflexRouter) {
        reflexRouter = _reflexRouter;
    }
    
    function createPoolWithMEV(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external returns (address pool, address plugin) {
        // Create pool
        pool = _createPool(tokenA, tokenB, fee);
        
        // Deploy plugin
        plugin = new UniV2ReflexPlugin(
            reflexRouter,
            pool,
            keccak256(abi.encodePacked("POOL_", pool))
        );
        
        // Configure pool to use plugin
        IYourPool(pool).setReflexPlugin(plugin);
        
        poolPlugins[pool] = plugin;
        
        emit PoolCreatedWithMEV(pool, plugin);
    }
}
```

## Deployment Guide

### 1. Deploy Plugin Contract

```typescript
// deploy-plugin.ts
import { ethers } from "hardhat";

async function deployPlugin() {
    const [deployer] = await ethers.getSigners();
    
    const Plugin = await ethers.getContractFactory("UniV2ReflexPlugin");
    const plugin = await Plugin.deploy(
        "0x742d35Cc6634C0532925a3b8D598C4B4B3A3A3A3", // Reflex Router
        "0xYourPoolAddress",
        ethers.id("YOUR_CONFIG_ID")
    );
    
    await plugin.waitForDeployment();
    
    console.log("Plugin deployed to:", await plugin.getAddress());
    return plugin;
}
```

### 2. Configure Revenue Sharing

```typescript
// configure-revenue.ts
async function configureRevenue() {
    const reflexRouter = await ethers.getContractAt(
        "ReflexRouter",
        "0x742d35Cc6634C0532925a3b8D598C4B4B3A3A3A3"
    );
    
    const configId = ethers.id("YOUR_CONFIG_ID");
    const recipients = [
        "0xProtocolTreasury",
        "0xUserRewards",
        "0xValidatorTips"
    ];
    const shares = [40, 50, 10]; // Percentages
    
    await reflexRouter.configureRevenue(configId, recipients, shares);
}
```

### 3. Integration Testing

```solidity
// Test your integration
contract PluginIntegrationTest {
    function testMEVCapture() public {
        // 1. Execute a large swap
        pool.swap(largeAmount, 0, user, "");
        
        // 2. Verify plugin was triggered
        assertEq(plugin.lastTriggerBlock(), block.number);
        
        // 3. Check profit distribution
        uint256 userBalance = token.balanceOf(user);
        assertGt(userBalance, initialBalance);
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

For SDK integration, see the [SDK Integration Guide](./sdk-integration).
For detailed examples, check out the [Integration Examples](./examples).
