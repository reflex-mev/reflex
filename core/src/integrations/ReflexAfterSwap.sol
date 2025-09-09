// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "../interfaces/IReflexRouter.sol";
import "../utils/GracefulReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title ReflexAfterSwap
/// @notice Abstract contract that integrates with Reflex Router for post-swap profit extraction
/// @dev Implements failsafe mechanisms to prevent router failures from affecting main swap operations
/// @dev Profit distribution is handled externally - this contract only extracts profits
abstract contract ReflexAfterSwap is GracefulReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Address of the Reflex router contract
    address router;

    /// @notice Address of the reflex admin (authorized controller)
    address reflexAdmin;

    /// @notice Event emitted when profit is extracted
    event ProfitExtracted(
        bytes32 indexed triggerPoolId, address indexed profitToken, uint256 amount, address indexed recipient
    );

    /// @notice Event emitted when router is updated
    event RouterUpdated(address indexed oldRouter, address indexed newRouter, address indexed newAdmin);

    /// @notice Constructor to initialize the ReflexAfterSwap contract
    /// @param _router Address of the Reflex router contract
    /// @dev Validates router address and fetches the admin from the router
    constructor(address _router) {
        require(_router != address(0), "Invalid router address");
        router = _router;
        reflexAdmin = IReflexRouter(_router).getReflexAdmin();
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
        address oldRouter = router;
        router = _router;
        address newAdmin = IReflexRouter(_router).getReflexAdmin();
        reflexAdmin = newAdmin;
        emit RouterUpdated(oldRouter, _router, newAdmin);
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

    /// @notice Main entry point for post-swap profit extraction via backrunning
    /// @param triggerPoolId Unique identifier for the pool that triggered the swap
    /// @param amount0Delta The change in token0 balance from the original swap
    /// @param amount1Delta The change in token1 balance from the original swap
    /// @param zeroForOne Direction of the original swap (true if token0 -> token1)
    /// @param recipient Address that should receive the extracted profits
    /// @return profit Amount of profit extracted
    /// @dev Internal function with reentrancy protection using graceful reentrancy guard
    /// @dev Uses try-catch for failsafe operation - router failures won't break main swap
    /// @dev All extracted profits are sent directly to the recipient
    function reflexAfterSwap(
        bytes32 triggerPoolId,
        int256 amount0Delta,
        int256 amount1Delta,
        bool zeroForOne,
        address recipient
    ) internal gracefulNonReentrant returns (uint256 profit) {
        uint256 swapAmountIn = uint256(amount0Delta > 0 ? amount0Delta : amount1Delta);

        // Failsafe: Use try-catch to prevent router failures from breaking the main swap
        try IReflexRouter(router).triggerBackrun(triggerPoolId, uint112(swapAmountIn), zeroForOne, address(this))
        returns (uint256 backrunProfit, address profitToken) {
            if (backrunProfit > 0 && profitToken != address(0)) {
                // Transfer all profit directly to recipient
                IERC20(profitToken).safeTransfer(recipient, backrunProfit);
                emit ProfitExtracted(triggerPoolId, profitToken, backrunProfit, recipient);
                return backrunProfit;
            }
        } catch {
            // Router call failed, but don't revert the main transaction
            // This ensures the main swap can still complete successfully
        }

        return 0;
    }
}
