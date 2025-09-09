// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@reflex/interfaces/IReflexRouter.sol";
import "./MockToken.sol";

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

    TriggerBackrunCall[] public triggerBackrunCalls;
    address public reflexAdmin;
    MockToken public profitToken;
    uint256 public mockProfit;
    bool public shouldRevert;

    constructor(address _admin, address _profitToken) {
        reflexAdmin = _admin;
        if (_profitToken != address(0)) {
            profitToken = MockToken(_profitToken);
        }
        mockProfit = 1000 * 10 ** 18; // Default 1000 tokens profit
    }

    function getReflexAdmin() external view override returns (address) {
        return reflexAdmin;
    }

    function setMockProfit(uint256 _profit) external {
        mockProfit = _profit;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function setReflexAdmin(address _admin) external {
        reflexAdmin = _admin;
    }

    function setProfitToken(address _profitToken) external {
        profitToken = MockToken(_profitToken);
        // Mint tokens to this router so it can transfer them
        if (_profitToken != address(0)) {
            profitToken.mint(address(this), 10000000 * 10 ** 18);
        }
    }

    function triggerBackrun(
        bytes32 triggerPoolId,
        uint112 swapAmountIn,
        bool token0In,
        address recipient,
        bytes32 configId
    ) external returns (uint256 profit, address _profitToken) {
        if (shouldRevert) {
            revert("Mock router reverted");
        }

        triggerBackrunCalls.push(
            TriggerBackrunCall({
                triggerPoolId: triggerPoolId,
                swapAmountIn: swapAmountIn,
                token0In: token0In,
                recipient: recipient,
                configId: configId
            })
        );

        // Transfer the profit tokens to the recipient if configured
        if (mockProfit > 0 && address(profitToken) != address(0)) {
            profitToken.transfer(recipient, mockProfit);
        }

        return (mockProfit, address(profitToken));
    }

    function backrunedExecute(
        IReflexRouter.ExecuteParams calldata executeParams,
        IReflexRouter.BackrunParams[] calldata backrunParams
    )
        external
        payable
        override
        returns (bool success, bytes memory returnData, uint256[] memory profits, address[] memory profitTokens)
    {
        // Mock the call to target
        if (executeParams.target != address(0)) {
            (success, returnData) = executeParams.target.call{value: executeParams.value}(executeParams.callData);
        } else {
            success = true;
            returnData = "";
        }

        // Initialize arrays
        profits = new uint256[](backrunParams.length);
        profitTokens = new address[](backrunParams.length);

        // Call triggerBackrun for each backrun param
        for (uint256 i = 0; i < backrunParams.length; i++) {
            (profits[i], profitTokens[i]) = this.triggerBackrun(
                backrunParams[i].triggerPoolId,
                backrunParams[i].swapAmountIn,
                backrunParams[i].token0In,
                backrunParams[i].recipient,
                backrunParams[i].configId
            );
        }

        return (success, returnData, profits, profitTokens);
    }

    function getTriggerBackrunCallsLength() external view returns (uint256) {
        return triggerBackrunCalls.length;
    }

    function getTriggerBackrunCall(uint256 index) external view returns (TriggerBackrunCall memory) {
        return triggerBackrunCalls[index];
    }

    function clearTriggerBackrunCalls() external {
        delete triggerBackrunCalls;
    }
}
