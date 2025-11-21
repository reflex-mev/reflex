// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import "@cryptoalgebra/core/libraries/Plugins.sol";
import "@cryptoalgebra/core/interfaces/plugin/IAlgebraPlugin.sol";
import "@cryptoalgebra/core/interfaces/IAlgebraFactory.sol";

import "@cryptoalgebra/plugin/plugins/DynamicFeePlugin.sol";
import "@cryptoalgebra/plugin/plugins/FarmingProxyPlugin.sol";
import "@cryptoalgebra/plugin/plugins/VolatilityOraclePlugin.sol";
import "../../ReflexAfterSwap.sol";

/// @title Algebra V1-based plugin with ReflexAfterSwap functionality
/// @notice This plugin extends AlgebraBasePluginV1 components with ReflexAfterSwap integration
/// @dev Inherits from V1 plugin components and adds ReflexAfterSwap functionality
contract AlgebraBasePluginV1 is DynamicFeePlugin, FarmingProxyPlugin, VolatilityOraclePlugin, ReflexAfterSwap {
    using Plugins for uint8;

    /// @inheritdoc IAlgebraPlugin
    uint8 public constant override defaultPluginConfig =
        uint8(Plugins.AFTER_INIT_FLAG | Plugins.BEFORE_SWAP_FLAG | Plugins.AFTER_SWAP_FLAG | Plugins.DYNAMIC_FEE);

    /// @notice Whether Reflex functionality is enabled
    bool public reflexEnabled = true;

    constructor(
        address _pool,
        address _factory,
        address _pluginFactory,
        AlgebraFeeConfiguration memory _config,
        address _reflexRouter,
        bytes32 _configId
    )
        AlgebraBasePlugin(_pool, _factory, _pluginFactory)
        DynamicFeePlugin(_config)
        ReflexAfterSwap(_reflexRouter, _configId)
    {}

    // ###### HOOKS ######

    function beforeInitialize(address, uint160) external override onlyPool returns (bytes4) {
        _updatePluginConfigInPool(defaultPluginConfig);
        return IAlgebraPlugin.beforeInitialize.selector;
    }

    function afterInitialize(address, uint160, int24 tick) external override onlyPool returns (bytes4) {
        _initialize_TWAP(tick);
        return IAlgebraPlugin.afterInitialize.selector;
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

    function beforeSwap(address sender, address, bool, int256, uint160, bool, bytes calldata)
        external
        override
        onlyPool
        returns (bytes4, uint24, uint24)
    {
        _writeTimepoint();
        uint88 volatilityAverage = _getAverageVolatilityLast();
        uint24 fee = _getCurrentFee(volatilityAverage);

        if (sender == getRouter()) {
            fee = 1;
        }
        return (IAlgebraPlugin.beforeSwap.selector, fee, 0);
    }

    /// @inheritdoc IAlgebraPlugin
    function afterSwap(
        address,
        address recipient,
        bool zeroToOne,
        int256,
        uint160,
        int256 amount0,
        int256 amount1,
        bytes calldata
    ) external override onlyPool returns (bytes4) {
        if (incentive != address(0)) {
            // If there's an active incentive, skip ReflexAfterSwap to avoid conflicts
            _updateVirtualPoolTick(zeroToOne);
        }

        // Only execute ReflexAfterSwap if enabled
        if (reflexEnabled) {
            bytes32 triggerPoolId = bytes32(uint256(uint160(pool)));
            _reflexAfterSwap(triggerPoolId, amount0, amount1, zeroToOne, recipient);
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

    function getCurrentFee() external view override returns (uint16 fee) {
        uint88 volatilityAverage = _getAverageVolatilityLast();
        fee = _getCurrentFee(volatilityAverage);
    }

    /// @notice Enable or disable Reflex functionality
    /// @param enabled Whether to enable Reflex functionality
    function setReflexEnabled(bool enabled) external {
        _authorize();
        reflexEnabled = enabled;
    }

    /// @inheritdoc ReflexAfterSwap
    function _onlyReflexAdmin() internal view override {
        _authorize();
    }
}
