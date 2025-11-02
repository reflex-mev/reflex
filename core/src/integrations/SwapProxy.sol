// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IReflexRouter} from "../interfaces/IReflexRouter.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title BackrunEnabledSwapProxy
/// @notice Enables executing swaps on a target contract with integrated backrun functionality via Reflex Router

contract BackrunEnabledSwapProxy is ReentrancyGuard {
    using SafeERC20 for IERC20;

    // Custom errors
    error InsufficientBalance(address token, uint256 required, uint256 actual);
    error InsufficientAllowance(address token, uint256 required, uint256 actual);
    error SwapCallFailed(bytes returnData);
    error LeftoverTokenBalance(address token, uint256 amount);
    error LeftoverETHBalance(uint256 amount);
    error InvalidTarget();
    error InvalidReflexRouter();
    error InvalidTokenIn();
    error InvalidAmountIn();
    error ETHTransferFailed();

    address public immutable target;

    /// @notice Constructor sets the target contract address
    /// @param _target The address of the target contract to delegate calls to
    constructor(address _target) {
        if (_target == address(0)) revert InvalidTarget();
        target = _target;
    }

    function swapWithbackrun(
        bytes calldata swapTxCallData,
        address tokenIn,
        uint256 amountIn,
        address reflexRouter,
        IReflexRouter.BackrunParams[] calldata backrunParams
    )
        public
        payable
        nonReentrant
        returns (bytes memory swapReturnData, uint256[] memory profits, address[] memory profitTokens)
    {
        // Validate input parameters
        if (tokenIn == address(0)) revert InvalidTokenIn();
        if (amountIn == 0) revert InvalidAmountIn();
        if (reflexRouter == address(0)) revert InvalidReflexRouter();

        uint256 balance = IERC20(tokenIn).balanceOf(msg.sender);
        if (balance < amountIn) {
            revert InsufficientBalance(tokenIn, amountIn, balance);
        }

        uint256 allowance = IERC20(tokenIn).allowance(msg.sender, address(this));
        if (allowance < amountIn) {
            revert InsufficientAllowance(tokenIn, amountIn, allowance);
        }

        // Transfer the input tokens from the caller to this contract
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        // Approve the target contract to spend tokens
        IERC20(tokenIn).forceApprove(target, 0);
        IERC20(tokenIn).forceApprove(target, amountIn);

        // Execute the swap tx on the target contract
        (bool success, bytes memory returnData) = target.call{value: msg.value}(swapTxCallData);
        if (!success) revert SwapCallFailed(returnData);
        swapReturnData = returnData;

        // Reset approval to 0 for security (protection against approval race conditions)
        IERC20(tokenIn).forceApprove(target, 0);

        // After swap, return any leftover tokens/ETH to the user
        uint256 tokenBalanceAfter = IERC20(tokenIn).balanceOf(address(this));
        if (tokenBalanceAfter > 0) {
            // Transfer any remaining tokens back to the user
            IERC20(tokenIn).safeTransfer(msg.sender, tokenBalanceAfter);
        }

        uint256 ethBalanceAfter = address(this).balance;
        if (ethBalanceAfter > 0) {
            // Transfer any remaining ETH back to the user using call instead of transfer
            (bool ethSuccess,) = payable(msg.sender).call{value: ethBalanceAfter}("");
            if (!ethSuccess) revert ETHTransferFailed();
        }

        // Sanity checks to ensure no leftover balances
        uint256 finalTokenBalance = IERC20(tokenIn).balanceOf(address(this));
        if (finalTokenBalance != 0) {
            revert LeftoverTokenBalance(tokenIn, finalTokenBalance);
        }

        uint256 finalETHBalance = address(this).balance;
        if (finalETHBalance != 0) {
            revert LeftoverETHBalance(finalETHBalance);
        }

        // Execute backrun operations via Reflex Router
        profits = new uint256[](backrunParams.length);
        profitTokens = new address[](backrunParams.length);
        for (uint256 i = 0; i < backrunParams.length; i++) {
            try IReflexRouter(reflexRouter).triggerBackrun(
                backrunParams[i].triggerPoolId,
                backrunParams[i].swapAmountIn,
                backrunParams[i].token0In,
                backrunParams[i].recipient,
                backrunParams[i].configId
            ) returns (uint256 profit, address profitToken) {
                profits[i] = profit;
                profitTokens[i] = profitToken;
            } catch {
                // If backrun fails, set profit to 0 and token to zero address
                // This allows other backruns to continue executing
                profits[i] = 0;
                profitTokens[i] = address(0);
            }
        }
    }
}
