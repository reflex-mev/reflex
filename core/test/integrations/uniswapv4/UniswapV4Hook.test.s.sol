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
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
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
    address public wethAddr;

    bytes32 public testConfigId = keccak256("uniswapv4-config");

    function setUp() public {
        admin = address(this);

        // Create profit token and router
        profitToken = MockToken(TestUtils.createStandardMockToken());
        reflexRouter = MockReflexRouter(TestUtils.createMockReflexRouter(admin, address(profitToken)));

        // Use a mock address for pool manager
        poolManager = makeAddr("poolManager");
        wethAddr = makeAddr("weth");

        // Compute hook address with AFTER_SWAP_FLAG set in the last 14 bits
        // AFTER_SWAP_FLAG = 1 << 6 = 0x40
        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);

        // Deploy hook to a flag-compliant address
        deployCodeTo(
            "UniswapV4Hook.sol:UniswapV4Hook",
            abi.encode(IPoolManager(poolManager), address(reflexRouter), testConfigId, address(this), wethAddr),
            address(flags)
        );
        hook = UniswapV4Hook(payable(address(flags)));
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

    function _createSwapParams(bool zeroForOne, int256 amountSpecified)
        internal
        pure
        returns (IPoolManager.SwapParams memory)
    {
        return IPoolManager.SwapParams({zeroForOne: zeroForOne, amountSpecified: amountSpecified, sqrtPriceLimitX96: 0});
    }

    // ========== Constructor Tests ==========

    function testConstructor() public view {
        assertEq(hook.owner(), admin);
        assertEq(hook.getRouter(), address(reflexRouter));
        assertEq(hook.getConfigId(), testConfigId);
        assertEq(address(hook.poolManager()), poolManager);
        assertEq(hook.weth(), wethAddr);
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
        // V4: negative = amount in, positive = amount out
        // zeroForOne=true: token0 in (negative), token1 out (positive)
        BalanceDelta delta = toBalanceDelta(-500e6, 250e18);

        vm.prank(poolManager);
        (bytes4 selector, int128 hookDelta) = hook.afterSwap(alice, key, params, delta, "");

        assertEq(selector, IHooks.afterSwap.selector);
        assertEq(hookDelta, 0);
    }

    function testAfterSwapParameterMapping() public {
        PoolKey memory key = _createPoolKey();
        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        // V4: zeroForOne=true: token0 in (negative), token1 out (positive)
        BalanceDelta delta = toBalanceDelta(-500e6, 250e18);

        vm.prank(poolManager, alice);
        hook.afterSwap(alice, key, params, delta, "");

        // Verify triggerBackrun was called with correct parameters
        assertEq(reflexRouter.getTriggerBackrunCallsLength(), 1);
        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);

        // triggerPoolId should be the keccak256 hash of the pool key
        bytes32 expectedPoolId = PoolId.unwrap(key.toId());
        assertEq(call.triggerPoolId, expectedPoolId);

        // amountIn should be the absolute value of the negative (input) delta
        assertEq(call.swapAmountIn, uint112(uint256(500e6)));

        // zeroForOne should be passed through
        assertTrue(call.token0In);

        // recipient should be tx.origin
        assertEq(call.recipient, alice);

        // configId should match
        assertEq(call.configId, testConfigId);
    }

    function testAfterSwapZeroForOneTrue() public {
        PoolKey memory key = _createPoolKey();
        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        // V4: zeroForOne=true: token0 in (negative), token1 out (positive)
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        vm.prank(poolManager, alice);
        hook.afterSwap(alice, key, params, delta, "");

        // Alice (tx.origin) should receive profit
        assertTrue(profitToken.balanceOf(alice) > aliceInitialBalance);

        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertTrue(call.token0In);
        assertEq(call.swapAmountIn, uint112(uint256(500e6)));
    }

    function testAfterSwapZeroForOneFalse() public {
        PoolKey memory key = _createPoolKey();
        IPoolManager.SwapParams memory params = _createSwapParams(false, -1000e18);
        // V4: zeroForOne=false: token1 in (negative), token0 out (positive)
        BalanceDelta delta = toBalanceDelta(250e6, -500e6);

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        vm.prank(poolManager, alice);
        hook.afterSwap(alice, key, params, delta, "");

        assertTrue(profitToken.balanceOf(alice) > aliceInitialBalance);

        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertFalse(call.token0In);
        assertEq(call.swapAmountIn, uint112(uint256(500e6)));
    }

    function testAfterSwapTxOriginAsRecipient() public {
        PoolKey memory key = _createPoolKey();
        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        // V4: zeroForOne=true: token0 in (negative), token1 out (positive)
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        // Bob is tx.origin — profits go to tx.origin
        vm.prank(poolManager, bob);
        hook.afterSwap(alice, key, params, delta, "");

        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.recipient, bob);
    }

    function testAfterSwapOnlyPoolManager() public {
        PoolKey memory key = _createPoolKey();
        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        vm.prank(attacker);
        vm.expectRevert("UniswapV4Hook: Caller is not the PoolManager");
        hook.afterSwap(alice, key, params, delta, "");
    }

    // ========== ReflexAfterSwap Integration Tests ==========

    function testProfitExtractionFlow() public {
        PoolKey memory key = _createPoolKey();
        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        // V4: zeroForOne=true: token0 in (negative), token1 out (positive)
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        vm.prank(poolManager, alice);
        hook.afterSwap(alice, key, params, delta, "");

        uint256 aliceFinalBalance = profitToken.balanceOf(alice);
        assertTrue(aliceFinalBalance > aliceInitialBalance);
        assertEq(aliceFinalBalance - aliceInitialBalance, reflexRouter.mockProfit());
    }

    function testRouterFailureFailsafe() public {
        reflexRouter.setShouldRevert(true);

        PoolKey memory key = _createPoolKey();
        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        // Should not revert even if router fails
        vm.prank(poolManager, alice);
        (bytes4 selector,) = hook.afterSwap(alice, key, params, delta, "");

        assertEq(selector, IHooks.afterSwap.selector);
        assertEq(profitToken.balanceOf(alice), aliceInitialBalance);
    }

    function testMultipleConsecutiveSwaps() public {
        PoolKey memory key = _createPoolKey();

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);
        uint256 bobInitialBalance = profitToken.balanceOf(bob);

        // First swap - alice is tx.origin, zeroForOne=true: token0 in (negative)
        vm.prank(poolManager, alice);
        hook.afterSwap(alice, key, _createSwapParams(true, -1000e18), toBalanceDelta(-500e6, 250e6), "");

        uint256 aliceAfterFirst = profitToken.balanceOf(alice);
        assertTrue(aliceAfterFirst > aliceInitialBalance);

        // Second swap - bob is tx.origin, zeroForOne=false: token1 in (negative)
        vm.prank(poolManager, bob);
        hook.afterSwap(bob, key, _createSwapParams(false, -2000e18), toBalanceDelta(800e6, -400e6), "");

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
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        vm.prank(poolManager, alice);
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
        // V4: the input token delta must be negative
        // Ensure the input side is negative to avoid underflow in uint256(-int256(...))
        if (zeroForOne) {
            vm.assume(amount0 <= 0);
        } else {
            vm.assume(amount1 <= 0);
        }

        PoolKey memory key = _createPoolKey();
        IPoolManager.SwapParams memory params = _createSwapParams(zeroForOne, -1000e18);
        BalanceDelta delta = toBalanceDelta(amount0, amount1);

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        vm.prank(poolManager, alice);
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
        // V4: zeroForOne=true: token0 in (negative), token1 out (positive)
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        vm.prank(poolManager, alice);
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

        // V4: negative = amount in, positive = amount out
        BalanceDelta delta;
        if (zeroForOne) {
            delta = toBalanceDelta(-absAmount0, absAmount1);
        } else {
            delta = toBalanceDelta(absAmount0, -absAmount1);
        }

        vm.prank(poolManager, alice);
        hook.afterSwap(alice, key, params, delta, "");

        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.token0In, zeroForOne);
    }

    // ========== Donate to LP Tests ==========

    /// @notice Helper: deploy a hook where profitToken matches a pool currency for donate tests
    function _setupDonateHook(address _profitTokenAddr)
        internal
        returns (UniswapV4Hook donateHook, MockReflexRouter donateRouter)
    {
        donateRouter = MockReflexRouter(TestUtils.createMockReflexRouter(admin, _profitTokenAddr));

        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);
        deployCodeTo(
            "UniswapV4Hook.sol:UniswapV4Hook",
            abi.encode(IPoolManager(poolManager), address(donateRouter), testConfigId, address(this), wethAddr),
            address(flags)
        );
        donateHook = UniswapV4Hook(payable(address(flags)));
    }

    /// @notice Helper: mock PoolManager donate/sync/settle for ERC20 donations
    function _mockPoolManagerForDonate(uint256 donateAmount, bool) internal {
        // Mock donate to return BalanceDelta
        vm.mockCall(poolManager, abi.encodeWithSelector(IPoolManager.donate.selector), abi.encode(int256(0)));

        // Mock sync
        vm.mockCall(poolManager, abi.encodeWithSelector(IPoolManager.sync.selector), "");

        // Mock settle (no value — ERC20 path)
        vm.mockCall(poolManager, 0, abi.encodeWithSelector(IPoolManager.settle.selector), abi.encode(donateAmount));
    }

    function testAfterSwapDonatesProfitToLps() public {
        // Use profitToken as currency1 so it matches the pool
        address otherToken = address(0x0001);
        // profitToken address > otherToken, so currency0=otherToken, currency1=profitToken
        require(address(profitToken) > otherToken, "test setup: need profitToken > otherToken");

        (UniswapV4Hook donateHook, MockReflexRouter donateRouter) = _setupDonateHook(address(profitToken));

        uint256 lpShare = 200e18;
        donateRouter.setMockLpShare(lpShare);

        _mockPoolManagerForDonate(lpShare, false);

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(otherToken),
            currency1: Currency.wrap(address(profitToken)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(donateHook))
        });
        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        vm.prank(poolManager, alice);
        donateHook.afterSwap(alice, key, params, delta, "");

        // Hook should have donated its entire LP share — balance should be 0
        assertEq(profitToken.balanceOf(address(donateHook)), 0);
        // poolManager should have received the tokens via safeTransfer
        assertEq(profitToken.balanceOf(poolManager), lpShare);
    }

    function testAfterSwapProfitTokenMatchesCurrency0() public {
        // Use profitToken as currency0
        address otherToken = address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
        // profitToken address < otherToken
        require(address(profitToken) < otherToken, "test setup: need profitToken < otherToken");

        (UniswapV4Hook donateHook, MockReflexRouter donateRouter) = _setupDonateHook(address(profitToken));

        uint256 lpShare = 300e18;
        donateRouter.setMockLpShare(lpShare);

        _mockPoolManagerForDonate(lpShare, true);

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(profitToken)),
            currency1: Currency.wrap(otherToken),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(donateHook))
        });
        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        vm.prank(poolManager, alice);
        donateHook.afterSwap(alice, key, params, delta, "");

        // Hook donated everything
        assertEq(profitToken.balanceOf(address(donateHook)), 0);
        assertEq(profitToken.balanceOf(poolManager), lpShare);
    }

    function testAfterSwapDonatesWethAsNativeEth() public {
        // Deploy hook with profitToken acting as WETH
        address wethToken = address(profitToken);
        MockReflexRouter wethRouter = MockReflexRouter(TestUtils.createMockReflexRouter(admin, wethToken));

        uint160 flags = uint160(Hooks.AFTER_SWAP_FLAG);
        deployCodeTo(
            "UniswapV4Hook.sol:UniswapV4Hook",
            abi.encode(IPoolManager(poolManager), address(wethRouter), testConfigId, address(this), wethToken),
            address(flags)
        );
        UniswapV4Hook wethHook = UniswapV4Hook(payable(address(flags)));

        uint256 lpShare = 100e18;
        wethRouter.setMockLpShare(lpShare);

        // Pool with native ETH (address(0)) as currency0
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(0x3333)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(wethHook))
        });

        // Mock donate
        vm.mockCall(poolManager, abi.encodeWithSelector(IPoolManager.donate.selector), abi.encode(int256(0)));

        // Mock WETH withdraw
        vm.mockCall(wethToken, abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256)"))), "");

        // Give hook ETH for settlement (since mocked withdraw won't actually unwrap)
        vm.deal(address(wethHook), lpShare);

        // Mock settle with value (native ETH path)
        vm.mockCall(poolManager, lpShare, abi.encodeWithSelector(IPoolManager.settle.selector), abi.encode(lpShare));

        // Verify the WETH path is taken: withdraw called, then settle with ETH value
        vm.expectCall(wethToken, abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256)")), lpShare));
        vm.expectCall(poolManager, lpShare, abi.encodeWithSelector(IPoolManager.settle.selector));

        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        vm.prank(poolManager, alice);
        wethHook.afterSwap(alice, key, params, delta, "");
    }

    function testAfterSwapProfitTokenDoesNotMatchPool() public {
        // profitToken doesn't match either pool currency — should transfer to tx.origin
        (UniswapV4Hook donateHook, MockReflexRouter donateRouter) = _setupDonateHook(address(profitToken));

        uint256 lpShare = 150e18;
        donateRouter.setMockLpShare(lpShare);

        // Pool currencies are 0x1111 and 0x2222 — neither matches profitToken
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(donateHook))
        });

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        vm.prank(poolManager, alice);
        donateHook.afterSwap(alice, key, params, delta, "");

        // Hook should have 0 balance — LP share sent to tx.origin (alice)
        assertEq(profitToken.balanceOf(address(donateHook)), 0);
        // alice gets both user share (mockProfit) and LP share (since no match)
        assertEq(profitToken.balanceOf(alice) - aliceInitialBalance, donateRouter.mockProfit() + lpShare);
    }

    function testAfterSwapDonateFailsFallbackToSender() public {
        // profitToken matches currency1, but donate reverts
        address otherToken = address(0x0001);
        require(address(profitToken) > otherToken, "test setup: need profitToken > otherToken");

        (UniswapV4Hook donateHook, MockReflexRouter donateRouter) = _setupDonateHook(address(profitToken));

        uint256 lpShare = 250e18;
        donateRouter.setMockLpShare(lpShare);

        // Mock donate to REVERT (e.g., no in-range liquidity)
        vm.mockCallRevert(poolManager, abi.encodeWithSelector(IPoolManager.donate.selector), "no in-range liquidity");

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(otherToken),
            currency1: Currency.wrap(address(profitToken)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(donateHook))
        });

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        vm.prank(poolManager, alice);
        donateHook.afterSwap(alice, key, params, delta, "");

        // Hook should have 0 balance — LP share fell back to tx.origin
        assertEq(profitToken.balanceOf(address(donateHook)), 0);
        // alice gets both user share and LP share (fallback)
        assertEq(profitToken.balanceOf(alice) - aliceInitialBalance, donateRouter.mockProfit() + lpShare);
    }

    function testAfterSwapRouterFailsSwapStillWorks() public {
        // Router reverts but swap should still complete — same as testRouterFailureFailsafe
        // but with LP share configured (should have no effect since router fails)
        reflexRouter.setShouldRevert(true);
        reflexRouter.setMockLpShare(500e18);

        PoolKey memory key = _createPoolKey();
        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        vm.prank(poolManager, alice);
        (bytes4 selector,) = hook.afterSwap(alice, key, params, delta, "");

        assertEq(selector, IHooks.afterSwap.selector);
        // No tokens moved since router reverted
        assertEq(profitToken.balanceOf(alice), aliceInitialBalance);
        assertEq(profitToken.balanceOf(address(hook)), 0);
    }

    function testAfterSwapZeroProfitNoAction() public {
        // Set mock profit and LP share to 0
        reflexRouter.setMockProfit(0);
        reflexRouter.setMockLpShare(0);

        PoolKey memory key = _createPoolKey();
        IPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        vm.prank(poolManager, alice);
        (bytes4 selector,) = hook.afterSwap(alice, key, params, delta, "");

        assertEq(selector, IHooks.afterSwap.selector);
        // No tokens moved
        assertEq(profitToken.balanceOf(alice), aliceInitialBalance);
        assertEq(profitToken.balanceOf(address(hook)), 0);
    }

    function testDonateToPoolOnlySelfCall() public {
        PoolKey memory key = _createPoolKey();

        vm.expectRevert("UniswapV4Hook: Only self-call");
        hook._donateToPool(key, token0, true, 100);
    }
}
