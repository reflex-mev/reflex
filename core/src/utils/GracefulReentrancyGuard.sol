// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

/**
 * @title GracefulReentrancyGuard
 * @notice A custom reentrancy guard that prevents reentrancy gracefully without reverting
 * @dev Unlike OpenZeppelin's ReentrancyGuard which reverts on reentrancy attempts,
 * this implementation allows functions to exit gracefully when reentrancy is detected
 */
abstract contract GracefulReentrancyGuard {
    // Reentrancy status constants
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    // Current reentrancy status
    uint256 private _status;

    /**
     * @notice Constructor sets initial status to NOT_ENTERED
     */
    constructor() {
        _status = _NOT_ENTERED;
    }

    /**
     * @notice Modifier that prevents reentrancy gracefully
     * @dev If reentrancy is detected, the function will return with default values
     * instead of reverting the entire transaction
     */
    modifier gracefulNonReentrant() {
        // Check if we're already in a call
        if (_status == _ENTERED) {
            // Gracefully exit without reverting
            return;
        }

        // Set status to entered
        _status = _ENTERED;

        // Execute the function
        _;

        // Reset status back to not entered
        _status = _NOT_ENTERED;
    }

    /**
     * @notice Check if a call is currently in progress (for internal use)
     * @return true if a call is in progress, false otherwise
     */
    function _isReentrant() internal view returns (bool) {
        return _status == _ENTERED;
    }

    /**
     * @notice Get current reentrancy status for debugging/testing
     * @dev Should only be used for testing purposes
     * @return Current reentrancy status (1 = not entered, 2 = entered)
     */
    function _getReentrancyStatus() internal view returns (uint256) {
        return _status;
    }
}
