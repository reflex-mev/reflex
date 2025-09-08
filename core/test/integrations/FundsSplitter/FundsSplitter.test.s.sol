// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@reflex/integrations/FundsSplitter/FundsSplitter.sol";
import "@reflex/integrations/FundsSplitter/IFundsSplitter.sol";
import "../../utils/TestUtils.sol";

contract TestableSplitter is FundsSplitter {
    address private _admin;

    constructor(address admin_, address[] memory recipients_, uint256[] memory sharesBps_) {
        _admin = admin_;
        _setShares(recipients_, sharesBps_);
    }

    function _onlyFundsAdmin() internal view override {
        require(msg.sender == _admin, "NotAdmin");
    }

    // Expose internal functions for testing
    function splitERC20(address token, uint256 amount, address dustRecipient) external {
        _splitERC20(token, amount, dustRecipient);
    }

    function splitETH(address dustRecipient) external payable {
        _splitETH(dustRecipient);
    }
}

contract FundsSplitterTest is Test, IFundsSplitter {
    TestableSplitter public splitter;
    MockToken public token;
    address public admin;
    address public alice = address(0xA);
    address public bob = address(0xB);
    address public charlie = address(0xC);
    address public diana = address(0xD);

    address[] public recipients;
    uint256[] public shares;

    receive() external payable {}

    // ========== IFundsSplitter Implementation (dummy for events) ==========
    function getRecipients() external pure override returns (address[] memory, uint256[] memory) {
        revert("Use splitter.getRecipients() instead");
    }

    function updateShares(address[] calldata, uint256[] calldata) external pure override {
        revert("Use splitter.updateShares() instead");
    }

    // ========== Test Setup ==========

    function setUp() public {
        admin = address(this);
        token = MockToken(TestUtils.createStandardMockToken());

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

        splitter = new TestableSplitter(admin, recipients, shares);

        // Give the splitter some tokens for testing
        token.mint(address(splitter), 10000 * 10 ** 18);
    }

    function testGetRecipients() public view {
        (address[] memory r, uint256[] memory s) = splitter.getRecipients();
        assertEq(r.length, 4);
        assertEq(s.length, 4);
        assertEq(r[0], alice);
        assertEq(r[1], bob);
        assertEq(r[2], charlie);
        assertEq(r[3], diana);
        assertEq(s[0], 2500);
        assertEq(s[1], 2500);
        assertEq(s[2], 2500);
        assertEq(s[3], 2500);
    }

    function testUpdateShares() public {
        address[] memory newRecipients = new address[](4);
        newRecipients[0] = alice;
        newRecipients[1] = bob;
        newRecipients[2] = charlie;
        newRecipients[3] = diana;

        uint256[] memory newShares = new uint256[](4);
        newShares[0] = 1000;
        newShares[1] = 2000;
        newShares[2] = 3000;
        newShares[3] = 4000;

        splitter.updateShares(newRecipients, newShares);

        (address[] memory r, uint256[] memory s) = splitter.getRecipients();
        assertEq(r.length, 4);
        assertEq(r[0], alice);
        assertEq(s[3], 4000);
    }

    function testUnauthorizedUpdateFails() public {
        address attacker = address(0xBAD);
        vm.prank(attacker);

        address[] memory newRecipients = new address[](1);
        newRecipients[0] = alice;

        uint256[] memory newShares = new uint256[](1);
        newShares[0] = 10000;

        vm.expectRevert("NotAdmin");
        splitter.updateShares(newRecipients, newShares);
    }

    function testRevertWhenEmptyRecipients() public {
        address[] memory newRecipients = new address[](0);
        uint256[] memory newShares = new uint256[](0);

        vm.expectRevert("Invalid total shares");
        splitter.updateShares(newRecipients, newShares);
    }

    function testRevertWhenZeroShare() public {
        address[] memory newRecipients = new address[](2);
        newRecipients[0] = alice;
        newRecipients[1] = bob;

        uint256[] memory newShares = new uint256[](2);
        newShares[0] = 0;
        newShares[1] = 10000;

        vm.expectRevert("Invalid recipient or share");
        splitter.updateShares(newRecipients, newShares);
    }

    function testRevertWhenZeroAddress() public {
        address[] memory newRecipients = new address[](2);
        newRecipients[0] = address(0);
        newRecipients[1] = bob;

        uint256[] memory newShares = new uint256[](2);
        newShares[0] = 5000;
        newShares[1] = 5000;

        vm.expectRevert("Invalid recipient or share");
        splitter.updateShares(newRecipients, newShares);
    }

    function testRevertWhenInvalidTotalShares() public {
        address[] memory newRecipients = new address[](2);
        newRecipients[0] = alice;
        newRecipients[1] = bob;

        uint256[] memory newShares = new uint256[](2);
        newShares[0] = 3000;
        newShares[1] = 3000; // Total: 6000, should be 10000

        vm.expectRevert("Invalid total shares");
        splitter.updateShares(newRecipients, newShares);
    }

    function testRevertWhenLengthMismatch() public {
        address[] memory newRecipients = new address[](2);
        newRecipients[0] = alice;
        newRecipients[1] = bob;

        uint256[] memory newShares = new uint256[](3);
        newShares[0] = 5000;
        newShares[1] = 5000;
        newShares[2] = 0;

        vm.expectRevert("Recipients and shares length mismatch");
        splitter.updateShares(newRecipients, newShares);
    }

    function testUpdateSharesWithDifferentRecipients() public {
        address eve = address(0xE);
        address frank = address(0xF);

        address[] memory newRecipients = new address[](2);
        newRecipients[0] = eve;
        newRecipients[1] = frank;

        uint256[] memory newShares = new uint256[](2);
        newShares[0] = 6000; // 60%
        newShares[1] = 4000; // 40%

        splitter.updateShares(newRecipients, newShares);

        (address[] memory r, uint256[] memory s) = splitter.getRecipients();
        assertEq(r.length, 2);
        assertEq(r[0], eve);
        assertEq(r[1], frank);
        assertEq(s[0], 6000);
        assertEq(s[1], 4000);
    }

    function testUpdateSharesWithSingleRecipient() public {
        address[] memory newRecipients = new address[](1);
        newRecipients[0] = alice;

        uint256[] memory newShares = new uint256[](1);
        newShares[0] = 10000; // 100%

        splitter.updateShares(newRecipients, newShares);

        (address[] memory r, uint256[] memory s) = splitter.getRecipients();
        assertEq(r.length, 1);
        assertEq(r[0], alice);
        assertEq(s[0], 10000);
    }

    function testSharesUpdatedEvent() public {
        address[] memory newRecipients = new address[](2);
        newRecipients[0] = alice;
        newRecipients[1] = bob;

        uint256[] memory newShares = new uint256[](2);
        newShares[0] = 7000;
        newShares[1] = 3000;

        vm.expectEmit(true, true, true, true);
        emit SharesUpdated(newRecipients, newShares);

        splitter.updateShares(newRecipients, newShares);
    }

    // ========== Splitting Function Tests ==========

    function testSplitERC20BasicFunctionality() public {
        uint256 amount = 1000 * 10 ** 18;

        // Clear splitter balance and give it exactly the amount we want to split
        uint256 currentBalance = token.balanceOf(address(splitter));
        if (currentBalance > 0) {
            vm.prank(address(splitter));
            token.transfer(address(this), currentBalance);
        }

        // Record initial balances
        uint256 aliceInitial = token.balanceOf(alice);
        uint256 bobInitial = token.balanceOf(bob);
        uint256 charlieInitial = token.balanceOf(charlie);
        uint256 dianaInitial = token.balanceOf(diana);

        // Give splitter exactly the amount to split
        token.mint(address(splitter), amount);

        // Calculate expected amounts for event
        uint256 expectedAmount = (amount * 2500) / 10000; // 25%
        uint256[] memory expectedAmounts = new uint256[](4);
        expectedAmounts[0] = expectedAmount;
        expectedAmounts[1] = expectedAmount;
        expectedAmounts[2] = expectedAmount;
        expectedAmounts[3] = expectedAmount;

        vm.expectEmit(true, true, true, true);
        emit SplitExecuted(address(token), amount, recipients, expectedAmounts);

        splitter.splitERC20(address(token), amount, alice);

        // Check that each recipient got 25% (2500 basis points)
        assertEq(token.balanceOf(alice), aliceInitial + expectedAmount);
        assertEq(token.balanceOf(bob), bobInitial + expectedAmount);
        assertEq(token.balanceOf(charlie), charlieInitial + expectedAmount);
        assertEq(token.balanceOf(diana), dianaInitial + expectedAmount);

        // Verify splitter balance is now zero
        assertEq(token.balanceOf(address(splitter)), 0);
    }

    function testSplitERC20UnequalShares() public {
        // Update to unequal shares: 40%, 30%, 20%, 10%
        address[] memory newRecipients = new address[](4);
        newRecipients[0] = alice;
        newRecipients[1] = bob;
        newRecipients[2] = charlie;
        newRecipients[3] = diana;

        uint256[] memory newShares = new uint256[](4);
        newShares[0] = 4000; // 40%
        newShares[1] = 3000; // 30%
        newShares[2] = 2000; // 20%
        newShares[3] = 1000; // 10%

        splitter.updateShares(newRecipients, newShares);

        uint256 amount = 1000 * 10 ** 18;

        // Clear splitter balance and give it exactly the amount we want to split
        uint256 currentBalance = token.balanceOf(address(splitter));
        if (currentBalance > 0) {
            vm.prank(address(splitter));
            token.transfer(address(this), currentBalance);
        }
        token.mint(address(splitter), amount);

        splitter.splitERC20(address(token), amount, alice);

        // Check distributions
        assertEq(token.balanceOf(alice), (amount * 4000) / 10000); // 40%
        assertEq(token.balanceOf(bob), (amount * 3000) / 10000); // 30%
        assertEq(token.balanceOf(charlie), (amount * 2000) / 10000); // 20%
        assertEq(token.balanceOf(diana), (amount * 1000) / 10000); // 10%
    }

    function testSplitERC20WithDustRounding() public {
        // Test with an amount that doesn't divide evenly
        uint256 amount = 999; // This will create dust when divided by 2500

        // Clear splitter balance and give it exactly the amount we want to split
        uint256 currentBalance = token.balanceOf(address(splitter));
        if (currentBalance > 0) {
            vm.prank(address(splitter));
            token.transfer(address(this), currentBalance);
        }
        token.mint(address(splitter), amount);

        splitter.splitERC20(address(token), amount, alice);

        // Check that the total distributed equals the input amount
        uint256 totalDistributed =
            token.balanceOf(alice) + token.balanceOf(bob) + token.balanceOf(charlie) + token.balanceOf(diana);

        // The splitter should have distributed all tokens (within rounding)
        uint256 remaining = token.balanceOf(address(splitter));
        assertTrue(remaining <= 3, "Should have minimal dust remaining"); // At most 3 wei dust for 4 recipients
        assertEq(totalDistributed, amount - remaining);
    }

    function testSplitETHBasicFunctionality() public {
        uint256 amount = 1 ether;

        // Record initial balances
        uint256 aliceInitial = alice.balance;
        uint256 bobInitial = bob.balance;
        uint256 charlieInitial = charlie.balance;
        uint256 dianaInitial = diana.balance;

        // Calculate expected amounts for event
        uint256 expectedAmount = (amount * 2500) / 10000; // 25%
        uint256[] memory expectedAmounts = new uint256[](4);
        expectedAmounts[0] = expectedAmount;
        expectedAmounts[1] = expectedAmount;
        expectedAmounts[2] = expectedAmount;
        expectedAmounts[3] = expectedAmount;

        // Send ETH to splitter and split
        vm.expectEmit(true, true, true, true);
        emit SplitExecuted(address(0), amount, recipients, expectedAmounts);

        splitter.splitETH{value: amount}(alice);

        // Check that each recipient got 25%
        assertEq(alice.balance, aliceInitial + expectedAmount);
        assertEq(bob.balance, bobInitial + expectedAmount);
        assertEq(charlie.balance, charlieInitial + expectedAmount);
        assertEq(diana.balance, dianaInitial + expectedAmount);

        // Verify splitter balance is now zero
        assertEq(address(splitter).balance, 0);
    }

    function testSplitETHUnequalShares() public {
        // Update to unequal shares
        address[] memory newRecipients = new address[](3);
        newRecipients[0] = alice;
        newRecipients[1] = bob;
        newRecipients[2] = charlie;

        uint256[] memory newShares = new uint256[](3);
        newShares[0] = 5000; // 50%
        newShares[1] = 3000; // 30%
        newShares[2] = 2000; // 20%

        splitter.updateShares(newRecipients, newShares);

        uint256 amount = 2 ether;

        uint256 aliceInitial = alice.balance;
        uint256 bobInitial = bob.balance;
        uint256 charlieInitial = charlie.balance;

        splitter.splitETH{value: amount}(alice);

        // Check distributions
        assertEq(alice.balance, aliceInitial + (amount * 5000) / 10000); // 50%
        assertEq(bob.balance, bobInitial + (amount * 3000) / 10000); // 30%
        assertEq(charlie.balance, charlieInitial + (amount * 2000) / 10000); // 20%
    }

    function testSplitETHWithSmallAmount() public {
        uint256 amount = 100 wei;

        uint256 totalInitial = alice.balance + bob.balance + charlie.balance + diana.balance;

        splitter.splitETH{value: amount}(alice);

        uint256 totalFinal = alice.balance + bob.balance + charlie.balance + diana.balance;

        // All ETH should be distributed (allowing for minimal rounding dust)
        assertTrue(totalFinal >= totalInitial + amount - 3, "Most ETH should be distributed");
        assertEq(address(splitter).balance, 0, "Splitter should have no remaining ETH");
    }

    function testSplitERC20ZeroAmount() public {
        // Test splitting zero amount (should not revert but also not transfer anything)
        uint256 aliceInitial = token.balanceOf(alice);

        splitter.splitERC20(address(token), 0, alice);

        assertEq(token.balanceOf(alice), aliceInitial, "No tokens should be transferred for zero amount");
    }

    function testSplitETHZeroAmount() public {
        uint256 aliceInitial = alice.balance;

        splitter.splitETH{value: 0}(alice);

        assertEq(alice.balance, aliceInitial, "No ETH should be transferred for zero amount");
    }

    function testSplitERC20InsufficientBalance() public {
        uint256 amount = 1000 * 10 ** 18;

        // Clear the splitter's balance first
        uint256 currentBalance = token.balanceOf(address(splitter));
        if (currentBalance > 0) {
            vm.prank(address(splitter));
            token.transfer(address(this), currentBalance);
        }

        // Try to split more than the contract has (should fail)
        vm.expectRevert(); // The specific error depends on OpenZeppelin version
        splitter.splitERC20(address(token), amount, alice);
    }

    function testSplitERC20SingleRecipient() public {
        // Update to single recipient
        address[] memory newRecipients = new address[](1);
        newRecipients[0] = alice;

        uint256[] memory newShares = new uint256[](1);
        newShares[0] = 10000; // 100%

        splitter.updateShares(newRecipients, newShares);

        uint256 amount = 500 * 10 ** 18;

        // Clear splitter balance and give it exactly the amount we want to split
        uint256 currentBalance = token.balanceOf(address(splitter));
        if (currentBalance > 0) {
            vm.prank(address(splitter));
            token.transfer(address(this), currentBalance);
        }
        token.mint(address(splitter), amount);

        uint256 aliceInitial = token.balanceOf(alice);
        splitter.splitERC20(address(token), amount, alice);

        assertEq(token.balanceOf(alice), aliceInitial + amount, "Alice should receive 100%");
    }

    function testSplitETHSingleRecipient() public {
        // Update to single recipient
        address[] memory newRecipients = new address[](1);
        newRecipients[0] = alice;

        uint256[] memory newShares = new uint256[](1);
        newShares[0] = 10000; // 100%

        splitter.updateShares(newRecipients, newShares);

        uint256 amount = 1 ether;
        uint256 aliceInitial = alice.balance;

        splitter.splitETH{value: amount}(alice);

        assertEq(alice.balance, aliceInitial + amount, "Alice should receive 100%");
    }

    function testMultipleSplitsAccumulate() public {
        uint256 amount1 = 100 * 10 ** 18;
        uint256 amount2 = 200 * 10 ** 18;

        // Clear splitter balance first
        uint256 currentBalance = token.balanceOf(address(splitter));
        if (currentBalance > 0) {
            vm.prank(address(splitter));
            token.transfer(address(this), currentBalance);
        }

        // First split
        token.mint(address(splitter), amount1);
        splitter.splitERC20(address(token), amount1, alice);

        uint256 aliceAfterFirst = token.balanceOf(alice);

        // Second split
        token.mint(address(splitter), amount2);
        splitter.splitERC20(address(token), amount2, alice);

        // Alice should have received 25% of both amounts
        uint256 expectedTotal = ((amount1 + amount2) * 2500) / 10000;
        assertEq(token.balanceOf(alice), expectedTotal);

        // Verify the accumulation
        uint256 expectedSecond = (amount2 * 2500) / 10000;
        assertEq(token.balanceOf(alice), aliceAfterFirst + expectedSecond);
    }

    function testDustHandlingERC20() public {
        // Test that dust goes to the specified recipient
        uint256 amount = 999; // Creates remainder when divided

        // Clear splitter balance and give it exactly the amount we want to split
        uint256 currentBalance = token.balanceOf(address(splitter));
        if (currentBalance > 0) {
            vm.prank(address(splitter));
            token.transfer(address(this), currentBalance);
        }
        token.mint(address(splitter), amount);

        uint256 bobInitial = token.balanceOf(bob);
        uint256 aliceInitial = token.balanceOf(alice);

        // Split with bob as dust recipient
        splitter.splitERC20(address(token), amount, bob);

        // Calculate expected amounts
        uint256 expectedShare = (amount * 2500) / 10000; // 249 for each recipient
        uint256 totalNormalDistribution = expectedShare * 4; // 996
        uint256 dust = amount - totalNormalDistribution; // 3

        // Alice should get her normal share (she's not the dust recipient in this test)
        assertEq(token.balanceOf(alice), aliceInitial + expectedShare);

        // Bob should get his normal share PLUS the dust
        assertEq(token.balanceOf(bob), bobInitial + expectedShare + dust);

        // Contract should have no remaining tokens
        assertEq(token.balanceOf(address(splitter)), 0);
    }

    function testDustHandlingETH() public {
        // Test that ETH dust goes to the specified recipient
        uint256 amount = 999 wei; // Creates remainder when divided

        uint256 charlieInitial = charlie.balance;
        uint256 aliceInitial = alice.balance;

        // Split with charlie as dust recipient
        splitter.splitETH{value: amount}(charlie);

        // Calculate expected amounts
        uint256 expectedShare = (amount * 2500) / 10000; // 249 for each recipient
        uint256 totalNormalDistribution = expectedShare * 4; // 996
        uint256 dust = amount - totalNormalDistribution; // 3

        // Alice should get her normal share (she's not the dust recipient in this test)
        assertEq(alice.balance, aliceInitial + expectedShare);

        // Charlie should get his normal share PLUS the dust
        assertEq(charlie.balance, charlieInitial + expectedShare + dust);

        // Contract should have no remaining ETH
        assertEq(address(splitter).balance, 0);
    }

    function testNoDustRecipient() public {
        // Test with address(0) as dust recipient - dust should be lost
        uint256 amount = 999; // Creates remainder when divided

        // Clear splitter balance and give it exactly the amount we want to split
        uint256 currentBalance = token.balanceOf(address(splitter));
        if (currentBalance > 0) {
            vm.prank(address(splitter));
            token.transfer(address(this), currentBalance);
        }
        token.mint(address(splitter), amount);

        uint256 splitterInitial = token.balanceOf(address(splitter));

        // Split with address(0) as dust recipient
        splitter.splitERC20(address(token), amount, address(0));

        // Calculate expected amounts
        uint256 expectedShare = (amount * 2500) / 10000; // 249 for each recipient
        uint256 totalNormalDistribution = expectedShare * 4; // 996
        uint256 dust = amount - totalNormalDistribution; // 3

        // Contract should have the dust remaining (since address(0) can't receive it)
        assertEq(token.balanceOf(address(splitter)), splitterInitial - amount + dust);
    }

    // ========== Fuzz Tests ==========

    function testFuzzUpdateSharesValidTotal(uint256 share1, uint256 share2) public {
        // Bound shares to reasonable values that sum to TOTAL_BPS
        vm.assume(share1 > 0 && share1 < 10000);
        share2 = 10000 - share1;
        vm.assume(share2 > 0);

        address[] memory newRecipients = new address[](2);
        newRecipients[0] = alice;
        newRecipients[1] = bob;

        uint256[] memory newShares = new uint256[](2);
        newShares[0] = share1;
        newShares[1] = share2;

        splitter.updateShares(newRecipients, newShares);

        (address[] memory r, uint256[] memory s) = splitter.getRecipients();
        assertEq(r.length, 2);
        assertEq(s[0], share1);
        assertEq(s[1], share2);
        assertEq(s[0] + s[1], 10000);
    }

    function testFuzzUpdateSharesInvalidTotal(uint256 share1, uint256 share2) public {
        // Test cases where total doesn't equal 10000
        // Bound inputs to reasonable ranges to prevent overflow
        share1 = bound(share1, 1, 15000);
        share2 = bound(share2, 1, 15000);

        // Ensure they don't sum to exactly 10000
        vm.assume(share1 + share2 != 10000);

        address[] memory newRecipients = new address[](2);
        newRecipients[0] = alice;
        newRecipients[1] = bob;

        uint256[] memory newShares = new uint256[](2);
        newShares[0] = share1;
        newShares[1] = share2;

        vm.expectRevert("Invalid total shares");
        splitter.updateShares(newRecipients, newShares);
    }

    function testFuzzUpdateSharesThreeRecipients(uint256 share1, uint256 share2, uint256 share3) public {
        // Test with three recipients
        vm.assume(share1 > 0 && share2 > 0 && share3 > 0);
        vm.assume(share1 < 3333 && share2 < 3333 && share3 < 3333); // Smaller bounds to ensure sum can equal 10000

        // Calculate share3 to make total exactly 10000
        uint256 remainingShare = 10000 - share1 - share2;
        vm.assume(remainingShare > 0 && remainingShare <= 10000);
        share3 = remainingShare;

        address[] memory newRecipients = new address[](3);
        newRecipients[0] = alice;
        newRecipients[1] = bob;
        newRecipients[2] = charlie;

        uint256[] memory newShares = new uint256[](3);
        newShares[0] = share1;
        newShares[1] = share2;
        newShares[2] = share3;

        splitter.updateShares(newRecipients, newShares);

        (address[] memory r, uint256[] memory s) = splitter.getRecipients();
        assertEq(r.length, 3);
        assertEq(s[0] + s[1] + s[2], 10000);
    }

    function testFuzzGetRecipientsConsistency(uint256 numRecipients) public {
        // Test with different numbers of recipients (1-10)
        numRecipients = bound(numRecipients, 1, 10);

        address[] memory newRecipients = new address[](numRecipients);
        uint256[] memory newShares = new uint256[](numRecipients);

        // Create recipients with equal shares
        uint256 sharePerRecipient = 10000 / numRecipients;
        uint256 remainder = 10000 % numRecipients;

        for (uint256 i = 0; i < numRecipients; i++) {
            newRecipients[i] = address(uint160(0x1000 + i)); // Generate unique addresses
            newShares[i] = sharePerRecipient;
            if (i == 0) {
                newShares[i] += remainder; // Give remainder to first recipient
            }
        }

        splitter.updateShares(newRecipients, newShares);

        (address[] memory r, uint256[] memory s) = splitter.getRecipients();
        assertEq(r.length, numRecipients);
        assertEq(s.length, numRecipients);

        // Verify total shares
        uint256 total = 0;
        for (uint256 i = 0; i < s.length; i++) {
            total += s[i];
        }
        assertEq(total, 10000);
    }

    function testFuzzRevertOnZeroShare(uint256 validShare, uint256 invalidIndex) public {
        // Test that zero shares are rejected at any position
        vm.assume(validShare > 0 && validShare < 10000);

        uint256 numRecipients = 3;
        invalidIndex = bound(invalidIndex, 0, numRecipients - 1);

        address[] memory newRecipients = new address[](numRecipients);
        uint256[] memory newShares = new uint256[](numRecipients);

        for (uint256 i = 0; i < numRecipients; i++) {
            newRecipients[i] = address(uint160(0x2000 + i));
            if (i == invalidIndex) {
                newShares[i] = 0; // Set one share to zero
            } else {
                newShares[i] = validShare;
            }
        }

        vm.expectRevert("Invalid recipient or share");
        splitter.updateShares(newRecipients, newShares);
    }

    function testFuzzEdgeCaseShares(uint256 seed) public {
        // Test extreme but valid share distributions
        seed = bound(seed, 0, 2);

        address[] memory newRecipients = new address[](2);
        newRecipients[0] = alice;
        newRecipients[1] = bob;

        uint256[] memory newShares = new uint256[](2);

        if (seed == 0) {
            // One recipient gets almost everything
            newShares[0] = 9999;
            newShares[1] = 1;
        } else if (seed == 1) {
            // Reverse distribution
            newShares[0] = 1;
            newShares[1] = 9999;
        } else {
            // Equal split
            newShares[0] = 5000;
            newShares[1] = 5000;
        }

        splitter.updateShares(newRecipients, newShares);

        (, uint256[] memory s) = splitter.getRecipients();
        assertEq(s[0] + s[1], 10000);
        assertTrue(s[0] > 0 && s[1] > 0);
    }

    // ========== Property-Based Tests ==========

    function testPropertySharesSumToTotalBps() public {
        // Property: shares should always sum to TOTAL_BPS after valid update
        address[] memory newRecipients = new address[](3);
        newRecipients[0] = alice;
        newRecipients[1] = bob;
        newRecipients[2] = charlie;

        uint256[] memory newShares = new uint256[](3);
        newShares[0] = 3333;
        newShares[1] = 3333;
        newShares[2] = 3334; // 3333 + 3333 + 3334 = 10000

        splitter.updateShares(newRecipients, newShares);

        (, uint256[] memory s) = splitter.getRecipients();

        uint256 total = 0;
        for (uint256 i = 0; i < s.length; i++) {
            total += s[i];
        }

        assertEq(total, splitter.TOTAL_BPS());
        assertEq(total, 10000);
    }

    function testPropertyAllRecipientsHavePositiveShares() public view {
        // Property: all recipients should have positive shares
        (address[] memory r, uint256[] memory s) = splitter.getRecipients();

        for (uint256 i = 0; i < s.length; i++) {
            assertTrue(s[i] > 0, "All shares must be positive");
            assertTrue(r[i] != address(0), "All recipients must be valid addresses");
        }
    }

    function testPropertyRecipientsArrayLengthMatchesSharesArray() public view {
        // Property: recipients and shares arrays should always have same length
        (address[] memory r, uint256[] memory s) = splitter.getRecipients();
        assertEq(r.length, s.length);
    }

    // ========== Invariant Tests ==========

    function invariant_TotalSharesAlways10000() public view {
        (, uint256[] memory s) = splitter.getRecipients();

        uint256 total = 0;
        for (uint256 i = 0; i < s.length; i++) {
            total += s[i];
        }

        assertEq(total, 10000);
    }

    function invariant_NoZeroSharesOrAddresses() public view {
        (address[] memory r, uint256[] memory s) = splitter.getRecipients();

        for (uint256 i = 0; i < r.length; i++) {
            assertTrue(r[i] != address(0));
            assertTrue(s[i] > 0);
        }
    }
}
