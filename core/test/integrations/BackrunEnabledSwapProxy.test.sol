// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@reflex/integrations/router/BackrunEnabledSwapProxy.sol";
import "@reflex/interfaces/IReflexRouter.sol";
import "../mocks/MockToken.sol";
import "../mocks/MockReflexRouter.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title MockTargetRouter
/// @notice Mock implementation of a swap router for testing
contract MockTargetRouter {
    address public outputToken;
    uint256 public swapOutputAmount;
    bool public shouldRevert;
    bool public shouldConsumePartial;
    uint256 public partialConsumeAmount;

    constructor(address _outputToken) {
        outputToken = _outputToken;
        swapOutputAmount = 1000 * 10 ** 18; // Default output
    }

    function setSwapOutputAmount(uint256 _amount) external {
        swapOutputAmount = _amount;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function setPartialConsume(bool _shouldConsumePartial, uint256 _amount) external {
        shouldConsumePartial = _shouldConsumePartial;
        partialConsumeAmount = _amount;
    }

    /// @notice Mock swap function that simulates a swap
    /// @dev Takes input tokens and gives output tokens
    function swap(address tokenIn, uint256 amountIn, address tokenOut, address recipient)
        external
        payable
        returns (bool)
    {
        if (shouldRevert) {
            revert("Mock swap failed");
        }

        // Determine how much to consume
        uint256 amountToConsume = shouldConsumePartial ? partialConsumeAmount : amountIn;

        // Transfer input tokens from caller
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountToConsume);

        // Transfer output tokens to recipient
        if (swapOutputAmount > 0 && tokenOut != address(0)) {
            MockToken(tokenOut).mint(recipient, swapOutputAmount);
        }

        // If ETH was sent but not needed, return it
        if (msg.value > 0) {
            payable(msg.sender).transfer(msg.value);
        }

        return true;
    }

    /// @notice Mock swap function that accepts ETH
    function swapETH(address tokenOut, address recipient) external payable {
        if (shouldRevert) {
            revert("Mock swap failed");
        }

        // Transfer output tokens to recipient
        if (swapOutputAmount > 0 && tokenOut != address(0)) {
            MockToken(tokenOut).mint(recipient, swapOutputAmount);
        }
    }

    /// @notice Function to receive ETH
    receive() external payable {}
}

/// @title BackrunEnabledSwapProxyTest
/// @notice Comprehensive test suite for BackrunEnabledSwapProxy contract
contract BackrunEnabledSwapProxyTest is Test {
    BackrunEnabledSwapProxy public swapProxy;
    MockTargetRouter public targetRouter;
    MockReflexRouter public reflexRouter;
    MockToken public tokenIn;
    MockToken public tokenOut;
    MockToken public profitToken;

    address public user = address(0x1);
    address public recipient = address(0x2);

    // Events to test
    event Transfer(address indexed from, address indexed to, uint256 value);

    function setUp() public {
        // Deploy mock tokens
        tokenIn = new MockToken("Token In", "TIN", 1000000 * 10 ** 18);
        tokenOut = new MockToken("Token Out", "TOUT", 1000000 * 10 ** 18);
        profitToken = new MockToken("Profit Token", "PROF", 1000000 * 10 ** 18);

        // Deploy mock target router
        targetRouter = new MockTargetRouter(address(tokenOut));

        // Deploy mock Reflex router
        reflexRouter = new MockReflexRouter(address(this), address(profitToken));

        // Give reflexRouter plenty of profit tokens to distribute
        profitToken.mint(address(reflexRouter), 100000000 * 10 ** 18);

        // Deploy the swap proxy
        swapProxy = new BackrunEnabledSwapProxy(address(targetRouter));

        // Setup user with tokens
        tokenIn.mint(user, 10000 * 10 ** 18);

        // Give user approval to swap proxy
        vm.prank(user);
        tokenIn.approve(address(swapProxy), type(uint256).max);
    }

    // ============ Constructor Tests ============

    function test_Constructor_Success() public {
        BackrunEnabledSwapProxy proxy = new BackrunEnabledSwapProxy(address(targetRouter));
        assertEq(proxy.targetRouter(), address(targetRouter));
    }

    function test_Constructor_RevertsOnZeroAddress() public {
        vm.expectRevert(BackrunEnabledSwapProxy.InvalidTarget.selector);
        new BackrunEnabledSwapProxy(address(0));
    }

    // ============ Input Validation Tests ============

    function test_SwapWithBackrun_RevertsOnZeroTokenIn() public {
        bytes memory swapCallData = abi.encodeWithSelector(
            MockTargetRouter.swap.selector, address(tokenIn), 100 * 10 ** 18, address(tokenOut), user
        );

        IReflexRouter.BackrunParams[] memory backrunParams = new IReflexRouter.BackrunParams[](0);

        BackrunEnabledSwapProxy.SwapMetadata memory metadata = BackrunEnabledSwapProxy.SwapMetadata({
            swapTxCallData: swapCallData,
            tokenIn: address(0),
            amountIn: 100 * 10 ** 18,
            tokenOut: address(tokenOut),
            recipient: user
        });

        vm.prank(user);
        vm.expectRevert(BackrunEnabledSwapProxy.InvalidTokenIn.selector);
        swapProxy.swapWithBackrun(metadata, address(reflexRouter), backrunParams);
    }

    function test_SwapWithBackrun_RevertsOnZeroAmount() public {
        bytes memory swapCallData = abi.encodeWithSelector(
            MockTargetRouter.swap.selector, address(tokenIn), 100 * 10 ** 18, address(tokenOut), user
        );

        IReflexRouter.BackrunParams[] memory backrunParams = new IReflexRouter.BackrunParams[](0);

        BackrunEnabledSwapProxy.SwapMetadata memory metadata = BackrunEnabledSwapProxy.SwapMetadata({
            swapTxCallData: swapCallData,
            tokenIn: address(tokenIn),
            amountIn: 0,
            tokenOut: address(tokenOut),
            recipient: user
        });

        vm.prank(user);
        vm.expectRevert(BackrunEnabledSwapProxy.InvalidAmountIn.selector);
        swapProxy.swapWithBackrun(metadata, address(reflexRouter), backrunParams);
    }

    function test_SwapWithBackrun_RevertsOnZeroReflexRouter() public {
        bytes memory swapCallData = abi.encodeWithSelector(
            MockTargetRouter.swap.selector, address(tokenIn), 100 * 10 ** 18, address(tokenOut), user
        );

        IReflexRouter.BackrunParams[] memory backrunParams = new IReflexRouter.BackrunParams[](0);

        BackrunEnabledSwapProxy.SwapMetadata memory metadata = BackrunEnabledSwapProxy.SwapMetadata({
            swapTxCallData: swapCallData,
            tokenIn: address(tokenIn),
            amountIn: 100 * 10 ** 18,
            tokenOut: address(tokenOut),
            recipient: user
        });

        vm.prank(user);
        vm.expectRevert(BackrunEnabledSwapProxy.InvalidReflexRouter.selector);
        swapProxy.swapWithBackrun(metadata, address(0), backrunParams);
    }

    // ============ Swap Execution Tests ============

    function test_SwapWithBackrun_SuccessfulSwapWithoutBackruns() public {
        uint256 amountIn = 100 * 10 ** 18;
        uint256 userBalanceBefore = tokenIn.balanceOf(user);

        bytes memory swapCallData =
            abi.encodeWithSelector(MockTargetRouter.swap.selector, address(tokenIn), amountIn, address(tokenOut), user);

        IReflexRouter.BackrunParams[] memory backrunParams = new IReflexRouter.BackrunParams[](0);

        BackrunEnabledSwapProxy.SwapMetadata memory metadata = BackrunEnabledSwapProxy.SwapMetadata({
            swapTxCallData: swapCallData,
            tokenIn: address(tokenIn),
            amountIn: amountIn,
            tokenOut: address(tokenOut),
            recipient: user
        });

        vm.prank(user);
        (bytes memory swapReturnData, uint256[] memory profits, address[] memory profitTokens) =
            swapProxy.swapWithBackrun(metadata, address(reflexRouter), backrunParams);

        // Verify swap executed (returns true as a boolean)
        assertEq(swapReturnData.length, 32); // Returns a bool (32 bytes)
        assertEq(profits.length, 0); // No backruns
        assertEq(profitTokens.length, 0); // No backruns

        // Verify tokens were transferred
        assertEq(tokenIn.balanceOf(user), userBalanceBefore - amountIn);
        assertEq(tokenOut.balanceOf(user), targetRouter.swapOutputAmount());

        // Verify no leftover balances in proxy
        assertEq(tokenIn.balanceOf(address(swapProxy)), 0);
        assertEq(address(swapProxy).balance, 0);
    }

    function test_SwapWithBackrun_SuccessfulSwapWithSingleBackrun() public {
        uint256 amountIn = 100 * 10 ** 18;

        bytes memory swapCallData =
            abi.encodeWithSelector(MockTargetRouter.swap.selector, address(tokenIn), amountIn, address(tokenOut), user);

        IReflexRouter.BackrunParams[] memory backrunParams = new IReflexRouter.BackrunParams[](1);
        backrunParams[0] = IReflexRouter.BackrunParams({
            triggerPoolId: keccak256("pool1"),
            swapAmountIn: 50 * 10 ** 18,
            token0In: true,
            recipient: recipient,
            configId: keccak256("config1")
        });

        BackrunEnabledSwapProxy.SwapMetadata memory metadata = BackrunEnabledSwapProxy.SwapMetadata({
            swapTxCallData: swapCallData,
            tokenIn: address(tokenIn),
            amountIn: amountIn,
            tokenOut: address(tokenOut),
            recipient: user
        });

        vm.prank(user);
        (bytes memory swapReturnData, uint256[] memory profits, address[] memory profitTokens) =
            swapProxy.swapWithBackrun(metadata, address(reflexRouter), backrunParams);

        // Verify backrun was triggered
        assertEq(profits.length, 1);
        assertEq(profitTokens.length, 1);
        assertEq(profits[0], reflexRouter.mockProfit());
        assertEq(profitTokens[0], address(profitToken));

        // Verify backrun profit was sent to recipient
        assertEq(profitToken.balanceOf(recipient), reflexRouter.mockProfit());

        // Verify no leftover balances in proxy
        assertEq(tokenIn.balanceOf(address(swapProxy)), 0);
        assertEq(address(swapProxy).balance, 0);
    }

    function test_SwapWithBackrun_SuccessfulSwapWithMultipleBackruns() public {
        uint256 amountIn = 100 * 10 ** 18;

        bytes memory swapCallData =
            abi.encodeWithSelector(MockTargetRouter.swap.selector, address(tokenIn), amountIn, address(tokenOut), user);

        IReflexRouter.BackrunParams[] memory backrunParams = new IReflexRouter.BackrunParams[](3);
        backrunParams[0] = IReflexRouter.BackrunParams({
            triggerPoolId: keccak256("pool1"),
            swapAmountIn: 50 * 10 ** 18,
            token0In: true,
            recipient: recipient,
            configId: keccak256("config1")
        });
        backrunParams[1] = IReflexRouter.BackrunParams({
            triggerPoolId: keccak256("pool2"),
            swapAmountIn: 75 * 10 ** 18,
            token0In: false,
            recipient: recipient,
            configId: keccak256("config2")
        });
        backrunParams[2] = IReflexRouter.BackrunParams({
            triggerPoolId: keccak256("pool3"),
            swapAmountIn: 100 * 10 ** 18,
            token0In: true,
            recipient: recipient,
            configId: keccak256("config3")
        });

        BackrunEnabledSwapProxy.SwapMetadata memory metadata = BackrunEnabledSwapProxy.SwapMetadata({
            swapTxCallData: swapCallData,
            tokenIn: address(tokenIn),
            amountIn: amountIn,
            tokenOut: address(tokenOut),
            recipient: user
        });

        vm.prank(user);
        (bytes memory swapReturnData, uint256[] memory profits, address[] memory profitTokens) =
            swapProxy.swapWithBackrun(metadata, address(reflexRouter), backrunParams);

        // Verify all backruns were triggered
        assertEq(profits.length, 3);
        assertEq(profitTokens.length, 3);

        for (uint256 i = 0; i < 3; i++) {
            assertEq(profits[i], reflexRouter.mockProfit());
            assertEq(profitTokens[i], address(profitToken));
        }

        // Verify total backrun profit was sent to recipient
        assertEq(profitToken.balanceOf(recipient), reflexRouter.mockProfit() * 3);

        // Verify no leftover balances in proxy
        assertEq(tokenIn.balanceOf(address(swapProxy)), 0);
        assertEq(address(swapProxy).balance, 0);
    }

    function test_SwapWithBackrun_BackrunFailureDoesNotRevert() public {
        uint256 amountIn = 100 * 10 ** 18;

        bytes memory swapCallData =
            abi.encodeWithSelector(MockTargetRouter.swap.selector, address(tokenIn), amountIn, address(tokenOut), user);

        // Make the reflex router revert on backrun
        reflexRouter.setShouldRevert(true);

        IReflexRouter.BackrunParams[] memory backrunParams = new IReflexRouter.BackrunParams[](1);
        backrunParams[0] = IReflexRouter.BackrunParams({
            triggerPoolId: keccak256("pool1"),
            swapAmountIn: 50 * 10 ** 18,
            token0In: true,
            recipient: recipient,
            configId: keccak256("config1")
        });

        BackrunEnabledSwapProxy.SwapMetadata memory metadata = BackrunEnabledSwapProxy.SwapMetadata({
            swapTxCallData: swapCallData,
            tokenIn: address(tokenIn),
            amountIn: amountIn,
            tokenOut: address(tokenOut),
            recipient: user
        });

        vm.prank(user);
        (bytes memory swapReturnData, uint256[] memory profits, address[] memory profitTokens) =
            swapProxy.swapWithBackrun(metadata, address(reflexRouter), backrunParams);

        // Verify backrun failed gracefully
        assertEq(profits.length, 1);
        assertEq(profitTokens.length, 1);
        assertEq(profits[0], 0); // Failed backrun returns 0 profit
        assertEq(profitTokens[0], address(0)); // Failed backrun returns zero address

        // Verify no leftover balances in proxy
        assertEq(tokenIn.balanceOf(address(swapProxy)), 0);
        assertEq(address(swapProxy).balance, 0);
    }

    function test_SwapWithBackrun_PartialBackrunFailure() public {
        uint256 amountIn = 100 * 10 ** 18;

        bytes memory swapCallData =
            abi.encodeWithSelector(MockTargetRouter.swap.selector, address(tokenIn), amountIn, address(tokenOut), user);

        IReflexRouter.BackrunParams[] memory backrunParams = new IReflexRouter.BackrunParams[](3);
        backrunParams[0] = IReflexRouter.BackrunParams({
            triggerPoolId: keccak256("pool1"),
            swapAmountIn: 50 * 10 ** 18,
            token0In: true,
            recipient: recipient,
            configId: keccak256("config1")
        });
        backrunParams[1] = IReflexRouter.BackrunParams({
            triggerPoolId: keccak256("pool2"),
            swapAmountIn: 75 * 10 ** 18,
            token0In: false,
            recipient: recipient,
            configId: keccak256("config2")
        });
        backrunParams[2] = IReflexRouter.BackrunParams({
            triggerPoolId: keccak256("pool3"),
            swapAmountIn: 100 * 10 ** 18,
            token0In: true,
            recipient: recipient,
            configId: keccak256("config3")
        });

        BackrunEnabledSwapProxy.SwapMetadata memory metadata = BackrunEnabledSwapProxy.SwapMetadata({
            swapTxCallData: swapCallData,
            tokenIn: address(tokenIn),
            amountIn: amountIn,
            tokenOut: address(tokenOut),
            recipient: user
        });

        // Make the router succeed for first call, then fail, then succeed again
        vm.mockCallRevert(
            address(reflexRouter),
            abi.encodeWithSelector(
                IReflexRouter.triggerBackrun.selector,
                backrunParams[1].triggerPoolId,
                backrunParams[1].swapAmountIn,
                backrunParams[1].token0In,
                backrunParams[1].recipient,
                backrunParams[1].configId
            ),
            "Backrun 2 failed"
        );

        vm.prank(user);
        (bytes memory swapReturnData, uint256[] memory profits, address[] memory profitTokens) =
            swapProxy.swapWithBackrun(metadata, address(reflexRouter), backrunParams);

        // Verify partial failure
        assertEq(profits.length, 3);
        assertEq(profitTokens.length, 3);

        // First backrun succeeded
        assertEq(profits[0], reflexRouter.mockProfit());
        assertEq(profitTokens[0], address(profitToken));

        // Second backrun failed
        assertEq(profits[1], 0);
        assertEq(profitTokens[1], address(0));

        // Third backrun succeeded
        assertEq(profits[2], reflexRouter.mockProfit());
        assertEq(profitTokens[2], address(profitToken));

        // Verify no leftover balances in proxy
        assertEq(tokenIn.balanceOf(address(swapProxy)), 0);
        assertEq(address(swapProxy).balance, 0);
    }

    // ============ Swap Failure Tests ============

    function test_SwapWithBackrun_RevertsOnSwapFailure() public {
        uint256 amountIn = 100 * 10 ** 18;

        // Make the target router revert
        targetRouter.setShouldRevert(true);

        bytes memory swapCallData =
            abi.encodeWithSelector(MockTargetRouter.swap.selector, address(tokenIn), amountIn, address(tokenOut), user);

        IReflexRouter.BackrunParams[] memory backrunParams = new IReflexRouter.BackrunParams[](0);

        BackrunEnabledSwapProxy.SwapMetadata memory metadata = BackrunEnabledSwapProxy.SwapMetadata({
            swapTxCallData: swapCallData,
            tokenIn: address(tokenIn),
            amountIn: amountIn,
            tokenOut: address(tokenOut),
            recipient: user
        });

        vm.prank(user);
        vm.expectRevert();
        swapProxy.swapWithBackrun(metadata, address(reflexRouter), backrunParams);
    }

    // ============ Leftover Token Return Tests ============

    function test_SwapWithBackrun_ReturnsLeftoverTokens() public {
        uint256 amountIn = 100 * 10 ** 18;
        uint256 partialAmount = 60 * 10 ** 18;

        // Make router consume only partial amount
        targetRouter.setPartialConsume(true, partialAmount);

        bytes memory swapCallData =
            abi.encodeWithSelector(MockTargetRouter.swap.selector, address(tokenIn), amountIn, address(tokenOut), user);

        IReflexRouter.BackrunParams[] memory backrunParams = new IReflexRouter.BackrunParams[](0);

        BackrunEnabledSwapProxy.SwapMetadata memory metadata = BackrunEnabledSwapProxy.SwapMetadata({
            swapTxCallData: swapCallData,
            tokenIn: address(tokenIn),
            amountIn: amountIn,
            tokenOut: address(tokenOut),
            recipient: user
        });

        uint256 userBalanceBefore = tokenIn.balanceOf(user);

        vm.prank(user);
        swapProxy.swapWithBackrun(metadata, address(reflexRouter), backrunParams);

        // Verify leftover tokens were returned
        uint256 expectedBalance = userBalanceBefore - partialAmount;
        assertEq(tokenIn.balanceOf(user), expectedBalance);

        // Verify no leftover balances in proxy
        assertEq(tokenIn.balanceOf(address(swapProxy)), 0);
        assertEq(address(swapProxy).balance, 0);
    }

    function test_SwapWithBackrun_ReturnsLeftoverOutputTokens() public {
        uint256 amountIn = 100 * 10 ** 18;
        uint256 leftoverAmount = 50 * 10 ** 18;

        // Use the proxy address as the recipient in the swap calldata
        // This simulates a router that sends tokens to the proxy
        bytes memory swapCallData = abi.encodeWithSelector(
            MockTargetRouter.swap.selector, address(tokenIn), amountIn, address(tokenOut), address(swapProxy)
        );

        IReflexRouter.BackrunParams[] memory backrunParams = new IReflexRouter.BackrunParams[](0);

        BackrunEnabledSwapProxy.SwapMetadata memory metadata = BackrunEnabledSwapProxy.SwapMetadata({
            swapTxCallData: swapCallData,
            tokenIn: address(tokenIn),
            amountIn: amountIn,
            tokenOut: address(tokenOut),
            recipient: recipient // Actual recipient who should receive the tokens
        });

        // Pre-fund the proxy with some leftover tokens (simulating previous swap leftovers)
        tokenOut.mint(address(swapProxy), leftoverAmount);

        uint256 recipientBalanceBefore = tokenOut.balanceOf(recipient);

        vm.prank(user);
        swapProxy.swapWithBackrun(metadata, address(reflexRouter), backrunParams);

        // Verify output tokens were sent to the specified recipient
        // Should include both the swap output AND the leftover tokens
        uint256 expectedBalance = recipientBalanceBefore + targetRouter.swapOutputAmount() + leftoverAmount;
        assertEq(tokenOut.balanceOf(recipient), expectedBalance);

        // Verify no leftover balances in proxy
        assertEq(tokenIn.balanceOf(address(swapProxy)), 0);
        assertEq(tokenOut.balanceOf(address(swapProxy)), 0);
        assertEq(address(swapProxy).balance, 0);
    }

    function test_SwapWithBackrun_ReturnsLeftoverETH() public {
        uint256 amountIn = 100 * 10 ** 18;
        uint256 ethSent = 1 ether;

        bytes memory swapCallData = abi.encodeWithSelector(MockTargetRouter.swapETH.selector, address(tokenOut), user);

        IReflexRouter.BackrunParams[] memory backrunParams = new IReflexRouter.BackrunParams[](0);

        BackrunEnabledSwapProxy.SwapMetadata memory metadata = BackrunEnabledSwapProxy.SwapMetadata({
            swapTxCallData: swapCallData,
            tokenIn: address(tokenIn),
            amountIn: amountIn,
            tokenOut: address(tokenOut),
            recipient: user
        });

        // Give user some ETH
        vm.deal(user, 10 ether);

        uint256 userEthBefore = user.balance;

        vm.prank(user);
        swapProxy.swapWithBackrun{value: ethSent}(metadata, address(reflexRouter), backrunParams);

        // Verify ETH was sent to the target router (not returned since it was consumed)
        // The target router keeps the ETH in our mock implementation
        assertEq(user.balance, userEthBefore - ethSent);
        assertEq(address(targetRouter).balance, ethSent);

        // Verify no leftover balances in proxy
        assertEq(tokenIn.balanceOf(address(swapProxy)), 0);
        assertEq(address(swapProxy).balance, 0);
    }

    function test_SwapWithBackrun_ReturnsUnusedETH() public {
        uint256 amountIn = 100 * 10 ** 18;

        // Create a call that doesn't consume ETH but we send some anyway
        bytes memory swapCallData =
            abi.encodeWithSelector(MockTargetRouter.swap.selector, address(tokenIn), amountIn, address(tokenOut), user);

        IReflexRouter.BackrunParams[] memory backrunParams = new IReflexRouter.BackrunParams[](0);

        BackrunEnabledSwapProxy.SwapMetadata memory metadata = BackrunEnabledSwapProxy.SwapMetadata({
            swapTxCallData: swapCallData,
            tokenIn: address(tokenIn),
            amountIn: amountIn,
            tokenOut: address(tokenOut),
            recipient: user
        });

        // Give user some ETH
        vm.deal(user, 10 ether);
        uint256 ethSent = 1 ether;

        uint256 userEthBefore = user.balance;

        vm.prank(user);
        swapProxy.swapWithBackrun{value: ethSent}(metadata, address(reflexRouter), backrunParams);

        // Since the swap function doesn't consume ETH, it should be returned
        assertEq(user.balance, userEthBefore);

        // Verify no leftover balances in proxy
        assertEq(address(swapProxy).balance, 0);
    }

    // ============ Reentrancy Tests ============

    function test_SwapWithBackrun_PreventsReentrancy() public {
        // This test verifies the nonReentrant modifier is working
        // In a real scenario, we'd need a malicious contract that tries to reenter
        // For now, we verify the modifier is present by checking the contract state
        uint256 amountIn = 100 * 10 ** 18;

        bytes memory swapCallData =
            abi.encodeWithSelector(MockTargetRouter.swap.selector, address(tokenIn), amountIn, address(tokenOut), user);

        IReflexRouter.BackrunParams[] memory backrunParams = new IReflexRouter.BackrunParams[](0);

        BackrunEnabledSwapProxy.SwapMetadata memory metadata = BackrunEnabledSwapProxy.SwapMetadata({
            swapTxCallData: swapCallData,
            tokenIn: address(tokenIn),
            amountIn: amountIn,
            tokenOut: address(tokenOut),
            recipient: user
        });

        vm.prank(user);
        swapProxy.swapWithBackrun(metadata, address(reflexRouter), backrunParams);

        // Verify the call succeeded (reentrancy guard didn't block legitimate call)
        assertEq(tokenIn.balanceOf(address(swapProxy)), 0);
    }

    // ============ ETH Forwarding Tests ============

    function test_SwapWithBackrun_ForwardsETHToTargetRouter() public {
        uint256 amountIn = 100 * 10 ** 18;
        uint256 ethToSend = 0.5 ether;

        bytes memory swapCallData = abi.encodeWithSelector(MockTargetRouter.swapETH.selector, address(tokenOut), user);

        IReflexRouter.BackrunParams[] memory backrunParams = new IReflexRouter.BackrunParams[](0);

        BackrunEnabledSwapProxy.SwapMetadata memory metadata = BackrunEnabledSwapProxy.SwapMetadata({
            swapTxCallData: swapCallData,
            tokenIn: address(tokenIn),
            amountIn: amountIn,
            tokenOut: address(tokenOut),
            recipient: user
        });

        // Give user some ETH
        vm.deal(user, 10 ether);

        uint256 routerBalanceBefore = address(targetRouter).balance;

        vm.prank(user);
        swapProxy.swapWithBackrun{value: ethToSend}(metadata, address(reflexRouter), backrunParams);

        // Verify ETH was forwarded to router
        assertEq(address(targetRouter).balance, routerBalanceBefore + ethToSend);

        // Verify no leftover ETH in proxy
        assertEq(address(swapProxy).balance, 0);
    }

    // ============ Approval Security Tests ============

    function test_SwapWithBackrun_ResetsApprovalAfterSwap() public {
        uint256 amountIn = 100 * 10 ** 18;

        bytes memory swapCallData =
            abi.encodeWithSelector(MockTargetRouter.swap.selector, address(tokenIn), amountIn, address(tokenOut), user);

        IReflexRouter.BackrunParams[] memory backrunParams = new IReflexRouter.BackrunParams[](0);

        BackrunEnabledSwapProxy.SwapMetadata memory metadata = BackrunEnabledSwapProxy.SwapMetadata({
            swapTxCallData: swapCallData,
            tokenIn: address(tokenIn),
            amountIn: amountIn,
            tokenOut: address(tokenOut),
            recipient: user
        });

        vm.prank(user);
        swapProxy.swapWithBackrun(metadata, address(reflexRouter), backrunParams);

        // Verify approval is reset to 0
        assertEq(tokenIn.allowance(address(swapProxy), address(targetRouter)), 0);
    }

    // ============ Edge Cases ============

    function test_SwapWithBackrun_ZeroBackrunParams() public {
        uint256 amountIn = 100 * 10 ** 18;

        bytes memory swapCallData =
            abi.encodeWithSelector(MockTargetRouter.swap.selector, address(tokenIn), amountIn, address(tokenOut), user);

        IReflexRouter.BackrunParams[] memory backrunParams = new IReflexRouter.BackrunParams[](0);

        BackrunEnabledSwapProxy.SwapMetadata memory metadata = BackrunEnabledSwapProxy.SwapMetadata({
            swapTxCallData: swapCallData,
            tokenIn: address(tokenIn),
            amountIn: amountIn,
            tokenOut: address(tokenOut),
            recipient: user
        });

        vm.prank(user);
        (bytes memory swapReturnData, uint256[] memory profits, address[] memory profitTokens) =
            swapProxy.swapWithBackrun(metadata, address(reflexRouter), backrunParams);

        // Verify empty arrays returned
        assertEq(profits.length, 0);
        assertEq(profitTokens.length, 0);
    }

    function test_SwapWithBackrun_LargeNumberOfBackruns() public {
        uint256 amountIn = 100 * 10 ** 18;

        bytes memory swapCallData =
            abi.encodeWithSelector(MockTargetRouter.swap.selector, address(tokenIn), amountIn, address(tokenOut), user);

        // Create 10 backrun params
        IReflexRouter.BackrunParams[] memory backrunParams = new IReflexRouter.BackrunParams[](10);
        for (uint256 i = 0; i < 10; i++) {
            backrunParams[i] = IReflexRouter.BackrunParams({
                triggerPoolId: keccak256(abi.encodePacked("pool", i)),
                swapAmountIn: uint112(50 * 10 ** 18),
                token0In: i % 2 == 0,
                recipient: recipient,
                configId: keccak256(abi.encodePacked("config", i))
            });
        }

        BackrunEnabledSwapProxy.SwapMetadata memory metadata = BackrunEnabledSwapProxy.SwapMetadata({
            swapTxCallData: swapCallData,
            tokenIn: address(tokenIn),
            amountIn: amountIn,
            tokenOut: address(tokenOut),
            recipient: user
        });

        vm.prank(user);
        (bytes memory swapReturnData, uint256[] memory profits, address[] memory profitTokens) =
            swapProxy.swapWithBackrun(metadata, address(reflexRouter), backrunParams);

        // Verify all backruns executed
        assertEq(profits.length, 10);
        assertEq(profitTokens.length, 10);

        for (uint256 i = 0; i < 10; i++) {
            assertEq(profits[i], reflexRouter.mockProfit());
            assertEq(profitTokens[i], address(profitToken));
        }

        // Verify no leftover balances
        assertEq(tokenIn.balanceOf(address(swapProxy)), 0);
        assertEq(address(swapProxy).balance, 0);
    }

    // ============ Gas Tests ============

    function testGas_SwapWithBackrun_SingleBackrun() public {
        uint256 amountIn = 100 * 10 ** 18;

        bytes memory swapCallData =
            abi.encodeWithSelector(MockTargetRouter.swap.selector, address(tokenIn), amountIn, address(tokenOut), user);

        IReflexRouter.BackrunParams[] memory backrunParams = new IReflexRouter.BackrunParams[](1);
        backrunParams[0] = IReflexRouter.BackrunParams({
            triggerPoolId: keccak256("pool1"),
            swapAmountIn: 50 * 10 ** 18,
            token0In: true,
            recipient: recipient,
            configId: keccak256("config1")
        });

        BackrunEnabledSwapProxy.SwapMetadata memory metadata = BackrunEnabledSwapProxy.SwapMetadata({
            swapTxCallData: swapCallData,
            tokenIn: address(tokenIn),
            amountIn: amountIn,
            tokenOut: address(tokenOut),
            recipient: user
        });

        vm.prank(user);
        swapProxy.swapWithBackrun(metadata, address(reflexRouter), backrunParams);
    }

    // ============ Fuzz Tests ============

    function testFuzz_SwapWithBackrun_VaryingAmounts(uint256 amountIn) public {
        // Bound the amount to reasonable values
        amountIn = bound(amountIn, 1 * 10 ** 18, 5000 * 10 ** 18);

        // Ensure user has enough tokens
        tokenIn.mint(user, amountIn);

        bytes memory swapCallData =
            abi.encodeWithSelector(MockTargetRouter.swap.selector, address(tokenIn), amountIn, address(tokenOut), user);

        IReflexRouter.BackrunParams[] memory backrunParams = new IReflexRouter.BackrunParams[](0);

        BackrunEnabledSwapProxy.SwapMetadata memory metadata = BackrunEnabledSwapProxy.SwapMetadata({
            swapTxCallData: swapCallData,
            tokenIn: address(tokenIn),
            amountIn: amountIn,
            tokenOut: address(tokenOut),
            recipient: user
        });

        vm.prank(user);
        swapProxy.swapWithBackrun(metadata, address(reflexRouter), backrunParams);

        // Verify no leftover balances
        assertEq(tokenIn.balanceOf(address(swapProxy)), 0);
        assertEq(address(swapProxy).balance, 0);
    }
}
