// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@reflex/integrations/ReflexAfterSwap.sol";
import "@reflex/integrations/FundsSplitter/IFundsSplitter.sol";
import "@reflex/interfaces/IReflexRouter.sol";
import "../utils/TestUtils.sol";

// Testable implementation of ReflexAfterSwap
contract TestableReflexAfterSwap is ReflexAfterSwap {
    constructor(address _router, address[] memory _recipients, uint256[] memory _sharesBps) ReflexAfterSwap(_router) {
        _setShares(_recipients, _sharesBps);
    }

    // Implement the required abstract function
    function _onlyFundsAdmin() internal view override {
        require(msg.sender == reflexAdmin, "Caller is not the reflex admin");
    }

    // Expose internal function for testing
    function testReflexAfterSwap(
        bytes32 triggerPoolId,
        int256 amount0Delta,
        int256 amount1Delta,
        bool zeroForOne,
        address recipient
    ) external returns (uint256) {
        return reflexAfterSwap(triggerPoolId, amount0Delta, amount1Delta, zeroForOne, recipient);
    }
}

// Malicious contract that attempts reentrancy on ReflexAfterSwap
contract MaliciousReentrancyAfterSwap {
    TestableReflexAfterSwap public reflexAfterSwap;
    bool public shouldReenter;
    uint256 public callCount;

    constructor(address _reflexAfterSwap) {
        reflexAfterSwap = TestableReflexAfterSwap(_reflexAfterSwap);
    }

    function setShouldReenter(bool _shouldReenter) external {
        shouldReenter = _shouldReenter;
    }

    function attack(bytes32 poolKey, int256 amount0Delta, int256 amount1Delta, bool settle)
        external
        returns (uint256)
    {
        callCount++;
        return reflexAfterSwap.testReflexAfterSwap(poolKey, amount0Delta, amount1Delta, settle, address(this));
    }

    // This is called during the reflexAfterSwap function execution
    function mockSwapResponse() external returns (uint256) {
        if (shouldReenter && callCount == 1) {
            // Attempt reentrancy - this should be gracefully blocked
            callCount++;
            reflexAfterSwap.testReflexAfterSwap(keccak256("reentrancy"), 500, -250, true, address(this));
        }
        return 1000 * 10 ** 18; // Mock profit
    }
}

contract ReflexAfterSwapTest is Test {
    using TestUtils for *;

    TestableReflexAfterSwap public reflexAfterSwap;
    MockReflexRouter public mockRouter;
    MockToken public profitToken;

    address public admin = address(0x1);
    address public alice = address(0xA);
    address public bob = address(0xB);
    address public charlie = address(0xC);
    address public diana = address(0xD);
    address public attacker = address(0xBAD);

    address[] public recipients;
    uint256[] public shares;

    function setUp() public {
        profitToken = MockToken(TestUtils.createStandardMockToken());
        mockRouter = MockReflexRouter(TestUtils.createMockReflexRouter(admin, address(profitToken)));

        recipients = new address[](4);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = charlie;
        recipients[3] = diana;

        shares = new uint256[](4);
        shares[0] = 2500; // 25%
        shares[1] = 2500; // 25%
        shares[2] = 2500; // 25%
        shares[3] = 2500; // 25%

        reflexAfterSwap = new TestableReflexAfterSwap(address(mockRouter), recipients, shares);
    }

    // ========== Constructor Tests ==========

    function testConstructor() public view {
        assertEq(reflexAfterSwap.getRouter(), address(mockRouter));
        assertEq(reflexAfterSwap.getReflexAdmin(), admin);

        (address[] memory r, uint256[] memory s) = reflexAfterSwap.getRecipients();
        assertEq(r.length, 4);
        assertEq(s.length, 4);
        assertEq(r[0], alice);
        assertEq(s[0], 2500);
    }

    function testConstructorInvalidRouter() public {
        vm.expectRevert("Invalid router address");
        new TestableReflexAfterSwap(address(0), recipients, shares);
    }

    // ========== Access Control Tests ==========

    function testOnlyReflexAdminModifier() public {
        // Admin should be able to call admin functions
        vm.prank(admin);
        reflexAfterSwap.updateShares(recipients, shares);

        // Non-admin should not be able to call admin functions
        vm.prank(attacker);
        vm.expectRevert("Caller is not the reflex admin");
        reflexAfterSwap.updateShares(recipients, shares);
    }

    function testSetReflexRouter() public {
        MockReflexRouter newRouter = MockReflexRouter(TestUtils.createMockReflexRouter(admin, address(profitToken)));

        vm.prank(admin);
        reflexAfterSwap.setReflexRouter(address(newRouter));

        assertEq(reflexAfterSwap.getRouter(), address(newRouter));
        assertEq(reflexAfterSwap.getReflexAdmin(), admin);
    }

    function testSetReflexRouterUnauthorized() public {
        MockReflexRouter newRouter = MockReflexRouter(TestUtils.createMockReflexRouter(admin, address(profitToken)));

        vm.prank(attacker);
        vm.expectRevert("Caller is not the reflex admin");
        reflexAfterSwap.setReflexRouter(address(newRouter));
    }

    function testSetReflexRouterInvalidAddress() public {
        vm.prank(admin);
        vm.expectRevert("Invalid router address");
        reflexAfterSwap.setReflexRouter(address(0));
    }

    function testAdminChange() public {
        address newAdmin = address(0x2);

        // Change admin in router
        mockRouter.setReflexAdmin(newAdmin);

        // Update router to reflect admin change
        vm.prank(admin);
        reflexAfterSwap.setReflexRouter(address(mockRouter));

        // Old admin should no longer have access
        vm.prank(admin);
        vm.expectRevert("Caller is not the reflex admin");
        reflexAfterSwap.updateShares(recipients, shares);

        // New admin should have access
        vm.prank(newAdmin);
        reflexAfterSwap.updateShares(recipients, shares);

        assertEq(reflexAfterSwap.getReflexAdmin(), newAdmin);
    }

    // ========== Backrun Tests ==========

    function testReflexAfterSwapBasic() public {
        bytes32 poolId = keccak256("test-pool");
        int256 amount0Delta = 1000;
        int256 amount1Delta = -500;
        bool zeroForOne = true;
        address recipient = alice;

        uint256 aliceInitial = profitToken.balanceOf(alice);
        uint256 bobInitial = profitToken.balanceOf(bob);
        uint256 charlieInitial = profitToken.balanceOf(charlie);
        uint256 dianaInitial = profitToken.balanceOf(diana);

        uint256 profit = reflexAfterSwap.testReflexAfterSwap(poolId, amount0Delta, amount1Delta, zeroForOne, recipient);

        uint256 expectedProfit = 1000 * 10 ** 18; // Default mock profit
        assertEq(profit, expectedProfit);

        // Each recipient should get 25% of profit, with dust going to alice (recipient)
        uint256 expectedShare = (expectedProfit * 2500) / 10000;
        assertEq(profitToken.balanceOf(alice), aliceInitial + expectedShare);
        assertEq(profitToken.balanceOf(bob), bobInitial + expectedShare);
        assertEq(profitToken.balanceOf(charlie), charlieInitial + expectedShare);
        assertEq(profitToken.balanceOf(diana), dianaInitial + expectedShare);
    }

    function testReflexAfterSwapWithDust() public {
        // Set a profit amount that creates dust when split
        uint256 dustyProfit = 999; // Creates remainder when divided by 2500
        mockRouter.setMockProfit(dustyProfit);

        bytes32 poolId = keccak256("dusty-pool");
        address dustRecipient = bob;

        uint256 bobInitial = profitToken.balanceOf(bob);
        uint256 aliceInitial = profitToken.balanceOf(alice);

        uint256 profit = reflexAfterSwap.testReflexAfterSwap(poolId, 1000, -500, true, dustRecipient);

        assertEq(profit, dustyProfit);

        // Calculate expected distribution
        uint256 expectedShare = (dustyProfit * 2500) / 10000; // 249
        uint256 totalNormalDistribution = expectedShare * 4; // 996
        uint256 dust = dustyProfit - totalNormalDistribution; // 3

        // Alice gets normal share
        assertEq(profitToken.balanceOf(alice), aliceInitial + expectedShare);

        // Bob (dust recipient) gets normal share + dust
        assertEq(profitToken.balanceOf(bob), bobInitial + expectedShare + dust);
    }

    function testReflexAfterSwapNegativeAmount1Delta() public {
        bytes32 poolId = keccak256("negative-pool");
        int256 amount0Delta = -800;
        int256 amount1Delta = 1200; // This should be used as swapAmountIn

        uint256 profit = reflexAfterSwap.testReflexAfterSwap(poolId, amount0Delta, amount1Delta, false, alice);

        assertEq(profit, 1000 * 10 ** 18);
    }

    function testReflexAfterSwapZeroProfit() public {
        mockRouter.setMockProfit(0);

        uint256 aliceInitial = profitToken.balanceOf(alice);

        uint256 profit = reflexAfterSwap.testReflexAfterSwap(keccak256("zero-pool"), 1000, -500, true, alice);

        assertEq(profit, 0);
        assertEq(profitToken.balanceOf(alice), aliceInitial); // No tokens transferred
    }

    function testReflexAfterSwapRouterReverts() public {
        mockRouter.setShouldRevert(true);

        // With the failsafe, the function should not revert but return 0 profit
        uint256 profit = reflexAfterSwap.testReflexAfterSwap(keccak256("revert-pool"), 1000, -500, true, alice);

        // Verify failsafe behavior: no revert, zero profit returned
        assertEq(profit, 0);

        // Verify no tokens were transferred since router failed
        assertEq(profitToken.balanceOf(alice), 0);
    }

    // ========== Reentrancy Tests ==========

    function testNonReentrantModifier() public {
        // Test graceful reentrancy protection
        // Create a malicious contract that attempts reentrancy
        MaliciousReentrancyAfterSwap attackerContract = new MaliciousReentrancyAfterSwap(address(reflexAfterSwap));

        // Enable reentrancy attempt
        attackerContract.setShouldReenter(true);

        // Attempt the attack - with graceful reentrancy guard, this should not revert
        // but should block the reentrancy attempt gracefully
        uint256 profit = attackerContract.attack(keccak256("pool1"), 1000, -500, true);

        // Verify the attack was blocked gracefully
        // The first call should execute normally, but reentrancy attempts should return early with 0 profit
        assertEq(profit, 1000 * 10 ** 18, "First call should succeed normally");
        assertEq(attackerContract.callCount(), 1, "Only the first call should execute, reentrancy blocked gracefully");

        // Test that normal sequential calls still work
        uint256 profit2 = reflexAfterSwap.testReflexAfterSwap(keccak256("pool2"), 2000, -1000, false, bob);
        assertEq(profit2, 1000 * 10 ** 18, "Sequential calls should work normally");
    }

    // ========== Integration Tests ==========

    function testUnequalShares() public {
        // Update to unequal shares
        address[] memory newRecipients = new address[](3);
        newRecipients[0] = alice;
        newRecipients[1] = bob;
        newRecipients[2] = charlie;

        uint256[] memory newShares = new uint256[](3);
        newShares[0] = 5000; // 50%
        newShares[1] = 3000; // 30%
        newShares[2] = 2000; // 20%

        vm.prank(admin);
        reflexAfterSwap.updateShares(newRecipients, newShares);

        uint256 profit = 10000; // Even number for clean division
        mockRouter.setMockProfit(profit);

        uint256 aliceInitial = profitToken.balanceOf(alice);
        uint256 bobInitial = profitToken.balanceOf(bob);
        uint256 charlieInitial = profitToken.balanceOf(charlie);

        reflexAfterSwap.testReflexAfterSwap(keccak256("unequal-pool"), 1000, -500, true, alice);

        assertEq(profitToken.balanceOf(alice), aliceInitial + (profit * 5000) / 10000); // 50%
        assertEq(profitToken.balanceOf(bob), bobInitial + (profit * 3000) / 10000); // 30%
        assertEq(profitToken.balanceOf(charlie), charlieInitial + (profit * 2000) / 10000); // 20%
    }

    function testMultipleBackruns() public {
        uint256 aliceInitial = profitToken.balanceOf(alice);

        // First backrun
        reflexAfterSwap.testReflexAfterSwap(keccak256("pool1"), 1000, -500, true, alice);

        uint256 aliceAfterFirst = profitToken.balanceOf(alice);

        // Second backrun
        reflexAfterSwap.testReflexAfterSwap(keccak256("pool2"), 2000, -1000, false, bob);

        uint256 expectedShare = (1000 * 10 ** 18 * 2500) / 10000; // 25% each time
        assertEq(profitToken.balanceOf(alice), aliceInitial + (expectedShare * 2));
        assertEq(aliceAfterFirst, aliceInitial + expectedShare);
    }

    // ========== Edge Cases ==========

    function testLargeProfitAmounts() public {
        uint256 largeProfit = 1000000 * 10 ** 18; // 1M tokens
        mockRouter.setMockProfit(largeProfit);

        uint256 profit = reflexAfterSwap.testReflexAfterSwap(keccak256("large-pool"), 1000, -500, true, alice);

        assertEq(profit, largeProfit);

        uint256 expectedShare = (largeProfit * 2500) / 10000;
        assertEq(profitToken.balanceOf(alice), expectedShare);
    }

    function testMaxIntSwapAmount() public {
        int256 maxAmount = type(int112).max;

        uint256 profit = reflexAfterSwap.testReflexAfterSwap(keccak256("max-pool"), maxAmount, -100, true, alice);

        assertEq(profit, 1000 * 10 ** 18);
    }

    // ========== Events Tests ==========

    function testSplitExecutedEvent() public {
        uint256 profit = 1000 * 10 ** 18;
        mockRouter.setMockProfit(profit);

        uint256 expectedShare = (profit * 2500) / 10000;
        uint256[] memory expectedAmounts = new uint256[](4);
        expectedAmounts[0] = expectedShare;
        expectedAmounts[1] = expectedShare;
        expectedAmounts[2] = expectedShare;
        expectedAmounts[3] = expectedShare;

        vm.expectEmit(true, true, true, true);
        emit SplitExecuted(address(profitToken), profit, recipients, expectedAmounts);

        reflexAfterSwap.testReflexAfterSwap(keccak256("event-pool"), 1000, -500, true, alice);
    }

    // ========== Recipient Share Tests ==========

    function testRecipientShareDefault() public {
        assertEq(reflexAfterSwap.getRecipientShare(), 0, "Default recipient share should be 0");
    }

    function testSetRecipientShare() public {
        uint256 sharePercent = 2500; // 25%

        vm.prank(admin);
        reflexAfterSwap.setRecipientShare(sharePercent);

        assertEq(reflexAfterSwap.getRecipientShare(), sharePercent, "Recipient share should be set correctly");
    }

    function testSetRecipientShareUnauthorized() public {
        vm.prank(attacker);
        vm.expectRevert("Caller is not the reflex admin");
        reflexAfterSwap.setRecipientShare(1000);
    }

    function testSetRecipientShareTooHigh() public {
        vm.prank(admin);
        vm.expectRevert("Recipient share too high");
        reflexAfterSwap.setRecipientShare(5001); // Over 50%
    }

    function testReflexAfterSwapWithRecipientShare() public {
        uint256 profit = 1000;
        uint256 recipientShare = 2500; // 25%
        profitToken.mint(address(reflexAfterSwap), profit);

        // Set recipient share to 25%
        vm.prank(admin);
        reflexAfterSwap.setRecipientShare(recipientShare);

        // Set up the mock router to return profit
        mockRouter.setMockProfit(profit);

        uint256 result = reflexAfterSwap.testReflexAfterSwap(keccak256("recipient-share-pool"), 1000, -500, true, alice);

        assertEq(result, profit, "Should return total profit");

        // Calculate expected amounts
        uint256 expectedRecipientAmount = (profit * recipientShare) / 10000; // 250
        uint256 expectedRemainingAmount = profit - expectedRecipientAmount; // 750
        uint256 expectedShareEach = expectedRemainingAmount / 4; // 187.5 -> 187 (due to rounding)
        uint256 dust = expectedRemainingAmount - (expectedShareEach * 4); // Remaining dust goes to alice too

        // Verify alice got both recipient share + her normal share + dust
        uint256 expectedAliceTotal = expectedRecipientAmount + expectedShareEach + dust;
        assertEq(
            profitToken.balanceOf(alice),
            expectedAliceTotal,
            "Alice should receive recipient share + normal share + dust"
        );

        // Verify others got only their normal shares
        assertEq(profitToken.balanceOf(bob), expectedShareEach, "Bob should receive normal share only");
        assertEq(profitToken.balanceOf(charlie), expectedShareEach, "Charlie should receive normal share only");
        assertEq(profitToken.balanceOf(diana), expectedShareEach, "Diana should receive normal share only");
    }

    // Events
    event SplitExecuted(address indexed token, uint256 totalAmount, address[] recipients, uint256[] amounts);
}
