// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "@cryptoalgebra/core/interfaces/IAlgebraFactory.sol";
import "../interfaces/IBasePluginV3Factory.sol";
import "./AlgebraBasePluginV3.sol";

/// @title Algebra Integral 1.2.2 default plugin factory
/// @notice This contract creates Algebra sliding fee plugins for Algebra liquidity pools
/// @dev This plugin factory can only be used for Algebra base pools
contract BasePluginV3Factory is IBasePluginV3Factory {
    /// @inheritdoc IBasePluginV2Factory
    bytes32 public constant override ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR =
        keccak256("ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR");

    /// @inheritdoc IBasePluginV2Factory
    address public immutable override algebraFactory;

    /// @inheritdoc IBasePluginV2Factory
    address public override farmingAddress;

    /// @inheritdoc IBasePluginV2Factory
    uint16 public override defaultBaseFee = 3000;

    address public reflexRouter;

    /// @notice Configuration ID for profit distribution used by plugins created by this factory
    bytes32 public reflexConfigId;

    /// @inheritdoc IBasePluginV2Factory
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
        reflexConfigId = _configId;
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

    /// @inheritdoc IBasePluginV2Factory
    function createPluginForExistingPool(address token0, address token1) external override returns (address) {
        IAlgebraFactory factory = IAlgebraFactory(algebraFactory);
        require(factory.hasRoleOrOwner(factory.POOLS_ADMINISTRATOR_ROLE(), msg.sender));

        address pool = factory.poolByPair(token0, token1);
        require(pool != address(0), "Pool not exist");

        return _createPlugin(pool);
    }

    function _createPlugin(address pool) internal returns (address) {
        require(pluginByPool[pool] == address(0), "Already created");
        AlgebraBasePluginV3 plugin =
            new AlgebraBasePluginV3(pool, algebraFactory, address(this), defaultBaseFee, reflexRouter, reflexConfigId);
        pluginByPool[pool] = address(plugin);
        return address(plugin);
    }

    /// @inheritdoc IBasePluginV2Factory
    function setFarmingAddress(address newFarmingAddress) external override onlyAdministrator {
        require(farmingAddress != newFarmingAddress);
        farmingAddress = newFarmingAddress;
        emit FarmingAddress(newFarmingAddress);
    }

    /// @inheritdoc IBasePluginV2Factory
    function setDefaultBaseFee(uint16 newDefaultBaseFee) external override onlyAdministrator {
        require(defaultBaseFee != newDefaultBaseFee);
        defaultBaseFee = newDefaultBaseFee;
        emit DefaultBaseFee(newDefaultBaseFee);
    }

    /// @inheritdoc IBasePluginV3Factory
    function setReflexRouter(address _reflexRouter) external onlyAdministrator {
        reflexRouter = _reflexRouter;
    }

    /// @notice Set the configuration ID for profit distribution
    /// @param _configId New configuration ID to use for plugins created by this factory
    function setConfigId(bytes32 _configId) external onlyAdministrator {
        reflexConfigId = _configId;
    }
}
