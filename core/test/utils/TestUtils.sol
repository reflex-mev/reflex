// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "../mocks/MockToken.sol";
import "../mocks/MockReflexRouter.sol";
import "../mocks/MockAlgebraFactory.sol";
import "../mocks/MockAlgebraPool.sol";
import "../mocks/MockPool.sol";

/// @title TestUtils
/// @notice Shared utilities and mock contracts for testing
library TestUtils {
    /// @notice Creates a new MockToken instance
    /// @param name The name of the token
    /// @param symbol The symbol of the token
    /// @param initialSupply The initial supply to mint to the deployer
    /// @return The address of the deployed MockToken
    function createMockToken(string memory name, string memory symbol, uint256 initialSupply)
        internal
        returns (address)
    {
        MockToken token = new MockToken(name, symbol, initialSupply);
        return address(token);
    }

    /// @notice Creates a standard MockToken with default values
    /// @return The address of the deployed MockToken
    function createStandardMockToken() internal returns (address) {
        return createMockToken("MockToken", "MOCK", 1000000 * 10 ** 18);
    }

    /// @notice Creates a MockReflexRouter instance
    /// @param admin The admin address for the router
    /// @param profitToken The profit token address (can be zero)
    /// @return The address of the deployed MockReflexRouter
    function createMockReflexRouter(address admin, address profitToken) internal returns (address) {
        MockReflexRouter router = new MockReflexRouter(admin, profitToken);

        // Give the router some tokens to transfer if profitToken is specified
        if (profitToken != address(0)) {
            MockToken token = MockToken(profitToken);
            token.mint(address(router), 10000000 * 10 ** 18); // Mint a large amount for testing
        }

        return address(router);
    }

    /// @notice Creates a MockReflexRouter with default profit token
    /// @param admin The admin address for the router
    /// @return The address of the deployed MockReflexRouter
    function createMockReflexRouter(address admin) internal returns (address) {
        MockReflexRouter router = new MockReflexRouter(admin, address(0));
        return address(router);
    }

    /// @notice Creates a simple MockReflexRouter (no profit handling, like ComplexReflexRouter)
    /// @param admin The admin address for the router
    /// @return The address of the deployed MockReflexRouter
    function createSimpleMockReflexRouter(address admin) internal returns (address) {
        MockReflexRouter router = new MockReflexRouter(admin, address(0));
        // For simple mode, set profit to 0 to match ComplexReflexRouter behavior
        router.setMockProfit(0);
        return address(router);
    }

    /// @notice Creates a MockAlgebraFactory instance
    /// @return The address of the deployed MockAlgebraFactory
    function createMockAlgebraFactory() internal returns (address) {
        MockAlgebraFactory factory = new MockAlgebraFactory();
        return address(factory);
    }

    /// @notice Creates a MockAlgebraPool instance
    /// @param token0 The first token address
    /// @param token1 The second token address
    /// @return The address of the deployed MockAlgebraPool
    function createMockAlgebraPool(address token0, address token1) internal returns (address) {
        MockAlgebraPool pool = new MockAlgebraPool(token0, token1);
        return address(pool);
    }

    /// @notice Creates a MockPool instance (simple pool for basic testing)
    /// @param token0 The first token address
    /// @param token1 The second token address
    /// @return The address of the deployed MockPool
    function createMockPool(address token0, address token1) internal returns (address) {
        MockPool pool = new MockPool(token0, token1, address(0));
        return address(pool);
    }

    /// @notice Creates a MockPool instance with factory
    /// @param token0 The first token address
    /// @param token1 The second token address
    /// @param factory The factory address
    /// @return The address of the deployed MockPool
    function createMockPool(address token0, address token1, address factory) internal returns (address) {
        MockPool pool = new MockPool(token0, token1, factory);
        return address(pool);
    }
}
