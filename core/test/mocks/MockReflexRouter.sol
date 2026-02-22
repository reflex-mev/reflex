// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "../../src/interfaces/IReflexRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title MockReflexRouter
/// @notice Mock implementation of IReflexRouter for testing
contract MockReflexRouter is IReflexRouter {
    struct TriggerBackrunCall {
        bytes32 triggerPoolId;
        uint112 swapAmountIn;
        bool token0In;
        address recipient;
        bytes32 configId;
    }

    address public admin;
    address public profitToken;
    uint256 public mockProfit;
    uint256 public mockLpShare;
    bool public shouldRevert;

    TriggerBackrunCall[] public triggerBackrunCalls;

    constructor(address _admin, address _profitToken) {
        admin = _admin;
        profitToken = _profitToken;
        mockProfit = 1000 * 10 ** 18;
    }

    function setMockProfit(uint256 _profit) external {
        mockProfit = _profit;
    }

    /// @notice Set LP share amount — sent to msg.sender (the hook) instead of recipient
    function setMockLpShare(uint256 _lpShare) external {
        mockLpShare = _lpShare;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function setProfitToken(address _profitToken) external {
        profitToken = _profitToken;
    }

    function getTriggerBackrunCallsLength() external view returns (uint256) {
        return triggerBackrunCalls.length;
    }

    function getTriggerBackrunCall(uint256 index) external view returns (TriggerBackrunCall memory) {
        return triggerBackrunCalls[index];
    }

    function triggerBackrun(
        bytes32 triggerPoolId,
        uint112 swapAmountIn,
        bool token0In,
        address recipient,
        bytes32 configId
    ) external override returns (uint256 profit, address _profitToken) {
        if (shouldRevert) revert("MockReflexRouter: forced revert");

        triggerBackrunCalls.push(
            TriggerBackrunCall({
                triggerPoolId: triggerPoolId,
                swapAmountIn: swapAmountIn,
                token0In: token0In,
                recipient: recipient,
                configId: configId
            })
        );

        profit = mockProfit;
        _profitToken = profitToken;

        if (profit > 0 && profitToken != address(0)) {
            IERC20(profitToken).transfer(recipient, profit);
        }

        // Send LP share to caller (hook) if configured
        if (mockLpShare > 0 && profitToken != address(0)) {
            IERC20(profitToken).transfer(msg.sender, mockLpShare);
        }
    }

    function backrunedExecute(ExecuteParams calldata, BackrunParams[] calldata backrunParams)
        external
        payable
        override
        returns (bool success, bytes memory returnData, uint256[] memory profits, address[] memory profitTokens)
    {
        if (shouldRevert) revert("MockReflexRouter: forced revert");

        success = true;
        returnData = "";
        profits = new uint256[](backrunParams.length);
        profitTokens = new address[](backrunParams.length);

        for (uint256 i = 0; i < backrunParams.length; i++) {
            profits[i] = mockProfit;
            profitTokens[i] = profitToken;
        }
    }

    function getReflexAdmin() external view override returns (address) {
        return admin;
    }
}
