// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {UniswapV4Hook} from "@reflex/integrations/plugin/uniswapv4/UniswapV4Hook.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta, toBalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import "../../utils/TestUtils.sol";
import "../../mocks/MockToken.sol";
import "../../mocks/MockReflexRouter.sol";

contract UniswapV4HookTest is Test {
    using TestUtils for *;
    using PoolIdLibrary for PoolKey;

    UniswapV4Hook public hook;
    MockReflexRouter public reflexRouter;
    MockToken public profitToken;

    address public admin;
    address public alice = address(0xA);
    address public bob = address(0xB);
    address public attacker = address(0xBAD);
    address public poolManager;

    // Test pool key components
    address public token0 = address(0x1111);
    address public token1 = address(0x2222);

    bytes32 public testConfigId = keccak256("uniswapv4-config");

    function setUp() public {
        admin = address(this);

        // Create profit token and router
        profitToken = MockToken(TestUtils.createStandardMockToken());
        reflexRouter = MockReflexRouter(TestUtils.createMockReflexRouter(admin, address(profitToken)));

        // Use a mock address for pool manager
        poolManager = makeAddr("poolManager");

        // Compute hook address with AFTER_SWAP_FLAG set in the last 14 bits
        // AFTER_SWAP_FLAG = 1 << 6 = 0x40
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);

        // Deploy hook to a flag-compliant address
        deployCodeTo(
            "UniswapV4Hook.sol:UniswapV4Hook",
            abi.encode(IPoolManager(poolManager), address(reflexRouter), testConfigId, address(this)),
            address(flags)
        );
        hook = UniswapV4Hook(address(flags));
    }

    // ========== Helper Functions ==========

    function _createPoolKey() internal view returns (PoolKey memory) {
        return PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
    }

    function _createPoolKey(address _token0, address _token1) internal view returns (PoolKey memory) {
        return PoolKey({
            currency0: Currency.wrap(_token0),
            currency1: Currency.wrap(_token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(hook))
        });
    }

    function _createSwapParams(bool zeroForOne, int256 amountSpecified) internal pure returns (IPoolManager.SwapParams memory) {
        return IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: 0
        });
    }

    // ========== Constructor Tests ==========

    function testConstructor() public view {
        assertEq(hook.owner(), admin);
        assertEq(hook.getRouter(), address(reflexRouter));
        assertEq(hook.getConfigId(), testConfigId);
        assertEq(address(hook.poolManager()), poolManager);
    }

    function _hasPermission(address hookAddr, uint160 flag) internal pure returns (bool) {
        return uint160(hookAddr) & flag != 0;
    }

    function testHookPermissions() public view {
        address hookAddr = address(hook);
        // Only AFTER_SWAP_FLAG should be set
        assertTrue(_hasPermission(hookAddr, Hooks.AFTER_SWAP_FLAG));
        assertFalse(_hasPermission(hookAddr, Hooks.BEFORE_SWAP_FLAG));
        assertFalse(_hasPermission(hookAddr, Hooks.BEFORE_INITIALIZE_FLAG));
        assertFalse(_hasPermission(hookAddr, Hooks.AFTER_INITIALIZE_FLAG));
        assertFalse(_hasPermission(hookAddr, Hooks.BEFORE_ADD_LIQUIDITY_FLAG));
        assertFalse(_hasPermission(hookAddr, Hooks.AFTER_ADD_LIQUIDITY_FLAG));
        assertFalse(_hasPermission(hookAddr, Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG));
        assertFalse(_hasPermission(hookAddr, Hooks.AFTER_REMOVE_LIQUIDITY_FLAG));
        assertFalse(_hasPermission(hookAddr, Hooks.BEFORE_DONATE_FLAG));
        assertFalse(_hasPermission(hookAddr, Hooks.AFTER_DONATE_FLAG));
    }

    // ========== afterSwap Tests ==========

    function testAfterSwap() public {
        PoolKey memory key = _createPoolKey();
        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(-500e6, 250e18);

        vm.prank(poolManager);
        (bytes4 selector, int128 hookDelta) = hook.afterSwap(alice, key, params, delta, "");

        assertEq(selector, IHooks.afterSwap.selector);
        assertEq(hookDelta, 0);
    }

    function testAfterSwapParameterMapping() public {
        PoolKey memory key = _createPoolKey();
        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        // zeroForOne=true: user pays token0 (negative), receives token1 (positive)
        // In V4 convention: negative = user owes, positive = user is owed
        BalanceDelta delta = toBalanceDelta(-500e6, 250e18);

        vm.prank(poolManager);
        hook.afterSwap(alice, key, params, delta, "");

        // Verify triggerBackrun was called with correct parameters
        assertEq(reflexRouter.getTriggerBackrunCallsLength(), 1);
        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);

        // triggerPoolId should be the keccak256 hash of the pool key
        bytes32 expectedPoolId = PoolId.unwrap(key.toId());
        assertEq(call.triggerPoolId, expectedPoolId);

        // zeroForOne should be passed through
        assertTrue(call.token0In);

        // recipient should be the sender
        assertEq(call.recipient, alice);

        // configId should match
        assertEq(call.configId, testConfigId);
    }

    function testAfterSwapZeroForOneTrue() public {
        PoolKey memory key = _createPoolKey();
        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        // Positive amount0 = token0 going in, negative amount1 = token1 going out
        BalanceDelta delta = toBalanceDelta(500e6, -250e6);

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        vm.prank(poolManager);
        hook.afterSwap(alice, key, params, delta, "");

        // Alice should receive profit
        assertTrue(profitToken.balanceOf(alice) > aliceInitialBalance);

        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertTrue(call.token0In);
    }

    function testAfterSwapZeroForOneFalse() public {
        PoolKey memory key = _createPoolKey();
        IPoolManager.SwapParams memory params = _createSwapParams(false, -1000e18);
        // token1 going in (positive), token0 going out (negative)
        BalanceDelta delta = toBalanceDelta(-250e6, 500e6);

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        vm.prank(poolManager);
        hook.afterSwap(alice, key, params, delta, "");

        assertTrue(profitToken.balanceOf(alice) > aliceInitialBalance);

        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertFalse(call.token0In);
    }

    function testAfterSwapSenderAsRecipient() public {
        PoolKey memory key = _createPoolKey();
        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(500e6, -250e6);

        // Bob is the sender
        vm.prank(poolManager);
        hook.afterSwap(bob, key, params, delta, "");

        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.recipient, bob);
    }

    function testAfterSwapOnlyPoolManager() public {
        PoolKey memory key = _createPoolKey();
        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(500e6, -250e6);

        vm.prank(attacker);
        vm.expectRevert("UniswapV4Hook: Caller is not the PoolManager");
        hook.afterSwap(alice, key, params, delta, "");
    }

    // ========== ReflexAfterSwap Integration Tests ==========

    function testProfitExtractionFlow() public {
        PoolKey memory key = _createPoolKey();
        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(500e6, -250e6);

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        vm.prank(poolManager);
        hook.afterSwap(alice, key, params, delta, "");

        uint256 aliceFinalBalance = profitToken.balanceOf(alice);
        assertTrue(aliceFinalBalance > aliceInitialBalance);
        assertEq(aliceFinalBalance - aliceInitialBalance, reflexRouter.mockProfit());
    }

    function testRouterFailureFailsafe() public {
        reflexRouter.setShouldRevert(true);

        PoolKey memory key = _createPoolKey();
        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(500e6, -250e6);

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        // Should not revert even if router fails
        vm.prank(poolManager);
        (bytes4 selector,) = hook.afterSwap(alice, key, params, delta, "");

        assertEq(selector, IHooks.afterSwap.selector);
        assertEq(profitToken.balanceOf(alice), aliceInitialBalance);
    }

    function testMultipleConsecutiveSwaps() public {
        PoolKey memory key = _createPoolKey();

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);
        uint256 bobInitialBalance = profitToken.balanceOf(bob);

        // First swap - alice
        vm.prank(poolManager);
        hook.afterSwap(
            alice,
            key,
            _createSwapParams(true, -1000e18),
            toBalanceDelta(500e6, -250e6),
            ""
        );

        uint256 aliceAfterFirst = profitToken.balanceOf(alice);
        assertTrue(aliceAfterFirst > aliceInitialBalance);

        // Second swap - bob
        vm.prank(poolManager);
        hook.afterSwap(
            bob,
            key,
            _createSwapParams(false, -2000e18),
            toBalanceDelta(-800e6, 400e6),
            ""
        );

        // Alice balance unchanged from second swap
        assertEq(profitToken.balanceOf(alice), aliceAfterFirst);
        // Bob received profit
        assertTrue(profitToken.balanceOf(bob) > bobInitialBalance);

        // Both calls recorded
        assertEq(reflexRouter.getTriggerBackrunCallsLength(), 2);
    }

    // ========== Admin Tests ==========

    function testSetReflexRouter() public {
        address newRouter = makeAddr("newRouter");

        hook.setReflexRouter(newRouter);

        assertEq(hook.getRouter(), newRouter);
    }

    function testSetReflexRouterUnauthorized() public {
        vm.prank(attacker);
        vm.expectRevert("UniswapV4Hook: Caller is not the owner");
        hook.setReflexRouter(makeAddr("newRouter"));
    }

    function testSetReflexConfigId() public {
        bytes32 newConfigId = keccak256("new-config");

        hook.setReflexConfigId(newConfigId);

        assertEq(hook.getConfigId(), newConfigId);
    }

    function testSetReflexConfigIdUnauthorized() public {
        vm.prank(attacker);
        vm.expectRevert("UniswapV4Hook: Caller is not the owner");
        hook.setReflexConfigId(keccak256("new-config"));
    }

    function testSetReflexRouterZeroAddress() public {
        vm.expectRevert("Invalid router address");
        hook.setReflexRouter(address(0));
    }

    // ========== ConfigId Tests ==========

    function testConfigIdPassedToTriggerBackrun() public {
        PoolKey memory key = _createPoolKey();
        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(500e6, -250e6);

        vm.prank(poolManager);
        hook.afterSwap(alice, key, params, delta, "");

        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.configId, testConfigId);
    }

    // ========== No-op Hook Tests ==========

    function testBeforeInitializeNoOp() public view {
        PoolKey memory key = _createPoolKey();
        bytes4 selector = hook.beforeInitialize(address(0), key, 0);
        assertEq(selector, IHooks.beforeInitialize.selector);
    }

    function testAfterInitializeNoOp() public view {
        PoolKey memory key = _createPoolKey();
        bytes4 selector = hook.afterInitialize(address(0), key, 0, 0);
        assertEq(selector, IHooks.afterInitialize.selector);
    }

    function testBeforeSwapNoOp() public view {
        PoolKey memory key = _createPoolKey();
        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        (bytes4 selector, BeforeSwapDelta beforeDelta, uint24 fee) = hook.beforeSwap(address(0), key, params, "");
        assertEq(selector, IHooks.beforeSwap.selector);
        assertEq(BeforeSwapDelta.unwrap(beforeDelta), 0);
        assertEq(fee, 0);
    }

    function testBeforeDonateNoOp() public view {
        PoolKey memory key = _createPoolKey();
        bytes4 selector = hook.beforeDonate(address(0), key, 0, 0, "");
        assertEq(selector, IHooks.beforeDonate.selector);
    }

    function testAfterDonateNoOp() public view {
        PoolKey memory key = _createPoolKey();
        bytes4 selector = hook.afterDonate(address(0), key, 0, 0, "");
        assertEq(selector, IHooks.afterDonate.selector);
    }

    // ========== Fuzz Tests ==========

    function testFuzzAfterSwap(int128 amount0, int128 amount1, bool zeroForOne) public {
        PoolKey memory key = _createPoolKey();
        IPoolManager.SwapParams memory params = _createSwapParams(zeroForOne, -1000e18);
        BalanceDelta delta = toBalanceDelta(amount0, amount1);

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        vm.prank(poolManager);
        (bytes4 selector, int128 hookDelta) = hook.afterSwap(alice, key, params, delta, "");

        assertEq(selector, IHooks.afterSwap.selector);
        assertEq(hookDelta, 0);
        assertTrue(profitToken.balanceOf(alice) >= aliceInitialBalance);
    }

    function testFuzzDifferentPoolKeys(address _token0, address _token1, uint24 fee, int24 tickSpacing) public {
        vm.assume(_token0 != address(0) && _token1 != address(0));
        vm.assume(_token0 != _token1);
        vm.assume(fee <= 1_000_000);
        vm.assume(tickSpacing > 0 && tickSpacing < type(int16).max);

        // Ensure sorted order
        if (_token0 > _token1) (_token0, _token1) = (_token1, _token0);

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(_token0),
            currency1: Currency.wrap(_token1),
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(hook))
        });

        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(500e6, -250e6);

        vm.prank(poolManager);
        (bytes4 selector,) = hook.afterSwap(alice, key, params, delta, "");
        assertEq(selector, IHooks.afterSwap.selector);

        // Pool ID should be unique per pool key
        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.triggerPoolId, PoolId.unwrap(key.toId()));
    }

    function testFuzzSwapDirections(bool zeroForOne, int128 absAmount0, int128 absAmount1) public {
        vm.assume(absAmount0 > 0 && absAmount1 > 0);

        PoolKey memory key = _createPoolKey();
        IPoolManager.SwapParams memory params = _createSwapParams(zeroForOne, -1000e18);

        // Create deltas matching swap direction
        BalanceDelta delta;
        if (zeroForOne) {
            delta = toBalanceDelta(absAmount0, -absAmount1);
        } else {
            delta = toBalanceDelta(-absAmount0, absAmount1);
        }

        vm.prank(poolManager);
        hook.afterSwap(alice, key, params, delta, "");

        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.token0In, zeroForOne);
    }
}
