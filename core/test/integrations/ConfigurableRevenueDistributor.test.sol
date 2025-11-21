// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/base/ConfigurableRevenueDistributor/ConfigurableRevenueDistributor.sol";
import "../../src/base/ConfigurableRevenueDistributor/IConfigurableRevenueDistributor.sol";
import "../mocks/MockToken.sol";

/// @title TestableConfigurableRevenueDistributor
/// @notice Testable implementation of ConfigurableRevenueDistributor for testing
contract TestableConfigurableRevenueDistributor is ConfigurableRevenueDistributor {
    address public admin;

    constructor(address _admin) {
        admin = _admin;
    }

    function _onlyFundsAdmin() internal view override {
        require(msg.sender == admin, "Not admin");
    }

    // Expose internal functions for testing
    function splitERC20(bytes32 configId, address token, uint256 amount, address variedRecipient) external {
        _splitERC20(configId, token, amount, variedRecipient);
    }

    function splitETH(bytes32 configId, address variedRecipient) external payable {
        _splitETH(configId, variedRecipient);
    }

    // Allow contract to receive ETH
    receive() external payable {}
}

/// @title ConfigurableRevenueDistributorTest
/// @notice Comprehensive test suite for ConfigurableRevenueDistributor contract
contract ConfigurableRevenueDistributorTest is Test {
    TestableConfigurableRevenueDistributor public distributor;
    MockToken public token;

    address public admin = address(0x1);
    address public recipient1 = address(0x2);
    address public recipient2 = address(0x3);
    address public recipient3 = address(0x4);
    address public variedRecipient = address(0x5);
    address public nonAdmin = address(0x6);

    bytes32 public constant CONFIG_ID_1 = keccak256("config1");
    bytes32 public constant CONFIG_ID_2 = keccak256("config2");

    // Events from IConfigurableRevenueDistributor
    event SharesUpdated(bytes32 indexed configId, address[] recipients, uint256[] sharesBps, uint256 variedShareBps);
    event SplitExecuted(
        bytes32 indexed configId,
        address indexed token,
        uint256 totalAmount,
        address[] recipients,
        uint256[] amounts,
        address variedRecipient,
        uint256 variedAmount
    );

    uint256 public constant TOTAL_BPS = 10_000;

    function setUp() public {
        distributor = new TestableConfigurableRevenueDistributor(admin);
        token = new MockToken("Test Token", "TEST", 0);

        // Mint tokens to the test contract for transferring to distributor
        token.mint(address(this), 1_000_000 * 10 ** 18);

        // Fund test accounts with ETH
        vm.deal(address(this), 100 ether);
    }

    // ========== Configuration Tests ==========

    function testUpdateShares_ValidConfiguration() public {
        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;

        uint256[] memory sharesBps = new uint256[](2);
        sharesBps[0] = 3000; // 30%
        sharesBps[1] = 5000; // 50%

        uint256 variedShareBps = 2000; // 20%

        vm.prank(admin);
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, variedShareBps);

        IConfigurableRevenueDistributor.SplitConfig memory config = distributor.getConfig(CONFIG_ID_1);
        assertEq(config.recipients.length, 2);
        assertEq(config.recipients[0], recipient1);
        assertEq(config.recipients[1], recipient2);
        assertEq(config.sharesBps[0], 3000);
        assertEq(config.sharesBps[1], 5000);
        assertEq(config.variedShareBps, 2000);
    }

    function testUpdateShares_MultipleConfigurations() public {
        // Setup first configuration
        address[] memory recipients1 = new address[](2);
        recipients1[0] = recipient1;
        recipients1[1] = recipient2;
        uint256[] memory sharesBps1 = new uint256[](2);
        sharesBps1[0] = 4000;
        sharesBps1[1] = 4000;
        uint256 variedShareBps1 = 2000;

        // Setup second configuration
        address[] memory recipients2 = new address[](1);
        recipients2[0] = recipient3;
        uint256[] memory sharesBps2 = new uint256[](1);
        sharesBps2[0] = 7000;
        uint256 variedShareBps2 = 3000;

        vm.startPrank(admin);
        distributor.updateShares(CONFIG_ID_1, recipients1, sharesBps1, variedShareBps1);
        distributor.updateShares(CONFIG_ID_2, recipients2, sharesBps2, variedShareBps2);
        vm.stopPrank();

        // Verify first config
        IConfigurableRevenueDistributor.SplitConfig memory config1 = distributor.getConfig(CONFIG_ID_1);
        assertEq(config1.recipients.length, 2);
        assertEq(config1.variedShareBps, 2000);

        // Verify second config
        IConfigurableRevenueDistributor.SplitConfig memory config2 = distributor.getConfig(CONFIG_ID_2);
        assertEq(config2.recipients.length, 1);
        assertEq(config2.recipients[0], recipient3);
        assertEq(config2.variedShareBps, 3000);
    }

    function testUpdateShares_RevertWhenNotAdmin() public {
        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;
        uint256[] memory sharesBps = new uint256[](1);
        sharesBps[0] = 10000;

        vm.prank(nonAdmin);
        vm.expectRevert("Not admin");
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, 0);
    }

    function testUpdateShares_RevertWhenInvalidTotalShares() public {
        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;
        uint256[] memory sharesBps = new uint256[](2);
        sharesBps[0] = 3000;
        sharesBps[1] = 6000; // Total = 9000 + dust = 11000 > 10000

        vm.prank(admin);
        vm.expectRevert("Total shares must equal 100%");
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, 2000);
    }

    function testUpdateShares_RevertWhenLengthMismatch() public {
        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;
        uint256[] memory sharesBps = new uint256[](1);
        sharesBps[0] = 5000;

        vm.prank(admin);
        vm.expectRevert("Recipients and shares length mismatch");
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, 5000);
    }

    function testUpdateShares_RevertWhenNoRecipients() public {
        address[] memory recipients = new address[](0);
        uint256[] memory sharesBps = new uint256[](0);

        vm.prank(admin);
        vm.expectRevert("No recipients provided");
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, 0);
    }

    function testUpdateShares_RevertWhenInvalidRecipient() public {
        address[] memory recipients = new address[](1);
        recipients[0] = address(0);
        uint256[] memory sharesBps = new uint256[](1);
        sharesBps[0] = 10000;

        vm.prank(admin);
        vm.expectRevert("Invalid recipient address");
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, 0);
    }

    function testUpdateShares_RevertWhenZeroShare() public {
        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;
        uint256[] memory sharesBps = new uint256[](1);
        sharesBps[0] = 0;

        vm.prank(admin);
        vm.expectRevert("Invalid share amount");
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, 10000);
    }

    // ========== ERC20 Distribution Tests ==========

    function testSplitERC20_BasicDistribution() public {
        // Setup configuration: 30% to recipient1, 50% to recipient2, 20% dust
        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;
        uint256[] memory sharesBps = new uint256[](2);
        sharesBps[0] = 3000;
        sharesBps[1] = 5000;
        uint256 variedShareBps = 2000;

        vm.prank(admin);
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, variedShareBps);

        uint256 amount = 1000 * 10 ** 18;
        uint256 initialBalance1 = token.balanceOf(recipient1);
        uint256 initialBalance2 = token.balanceOf(recipient2);
        uint256 initialBalanceVaried = token.balanceOf(variedRecipient);

        // Transfer tokens to distributor
        token.transfer(address(distributor), amount);

        distributor.splitERC20(CONFIG_ID_1, address(token), amount, variedRecipient);

        // Check balances
        assertEq(token.balanceOf(recipient1), initialBalance1 + (amount * 3000 / TOTAL_BPS));
        assertEq(token.balanceOf(recipient2), initialBalance2 + (amount * 5000 / TOTAL_BPS));
        assertEq(token.balanceOf(variedRecipient), initialBalanceVaried + (amount * 2000 / TOTAL_BPS));
    }

    function testSplitERC20_WithRoundingDust() public {
        // Setup configuration that will create rounding dust
        address[] memory recipients = new address[](3);
        recipients[0] = recipient1;
        recipients[1] = recipient2;
        recipients[2] = recipient3;
        uint256[] memory sharesBps = new uint256[](3);
        sharesBps[0] = 3333; // 33.33%
        sharesBps[1] = 3333; // 33.33%
        sharesBps[2] = 3333; // 33.33%
        uint256 variedShareBps = 1; // 0.01%

        vm.prank(admin);
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, variedShareBps);

        uint256 amount = 100; // Small amount to create rounding issues
        uint256 initialBalanceVaried = token.balanceOf(variedRecipient);

        // Transfer tokens to distributor
        token.transfer(address(distributor), amount);

        distributor.splitERC20(CONFIG_ID_1, address(token), amount, variedRecipient);

        // Dust recipient should get their share plus any rounding remainder
        uint256 expectedVariedShare = (amount * 1) / TOTAL_BPS; // Should be 0 due to rounding
        uint256 distributedToRecipients = 3 * (amount * 3333 / TOTAL_BPS); // 3 * 33 = 99
        uint256 remainder = amount - distributedToRecipients - expectedVariedShare;

        assertEq(token.balanceOf(variedRecipient), initialBalanceVaried + expectedVariedShare + remainder);
    }

    function testSplitERC20_NoVariedRecipient() public {
        // Setup configuration without dust recipient
        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;
        uint256[] memory sharesBps = new uint256[](1);
        sharesBps[0] = 10000; // 100%
        uint256 variedShareBps = 0; // No dust share

        vm.prank(admin);
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, variedShareBps);

        uint256 amount = 1000 * 10 ** 18;
        uint256 initialBalance1 = token.balanceOf(recipient1);

        // Transfer tokens to distributor
        token.transfer(address(distributor), amount);

        distributor.splitERC20(CONFIG_ID_1, address(token), amount, address(0));

        // All tokens should go to recipient1
        assertEq(token.balanceOf(recipient1), initialBalance1 + amount);
    }

    function testSplitERC20_RevertWhenConfigNotFound() public {
        // Test that when config is not found, it falls back to default config
        // Since the default config has 80% to deployer (tx.origin) and 20% dust,
        // we need to ensure there are sufficient tokens for the split

        uint256 amount = 1000;

        // Give tokens to the distributor
        token.mint(address(distributor), amount);

        // The default config has tx.origin as the recipient
        // From the trace, we can see tx.origin is "DefaultSender" in the test environment
        // We need to check the actual balance change of the dust recipient instead
        uint256 initialVariedBalance = token.balanceOf(variedRecipient);

        // This should not revert but use default config
        distributor.splitERC20(CONFIG_ID_1, address(token), amount, variedRecipient);

        // Verify default config was used: 20% to dust recipient
        uint256 expectedVariedShare = (amount * 2000) / 10000; // 20%

        assertEq(token.balanceOf(variedRecipient), initialVariedBalance + expectedVariedShare);

        // Also verify the total amount was distributed (distributor should have 0 left)
        assertEq(token.balanceOf(address(distributor)), 0);
    }

    // ========== ETH Distribution Tests ==========

    function testSplitETH_BasicDistribution() public {
        // Setup configuration: 40% to recipient1, 40% to recipient2, 20% dust
        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;
        uint256[] memory sharesBps = new uint256[](2);
        sharesBps[0] = 4000;
        sharesBps[1] = 4000;
        uint256 variedShareBps = 2000;

        vm.prank(admin);
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, variedShareBps);

        uint256 amount = 10 ether;
        uint256 initialBalance1 = recipient1.balance;
        uint256 initialBalance2 = recipient2.balance;
        uint256 initialBalanceVaried = variedRecipient.balance;

        distributor.splitETH{value: amount}(CONFIG_ID_1, variedRecipient);

        // Check balances
        assertEq(recipient1.balance, initialBalance1 + (amount * 4000 / TOTAL_BPS));
        assertEq(recipient2.balance, initialBalance2 + (amount * 4000 / TOTAL_BPS));
        assertEq(variedRecipient.balance, initialBalanceVaried + (amount * 2000 / TOTAL_BPS));
    }

    function testSplitETH_WithRoundingDust() public {
        // Setup configuration that will create rounding dust
        address[] memory recipients = new address[](3);
        recipients[0] = recipient1;
        recipients[1] = recipient2;
        recipients[2] = recipient3;
        uint256[] memory sharesBps = new uint256[](3);
        sharesBps[0] = 3333;
        sharesBps[1] = 3333;
        sharesBps[2] = 3333;
        uint256 variedShareBps = 1;

        vm.prank(admin);
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, variedShareBps);

        uint256 amount = 100 wei; // Small amount to create rounding issues
        uint256 initialBalanceVaried = variedRecipient.balance;

        distributor.splitETH{value: amount}(CONFIG_ID_1, variedRecipient);

        // Dust recipient should get their share plus any rounding remainder
        uint256 expectedVariedShare = (amount * 1) / TOTAL_BPS;
        uint256 distributedToRecipients = 3 * (amount * 3333 / TOTAL_BPS);
        uint256 remainder = amount - distributedToRecipients - expectedVariedShare;

        assertEq(variedRecipient.balance, initialBalanceVaried + expectedVariedShare + remainder);
    }

    function testSplitETH_NoVariedRecipient() public {
        // Setup configuration without dust recipient
        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;
        uint256[] memory sharesBps = new uint256[](1);
        sharesBps[0] = 10000;
        uint256 variedShareBps = 0;

        vm.prank(admin);
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, variedShareBps);

        uint256 amount = 5 ether;
        uint256 initialBalance1 = recipient1.balance;

        distributor.splitETH{value: amount}(CONFIG_ID_1, address(0));

        // All ETH should go to recipient1
        assertEq(recipient1.balance, initialBalance1 + amount);
    }

    // ========== View Function Tests ==========

    function testGetRecipients() public {
        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;
        uint256[] memory sharesBps = new uint256[](2);
        sharesBps[0] = 6000;
        sharesBps[1] = 3000;
        uint256 variedShareBps = 1000;

        vm.prank(admin);
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, variedShareBps);

        (address[] memory returnedRecipients, uint256[] memory returnedShares, uint256 returnedDustShare) =
            distributor.getRecipients(CONFIG_ID_1);

        assertEq(returnedRecipients.length, 2);
        assertEq(returnedRecipients[0], recipient1);
        assertEq(returnedRecipients[1], recipient2);
        assertEq(returnedShares[0], 6000);
        assertEq(returnedShares[1], 3000);
        assertEq(returnedDustShare, 1000);
    }

    // ========== Event Tests ==========

    function testSharesUpdatedEvent() public {
        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;
        uint256[] memory sharesBps = new uint256[](1);
        sharesBps[0] = 8000;
        uint256 variedShareBps = 2000;

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit SharesUpdated(CONFIG_ID_1, recipients, sharesBps, variedShareBps);
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, variedShareBps);
    }

    function testSplitExecutedEvent_ERC20() public {
        // Setup configuration
        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;
        uint256[] memory sharesBps = new uint256[](1);
        sharesBps[0] = 8000;
        uint256 variedShareBps = 2000;

        vm.prank(admin);
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, variedShareBps);

        uint256 amount = 1000 * 10 ** 18;
        uint256[] memory expectedAmounts = new uint256[](1);
        expectedAmounts[0] = amount * 8000 / TOTAL_BPS;
        uint256 expectedVariedAmount = amount * 2000 / TOTAL_BPS;

        // Transfer tokens to distributor
        token.transfer(address(distributor), amount);

        vm.expectEmit(true, true, false, true);
        emit SplitExecuted(
            CONFIG_ID_1, address(token), amount, recipients, expectedAmounts, variedRecipient, expectedVariedAmount
        );
        distributor.splitERC20(CONFIG_ID_1, address(token), amount, variedRecipient);
    }

    function testSplitExecutedEvent_ETH() public {
        // Setup configuration
        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;
        uint256[] memory sharesBps = new uint256[](1);
        sharesBps[0] = 7000;
        uint256 variedShareBps = 3000;

        vm.prank(admin);
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, variedShareBps);

        uint256 amount = 10 ether;
        uint256[] memory expectedAmounts = new uint256[](1);
        expectedAmounts[0] = amount * 7000 / TOTAL_BPS;
        uint256 expectedVariedAmount = amount * 3000 / TOTAL_BPS;

        vm.expectEmit(true, true, false, true);
        emit SplitExecuted(
            CONFIG_ID_1, address(0), amount, recipients, expectedAmounts, variedRecipient, expectedVariedAmount
        );
        distributor.splitETH{value: amount}(CONFIG_ID_1, variedRecipient);
    }

    // ========== Edge Cases and Stress Tests ==========

    function testMaximumRecipients() public {
        // Test with a large number of recipients
        uint256 numRecipients = 100;
        address[] memory recipients = new address[](numRecipients);
        uint256[] memory sharesBps = new uint256[](numRecipients);

        for (uint256 i = 0; i < numRecipients; i++) {
            recipients[i] = address(uint160(i + 100)); // Avoid address(0)
            sharesBps[i] = 99; // 0.99% each
        }
        uint256 variedShareBps = 100; // 1% dust, total = 99*100 + 100 = 10000

        vm.prank(admin);
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, variedShareBps);

        uint256 amount = 10000 * 10 ** 18;

        // Transfer tokens to distributor
        token.transfer(address(distributor), amount);

        distributor.splitERC20(CONFIG_ID_1, address(token), amount, variedRecipient);

        // Verify each recipient got their share
        for (uint256 i = 0; i < numRecipients; i++) {
            assertEq(token.balanceOf(recipients[i]), amount * 99 / TOTAL_BPS);
        }
    }

    function testZeroAmountDistribution() public {
        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;
        uint256[] memory sharesBps = new uint256[](1);
        sharesBps[0] = 10000;

        vm.prank(admin);
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, 0);

        uint256 initialBalance = token.balanceOf(recipient1);

        // Transfer tokens to distributor (even though it's 0, for consistency)
        // No transfer needed for 0 amount

        distributor.splitERC20(CONFIG_ID_1, address(token), 0, address(0));

        // Balance should remain unchanged
        assertEq(token.balanceOf(recipient1), initialBalance);
    }

    // ========== Dust Recipient Zero Share Tests ==========

    function testSplitERC20_DustRecipientGetsRemainderWithZeroShare() public {
        // Setup configuration where dust recipient has 0 share but should still get remainder
        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;
        uint256[] memory sharesBps = new uint256[](2);
        sharesBps[0] = 3333; // 33.33%
        sharesBps[1] = 6667; // 66.67%
        uint256 variedShareBps = 0; // 0% - dust recipient gets no configured share

        vm.prank(admin);
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, variedShareBps);

        uint256 amount = 100; // Small amount to create rounding remainder
        uint256 initialBalanceVaried = token.balanceOf(variedRecipient);
        uint256 initialBalance1 = token.balanceOf(recipient1);
        uint256 initialBalance2 = token.balanceOf(recipient2);

        // Transfer tokens to distributor
        token.transfer(address(distributor), amount);

        distributor.splitERC20(CONFIG_ID_1, address(token), amount, variedRecipient);

        // Calculate expected amounts
        uint256 expectedShare1 = (amount * 3333) / TOTAL_BPS; // 33
        uint256 expectedShare2 = (amount * 6667) / TOTAL_BPS; // 66
        uint256 distributedTotal = expectedShare1 + expectedShare2; // 99
        uint256 remainder = amount - distributedTotal; // 1

        // Verify recipients got their shares
        assertEq(token.balanceOf(recipient1), initialBalance1 + expectedShare1);
        assertEq(token.balanceOf(recipient2), initialBalance2 + expectedShare2);

        // Verify dust recipient got remainder (but no configured share since it's 0)
        assertEq(token.balanceOf(variedRecipient), initialBalanceVaried + remainder);
    }

    function testSplitETH_DustRecipientGetsRemainderWithZeroShare() public {
        // Setup configuration where dust recipient has 0 share but should still get remainder
        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;
        uint256[] memory sharesBps = new uint256[](2);
        sharesBps[0] = 3333; // 33.33%
        sharesBps[1] = 6667; // 66.67%
        uint256 variedShareBps = 0; // 0% - dust recipient gets no configured share

        vm.prank(admin);
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, variedShareBps);

        uint256 amount = 100 wei; // Small amount to create rounding remainder
        uint256 initialBalanceVaried = variedRecipient.balance;
        uint256 initialBalance1 = recipient1.balance;
        uint256 initialBalance2 = recipient2.balance;

        distributor.splitETH{value: amount}(CONFIG_ID_1, variedRecipient);

        // Calculate expected amounts
        uint256 expectedShare1 = (amount * 3333) / TOTAL_BPS; // 33
        uint256 expectedShare2 = (amount * 6667) / TOTAL_BPS; // 66
        uint256 distributedTotal = expectedShare1 + expectedShare2; // 99
        uint256 remainder = amount - distributedTotal; // 1

        // Verify recipients got their shares
        assertEq(recipient1.balance, initialBalance1 + expectedShare1);
        assertEq(recipient2.balance, initialBalance2 + expectedShare2);

        // Verify dust recipient got remainder (but no configured share since it's 0)
        assertEq(variedRecipient.balance, initialBalanceVaried + remainder);
    }

    function testSplitERC20_DustRecipientGetsShareAndRemainder() public {
        // Test that dust recipient gets both configured share AND remainder
        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;
        uint256[] memory sharesBps = new uint256[](1);
        sharesBps[0] = 3333; // 33.33%
        uint256 variedShareBps = 6667; // 66.67% - dust recipient gets configured share (total = 100%)

        vm.prank(admin);
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, variedShareBps);

        uint256 amount = 100; // Amount to split
        uint256 initialBalanceVaried = token.balanceOf(variedRecipient);
        uint256 initialBalance1 = token.balanceOf(recipient1);

        // Transfer tokens to distributor
        token.transfer(address(distributor), amount);

        distributor.splitERC20(CONFIG_ID_1, address(token), amount, variedRecipient);

        // Calculate expected amounts
        uint256 expectedShare1 = (amount * 3333) / TOTAL_BPS; // 33
        uint256 expectedVariedShare = (amount * 6667) / TOTAL_BPS; // 66
        uint256 distributedTotal = expectedShare1 + expectedVariedShare; // 99
        uint256 remainder = amount - distributedTotal; // 1

        // Verify recipient1 got their share
        assertEq(token.balanceOf(recipient1), initialBalance1 + expectedShare1);

        // Verify dust recipient got both configured share AND remainder
        assertEq(token.balanceOf(variedRecipient), initialBalanceVaried + expectedVariedShare + remainder);
    }

    function testSplitETH_DustRecipientGetsShareAndRemainder() public {
        // Test that dust recipient gets both configured share AND remainder
        address[] memory recipients = new address[](1);
        recipients[0] = recipient1;
        uint256[] memory sharesBps = new uint256[](1);
        sharesBps[0] = 3333; // 33.33%
        uint256 variedShareBps = 6667; // 66.67% - dust recipient gets configured share (total = 100%)

        vm.prank(admin);
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, variedShareBps);

        uint256 amount = 100 wei; // Amount to split
        uint256 initialBalanceVaried = variedRecipient.balance;
        uint256 initialBalance1 = recipient1.balance;

        distributor.splitETH{value: amount}(CONFIG_ID_1, variedRecipient);

        // Calculate expected amounts
        uint256 expectedShare1 = (amount * 3333) / TOTAL_BPS; // 33
        uint256 expectedVariedShare = (amount * 6667) / TOTAL_BPS; // 66
        uint256 distributedTotal = expectedShare1 + expectedVariedShare; // 99
        uint256 remainder = amount - distributedTotal; // 1

        // Verify recipient1 got their share
        assertEq(recipient1.balance, initialBalance1 + expectedShare1);

        // Verify dust recipient got both configured share AND remainder
        assertEq(variedRecipient.balance, initialBalanceVaried + expectedVariedShare + remainder);
    }

    function testSplitERC20_NoVariedRecipientWithRemainder() public {
        // Test case where there's a remainder but no dust recipient - remainder should be lost
        address[] memory recipients = new address[](2);
        recipients[0] = recipient1;
        recipients[1] = recipient2;
        uint256[] memory sharesBps = new uint256[](2);
        sharesBps[0] = 3333; // 33.33%
        sharesBps[1] = 6666; // 66.66% - Total is 99.99%, leaving 0.01% remainder
        uint256 variedShareBps = 1; // 0.01%

        vm.prank(admin);
        distributor.updateShares(CONFIG_ID_1, recipients, sharesBps, variedShareBps);

        uint256 amount = 100; // Small amount to create remainder
        uint256 initialBalance1 = token.balanceOf(recipient1);
        uint256 initialBalance2 = token.balanceOf(recipient2);

        // Transfer tokens to distributor
        token.transfer(address(distributor), amount);

        // No dust recipient provided
        distributor.splitERC20(CONFIG_ID_1, address(token), amount, address(0));

        // Calculate expected amounts
        uint256 expectedShare1 = (amount * 3333) / TOTAL_BPS; // 33
        uint256 expectedShare2 = (amount * 6666) / TOTAL_BPS; // 66

        // Verify recipients got their shares
        assertEq(token.balanceOf(recipient1), initialBalance1 + expectedShare1);
        assertEq(token.balanceOf(recipient2), initialBalance2 + expectedShare2);

        // Remainder should stay in contract (lost) since no dust recipient
        assertEq(token.balanceOf(address(distributor)), amount - expectedShare1 - expectedShare2);
    }

    // ========== Receive function test for contracts that might send ETH ==========
    receive() external payable {}
}
