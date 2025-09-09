// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "@cryptoalgebra/core/interfaces/IAlgebraFactory.sol";
import "@cryptoalgebra/plugin/base/AlgebraFeeConfiguration.sol";
import "@cryptoalgebra/plugin/interfaces/IBasePluginV1Factory.sol";
import "./AlgebraBasePluginV1.sol";

/// @title Algebra V1-based plugin factory
/// @notice This contract creates Algebra V1-based plugins with ReflexAfterSwap functionality for Algebra liquidity pools
/// @dev This plugin factory can only be used for Algebra base pools
contract BasePluginV1Factory is IBasePluginV1Factory {
    /// @inheritdoc IBasePluginV1Factory
    bytes32 public constant override ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR =
        keccak256("ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR");

    /// @inheritdoc IBasePluginV1Factory
    address public immutable override algebraFactory;

    /// @inheritdoc IBasePluginV1Factory
    address public override farmingAddress;

    /// @notice Internal storage for the default fee configuration
    AlgebraFeeConfiguration private _defaultFeeConfiguration;

    /// @notice The ReflexRouter address for plugins created by this factory
    address public reflexRouter;

    /// @notice Configuration ID for profit distribution used by plugins created by this factory
    bytes32 public configId;

    /// @inheritdoc IBasePluginV1Factory
    mapping(address poolAddress => address pluginAddress) public override pluginByPool;

    modifier onlyAdministrator() {
        require(
            IAlgebraFactory(algebraFactory).hasRoleOrOwner(ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR, msg.sender),
            "Only administrator"
        );
        _;
    }

    constructor(address _algebraFactory, address _reflexRouter, bytes32 _configId) {
        algebraFactory = _algebraFactory;
        reflexRouter = _reflexRouter;
        configId = _configId;

        // Set default fee configuration similar to V1
        _defaultFeeConfiguration = AlgebraFeeConfiguration({
            alpha1: 2900,
            alpha2: 12000,
            beta1: 360,
            beta2: 60000,
            gamma1: 59,
            gamma2: 8500,
            baseFee: 100
        });
    }

    /// @inheritdoc IAlgebraPluginFactory
    function beforeCreatePoolHook(address pool, address, address, address, address, bytes calldata)
        external
        override
        returns (address)
    {
        require(msg.sender == algebraFactory);
        return _createPlugin(pool);
    }

    /// @inheritdoc IAlgebraPluginFactory
    function afterCreatePoolHook(address, address, address) external view override {
        require(msg.sender == algebraFactory);
    }

    /// @inheritdoc IBasePluginV1Factory
    function createPluginForExistingPool(address token0, address token1) external override returns (address) {
        IAlgebraFactory factory = IAlgebraFactory(algebraFactory);
        require(factory.hasRoleOrOwner(factory.POOLS_ADMINISTRATOR_ROLE(), msg.sender));

        address pool = factory.poolByPair(token0, token1);
        require(pool != address(0), "Pool not exist");

        return _createPlugin(pool);
    }

    function _createPlugin(address pool) internal returns (address) {
        require(pluginByPool[pool] == address(0), "Already created");
        AlgebraBasePluginV1 plugin =
            new AlgebraBasePluginV1(pool, algebraFactory, address(this), _defaultFeeConfiguration, reflexRouter, configId);
        pluginByPool[pool] = address(plugin);
        return address(plugin);
    }

    /// @inheritdoc IBasePluginV1Factory
    function setFarmingAddress(address newFarmingAddress) external override onlyAdministrator {
        require(farmingAddress != newFarmingAddress);
        farmingAddress = newFarmingAddress;
        emit FarmingAddress(newFarmingAddress);
    }

    /// @inheritdoc IBasePluginV1Factory
    function setDefaultFeeConfiguration(AlgebraFeeConfiguration calldata newConfig)
        external
        override
        onlyAdministrator
    {
        // Validate the configuration
        require(newConfig.gamma1 != 0 && newConfig.gamma2 != 0, "Gamma values must be > 0");
        require(
            uint256(newConfig.alpha1) + uint256(newConfig.alpha2) + uint256(newConfig.baseFee) <= type(uint16).max,
            "Max fee too high"
        );

        _defaultFeeConfiguration = newConfig;
        emit DefaultFeeConfiguration(newConfig);
    }

    /// @inheritdoc IBasePluginV1Factory
    function defaultFeeConfiguration()
        external
        view
        override
        returns (uint16 alpha1, uint16 alpha2, uint32 beta1, uint32 beta2, uint16 gamma1, uint16 gamma2, uint16 baseFee)
    {
        AlgebraFeeConfiguration memory config = _defaultFeeConfiguration;
        return (config.alpha1, config.alpha2, config.beta1, config.beta2, config.gamma1, config.gamma2, config.baseFee);
    }

    /// @notice Get the default fee configuration as a struct
    /// @return The default fee configuration struct
    function getDefaultFeeConfigurationStruct() external view returns (AlgebraFeeConfiguration memory) {
        return _defaultFeeConfiguration;
    }

    /// @notice Set the ReflexRouter address for plugins created by this factory
    /// @param _reflexRouter The new ReflexRouter address
    function setReflexRouter(address _reflexRouter) external onlyAdministrator {
        reflexRouter = _reflexRouter;
    }

    /// @notice Set the configuration ID for profit distribution
    /// @param _configId New configuration ID to use for plugins created by this factory
    function setConfigId(bytes32 _configId) external onlyAdministrator {
        configId = _configId;
    }
}
