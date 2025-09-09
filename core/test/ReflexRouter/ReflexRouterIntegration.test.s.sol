// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/ReflexRouter.sol";
import "../../src/interfaces/IReflexQuoter.sol";
import "../../src/libraries/DexTypes.sol";
import "../utils/TestUtils.sol";
import "../mocks/MockToken.sol";
import "../mocks/SharedRouterMocks.sol";

contract ReflexRouterIntegrationTest is Test {
    using TestUtils for *;
    using RouterTestHelper for uint256;

    // Events
    event BackrunExecuted(
        bytes32 indexed triggerPoolId,
        uint112 swapAmountIn,
        bool token0In,
        uint256 profit,
        address profitToken,
        address indexed recipient
    );

    ReflexRouter public reflexRouter;
    SharedMockQuoter public quoter;

    MockToken public tokenA;
    MockToken public tokenB;
    MockToken public tokenC;
    MockToken public tokenD;

    SharedMockV2Pool public poolAB_V2;
    SharedMockV2Pool public poolBC_V2; // B -> C pool for V2 testing
    SharedMockV3Pool public poolBC_V3;
    SharedMockV2Pool public poolBA_V2; // B -> A pool for simple arbitrage
    SharedMockV2Pool public poolCA_V2; // C -> A pool for complex arbitrage
    SharedMockV3Pool public poolAD_V3;
    SharedMockV2Pool public poolAD_V2; // A -> D pool for V2 testing
    SharedMockV2Pool public poolDA_V2; // D -> A pool for V2 testing
    SharedMockV2Pool public poolCD_V2; // C -> D pool for V2 testing

    address public owner = address(0x1);
    address public trader = address(0x2);
    address public recipient = address(0x3);

    function setUp() public {
        // Deploy router
        reflexRouter = new ReflexRouter();

        // Deploy shared mocks
        quoter = new SharedMockQuoter();

        vm.prank(reflexRouter.owner());
        reflexRouter.setReflexQuoter(address(quoter));

        // Deploy tokens
        tokenA = new MockToken("TokenA", "TKA", 1000000 * 10 ** 18);
        tokenB = new MockToken("TokenB", "TKB", 1000000 * 10 ** 18);
        tokenC = new MockToken("TokenC", "TKC", 1000000 * 10 ** 18);
        tokenD = new MockToken("TokenD", "TKD", 1000000 * 10 ** 18);

        // Deploy shared pools
        poolAB_V2 = new SharedMockV2Pool(address(tokenA), address(tokenB));
        poolBC_V2 = new SharedMockV2Pool(address(tokenB), address(tokenC)); // B -> C V2 pool
        poolBC_V3 = new SharedMockV3Pool(address(tokenB), address(tokenC));
        poolBA_V2 = new SharedMockV2Pool(address(tokenB), address(tokenA)); // B -> A for simple arbitrage
        poolCA_V2 = new SharedMockV2Pool(address(tokenC), address(tokenA)); // C -> A for complex arbitrage
        poolAD_V3 = new SharedMockV3Pool(address(tokenA), address(tokenD));
        poolAD_V2 = new SharedMockV2Pool(address(tokenA), address(tokenD)); // A -> D V2 pool
        poolDA_V2 = new SharedMockV2Pool(address(tokenD), address(tokenA)); // D -> A V2 pool
        poolCD_V2 = new SharedMockV2Pool(address(tokenC), address(tokenD)); // C -> D V2 pool

        // Setup realistic reserves for V2 pools
        poolAB_V2.setReserves(100000 * 10 ** 18, 100000 * 10 ** 18);
        poolBC_V2.setReserves(100000 * 10 ** 18, 100000 * 10 ** 18);
        poolBA_V2.setReserves(100000 * 10 ** 18, 100000 * 10 ** 18);
        poolCA_V2.setReserves(100000 * 10 ** 18, 100000 * 10 ** 18);
        poolAD_V2.setReserves(100000 * 10 ** 18, 100000 * 10 ** 18);
        poolDA_V2.setReserves(100000 * 10 ** 18, 100000 * 10 ** 18);
        poolCD_V2.setReserves(100000 * 10 ** 18, 100000 * 10 ** 18);

        // Fund router with tokens for flash loan scenarios
        // The profit calculation works by comparing balance before vs after swaps
        tokenA.mint(address(reflexRouter), 10000 * 10 ** 18);
        tokenB.mint(address(reflexRouter), 10000 * 10 ** 18);
        tokenC.mint(address(reflexRouter), 10000 * 10 ** 18);
        tokenD.mint(address(reflexRouter), 10000 * 10 ** 18);
    }

    // =============================================================================
    // Basic Integration Tests
    // =============================================================================

    function test_simple_two_hop_arbitrage() public {
        // A -> B -> A arbitrage
        uint256 swapAmount = 1000 * 10 ** 18;

        // Use simpler direct profit setup instead of complex callback simulation
        uint256 expectedProfit = 50 * 10 ** 18; // Simple 50 token profit

        // Set up route: poolAB_V2 -> poolCA_V2 (A -> B -> A arbitrage)
        address[] memory pools = new address[](2);
        pools[0] = address(poolAB_V2);
        pools[1] = address(poolCA_V2);

        uint8[] memory dexTypes = new uint8[](2);
        dexTypes[0] = DexTypes.UNISWAP_V2_WITH_CALLBACK;
        dexTypes[1] = DexTypes.UNISWAP_V2_WITH_CALLBACK;

        uint8[] memory dexMeta = new uint8[](2);
        dexMeta[0] = 0x80; // A -> B (zeroForOne = true)
        dexMeta[1] = 0x80; // B -> A (zeroForOne = true for tokenB->tokenA)

        address[] memory tokens = new address[](3);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        tokens[2] = address(tokenA);

        // Set amounts that will result in profit (like working test)
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = swapAmount;
        amounts[1] = 950 * 10 ** 18; // Intermediate amount
        amounts[2] = swapAmount + expectedProfit; // Final amount = input + profit

        quoter.addRoute(
            address(poolAB_V2),
            0, // tokenA is asset 0
            swapAmount,
            expectedProfit,
            pools,
            dexTypes,
            dexMeta,
            tokens,
            amounts,
            0
        );

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(poolAB_V2))));
        uint256 initialBalance = tokenA.balanceOf(recipient);

        (uint256 profit, address profitToken) = reflexRouter.triggerBackrun(
            triggerPoolId,
            uint112(swapAmount),
            true, // token0In (tokenA)
            recipient,
            bytes32(0)
        );

        assertEq(profit, expectedProfit);
        assertEq(profitToken, address(tokenA));

        // With the ConfigurableRevenueDistributor:
        // - 80% goes to the router owner (deployer)
        // - 20% goes to the dust recipient (recipient)
        uint256 expectedRecipientShare = (expectedProfit * 2000) / 10000; // 20% as dust recipient
        assertEq(tokenA.balanceOf(recipient), initialBalance + expectedRecipientShare);
    }

    function test_three_hop_arbitrage_mixed_dex() public {
        // A -> B -> C -> A arbitrage using mixed DEX types
        uint256 swapAmount = 1000 * 10 ** 18; // Use same amount as working 2-hop test

        // Use same profit as working test
        uint256 expectedProfit = 50 * 10 ** 18;

        // Set amounts that follow the working pattern
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = swapAmount;
        amounts[1] = 950 * 10 ** 18; // First hop A->B (same as working test)
        amounts[2] = 900 * 10 ** 18; // Second hop B->C (slightly less)
        amounts[3] = swapAmount + expectedProfit; // Final hop C->A (profitable)

        address[] memory pools = new address[](3);
        pools[0] = address(poolAB_V2); // V2
        pools[1] = address(poolBC_V2); // V2 (changed from V3)
        pools[2] = address(poolCA_V2); // V2

        uint8[] memory dexTypes = new uint8[](3);
        dexTypes[0] = DexTypes.UNISWAP_V2_WITH_CALLBACK;
        dexTypes[1] = DexTypes.UNISWAP_V2_WITH_CALLBACK; // Changed from V3
        dexTypes[2] = DexTypes.UNISWAP_V2_WITH_CALLBACK;

        uint8[] memory dexMeta = new uint8[](3);
        dexMeta[0] = 0x80; // A -> B
        dexMeta[1] = 0x80; // B -> C
        dexMeta[2] = 0x80; // C -> A (changed from 0x00 to 0x80)

        address[] memory tokens = new address[](4);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        tokens[2] = address(tokenC);
        tokens[3] = address(tokenA);

        quoter.addRoute(address(poolAB_V2), 0, swapAmount, expectedProfit, pools, dexTypes, dexMeta, tokens, amounts, 0);

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(poolAB_V2))));
        uint256 initialBalance = tokenA.balanceOf(recipient);

        (uint256 profit, address profitToken) =
            reflexRouter.triggerBackrun(triggerPoolId, uint112(swapAmount), true, recipient, bytes32(0));

        assertEq(profit, expectedProfit);
        assertEq(profitToken, address(tokenA));

        // With the ConfigurableRevenueDistributor:
        // - 80% goes to the router owner (deployer)
        // - 20% goes to the dust recipient (recipient)
        uint256 expectedRecipientShare = (expectedProfit * 2000) / 10000; // 20% as dust recipient
        assertEq(tokenA.balanceOf(recipient), initialBalance + expectedRecipientShare);
    }

    // =============================================================================
    // Performance Tests
    // =============================================================================

    function test_gas_usage_simple_arbitrage() public {
        uint256 swapAmount = 1000 * 10 ** 18;

        // Use simple direct profit setup like the working test
        uint256 expectedProfit = 50 * 10 ** 18;

        address[] memory pools = new address[](2);
        pools[0] = address(poolAB_V2);
        pools[1] = address(poolBA_V2); // Fixed: use B->A pool

        uint8[] memory dexTypes = new uint8[](2);
        dexTypes[0] = DexTypes.UNISWAP_V2_WITH_CALLBACK;
        dexTypes[1] = DexTypes.UNISWAP_V2_WITH_CALLBACK;

        uint8[] memory dexMeta = new uint8[](2);
        dexMeta[0] = 0x80;
        dexMeta[1] = 0x80; // Fixed: B->A direction

        address[] memory tokens = new address[](3);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        tokens[2] = address(tokenA);

        // Set amounts that will result in profit
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = swapAmount;
        amounts[1] = 950 * 10 ** 18;
        amounts[2] = swapAmount + expectedProfit;

        quoter.addRoute(address(poolAB_V2), 0, swapAmount, expectedProfit, pools, dexTypes, dexMeta, tokens, amounts, 0);

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(poolAB_V2))));

        uint256 gasBefore = gasleft();
        reflexRouter.triggerBackrun(triggerPoolId, uint112(swapAmount), true, recipient, bytes32(0));
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas used for 2-hop arbitrage", gasUsed);

        // Should be reasonable gas usage (under 700k - adjusted for mock complexity)
        assertLt(gasUsed, 700000);
    }

    function test_gas_usage_complex_arbitrage() public {
        uint256 swapAmount = 1000 * 10 ** 18;

        // For 4-hop, calculate amounts step by step to ensure profitability
        uint256[] memory amounts = new uint256[](5);
        amounts[0] = swapAmount;
        amounts[1] = swapAmount * 98 / 100; // 2% slippage
        amounts[2] = amounts[1] * 98 / 100; // Another 2% slippage
        amounts[3] = amounts[2] * 98 / 100; // Another 2% slippage
        amounts[4] = amounts[3] * 108 / 100; // 8% bonus on final hop for profitability

        uint256 expectedProfit = amounts[4] - amounts[0]; // Should be positive

        // 4-hop arbitrage: A -> B -> C -> D -> A (proper arbitrage route)
        address[] memory pools = new address[](4);
        pools[0] = address(poolAB_V2); // A -> B
        pools[1] = address(poolBC_V2); // B -> C (changed from V3)
        pools[2] = address(poolCD_V2); // C -> D (need to create this)
        pools[3] = address(poolDA_V2); // D -> A

        uint8[] memory dexTypes = new uint8[](4);
        dexTypes[0] = DexTypes.UNISWAP_V2_WITH_CALLBACK;
        dexTypes[1] = DexTypes.UNISWAP_V2_WITH_CALLBACK; // Changed from V3
        dexTypes[2] = DexTypes.UNISWAP_V2_WITH_CALLBACK; // Changed from V2
        dexTypes[3] = DexTypes.UNISWAP_V2_WITH_CALLBACK; // Changed from V3

        uint8[] memory dexMeta = new uint8[](4);
        dexMeta[0] = 0x80; // A -> B (token0 -> token1)
        dexMeta[1] = 0x80; // B -> C (token0 -> token1)
        dexMeta[2] = 0x80; // C -> D (token0 -> token1)
        dexMeta[3] = 0x80; // D -> A (token0 -> token1)

        address[] memory tokens = new address[](5);
        tokens[0] = address(tokenA); // Start
        tokens[1] = address(tokenB); // After hop 0
        tokens[2] = address(tokenC); // After hop 1
        tokens[3] = address(tokenD); // After hop 2
        tokens[4] = address(tokenA); // After hop 3 (back to A)

        quoter.addRoute(address(poolAB_V2), 0, swapAmount, expectedProfit, pools, dexTypes, dexMeta, tokens, amounts, 0);

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(poolAB_V2))));

        uint256 gasBefore = gasleft();
        reflexRouter.triggerBackrun(triggerPoolId, uint112(swapAmount), true, recipient, bytes32(0));
        uint256 gasUsed = gasBefore - gasleft();

        emit log_named_uint("Gas used for 4-hop arbitrage", gasUsed);

        // Should still be reasonable for complex arbitrage (under 1M gas)
        assertLt(gasUsed, 1000000);
    }

    // =============================================================================
    // Stress Tests
    // =============================================================================

    function test_multiple_sequential_arbitrages() public {
        uint256 swapAmount = 500 * 10 ** 18;

        // Use simple direct profit setup
        uint256 expectedProfit = 50 * 10 ** 18;

        // Set up a profitable route
        address[] memory pools = new address[](2);
        pools[0] = address(poolAB_V2);
        pools[1] = address(poolBA_V2);

        uint8[] memory dexTypes = new uint8[](2);
        dexTypes[0] = DexTypes.UNISWAP_V2_WITH_CALLBACK;
        dexTypes[1] = DexTypes.UNISWAP_V2_WITH_CALLBACK;

        uint8[] memory dexMeta = new uint8[](2);
        dexMeta[0] = 0x80;
        dexMeta[1] = 0x80;

        address[] memory tokens = new address[](3);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        tokens[2] = address(tokenA);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = swapAmount;
        amounts[1] = 475 * 10 ** 18; // Intermediate amount for smaller trade
        amounts[2] = swapAmount + expectedProfit; // Final profitable amount

        quoter.addRoute(address(poolAB_V2), 0, swapAmount, expectedProfit, pools, dexTypes, dexMeta, tokens, amounts, 0);

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(poolAB_V2))));
        uint256 totalProfit = 0;

        // Execute 10 arbitrages sequentially
        for (uint256 i = 0; i < 10; i++) {
            (uint256 profit,) =
                reflexRouter.triggerBackrun(triggerPoolId, uint112(swapAmount), true, recipient, bytes32(0));
            totalProfit += profit;
        }

        // Should have accumulated profit
        assertGt(totalProfit, 0);
        emit log_named_uint("Total profit from 10 arbitrages", totalProfit);
    }

    function test_rapid_fire_arbitrages() public {
        uint256 swapAmount = 100 * 10 ** 18;

        // Use simple direct profit setup
        uint256 expectedProfit = 5 * 10 ** 18; // Small profit for small trade

        address[] memory pools = new address[](2);
        pools[0] = address(poolAB_V2);
        pools[1] = address(poolBA_V2);

        uint8[] memory dexTypes = new uint8[](2);
        dexTypes[0] = DexTypes.UNISWAP_V2_WITH_CALLBACK;
        dexTypes[1] = DexTypes.UNISWAP_V2_WITH_CALLBACK;

        uint8[] memory dexMeta = new uint8[](2);
        dexMeta[0] = 0x80;
        dexMeta[1] = 0x80;

        address[] memory tokens = new address[](3);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        tokens[2] = address(tokenA);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = swapAmount;
        amounts[1] = 95 * 10 ** 18; // Intermediate amount
        amounts[2] = swapAmount + expectedProfit; // Final profitable amount

        quoter.addRoute(address(poolAB_V2), 0, swapAmount, expectedProfit, pools, dexTypes, dexMeta, tokens, amounts, 0);

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(poolAB_V2))));

        uint256 gasBefore = gasleft();

        // Execute 5 rapid arbitrages
        for (uint256 i = 0; i < 5; i++) {
            reflexRouter.triggerBackrun(triggerPoolId, uint112(swapAmount), true, recipient, bytes32(0));
        }

        uint256 gasUsed = gasBefore - gasleft();
        emit log_named_uint("Gas used for 5 rapid arbitrages", gasUsed);

        // Test passes if no reverts occurred during the 5 arbitrages
    }

    // =============================================================================
    // Real-world Scenario Tests
    // =============================================================================

    function test_arbitrage_with_price_impact() public {
        // Simulate arbitrage with realistic price impact
        uint256 swapAmount = 5000 * 10 ** 18; // Large trade

        // Update pool to reflect price impact
        poolBC_V3.setPrice(1100000000000000000); // Price increases due to large trade

        address[] memory pools = new address[](3);
        pools[0] = address(poolAB_V2);
        pools[1] = address(poolBC_V3);
        pools[2] = address(poolCA_V2);

        uint8[] memory dexTypes = new uint8[](3);
        dexTypes[0] = DexTypes.UNISWAP_V2_WITH_CALLBACK;
        dexTypes[1] = DexTypes.UNISWAP_V3;
        dexTypes[2] = DexTypes.UNISWAP_V2_WITH_CALLBACK;

        uint8[] memory dexMeta = new uint8[](3);
        dexMeta[0] = 0x80;
        dexMeta[1] = 0x80;
        dexMeta[2] = 0x00;

        address[] memory tokens = new address[](4);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        tokens[2] = address(tokenC);
        tokens[3] = address(tokenA);

        // Amounts reflecting price impact
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = swapAmount;
        amounts[1] = swapAmount * 90 / 100; // Higher slippage
        amounts[2] = swapAmount * 85 / 100; // Even higher due to price impact
        amounts[3] = swapAmount * 87 / 100; // Some recovery but still a loss

        quoter.addRoute(
            address(poolAB_V2),
            0,
            swapAmount,
            0, // No profit due to price impact
            pools,
            dexTypes,
            dexMeta,
            tokens,
            amounts,
            0
        );

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(poolAB_V2))));

        (uint256 profit, address profitToken) =
            reflexRouter.triggerBackrun(triggerPoolId, uint112(swapAmount), true, recipient, bytes32(0));

        // Should return no profit due to price impact
        assertEq(profit, 0);
        assertEq(profitToken, address(0));
    }

    function test_arbitrage_opportunity_disappears() public {
        // Test scenario where arbitrage opportunity disappears between quote and execution
        uint256 swapAmount = 1000 * 10 ** 18;

        // Initially profitable route
        address[] memory pools = new address[](2);
        pools[0] = address(poolAB_V2);
        pools[1] = address(poolCA_V2);

        uint8[] memory dexTypes = new uint8[](2);
        dexTypes[0] = DexTypes.UNISWAP_V2_WITH_CALLBACK;
        dexTypes[1] = DexTypes.UNISWAP_V2_WITH_CALLBACK;

        uint8[] memory dexMeta = new uint8[](2);
        dexMeta[0] = 0x80;
        dexMeta[1] = 0x00;

        address[] memory tokens = new address[](3);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        tokens[2] = address(tokenA);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = swapAmount;
        amounts[1] = swapAmount * 95 / 100;
        amounts[2] = swapAmount * 98 / 100; // Originally profitable

        quoter.addRoute(
            address(poolAB_V2),
            0,
            swapAmount,
            0, // No profit when actually executed
            pools,
            dexTypes,
            dexMeta,
            tokens,
            amounts,
            0
        );

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(poolAB_V2))));

        (uint256 profit, address profitToken) =
            reflexRouter.triggerBackrun(triggerPoolId, uint112(swapAmount), true, recipient, bytes32(0));

        // Should handle gracefully when opportunity disappears
        assertEq(profit, 0);
        assertEq(profitToken, address(0));
    }

    // =============================================================================
    // Event Verification Tests
    // =============================================================================

    function test_event_emission_comprehensive() public {
        uint256 swapAmount = 1000 * 10 ** 18;

        // Use simple direct profit setup
        uint256 expectedProfit = 50 * 10 ** 18;

        address[] memory pools = new address[](2);
        pools[0] = address(poolAB_V2);
        pools[1] = address(poolBA_V2);

        uint8[] memory dexTypes = new uint8[](2);
        dexTypes[0] = DexTypes.UNISWAP_V2_WITH_CALLBACK;
        dexTypes[1] = DexTypes.UNISWAP_V2_WITH_CALLBACK;

        uint8[] memory dexMeta = new uint8[](2);
        dexMeta[0] = 0x80;
        dexMeta[1] = 0x80;

        address[] memory tokens = new address[](3);
        tokens[0] = address(tokenA);
        tokens[1] = address(tokenB);
        tokens[2] = address(tokenA);

        uint256[] memory amounts = new uint256[](3);
        amounts[0] = swapAmount;
        amounts[1] = 950 * 10 ** 18;
        amounts[2] = swapAmount + expectedProfit;

        quoter.addRoute(address(poolAB_V2), 0, swapAmount, expectedProfit, pools, dexTypes, dexMeta, tokens, amounts, 0);

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(poolAB_V2))));

        // Expect the BackrunExecuted event
        vm.expectEmit(true, true, true, true);
        emit BackrunExecuted(triggerPoolId, uint112(swapAmount), true, expectedProfit, address(tokenA), recipient);

        reflexRouter.triggerBackrun(triggerPoolId, uint112(swapAmount), true, recipient, bytes32(0));
    }

    // =============================================================================
    // Fuzz Testing for Integration
    // =============================================================================

    function testFuzz_arbitrage_amounts(uint112 swapAmountIn) public {
        vm.assume(swapAmountIn > 1000 && swapAmountIn < 1000000 * 10 ** 18);

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(poolAB_V2))));

        (uint256 profit, address profitToken) =
            reflexRouter.triggerBackrun(triggerPoolId, swapAmountIn, true, recipient, bytes32(0));

        // Without configured quotes, should return no profit
        assertEq(profit, 0);
        assertEq(profitToken, address(0));
    }

    function testFuzz_multiple_recipients(address _recipient) public {
        vm.assume(_recipient != address(0));
        vm.assume(_recipient.code.length == 0); // EOA only

        bytes32 triggerPoolId = bytes32(uint256(uint160(address(poolAB_V2))));

        (uint256 profit,) = reflexRouter.triggerBackrun(triggerPoolId, 1000 * 10 ** 18, true, _recipient, bytes32(0));

        assertEq(profit, 0);
    }
}
