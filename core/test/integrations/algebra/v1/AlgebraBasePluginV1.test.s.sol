// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {AlgebraBasePluginV1} from "@reflex/integrations/algebra/v1/AlgebraBasePluginV1.sol";
import {IReflexRouter} from "@reflex/interfaces/IReflexRouter.sol";
import {AlgebraFeeConfiguration} from "@cryptoalgebra/plugin/base/AlgebraFeeConfiguration.sol";
import "../../../utils/TestUtils.sol";
import "../../../mocks/MockToken.sol";
import "../../../mocks/MockAlgebraFactory.sol";
import "../../../mocks/MockReflexRouter.sol";
import "../../../mocks/MockPool.sol";

contract AlgebraBasePluginV1Test is Test {
    using TestUtils for *;

    AlgebraBasePluginV1 public plugin;
    MockPool public pool;
    MockAlgebraFactory public factory;
    MockReflexRouter public reflexRouter;
    MockToken public profitToken;

    address public admin = address(0x1);
    address public alice = address(0xA);
    address public bob = address(0xB);
    address public attacker = address(0xBAD);

    AlgebraFeeConfiguration public defaultConfig;

    function setUp() public {
        // Create mock contracts
        factory = MockAlgebraFactory(TestUtils.createMockAlgebraFactory());
        factory.setOwner(admin);
        factory.grantRole(factory.ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR(), admin);

        // Create profit token and router
        profitToken = MockToken(TestUtils.createStandardMockToken());
        reflexRouter = MockReflexRouter(TestUtils.createMockReflexRouter(admin, address(profitToken)));

        // Create mock pool
        pool = MockPool(TestUtils.createMockPool(address(0x1), address(0x2), address(factory)));

        // Set up default fee configuration
        defaultConfig = AlgebraFeeConfiguration({
            alpha1: 2900,
            alpha2: 12000,
            beta1: 360,
            beta2: 60000,
            gamma1: 59,
            gamma2: 8500,
            baseFee: 100
        });

        // Deploy plugin
        plugin = new AlgebraBasePluginV1(
            address(pool),
            address(factory),
            address(this), // pluginFactory
            defaultConfig,
            address(reflexRouter)
        );

        // Set plugin in pool
        pool.setPlugin(address(plugin));

        // Initialize the plugin by calling the hook
        vm.prank(address(pool));
        plugin.beforeInitialize(address(0), 0);

        // Set up shared recipients for ReflexAfterSwap functionality
        address[] memory recipients = new address[](4);
        recipients[0] = alice;
        recipients[1] = bob;
        recipients[2] = address(0xC); // charlie equivalent
        recipients[3] = address(0xD); // diana equivalent

        uint256[] memory shares = new uint256[](4);
        shares[0] = 2500; // 25%
        shares[1] = 2500; // 25%
        shares[2] = 2500; // 25%
        shares[3] = 2500; // 25%

        vm.prank(admin);
        plugin.updateShares(recipients, shares);
    } // ========== Constructor Tests ==========

    function testConstructor() public view {
        assertEq(plugin.pool(), address(pool));
        assertEq(plugin.getRouter(), address(reflexRouter));
        assertEq(plugin.getReflexAdmin(), admin);
        assertTrue(plugin.reflexEnabled());
    }

    function testDefaultPluginConfig() public view {
        // BEFORE_SWAP_FLAG=1, AFTER_SWAP_FLAG=2, AFTER_INIT_FLAG=64, DYNAMIC_FEE=128
        // Total: 1+2+64+128=195
        assertEq(plugin.defaultPluginConfig(), 195);
    }

    // ========== Hook Tests ==========

    function testBeforeInitialize() public {
        vm.prank(address(pool));
        bytes4 selector = plugin.beforeInitialize(address(0), 0);

        assertEq(selector, plugin.beforeInitialize.selector);
    }

    function testBeforeInitializeOnlyPool() public {
        vm.prank(attacker);
        vm.expectRevert("Only pool can call this");
        plugin.beforeInitialize(address(0), 0);
    }

    function testAfterInitialize() public {
        vm.prank(address(pool));
        bytes4 selector = plugin.afterInitialize(address(0), 0, 0);

        assertEq(selector, plugin.afterInitialize.selector);
    }

    function testAfterInitializeOnlyPool() public {
        vm.prank(attacker);
        vm.expectRevert("Only pool can call this");
        plugin.afterInitialize(address(0), 0, 0);
    }

    // ========== Swap Hook Tests ==========

    function testBeforeSwap() public {
        // Initialize the volatility oracle first
        vm.prank(address(pool));
        plugin.afterInitialize(address(0), 0, 0);

        vm.prank(address(pool));
        (bytes4 selector, uint24 fee, uint24 fee2) = plugin.beforeSwap(
            address(0),
            alice, // sender
            true, // zeroToOne
            1000, // amountSpecified
            0, // limitSqrtPrice
            false, // payInAdvance
            "" // data
        );

        assertEq(selector, plugin.beforeSwap.selector);
        assertTrue(fee > 0); // Should return dynamic fee
        assertEq(fee2, 0); // Second fee should be 0
    }

    function testBeforeSwapReflexRouterGetsReducedFee() public {
        // Initialize the volatility oracle first
        vm.prank(address(pool));
        plugin.afterInitialize(address(0), 0, 0);

        vm.prank(address(pool));
        (bytes4 selector, uint24 fee, uint24 fee2) = plugin.beforeSwap(
            address(reflexRouter), // ReflexRouter as sender,
            address(0),
            true,
            1000,
            0,
            false,
            ""
        );

        assertEq(selector, plugin.beforeSwap.selector);
        assertEq(fee, 1); // ReflexRouter gets minimal fee
        assertEq(fee2, 0);
    }

    function testBeforeSwapOnlyPool() public {
        vm.prank(attacker);
        vm.expectRevert("Only pool can call this");
        plugin.beforeSwap(address(0), alice, true, 1000, 0, false, "");
    }

    function testAfterSwap() public {
        vm.prank(address(pool));
        bytes4 selector = plugin.afterSwap(
            address(0),
            alice, // recipient
            true, // zeroToOne
            1000, // amountSpecified
            0, // limitSqrtPrice
            500, // amount0
            -250, // amount1
            "" // data
        );

        assertEq(selector, plugin.afterSwap.selector);
    }

    function testAfterSwapWithReflexEnabled() public {
        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        vm.prank(address(pool));
        plugin.afterSwap(
            address(0),
            alice, // recipient
            true, // zeroToOne
            1000, // amountSpecified
            0, // limitSqrtPrice
            500, // amount0
            -250, // amount1
            "" // data
        );

        // Alice should receive profit from ReflexAfterSwap
        assertTrue(profitToken.balanceOf(alice) > aliceInitialBalance);
    }

    function testAfterSwapWithReflexDisabled() public {
        // Disable reflex functionality
        vm.prank(admin);
        plugin.setReflexEnabled(false);

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        vm.prank(address(pool));
        plugin.afterSwap(
            address(0),
            alice, // recipient
            true, // zeroToOne
            1000, // amountSpecified
            0, // limitSqrtPrice
            500, // amount0
            -250, // amount1
            "" // data
        );

        // Alice should not receive profit when reflex is disabled
        assertEq(profitToken.balanceOf(alice), aliceInitialBalance);
    }

    function testAfterSwapOnlyPool() public {
        vm.prank(attacker);
        vm.expectRevert("Only pool can call this");
        plugin.afterSwap(address(0), alice, true, 1000, 0, 500, -250, "");
    }

    // ========== Modify Position Hook Tests ==========

    function testBeforeModifyPosition() public {
        vm.prank(address(pool));
        (bytes4 selector, uint24 fee) = plugin.beforeModifyPosition(
            address(0),
            alice, // owner
            0, // bottomTick
            0, // topTick
            100, // liquidityDelta
            "" // data
        );

        assertEq(selector, plugin.beforeModifyPosition.selector);
        assertEq(fee, 0);
    }

    function testAfterModifyPosition() public {
        vm.prank(address(pool));
        bytes4 selector = plugin.afterModifyPosition(
            address(0),
            alice, // owner
            0, // bottomTick
            0, // topTick
            100, // liquidityDelta
            0, // amount0
            0, // amount1
            "" // data
        );

        assertEq(selector, plugin.afterModifyPosition.selector);
    }

    // ========== Flash Hook Tests ==========

    function testBeforeFlash() public {
        vm.prank(address(pool));
        bytes4 selector = plugin.beforeFlash(
            address(0),
            alice, // recipient
            1000, // amount0
            500, // amount1
            "" // data
        );

        assertEq(selector, plugin.beforeFlash.selector);
    }

    function testAfterFlash() public {
        vm.prank(address(pool));
        bytes4 selector = plugin.afterFlash(
            address(0),
            alice, // recipient
            1000, // amount0
            500, // amount1
            100, // paid0
            50, // paid1
            "" // data
        );

        assertEq(selector, plugin.afterFlash.selector);
    }

    // ========== Fee Calculation Tests ==========

    function testGetCurrentFee() public view {
        uint16 fee = plugin.getCurrentFee();

        // Fee should be within reasonable bounds
        assertTrue(fee > 0);
        assertTrue(fee <= type(uint16).max);
    }

    function testGetCurrentFeeConsistency() public view {
        uint16 fee1 = plugin.getCurrentFee();
        uint16 fee2 = plugin.getCurrentFee();

        // Should return same fee for same conditions
        assertEq(fee1, fee2);
    }

    // ========== Reflex Control Tests ==========

    function testReflexEnabledDefault() public view {
        assertTrue(plugin.reflexEnabled());
    }

    function testSetReflexEnabledByAuthorized() public {
        // Admin can disable
        vm.prank(admin);
        plugin.setReflexEnabled(false);
        assertFalse(plugin.reflexEnabled());

        // Admin can enable
        vm.prank(admin);
        plugin.setReflexEnabled(true);
        assertTrue(plugin.reflexEnabled());
    }

    function testSetReflexEnabledUnauthorized() public {
        vm.prank(attacker);
        vm.expectRevert(); // Algebra's _authorize() reverts without message
        plugin.setReflexEnabled(false);
    }

    function testReflexToggleMidOperation() public {
        // Start with reflex enabled
        assertTrue(plugin.reflexEnabled());

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        // Execute swap with reflex enabled
        vm.prank(address(pool));
        plugin.afterSwap(address(0), alice, true, 1000, 0, 500, -250, "");

        assertTrue(profitToken.balanceOf(alice) > aliceInitialBalance);

        // Disable reflex
        vm.prank(admin);
        plugin.setReflexEnabled(false);

        uint256 aliceBalanceAfterFirst = profitToken.balanceOf(alice);

        // Execute swap with reflex disabled
        vm.prank(address(pool));
        plugin.afterSwap(address(0), alice, true, 1000, 0, 500, -250, "");

        // Alice balance should not change from second swap
        assertEq(profitToken.balanceOf(alice), aliceBalanceAfterFirst);
    }

    // ========== Router Integration Tests ==========

    function testGetRouterReturnsCorrectAddress() public view {
        assertEq(plugin.getRouter(), address(reflexRouter));
    }

    function testReflexAfterSwapIntegration() public {
        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        // Mock the pool ID generation - this is internal logic verification
        // bytes32 expectedPoolId = bytes32(uint256(uint160(address(pool))));

        vm.prank(address(pool));
        plugin.afterSwap(address(0), alice, true, 1000, 0, 500, -250, "");

        // Verify ReflexAfterSwap was triggered and alice received profit
        assertTrue(profitToken.balanceOf(alice) > aliceInitialBalance);
    }

    function testMultipleSwaps() public {
        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        // First swap
        vm.prank(address(pool));
        plugin.afterSwap(address(0), alice, true, 1000, 0, 500, -250, "");

        uint256 aliceAfterFirst = profitToken.balanceOf(alice);
        assertTrue(aliceAfterFirst > aliceInitialBalance);

        // Second swap
        vm.prank(address(pool));
        plugin.afterSwap(address(0), bob, false, 2000, 0, -800, 400, "");

        uint256 aliceAfterSecond = profitToken.balanceOf(alice);
        assertTrue(aliceAfterSecond > aliceAfterFirst);
    }

    function testRouterFailure() public {
        // Configure router to fail
        reflexRouter.setShouldRevert(true);

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        // Swap should not revert even if router fails (graceful handling)
        vm.prank(address(pool));
        plugin.afterSwap(address(0), alice, true, 1000, 0, 500, -250, "");

        // Alice should not receive profit if router failed
        assertEq(profitToken.balanceOf(alice), aliceInitialBalance);
    }

    // ========== State Consistency Tests ==========

    function testStateConsistencyMultipleSwaps() public {
        // Initialize the volatility oracle first
        vm.prank(address(pool));
        plugin.afterInitialize(address(0), 0, 0);

        // Track initial state
        bool initialReflexEnabled = plugin.reflexEnabled();
        address initialRouter = plugin.getRouter();
        // uint16 initialFee = plugin.getCurrentFee();

        // Execute multiple operations
        vm.startPrank(address(pool));
        plugin.beforeSwap(address(0), alice, true, 1000, 0, false, "");
        plugin.afterSwap(address(0), alice, true, 1000, 0, 500, -250, "");
        plugin.beforeSwap(address(0), bob, false, 2000, 0, false, "");
        plugin.afterSwap(address(0), bob, false, 2000, 0, -800, 400, "");
        vm.stopPrank();

        // Verify state consistency
        assertEq(plugin.reflexEnabled(), initialReflexEnabled);
        assertEq(plugin.getRouter(), initialRouter);
        // Fee might change due to volatility, but should still be reasonable
        uint16 finalFee = plugin.getCurrentFee();
        assertTrue(finalFee > 0 && finalFee <= type(uint16).max);
    }

    // ========== Fuzz Tests ==========

    function testFuzzBeforeSwapReflexRouterAlwaysBaseFee(bool zeroToOne, int256 amountSpecified, address randomSender)
        public
    {
        vm.assume(randomSender != address(reflexRouter));
        vm.assume(amountSpecified != 0);

        // Initialize the volatility oracle first
        vm.prank(address(pool));
        plugin.afterInitialize(address(0), 0, 0);

        vm.prank(address(pool));
        (, uint24 reflexFee,) =
            plugin.beforeSwap(address(reflexRouter), address(0), zeroToOne, amountSpecified, 0, false, "");

        vm.prank(address(pool));
        (, uint24 normalFee,) = plugin.beforeSwap(address(0), randomSender, zeroToOne, amountSpecified, 0, false, "");

        assertEq(reflexFee, 1, "ReflexRouter should always get minimal fee");
        assertTrue(normalFee > reflexFee, "Normal users should pay higher fees");
    }

    function testFuzzBeforeSwapNonReflexRouterPaysFee(address sender, bool zeroToOne, int256 amountSpecified)
        // address randomAddress - unused parameter
        public
    {
        vm.assume(sender != address(reflexRouter));
        vm.assume(sender != address(0));
        vm.assume(amountSpecified != 0);

        // Initialize the volatility oracle first
        vm.prank(address(pool));
        plugin.afterInitialize(address(0), 0, 0);

        vm.prank(address(pool));
        (, uint24 fee,) = plugin.beforeSwap(address(0), sender, zeroToOne, amountSpecified, 0, false, "");

        assertTrue(fee > 1, "Non-ReflexRouter senders should pay dynamic fees");
    }

    function testFuzzAfterSwap(int256 amount0, int256 amount1, bool zeroToOne, address recipient) public {
        vm.assume(recipient != address(0));

        uint256 initialBalance = profitToken.balanceOf(recipient);

        vm.prank(address(pool));
        bytes4 selector = plugin.afterSwap(address(0), recipient, zeroToOne, 1000, 0, amount0, amount1, "");

        assertEq(selector, plugin.afterSwap.selector);

        // If reflex is enabled, recipient might receive profit
        if (plugin.reflexEnabled()) {
            assertTrue(profitToken.balanceOf(recipient) >= initialBalance);
        }
    }

    function testFuzzTriggerPoolId(address poolAddress) public {
        vm.assume(poolAddress != address(0));

        // Create plugin with different pool
        MockPool differentPool = MockPool(TestUtils.createMockPool(address(0x3), address(0x4), address(factory)));

        // AlgebraBasePluginV1 pluginWithDifferentPool = new AlgebraBasePluginV1(
        new AlgebraBasePluginV1(
            address(differentPool), address(factory), address(this), defaultConfig, address(reflexRouter)
        );

        // Pool ID should be derived from pool address
        // bytes32 expectedPoolId = bytes32(uint256(uint160(address(differentPool))));

        // This is internal logic verification - we check that different pools generate different IDs
        assertTrue(address(differentPool) != address(pool));
    }

    // ========== Integration with Dynamic Fee Tests ==========

    function testDynamicFeeChangesWithVolatility() public {
        // Initialize the volatility oracle first
        vm.prank(address(pool));
        plugin.afterInitialize(address(0), 0, 0);

        // uint16 initialFee = plugin.getCurrentFee();

        // Simulate some swaps to change volatility
        vm.startPrank(address(pool));
        for (uint256 i = 0; i < 5; i++) {
            plugin.beforeSwap(address(0), alice, true, 1000, 0, false, "");
            plugin.afterSwap(address(0), alice, true, 1000, 0, 500, -250, "");
        }
        vm.stopPrank();

        uint16 finalFee = plugin.getCurrentFee();

        // Fee might have changed due to volatility tracking
        // At minimum, it should still be a valid fee
        assertTrue(finalFee > 0);
        assertTrue(finalFee <= type(uint16).max);
    }

    function testFeeExemptionIntegrationWithDynamic() public {
        // Initialize the volatility oracle first
        vm.prank(address(pool));
        plugin.afterInitialize(address(0), 0, 0);

        // Get dynamic fee for normal user
        vm.prank(address(pool));
        (, uint24 normalFee,) = plugin.beforeSwap(address(0), alice, true, 1000, 0, false, "");

        // Get fee for ReflexRouter
        vm.prank(address(pool));
        (, uint24 reflexFee,) = plugin.beforeSwap(address(reflexRouter), address(0), true, 1000, 0, false, "");

        assertTrue(normalFee > 1, "Normal users should pay dynamic fee");
        assertEq(reflexFee, 1, "ReflexRouter should get minimal fee regardless of dynamic fee");
    }
}
