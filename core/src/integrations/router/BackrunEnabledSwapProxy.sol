// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import {IReflexRouter} from "../../interfaces/IReflexRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title BackrunEnabledSwapProxy
/// @notice Enables executing swaps on a target contract with integrated backrun functionality via Reflex Router
/// @dev This contract acts as a proxy that executes swaps on a target router and then triggers backrun operations
///      to capture MEV opportunities. It uses the ReentrancyGuard to prevent reentrancy attacks.

contract BackrunEnabledSwapProxy is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ============ Custom Errors ============

    /// @notice Thrown when the swap call to the target router fails
    /// @param returnData The error data returned from the failed call
    error SwapCallFailed(bytes returnData);

    /// @notice Thrown when an invalid target router address is provided (zero address)
    error InvalidTarget();

    /// @notice Thrown when an invalid Reflex router address is provided (zero address)
    error InvalidReflexRouter();

    /// @notice Thrown when an invalid token input address is provided (zero address)
    error InvalidTokenIn();

    /// @notice Thrown when an invalid amount (zero) is provided
    error InvalidAmountIn();

    /// @notice Thrown when ETH transfer to user fails
    error ETHTransferFailed();

    // ============ State Variables ============

    /// @notice The target router contract that will execute the actual swap
    /// @dev This is immutable and set at deployment time
    address public immutable targetRouter;

    // ============ Constructor ============

    /// @notice Constructor sets the targetRouter contract address
    /// @param _targetRouter The address of the targetRouter contract to delegate calls to
    /// @dev Reverts if _targetRouter is the zero address
    constructor(address _targetRouter) {
        if (_targetRouter == address(0)) revert InvalidTarget();
        targetRouter = _targetRouter;
    }

    struct SwapMetadata {
        bytes swapTxCallData;
        address tokenIn;
        uint256 amountIn;
        address tokenOut;
        address recipient;
    }

    // ============ External Functions ============

    /// @notice Executes a swap on the target router and then triggers backrun operations
    /// @dev This function is protected by the nonReentrant modifier to prevent reentrancy attacks
    /// @param swapMetadata Struct containing swap metadata (swapMetadata.swapTxCallData, swapMetadata.tokenIn, swapMetadata.amountIn, swapMetadata.tokenOut, swapMetadata.recipient)
    /// @param reflexRouter The address of the Reflex Router contract for backrun execution
    /// @param backrunParams Array of parameters for each backrun operation to execute
    /// @return swapReturnData The raw return data from the swap execution
    /// @return profits Array of profit amounts from each backrun operation (0 if failed)
    /// @return profitTokens Array of profit token addresses from each backrun (zero address if failed)
    function swapWithBackrun(
        SwapMetadata memory swapMetadata,
        address reflexRouter,
        IReflexRouter.BackrunParams[] calldata backrunParams
    )
        public
        payable
        nonReentrant
        returns (
            bytes memory swapReturnData,
            uint256[] memory profits,
            address[] memory profitTokens
        )
    {
        // ============ Input Validation ============

        // Validate that tokenIn is not the zero address
        if (swapMetadata.tokenIn == address(0)) revert InvalidTokenIn();

        // Validate that amountIn is not zero
        if (swapMetadata.amountIn == 0) revert InvalidAmountIn();

        // Validate that reflexRouter is not the zero address
        if (reflexRouter == address(0)) revert InvalidReflexRouter();

        // ============ Token Transfer ============

        // Transfer the input tokens from the caller to this contract
        IERC20(swapMetadata.tokenIn).safeTransferFrom(
            msg.sender,
            address(this),
            swapMetadata.amountIn
        );

        // ============ Swap Execution ============

        // Approve the target router to spend the exact amount needed for the swap
        IERC20(swapMetadata.tokenIn).forceApprove(
            targetRouter,
            swapMetadata.amountIn
        );

        // Execute the swap transaction on the target router
        // Forward any ETH sent with the transaction
        (bool success, bytes memory returnData) = targetRouter.call{
            value: msg.value
        }(swapMetadata.swapTxCallData);
        if (!success) revert SwapCallFailed(returnData);
        swapReturnData = returnData;

        // ============ Security Cleanup ============

        // Reset approval to 0 for security
        IERC20(swapMetadata.tokenIn).forceApprove(targetRouter, 0);

        // ============ Return Leftover Funds ============
        {
            // Check for leftover input tokens after swap
            uint256 tokenInBalanceAfter = IERC20(swapMetadata.tokenIn)
                .balanceOf(address(this));
            if (tokenInBalanceAfter > 0) {
                // Return any remaining input tokens to the caller
                // This can happen if the swap didn't use the full amount
                IERC20(swapMetadata.tokenIn).safeTransfer(
                    swapMetadata.recipient,
                    tokenInBalanceAfter
                );
            }

            // Check for leftover output tokens after swap
            uint256 tokenOutBalanceAfter = IERC20(swapMetadata.tokenOut)
                .balanceOf(address(this));
            if (tokenOutBalanceAfter > 0) {
                // Return any remaining output tokens to the caller
                IERC20(swapMetadata.tokenOut).safeTransfer(
                    swapMetadata.recipient,
                    tokenOutBalanceAfter
                );
            }

            // Check for leftover ETH after swap
            uint256 ethBalanceAfter = address(this).balance;
            if (ethBalanceAfter > 0) {
                // Return any remaining ETH to the caller
                // Using call instead of transfer to support contracts with custom receive functions
                (bool ethSuccess, ) = payable(swapMetadata.recipient).call{
                    value: ethBalanceAfter
                }("");
                if (!ethSuccess) revert ETHTransferFailed();
            }
        }

        // ============ Backrun Execution ============

        // Execute backrun operations via Reflex Router
        // Initialize arrays to store results from each backrun
        profits = new uint256[](backrunParams.length);
        profitTokens = new address[](backrunParams.length);

        // Iterate through all backrun parameters and execute each one
        for (uint256 i = 0; i < backrunParams.length; i++) {
            try
                IReflexRouter(reflexRouter).triggerBackrun(
                    backrunParams[i].triggerPoolId,
                    backrunParams[i].swapAmountIn,
                    backrunParams[i].token0In,
                    backrunParams[i].recipient,
                    backrunParams[i].configId
                )
            returns (uint256 profit, address profitToken) {
                // Store successful backrun results
                profits[i] = profit;
                profitTokens[i] = profitToken;
            } catch {
                // If backrun fails, zero profit and 0 address default are returned
                // This allows other backruns in the batch to continue executing
                // The caller can identify failed backruns by checking for zero values
            }
        }
    }
    /**
     * @notice Fallback function to receive Ether
     * @dev Allows the contract to receive ETH transfers
     */
    receive() external payable {}
}
