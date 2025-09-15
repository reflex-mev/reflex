// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@cryptoalgebra/core/interfaces/plugin/IAlgebraPlugin.sol";
import "@cryptoalgebra/core/libraries/Plugins.sol";
import "../ReflexAfterSwap.sol";

contract AlgebraPlugin is IAlgebraPlugin, ReflexAfterSwap {
    using Plugins for uint8;

    /// @inheritdoc IAlgebraPlugin
    uint8 public immutable override defaultPluginConfig;

    address public immutable pool;
    address public immutable owner;

    constructor(address _pool, address _reflexRouter, bytes32 _configId) ReflexAfterSwap(_reflexRouter, _configId) {
        pool = _pool;
        owner = msg.sender;
        defaultPluginConfig = uint8(Plugins.AFTER_SWAP_FLAG);
    }

    modifier onlyPool() {
        require(msg.sender == pool, "AlgebraPlugin: Caller is not the pool");
        _;
    }

    /// @inheritdoc IAlgebraPlugin
    function handlePluginFee(uint256, uint256) external view override onlyPool returns (bytes4) {
        return IAlgebraPlugin.handlePluginFee.selector;
    }

    function beforeInitialize(address, uint160) external view override onlyPool returns (bytes4) {
        return IAlgebraPlugin.beforeInitialize.selector;
    }

    function afterInitialize(address, uint160, int24) external view override onlyPool returns (bytes4) {
        return IAlgebraPlugin.afterInitialize.selector;
    }

    /// @dev unused
    function beforeModifyPosition(address, address, int24, int24, int128, bytes calldata)
        external
        view
        override
        onlyPool
        returns (bytes4, uint24)
    {
        return (IAlgebraPlugin.beforeModifyPosition.selector, 0);
    }

    /// @dev unused
    function afterModifyPosition(address, address, int24, int24, int128, uint256, uint256, bytes calldata)
        external
        view
        override
        onlyPool
        returns (bytes4)
    {
        return IAlgebraPlugin.afterModifyPosition.selector;
    }

    function beforeSwap(address, address, bool, int256, uint160, bool, bytes calldata)
        external
        view
        override
        onlyPool
        returns (bytes4, uint24, uint24)
    {
        return (IAlgebraPlugin.beforeSwap.selector, 0, 0);
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
        bytes32 triggerPoolId = bytes32(uint256(uint160(msg.sender)));
        reflexAfterSwap(triggerPoolId, amount0Out, amount1Out, zeroToOne, recipient);
        return IAlgebraPlugin.afterSwap.selector;
    }

    /// @dev unused
    function beforeFlash(address, address, uint256, uint256, bytes calldata)
        external
        view
        override
        onlyPool
        returns (bytes4)
    {
        return IAlgebraPlugin.beforeFlash.selector;
    }

    /// @dev unused
    function afterFlash(address, address, uint256, uint256, uint256, uint256, bytes calldata)
        external
        view
        override
        onlyPool
        returns (bytes4)
    {
        return IAlgebraPlugin.afterFlash.selector;
    }

    /// @inheritdoc ReflexAfterSwap
    function _onlyReflexAdmin() internal view override {
        require(msg.sender == owner, "AlgebraPlugin: Caller is not the owner");
    }
}
