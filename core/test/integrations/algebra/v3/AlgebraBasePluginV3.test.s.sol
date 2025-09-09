// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Test} from "forge-std/Test.sol";
import {AlgebraBasePluginV3} from "@reflex/integrations/algebra/full/AlgebraBasePluginV3.sol";
import {IReflexRouter} from "@reflex/interfaces/IReflexRouter.sol";
import {
    TestUtils, MockToken, MockReflexRouter, MockAlgebraFactory, MockAlgebraPool
} from "../../../utils/TestUtils.sol";
import {IAlgebraPlugin} from "@cryptoalgebra/core/interfaces/plugin/IAlgebraPlugin.sol";

contract AlgebraBasePluginV3Test is Test {
    using TestUtils for *;

    // Define the constant for authorization
    bytes32 public constant ALGEBRA_BASE_PLUGIN_MANAGER = keccak256("ALGEBRA_BASE_PLUGIN_MANAGER");

    AlgebraBasePluginV3 public plugin;
    MockAlgebraPool public pool;
    MockAlgebraFactory public factory;
    MockReflexRouter public reflexRouter;
    address public pluginFactory;

    address public token0;
    address public token1;
    address public recipient;
    address public admin;

    uint16 public constant BASE_FEE = 500;

    event AfterSwapCalled(
        bytes32 indexed triggerPoolId, int256 amount0Out, int256 amount1Out, bool zeroToOne, address recipient
    );

    function setUp() public {
        admin = makeAddr("admin");
        recipient = makeAddr("recipient");
        pluginFactory = makeAddr("pluginFactory");

        // Create mock tokens
        token0 = address(TestUtils.createMockToken("Token0", "T0", 1000000e18));
        token1 = address(TestUtils.createMockToken("Token1", "T1", 1000000e18));

        // Create mock contracts
        pool = MockAlgebraPool(TestUtils.createMockAlgebraPool(token0, token1));
        factory = MockAlgebraFactory(TestUtils.createMockAlgebraFactory());
        reflexRouter = MockReflexRouter(TestUtils.createMockReflexRouter(admin));

        // Set pool in factory
        factory.setPool(address(pool), true);

        // Grant the ALGEBRA_BASE_PLUGIN_MANAGER role to admin for testing
        factory.grantRole(ALGEBRA_BASE_PLUGIN_MANAGER, admin);

        // Create plugin
        vm.prank(pluginFactory);
        plugin =
            new AlgebraBasePluginV3(address(pool), address(factory), pluginFactory, BASE_FEE, address(reflexRouter), bytes32(0));

        // Set plugin in pool
        pool.setPlugin(address(plugin));
    }

    /// @notice Helper function to initialize the plugin for beforeSwap tests
    function _initializePlugin() internal {
        plugin.initializePlugin();
    }

    // ===== AfterSwap Hook Tests =====

    function test_AfterSwap_BasicFunctionality() public {
        int256 amount0Out = 1000e18;
        int256 amount1Out = -500e18;
        bool zeroToOne = true;

        vm.prank(address(pool));
        bytes4 selector = plugin.afterSwap(
            address(0), // sender
            recipient,
            zeroToOne,
            0, // amountSpecified
            0, // sqrtPriceX96After
            amount0Out,
            amount1Out,
            ""
        );

        assertEq(selector, IAlgebraPlugin.afterSwap.selector);

        // Verify reflexAfterSwap was called
        assertEq(reflexRouter.getTriggerBackrunCallsLength(), 1);

        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.triggerPoolId, bytes32(uint256(uint160(address(pool)))));
        assertEq(call.swapAmountIn, uint112(uint256(amount0Out > 0 ? amount0Out : amount1Out)));
        assertEq(call.token0In, zeroToOne);
        assertEq(call.recipient, recipient);
    }

    function test_AfterSwap_OnlyPoolCanCall() public {
        vm.expectRevert();
        plugin.afterSwap(address(0), recipient, true, 0, 0, 1000e18, -500e18, "");
    }

    function test_AfterSwap_ZeroToOneFalse() public {
        int256 amount0Out = -1000e18;
        int256 amount1Out = 500e18;
        bool zeroToOne = false;

        vm.prank(address(pool));
        plugin.afterSwap(address(0), recipient, zeroToOne, 0, 0, amount0Out, amount1Out, "");

        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.token0In, false);
        assertEq(call.swapAmountIn, uint112(uint256(amount1Out)));
        assertEq(call.recipient, recipient);
    }

    function test_AfterSwap_WithDifferentRecipients() public {
        address recipient1 = makeAddr("recipient1");
        address recipient2 = makeAddr("recipient2");

        // First swap
        vm.prank(address(pool));
        plugin.afterSwap(address(0), recipient1, true, 0, 0, 1000e18, -500e18, "");

        // Second swap
        vm.prank(address(pool));
        plugin.afterSwap(address(0), recipient2, false, 0, 0, -800e18, 400e18, "");

        assertEq(reflexRouter.getTriggerBackrunCallsLength(), 2);

        MockReflexRouter.TriggerBackrunCall memory call1 = reflexRouter.getTriggerBackrunCall(0);
        MockReflexRouter.TriggerBackrunCall memory call2 = reflexRouter.getTriggerBackrunCall(1);

        assertEq(call1.recipient, recipient1);
        assertEq(call2.recipient, recipient2);
    }

    function test_AfterSwap_LargeAmounts() public {
        int256 amount0Out = type(int128).max;
        int256 amount1Out = type(int128).min;

        vm.prank(address(pool));
        plugin.afterSwap(address(0), recipient, true, 0, 0, amount0Out, amount1Out, "");

        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.swapAmountIn, uint112(uint256(amount0Out)));
        assertEq(call.token0In, true);
    }

    function test_AfterSwap_ZeroAmounts() public {
        vm.prank(address(pool));
        plugin.afterSwap(
            address(0),
            recipient,
            true,
            0,
            0,
            0, // amount0Out
            0, // amount1Out
            ""
        );

        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.swapAmountIn, 0);
        assertEq(call.token0In, true);
    }

    // ===== ReflexAfterSwap Integration Tests =====

    function test_ReflexAfterSwap_Integration() public {
        // Setup: Give the router some tokens to return as profit
        MockToken profitToken = MockToken(token0);
        profitToken.mint(address(reflexRouter), 1000e18);

        reflexRouter.setMockProfit(1000e18);
        reflexRouter.setProfitToken(token0);

        vm.prank(address(pool));
        plugin.afterSwap(address(0), recipient, true, 0, 0, 1000e18, -500e18, "");

        // Verify the backrun was called with correct parameters
        assertEq(reflexRouter.getTriggerBackrunCallsLength(), 1);

        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.triggerPoolId, bytes32(uint256(uint160(address(pool)))));
    }

    function test_ReflexAfterSwap_RouterFailure() public {
        reflexRouter.setShouldRevert(true);

        // Should not revert even if router fails - this is the failsafe behavior
        vm.prank(address(pool));
        plugin.afterSwap(address(0), recipient, true, 0, 0, 1000e18, -500e18, "");

        // Router call should have been attempted but failed gracefully
        // No backrun calls should be recorded due to the failsafe catch block
        assertEq(reflexRouter.getTriggerBackrunCallsLength(), 0);
    }

    function test_ReflexAfterSwap_MultipleSwaps() public {
        // Setup: Give the router some tokens to return as profit
        MockToken profitToken = MockToken(token0);
        profitToken.mint(address(reflexRouter), 2000e18); // Enough for multiple swaps

        reflexRouter.setMockProfit(500e18);
        reflexRouter.setProfitToken(token0);

        // First swap
        vm.prank(address(pool));
        plugin.afterSwap(address(0), recipient, true, 0, 0, 1000e18, -500e18, "");

        // Second swap
        vm.prank(address(pool));
        plugin.afterSwap(address(0), recipient, false, 0, 0, -800e18, 400e18, "");

        // Third swap
        vm.prank(address(pool));
        plugin.afterSwap(address(0), recipient, true, 0, 0, 200e18, -100e18, "");

        assertEq(reflexRouter.getTriggerBackrunCallsLength(), 3);

        // Verify each call has unique parameters
        MockReflexRouter.TriggerBackrunCall memory call1 = reflexRouter.getTriggerBackrunCall(0);
        MockReflexRouter.TriggerBackrunCall memory call2 = reflexRouter.getTriggerBackrunCall(1);
        MockReflexRouter.TriggerBackrunCall memory call3 = reflexRouter.getTriggerBackrunCall(2);

        assertEq(call1.token0In, true);
        assertEq(call2.token0In, false);
        assertEq(call3.token0In, true);

        assertEq(call1.swapAmountIn, 1000e18);
        assertEq(call2.swapAmountIn, 400e18);
        assertEq(call3.swapAmountIn, 200e18);
    }

    // ===== Fuzz Tests =====

    function testFuzz_AfterSwap(int256 amount0Out, int256 amount1Out, bool zeroToOne, address fuzzRecipient) public {
        vm.assume(fuzzRecipient != address(0));

        vm.prank(address(pool));
        bytes4 selector = plugin.afterSwap(address(0), fuzzRecipient, zeroToOne, 0, 0, amount0Out, amount1Out, "");

        assertEq(selector, IAlgebraPlugin.afterSwap.selector);

        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        uint256 expectedSwapAmount = uint256(amount0Out > 0 ? amount0Out : amount1Out);
        assertEq(call.swapAmountIn, uint112(expectedSwapAmount));
        assertEq(call.token0In, zeroToOne);
        assertEq(call.recipient, fuzzRecipient);
    }

    function testFuzz_TriggerPoolId(address poolAddress) public {
        vm.assume(poolAddress != address(0));

        // Create a new plugin with different pool
        MockAlgebraPool newPool = new MockAlgebraPool(token0, token1);
        factory.setPool(address(newPool), true);

        vm.prank(pluginFactory);
        AlgebraBasePluginV3 newPlugin =
            new AlgebraBasePluginV3(address(newPool), address(factory), pluginFactory, BASE_FEE, address(reflexRouter), bytes32(0));

        newPool.setPlugin(address(newPlugin));

        vm.prank(address(newPool));
        newPlugin.afterSwap(address(0), recipient, true, 0, 0, 1000e18, -500e18, "");

        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.triggerPoolId, bytes32(uint256(uint160(address(newPool)))));
    }

    // ===== Edge Cases =====

    function test_AfterSwap_MaxValues() public {
        vm.prank(address(pool));
        plugin.afterSwap(
            address(0),
            recipient,
            true,
            type(int256).max,
            type(uint160).max,
            type(int256).max,
            type(int256).min,
            "0xffffffff"
        );

        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.swapAmountIn, uint112(uint256(type(int256).max)));
        assertEq(call.token0In, true);
    }

    function test_AfterSwap_EmptyCalldata() public {
        vm.prank(address(pool));
        plugin.afterSwap(address(0), recipient, true, 0, 0, 1000e18, -500e18, "");

        assertEq(reflexRouter.getTriggerBackrunCallsLength(), 1);
    }

    function test_AfterSwap_ReturnsCorrectSelector() public {
        vm.prank(address(pool));
        bytes4 returnedSelector = plugin.afterSwap(address(0), recipient, true, 0, 0, 1000e18, -500e18, "");

        assertEq(returnedSelector, IAlgebraPlugin.afterSwap.selector);
        assertEq(
            returnedSelector, bytes4(keccak256("afterSwap(address,address,bool,int256,uint160,int256,int256,bytes)"))
        );
    }

    // ===== State Consistency Tests =====

    function test_StateConsistency_MultipleSwaps() public {
        // Record initial state
        uint256 initialCallCount = reflexRouter.getTriggerBackrunCallsLength();

        // Perform multiple swaps
        for (uint256 i = 0; i < 5; i++) {
            vm.prank(address(pool));
            plugin.afterSwap(
                address(0),
                recipient,
                i % 2 == 0, // alternate zeroToOne
                0,
                0,
                int256(1000e18 + i),
                int256(-500e18 - int256(i)),
                ""
            );
        }

        // Verify all swaps were recorded
        assertEq(reflexRouter.getTriggerBackrunCallsLength(), initialCallCount + 5);

        // Verify each swap has correct sequential data
        for (uint256 i = 0; i < 5; i++) {
            MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(i);
            assertEq(call.token0In, i % 2 == 0);
            assertEq(call.swapAmountIn, uint112(1000e18 + i));
        }
    }

    // Tests for enable/disable functionality
    function test_ReflexEnabled_DefaultState() public view {
        // By default, reflex should be enabled
        assertTrue(plugin.reflexEnabled());
    }

    function test_SetReflexEnabled_ByAuthorized() public {
        // Admin should be able to disable reflex
        vm.prank(admin);
        plugin.setReflexEnabled(false);
        assertFalse(plugin.reflexEnabled());

        // And enable it again
        vm.prank(admin);
        plugin.setReflexEnabled(true);
        assertTrue(plugin.reflexEnabled());
    }

    function test_SetReflexEnabled_Unauthorized() public {
        // Unauthorized address should not be able to change state
        vm.prank(recipient);
        vm.expectRevert();
        plugin.setReflexEnabled(false);

        // State should remain unchanged
        assertTrue(plugin.reflexEnabled());
    }

    function test_AfterSwap_DisabledReflex() public {
        // First disable reflex
        vm.prank(admin);
        plugin.setReflexEnabled(false);

        // Record initial state
        uint256 initialCallCount = reflexRouter.getTriggerBackrunCallsLength();

        // Perform swap - should not trigger reflex
        vm.prank(address(pool));
        plugin.afterSwap(address(0), recipient, true, 0, 0, 1000e18, -500e18, "");

        // Verify no reflex call was made
        assertEq(reflexRouter.getTriggerBackrunCallsLength(), initialCallCount);
    }

    function test_AfterSwap_EnabledReflex() public {
        // Ensure reflex is enabled (default state)
        assertTrue(plugin.reflexEnabled());

        // Record initial state
        uint256 initialCallCount = reflexRouter.getTriggerBackrunCallsLength();

        // Perform swap - should trigger reflex
        vm.prank(address(pool));
        plugin.afterSwap(address(0), recipient, true, 0, 0, 1000e18, -500e18, "");

        // Verify reflex call was made
        assertEq(reflexRouter.getTriggerBackrunCallsLength(), initialCallCount + 1);
    }

    function test_ReflexToggle_MidOperation() public {
        // Record initial state
        uint256 initialCallCount = reflexRouter.getTriggerBackrunCallsLength();

        // Perform swap with reflex enabled
        vm.prank(address(pool));
        plugin.afterSwap(address(0), recipient, true, 0, 0, 1000e18, -500e18, "");
        assertEq(reflexRouter.getTriggerBackrunCallsLength(), initialCallCount + 1);

        // Disable reflex
        vm.prank(admin);
        plugin.setReflexEnabled(false);

        // Perform another swap - should not trigger reflex
        vm.prank(address(pool));
        plugin.afterSwap(address(0), recipient, false, 0, 0, 2000e18, -1000e18, "");
        assertEq(reflexRouter.getTriggerBackrunCallsLength(), initialCallCount + 1);

        // Re-enable reflex
        vm.prank(admin);
        plugin.setReflexEnabled(true);

        // Perform another swap - should trigger reflex again
        vm.prank(address(pool));
        plugin.afterSwap(address(0), recipient, true, 0, 0, 3000e18, -1500e18, "");
        assertEq(reflexRouter.getTriggerBackrunCallsLength(), initialCallCount + 2);
    }

    // ===== Fee Exemption Tests =====

    function test_BeforeSwap_ReflexRouterFeeExemption() public {
        _initializePlugin();

        // Test that reflexRouter gets zero fee
        vm.prank(address(pool));
        (, uint24 fee,) = plugin.beforeSwap(
            address(reflexRouter), // sender = reflexRouter
            recipient,
            true, // zeroToOne
            1000e18, // amountSpecified
            0, // sqrtPriceLimitX96
            false, // withPayment
            ""
        );

        // Fee should be 1 for reflexRouter
        assertEq(fee, 1);
    }

    function test_BeforeSwap_NormalUserPaysBaseFee() public {
        _initializePlugin();

        address normalUser = makeAddr("normalUser");

        vm.prank(address(pool));
        (, uint24 fee,) = plugin.beforeSwap(
            normalUser, // sender = normal user
            recipient,
            true, // zeroToOne
            1000e18, // amountSpecified
            0, // sqrtPriceLimitX96
            false, // withPayment
            ""
        );

        // Fee should be non-zero for normal users (base fee or calculated sliding fee)
        assertTrue(fee > 0);
    }

    function test_BeforeSwap_FeeExemptionOnlyForReflexRouter() public {
        _initializePlugin();

        address anotherRouter = makeAddr("anotherRouter");

        // Test normal user pays fee
        vm.prank(address(pool));
        (, uint24 normalFee,) = plugin.beforeSwap(
            recipient, // sender = normal user
            recipient,
            true,
            1000e18,
            0,
            false,
            ""
        );

        // Test another router address pays fee
        vm.prank(address(pool));
        (, uint24 otherRouterFee,) = plugin.beforeSwap(
            anotherRouter, // sender = different router
            recipient,
            true,
            1000e18,
            0,
            false,
            ""
        );

        // Test reflexRouter gets 500 fee
        vm.prank(address(pool));
        (, uint24 reflexRouterFee,) = plugin.beforeSwap(
            address(reflexRouter), // sender = reflexRouter
            recipient,
            true,
            1000e18,
            0,
            false,
            ""
        );

        // ReflexRouter should get 1 fee, others pay higher fees
        assertTrue(normalFee > 0);
        assertTrue(otherRouterFee > 0);
        assertEq(reflexRouterFee, 1);
    }

    function test_BeforeSwap_FeeExemptionBothDirections() public {
        _initializePlugin();

        // Test zero to one
        vm.prank(address(pool));
        (, uint24 feeZeroToOne,) = plugin.beforeSwap(
            address(reflexRouter),
            recipient,
            true, // zeroToOne = true
            1000e18,
            0,
            false,
            ""
        );

        // Test one to zero
        vm.prank(address(pool));
        (, uint24 feeOneToZero,) = plugin.beforeSwap(
            address(reflexRouter),
            recipient,
            false, // zeroToOne = false
            1000e18,
            0,
            false,
            ""
        );

        // Both directions should have 1 fee for reflexRouter
        assertEq(feeZeroToOne, 1);
        assertEq(feeOneToZero, 1);
    }

    function test_BeforeSwap_FeeExemptionWithDifferentAmounts() public {
        _initializePlugin();

        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 1e18; // Small amount
        amounts[1] = 1000e18; // Medium amount
        amounts[2] = 1000000e18; // Large amount
        amounts[3] = type(uint112).max; // Maximum amount

        for (uint256 i = 0; i < amounts.length; i++) {
            vm.prank(address(pool));
            (, uint24 fee,) =
                plugin.beforeSwap(address(reflexRouter), recipient, true, int256(amounts[i]), 0, false, "");

            // Fee should always be 1 for reflexRouter regardless of amount
            assertEq(fee, 1, string(abi.encodePacked("Fee should be 1 for amount: ", amounts[i])));
        }
    }

    function test_GetRouter_ReturnsCorrectAddress() public view {
        // Test that getRouter returns the reflexRouter address
        address routerFromPlugin = plugin.getRouter();
        assertEq(routerFromPlugin, address(reflexRouter));
    }

    function test_BeforeSwap_OnlyPoolCanCall() public {
        // Unauthorized caller should not be able to call beforeSwap
        vm.expectRevert();
        plugin.beforeSwap(address(reflexRouter), recipient, true, 1000e18, 0, false, "");
    }

    function test_BeforeSwap_ReturnsCorrectSelector() public {
        _initializePlugin();

        vm.prank(address(pool));
        (bytes4 selector,,) = plugin.beforeSwap(address(reflexRouter), recipient, true, 1000e18, 0, false, "");

        assertEq(selector, IAlgebraPlugin.beforeSwap.selector);
    }

    function testFuzz_BeforeSwap_ReflexRouterAlwaysBaseFee(
        bool zeroToOne,
        int256 amountSpecified,
        address recipientAddr
    ) public {
        vm.assume(recipientAddr != address(0));
        vm.assume(amountSpecified != 0);

        _initializePlugin();

        vm.prank(address(pool));
        (, uint24 fee,) =
            plugin.beforeSwap(address(reflexRouter), recipientAddr, zeroToOne, amountSpecified, 0, false, "");

        // ReflexRouter should always get 1 fee (minimal) regardless of parameters
        assertEq(fee, 1);
    }

    function testFuzz_BeforeSwap_NonReflexRouterPaysfee(
        address sender,
        bool zeroToOne,
        int256 amountSpecified,
        address recipientAddr
    ) public {
        vm.assume(recipientAddr != address(0));
        vm.assume(sender != address(0));
        vm.assume(sender != address(reflexRouter)); // Exclude reflexRouter
        vm.assume(amountSpecified != 0);

        _initializePlugin();

        vm.prank(address(pool));
        (, uint24 fee,) = plugin.beforeSwap(sender, recipientAddr, zeroToOne, amountSpecified, 0, false, "");

        // Non-reflexRouter addresses should pay fee (fee > 0)
        assertTrue(fee > 0);
    }

    function test_BeforeSwap_FeeExemptionIntegrationWithSliding() public {
        _initializePlugin();

        // Perform multiple swaps to build up fee history and test that
        // reflexRouter still gets exemption even with sliding fee adjustments

        address normalUser = makeAddr("normalUser");

        // First, perform swaps with normal user to establish sliding fee context
        for (uint256 i = 0; i < 3; i++) {
            vm.prank(address(pool));
            plugin.beforeSwap(
                normalUser,
                recipient,
                i % 2 == 0, // alternate direction
                1000e18,
                0,
                false,
                ""
            );
        }

        // Now test that reflexRouter still gets 1 fee
        vm.prank(address(pool));
        (, uint24 reflexFee,) = plugin.beforeSwap(address(reflexRouter), recipient, true, 1000e18, 0, false, "");

        // And normal user still pays fee
        vm.prank(address(pool));
        (, uint24 normalFee,) = plugin.beforeSwap(normalUser, recipient, true, 1000e18, 0, false, "");

        assertEq(reflexFee, 1);
        assertTrue(normalFee > 0);
    }

    // ===== ConfigId Tests =====

    function test_ConfigId_StoredCorrectly() public {
        bytes32 testConfigId = keccak256("custom-config-v3");
        
        vm.prank(pluginFactory);
        AlgebraBasePluginV3 customPlugin =
            new AlgebraBasePluginV3(address(pool), address(factory), pluginFactory, BASE_FEE, address(reflexRouter), testConfigId);

        assertEq(customPlugin.getConfigId(), testConfigId);
    }

    function test_ConfigId_UsedInAfterSwap() public {
        bytes32 testConfigId = keccak256("test-config-afterswap");
        
        // Create plugin with custom config ID
        vm.prank(pluginFactory);
        AlgebraBasePluginV3 customPlugin =
            new AlgebraBasePluginV3(address(pool), address(factory), pluginFactory, BASE_FEE, address(reflexRouter), testConfigId);
        
        // Set the custom plugin in pool
        pool.setPlugin(address(customPlugin));

        int256 amount0Out = 1000e18;
        int256 amount1Out = -500e18;
        bool zeroToOne = true;

        // Call afterSwap
        vm.prank(address(pool));
        customPlugin.afterSwap(
            address(0),
            recipient,
            zeroToOne,
            0,
            0,
            amount0Out,
            amount1Out,
            ""
        );

        // Verify the configId was passed to triggerBackrun
        assertEq(reflexRouter.getTriggerBackrunCallsLength(), 1);
        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.configId, testConfigId);
    }

    function test_ConfigId_DifferentPluginsDifferentConfigs() public {
        bytes32 configId1 = keccak256("config-1");
        bytes32 configId2 = keccak256("config-2");
        
        // Create two plugins with different config IDs
        vm.startPrank(pluginFactory);
        AlgebraBasePluginV3 plugin1 =
            new AlgebraBasePluginV3(address(pool), address(factory), pluginFactory, BASE_FEE, address(reflexRouter), configId1);
        AlgebraBasePluginV3 plugin2 =
            new AlgebraBasePluginV3(address(pool), address(factory), pluginFactory, BASE_FEE, address(reflexRouter), configId2);
        vm.stopPrank();

        assertEq(plugin1.getConfigId(), configId1);
        assertEq(plugin2.getConfigId(), configId2);
        assertTrue(plugin1.getConfigId() != plugin2.getConfigId());
    }

    function test_ConfigId_ZeroConfigId() public {
        bytes32 zeroConfigId = bytes32(0);
        
        vm.prank(pluginFactory);
        AlgebraBasePluginV3 zeroPlugin =
            new AlgebraBasePluginV3(address(pool), address(factory), pluginFactory, BASE_FEE, address(reflexRouter), zeroConfigId);

        assertEq(zeroPlugin.getConfigId(), zeroConfigId);
        
        // Test that it still works with zero config
        pool.setPlugin(address(zeroPlugin));
        
        vm.prank(address(pool));
        zeroPlugin.afterSwap(address(0), recipient, true, 0, 0, 1000e18, -500e18, "");
        
        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.configId, zeroConfigId);
    }
}
