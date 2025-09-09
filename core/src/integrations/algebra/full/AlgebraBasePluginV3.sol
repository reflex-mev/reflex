// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@cryptoalgebra/core/libraries/Plugins.sol";
import "@cryptoalgebra/core/interfaces/plugin/IAlgebraPlugin.sol";

import "@cryptoalgebra/plugin/plugins/FarmingProxyPlugin.sol";
import "@cryptoalgebra/plugin/plugins/SlidingFeePlugin.sol";
import "@cryptoalgebra/plugin/plugins/VolatilityOraclePlugin.sol";
import "../../ReflexAfterSwap.sol";

/// @title Algebra Integral 1.2.2 sliding fee plugin
contract AlgebraBasePluginV3 is SlidingFeePlugin, FarmingProxyPlugin, VolatilityOraclePlugin, ReflexAfterSwap {
    using Plugins for uint8;

    /// @notice Boolean flag to enable/disable ReflexAfterSwap functionality at plugin level
    bool public reflexEnabled;

    bool private initialized;

    /// @inheritdoc IAlgebraPlugin
    uint8 public constant override defaultPluginConfig =
        uint8(Plugins.AFTER_INIT_FLAG | Plugins.BEFORE_SWAP_FLAG | Plugins.AFTER_SWAP_FLAG | Plugins.DYNAMIC_FEE);

    constructor(
        address _pool,
        address _factory,
        address _pluginFactory,
        uint16 _baseFee,
        address _reflexRouter,
        bytes32 _configId
    )
        AlgebraBasePlugin(_pool, _factory, _pluginFactory)
        SlidingFeePlugin(_baseFee)
        ReflexAfterSwap(_reflexRouter, _configId)
    {
        reflexEnabled = true; // Enable reflex functionality by default
    }

    // ###### REFLEX CONTROL ######

    /// @notice Enable or disable ReflexAfterSwap functionality
    /// @param _enabled True to enable, false to disable
    /// @dev Only callable by addresses with ALGEBRA_BASE_PLUGIN_MANAGER role
    function setReflexEnabled(bool _enabled) external {
        _authorize();
        reflexEnabled = _enabled;
    }

    /// @notice Check if ReflexAfterSwap functionality is currently enabled
    /// @return True if enabled, false if disabled
    function isReflexEnabled() external view returns (bool) {
        return reflexEnabled;
    }

    // ###### HOOKS ######

    function beforeInitialize(address, uint160) external override onlyPool returns (bytes4) {
        _updatePluginConfigInPool(defaultPluginConfig);
        return IAlgebraPlugin.beforeInitialize.selector;
    }

    function afterInitialize(address, uint160, int24 tick) external override onlyPool returns (bytes4) {
        _initialize_TWAP(tick);

        return IAlgebraPlugin.afterInitialize.selector;
    }

    function initializePlugin() external {
        if (initialized) {
            return;
        }
        initialized = true;
        (, int24 tick,,) = _getPoolState();
        _updatePluginConfigInPool(defaultPluginConfig);
        _initialize_TWAP(tick);
    }

    /// @dev unused
    function beforeModifyPosition(address, address, int24, int24, int128, bytes calldata)
        external
        override
        onlyPool
        returns (bytes4, uint24)
    {
        _updatePluginConfigInPool(defaultPluginConfig); // should not be called, reset config
        return (IAlgebraPlugin.beforeModifyPosition.selector, 0);
    }

    /// @dev unused
    function afterModifyPosition(address, address, int24, int24, int128, uint256, uint256, bytes calldata)
        external
        override
        onlyPool
        returns (bytes4)
    {
        _updatePluginConfigInPool(defaultPluginConfig); // should not be called, reset config
        return IAlgebraPlugin.afterModifyPosition.selector;
    }

    function beforeSwap(address sender, address, bool zeroToOne, int256, uint160, bool, bytes calldata)
        external
        override
        onlyPool
        returns (bytes4, uint24, uint24)
    {
        (, int24 currentTick,,) = _getPoolState();
        int24 lastTick = _getLastTick();
        uint16 newFee = _getFeeAndUpdateFactors(zeroToOne, currentTick, lastTick);
        if (sender == getRouter()) {
            newFee = 1;
        }
        _writeTimepoint();
        return (IAlgebraPlugin.beforeSwap.selector, newFee, 0);
    }

    function afterSwap(
        address,
        address recipient,
        bool zeroToOne,
        int256,
        uint160,
        int256 amount0Out,
        int256 amount1Out,
        bytes calldata
    ) external override onlyPool returns (bytes4) {
        _updateVirtualPoolTick(zeroToOne);

        // Only trigger ReflexAfterSwap if it's enabled
        if (reflexEnabled) {
            bytes32 triggerPoolId = bytes32(uint256(uint160(msg.sender)));
            reflexAfterSwap(triggerPoolId, amount0Out, amount1Out, zeroToOne, recipient);
        }

        return IAlgebraPlugin.afterSwap.selector;
    }

    /// @dev unused
    function beforeFlash(address, address, uint256, uint256, bytes calldata)
        external
        override
        onlyPool
        returns (bytes4)
    {
        _updatePluginConfigInPool(defaultPluginConfig); // should not be called, reset config
        return IAlgebraPlugin.beforeFlash.selector;
    }

    /// @dev unused
    function afterFlash(address, address, uint256, uint256, uint256, uint256, bytes calldata)
        external
        override
        onlyPool
        returns (bytes4)
    {
        _updatePluginConfigInPool(defaultPluginConfig); // should not be called, reset config
        return IAlgebraPlugin.afterFlash.selector;
    }
}
