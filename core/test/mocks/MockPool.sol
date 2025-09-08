// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MockPool
/// @notice Simple mock pool for basic testing scenarios
contract MockPool {
    address public token0;
    address public token1;
    address public plugin;
    address public factory;

    // State variables for globalState
    uint160 public price = 79228162514264337593543950336; // Default price (1:1 ratio)
    int24 public tick = 0;
    uint16 public lastFee = 3000;
    uint8 public pluginConfig = 0;
    uint16 public communityFee = 0;
    bool public unlocked = true;

    constructor(address _token0, address _token1, address _factory) {
        token0 = _token0;
        token1 = _token1;
        factory = _factory;
    }

    function setPlugin(address _plugin) external {
        plugin = _plugin;
    }

    function setFactory(address _factory) external {
        factory = _factory;
    }

    function globalState() external view returns (uint160, int24, uint16, uint8, uint16, bool) {
        return (price, tick, lastFee, pluginConfig, communityFee, unlocked);
    }

    function setGlobalState(
        uint160 _price,
        int24 _tick,
        uint16 _lastFee,
        uint8 _pluginConfig,
        uint16 _communityFee,
        bool _unlocked
    ) external {
        price = _price;
        tick = _tick;
        lastFee = _lastFee;
        pluginConfig = _pluginConfig;
        communityFee = _communityFee;
        unlocked = _unlocked;
    }

    function setPluginConfig(uint8 _pluginConfig) external {
        pluginConfig = _pluginConfig;
    }
}
