// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "../../interfaces/IReflexRouter.sol";

/// @title ReflexAfterSwap
/// @notice Abstract contract that integrates with Reflex Router for post-swap profit extraction
/// @dev Implements failsafe mechanisms to prevent router failures from affecting main swap operations
/// @dev Profit distribution is handled externally - this contract only extracts profits
abstract contract ReflexAfterSwap {
    // ========== Events ==========

    /// @notice Emitted when the Reflex router address is updated
    /// @param oldRouter The address of the previous router contract
    /// @param newRouter The address of the new router contract
    event ReflexRouterUpdated(address oldRouter, address newRouter);

    /// @notice Emitted when the Reflex configuration ID is updated
    /// @param oldConfigId The previous configuration ID
    /// @param newConfigId The new configuration ID
    event ReflexConfigIdUpdated(bytes32 oldConfigId, bytes32 newConfigId);

    /// @notice Emitted when a global fee discount is set or removed
    /// @param user The address receiving (or losing) the discount
    /// @param discount Whether the discount is active
    event GlobalFeeDiscountSet(address indexed user, bool discount);

    /// @notice Emitted when a pool-specific fee discount is set or removed
    /// @param poolId The pool ID the discount applies to
    /// @param user The address receiving (or losing) the discount
    /// @param discount Whether the discount is active
    event PoolFeeDiscountSet(bytes32 indexed poolId, address indexed user, bool discount);

    // ========== State Variables ==========

    /// @notice Address of the Reflex router contract
    address reflexRouter;

    /// @notice Configuration ID for profit distribution
    bytes32 reflexConfigId;

    /// @notice Global fee discounts — address gets 100% fee discount on all pools
    mapping(address => bool) public globalFeeDiscount;

    /// @notice Per-pool fee discounts — address gets 100% fee discount on a specific pool
    mapping(bytes32 => mapping(address => bool)) public poolFeeDiscount;

    /// @notice Constructor to initialize the ReflexAfterSwap contract
    /// @param _router Address of the Reflex router contract
    /// @param _configId Configuration ID for profit distribution
    /// @dev Validates router address and fetches the admin from the router
    constructor(address _router, bytes32 _configId) {
        require(_router != address(0), "Invalid router address");
        reflexRouter = _router;
        reflexConfigId = _configId;
        globalFeeDiscount[_router] = true;
    }

    /// @notice Internal function that must be implemented by child contract to enforce admin access control
    function _onlyReflexAdmin() internal view virtual;

    /// @notice Updates the Reflex router address and refreshes admin
    /// @param _router New router address to set
    /// @dev Only callable by current reflex admin, validates non-zero address, and updates admin from new router
    function setReflexRouter(address _router) external {
        _onlyReflexAdmin();
        require(_router != address(0), "Invalid router address");
        address oldRouter = reflexRouter;
        globalFeeDiscount[oldRouter] = false;
        reflexRouter = _router;
        globalFeeDiscount[_router] = true;
        emit ReflexRouterUpdated(oldRouter, _router);
    }

    /// @notice Returns the current router address
    /// @return The address of the current Reflex router contract
    function getRouter() public view returns (address) {
        return reflexRouter;
    }

    /// @notice Get the current configuration ID for profit distribution
    /// @return The current configuration ID
    function getConfigId() external view returns (bytes32) {
        return reflexConfigId;
    }

    /// @notice Updates the configuration ID for profit distribution
    /// @param _configId New configuration ID to set
    /// @dev Only callable by current reflex admin
    function setReflexConfigId(bytes32 _configId) external {
        _onlyReflexAdmin();
        bytes32 oldConfigId = reflexConfigId;
        reflexConfigId = _configId;
        emit ReflexConfigIdUpdated(oldConfigId, _configId);
    }

    /// @notice Sets or removes a global fee discount for an address (applies to all pools)
    /// @param user The address to set the discount for
    /// @param discount Whether the discount is active
    function setGlobalFeeDiscount(address user, bool discount) external {
        _onlyReflexAdmin();
        globalFeeDiscount[user] = discount;
        emit GlobalFeeDiscountSet(user, discount);
    }

    /// @notice Sets or removes a pool-specific fee discount for an address
    /// @param poolId The pool ID the discount applies to
    /// @param user The address to set the discount for
    /// @param discount Whether the discount is active
    function setPoolFeeDiscount(bytes32 poolId, address user, bool discount) external {
        _onlyReflexAdmin();
        poolFeeDiscount[poolId][user] = discount;
        emit PoolFeeDiscountSet(poolId, user, discount);
    }

    /// @notice Checks if an address has a fee discount for a given pool
    /// @dev Checks pool-specific first, then global; checks sender first, then tx.origin
    /// @param poolId The pool ID to check
    /// @param sender The sender address (e.g. router contract calling poolManager.swap)
    /// @return True if the address has a fee discount
    function _hasDiscount(bytes32 poolId, address sender) internal view returns (bool) {
        return poolFeeDiscount[poolId][sender]
            || globalFeeDiscount[sender]
            || poolFeeDiscount[poolId][tx.origin]
            || globalFeeDiscount[tx.origin];
    }

    /// @notice Main entry point for post-swap profit extraction via backrunning
    /// @param triggerPoolId Unique identifier for the pool that triggered the swap
    /// @param amount0Delta The change in token0 balance from the original swap
    /// @param amount1Delta The change in token1 balance from the original swap
    /// @param zeroForOne Direction of the original swap (true if token0 -> token1)
    /// @param recipient Address that should receive the extracted profits
    /// @return profit Amount of profit extracted
    /// @return profitToken Address of the token in which profit was extracted
    /// @dev Internal function with reentrancy protection using graceful reentrancy guard
    /// @dev Uses try-catch for failsafe operation - router failures won't break main swap
    /// @dev Profit distribution is handled externally - this contract only extracts profits
    function _reflexAfterSwap(
        bytes32 triggerPoolId,
        int256 amount0Delta,
        int256 amount1Delta,
        bool zeroForOne,
        address recipient
    ) internal returns (uint256 profit, address profitToken) {
        uint256 swapAmountIn = uint256(amount0Delta > 0 ? amount0Delta : amount1Delta);
        return _reflexAfterSwap(triggerPoolId, swapAmountIn, zeroForOne, recipient);
    }

    /// @notice Overload that accepts amountIn directly for protocols where the caller
    ///         computes the input amount (e.g. Uniswap V4 where negative delta = amount in)
    /// @param triggerPoolId Unique identifier for the pool that triggered the swap
    /// @param amountIn The input amount of the original swap
    /// @param zeroForOne Direction of the original swap (true if token0 -> token1)
    /// @param recipient Address that should receive the extracted profits
    /// @return profit Amount of profit extracted
    /// @return profitToken Address of the token in which profit was extracted
    function _reflexAfterSwap(bytes32 triggerPoolId, uint256 amountIn, bool zeroForOne, address recipient)
        internal
        returns (uint256 profit, address profitToken)
    {
        // Failsafe: Use try-catch to prevent router failures from breaking the main swap
        try IReflexRouter(reflexRouter)
            .triggerBackrun(triggerPoolId, uint112(amountIn), zeroForOne, recipient, reflexConfigId) returns (
            uint256 backrunProfit, address backrunProfitToken
        ) {
            return (backrunProfit, backrunProfitToken);
        } catch {
            // Router call failed, but don't revert the main transaction
            // This ensures the main swap can still complete successfully
        }

        return (0, address(0));
    }
}
