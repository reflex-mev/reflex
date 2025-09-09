// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IReflexRouter.sol";
import "../utils/GracefulReentrancyGuard.sol";

/// @title ReflexAfterSwap
/// @notice Abstract contract that integrates with Reflex Router for post-swap profit extraction
/// @dev Implements failsafe mechanisms to prevent router failures from affecting main swap operations
/// @dev Profit distribution is handled externally - this contract only extracts profits
abstract contract ReflexAfterSwap is GracefulReentrancyGuard {
    /// @notice Address of the Reflex router contract
    address router;

    /// @notice Address of the reflex admin (authorized controller)
    address reflexAdmin;

    /// @notice Configuration ID for profit distribution
    bytes32 configId;

    /// @notice Constructor to initialize the ReflexAfterSwap contract
    /// @param _router Address of the Reflex router contract
    /// @param _configId Configuration ID for profit distribution
    /// @dev Validates router address and fetches the admin from the router
    constructor(address _router, bytes32 _configId) {
        require(_router != address(0), "Invalid router address");
        router = _router;
        reflexAdmin = IReflexRouter(_router).getReflexAdmin();
        configId = _configId;
    }

    /// @notice Modifier to restrict access to reflex admin only
    /// @dev Reverts with "Not authorized" if caller is not the reflex admin
    modifier onlyReflexAdmin() {
        require(msg.sender == reflexAdmin, "Caller is not the reflex admin");
        _;
    }

    /// @notice Updates the Reflex router address and refreshes admin
    /// @param _router New router address to set
    /// @dev Only callable by current reflex admin, validates non-zero address, and updates admin from new router
    function setReflexRouter(address _router) external onlyReflexAdmin {
        require(_router != address(0), "Invalid router address");
        router = _router;
        address newAdmin = IReflexRouter(_router).getReflexAdmin();
        reflexAdmin = newAdmin;
    }

    /// @notice Returns the current router address
    /// @return The address of the current Reflex router contract
    function getRouter() public view returns (address) {
        return router;
    }

    /// @notice Get the current reflex admin address
    /// @return The address of the current reflex admin
    function getReflexAdmin() external view returns (address) {
        return reflexAdmin;
    }

    /// @notice Get the current configuration ID for profit distribution
    /// @return The current configuration ID
    function getConfigId() external view returns (bytes32) {
        return configId;
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
    function reflexAfterSwap(
        bytes32 triggerPoolId,
        int256 amount0Delta,
        int256 amount1Delta,
        bool zeroForOne,
        address recipient
    ) internal gracefulNonReentrant returns (uint256 profit, address profitToken) {
        uint256 swapAmountIn = uint256(amount0Delta > 0 ? amount0Delta : amount1Delta);

        // Failsafe: Use try-catch to prevent router failures from breaking the main swap
        try IReflexRouter(router).triggerBackrun(triggerPoolId, uint112(swapAmountIn), zeroForOne, recipient, configId)
        returns (uint256 backrunProfit, address backrunProfitToken) {
            return (backrunProfit, backrunProfitToken);
        } catch {
            // Router call failed, but don't revert the main transaction
            // This ensures the main swap can still complete successfully
        }

        return (0, address(0));
    }
}
