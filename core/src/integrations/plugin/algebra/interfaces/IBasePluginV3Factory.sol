// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "@cryptoalgebra/plugin/interfaces/IBasePluginV2Factory.sol";

interface IBasePluginV3Factory is IBasePluginV2Factory {
    /// @notice The Reflex router address used for ReflexAfterSwap functionality
    function reflexRouter() external view returns (address);

    /// @notice Sets the Reflex router address
    /// @param _reflexRouter The new Reflex router address
    function setReflexRouter(address _reflexRouter) external;
}
