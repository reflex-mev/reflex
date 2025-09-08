// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MockAlgebraPool
/// @notice Mock implementation of Algebra pool for testing
contract MockAlgebraPool {
    address public plugin;
    address public token0;
    address public token1;
    uint160 public sqrtPriceX96;
    int24 public tick;
    uint16 public fee;
    uint8 public pluginConfig;
    uint160 public feeGrowthGlobal0X128;
    uint160 public feeGrowthGlobal1X128;

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
        sqrtPriceX96 = 79228162514264337593543950336; // sqrt(1) * 2^96
        tick = 0;
        fee = 3000;
    }

    function setPlugin(address _plugin) external {
        plugin = _plugin;
    }

    function setPluginConfig(uint8 newPluginConfig) external {
        pluginConfig = newPluginConfig;
    }

    function globalState() external view returns (uint160, int24, uint16, uint8, uint160, uint160) {
        return (sqrtPriceX96, tick, fee, pluginConfig, feeGrowthGlobal0X128, feeGrowthGlobal1X128);
    }

    function updateTick(int24 newTick) external {
        tick = newTick;
    }

    function updateFee(uint16 newFee) external {
        fee = newFee;
    }
}
