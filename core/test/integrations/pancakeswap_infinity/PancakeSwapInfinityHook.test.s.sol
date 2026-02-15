// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {PancakeSwapInfinityHook} from
    "@reflex/integrations/plugin/pancakeswap_infinity/PancakeSwapInfinityHook.sol";
import {
    ICLHooks,
    HOOKS_BEFORE_SWAP_OFFSET,
    HOOKS_AFTER_SWAP_OFFSET,
    HOOKS_BEFORE_INITIALIZE_OFFSET,
    HOOKS_AFTER_INITIALIZE_OFFSET,
    HOOKS_BEFORE_ADD_LIQUIDITY_OFFSET,
    HOOKS_AFTER_ADD_LIQUIDITY_OFFSET,
    HOOKS_BEFORE_REMOVE_LIQUIDITY_OFFSET,
    HOOKS_AFTER_REMOVE_LIQUIDITY_OFFSET,
    HOOKS_BEFORE_DONATE_OFFSET,
    HOOKS_AFTER_DONATE_OFFSET
} from "infinity-core/src/pool-cl/interfaces/ICLHooks.sol";
import {ICLPoolManager} from "infinity-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {IVault} from "infinity-core/src/interfaces/IVault.sol";
import {PoolKey} from "infinity-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "infinity-core/src/types/PoolId.sol";
import {BalanceDelta, toBalanceDelta} from "infinity-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "infinity-core/src/types/BeforeSwapDelta.sol";
import {Currency} from "infinity-core/src/types/Currency.sol";
import {IHooks} from "infinity-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "infinity-core/src/interfaces/IPoolManager.sol";
import {IProtocolFees} from "infinity-core/src/interfaces/IProtocolFees.sol";
import {CLPoolParametersHelper} from "infinity-core/src/pool-cl/libraries/CLPoolParametersHelper.sol";
import {LPFeeLibrary} from "infinity-core/src/libraries/LPFeeLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../utils/TestUtils.sol";
import "../../mocks/MockToken.sol";
import "../../mocks/MockReflexRouter.sol";

contract PancakeSwapInfinityHookTest is Test {
    using TestUtils for *;
    using PoolIdLibrary for PoolKey;

    PancakeSwapInfinityHook public hook;
    MockReflexRouter public reflexRouter;
    MockToken public profitToken;

    address public admin;
    address public alice = address(0xA);
    address public bob = address(0xB);
    address public attacker = address(0xBAD);
    address public poolManager;
    address public vaultAddr;

    // Test pool key components
    address public token0 = address(0x1111);
    address public token1 = address(0x2222);
    address public wethAddr;

    bytes32 public configIdFixture = keccak256("pancakeswap-infinity-config");

    // Hook bitmap for beforeSwap + afterSwap
    uint16 constant EXPECTED_BITMAP = uint16((1 << HOOKS_BEFORE_SWAP_OFFSET) | (1 << HOOKS_AFTER_SWAP_OFFSET));

    function setUp() public {
        admin = address(this);

        // Create profit token and router
        profitToken = MockToken(TestUtils.createStandardMockToken());
        reflexRouter = MockReflexRouter(TestUtils.createMockReflexRouter(admin, address(profitToken)));

        // Use mock addresses for pool manager and vault
        poolManager = makeAddr("poolManager");
        vaultAddr = makeAddr("vault");
        wethAddr = makeAddr("weth");

        // Mock poolManager.vault() to return vaultAddr
        vm.mockCall(poolManager, abi.encodeWithSelector(IProtocolFees.vault.selector), abi.encode(vaultAddr));

        // Deploy hook
        hook = new PancakeSwapInfinityHook(
            ICLPoolManager(poolManager), address(reflexRouter), configIdFixture, address(this), wethAddr
        );
    }

    // ========== Helper Functions ==========

    function _createPoolKey() internal view returns (PoolKey memory) {
        bytes32 parameters = bytes32(uint256(EXPECTED_BITMAP));
        parameters = CLPoolParametersHelper.setTickSpacing(parameters, 60);

        return PoolKey({
            currency0: Currency.wrap(token0),
            currency1: Currency.wrap(token1),
            hooks: IHooks(address(hook)),
            poolManager: IPoolManager(poolManager),
            fee: 3000,
            parameters: parameters
        });
    }

    function _createPoolKey(address _token0, address _token1) internal view returns (PoolKey memory) {
        bytes32 parameters = bytes32(uint256(EXPECTED_BITMAP));
        parameters = CLPoolParametersHelper.setTickSpacing(parameters, 60);

        return PoolKey({
            currency0: Currency.wrap(_token0),
            currency1: Currency.wrap(_token1),
            hooks: IHooks(address(hook)),
            poolManager: IPoolManager(poolManager),
            fee: 3000,
            parameters: parameters
        });
    }

    function _createSwapParams(bool zeroForOne, int256 amountSpecified)
        internal
        pure
        returns (ICLPoolManager.SwapParams memory)
    {
        return ICLPoolManager.SwapParams({zeroForOne: zeroForOne, amountSpecified: amountSpecified, sqrtPriceLimitX96: 0});
    }

    // ========== Constructor Tests ==========

    function testConstructor() public view {
        assertEq(hook.owner(), admin);
        assertEq(hook.getRouter(), address(reflexRouter));
        assertEq(hook.getConfigId(), configIdFixture);
        assertEq(address(hook.poolManager()), poolManager);
        assertEq(address(hook.vault()), vaultAddr);
        assertEq(hook.weth(), wethAddr);
    }

    function testHookPermissionsBitmap() public view {
        uint16 bitmap = hook.getHooksRegistrationBitmap();
        assertEq(bitmap, EXPECTED_BITMAP);

        // Verify specific bits
        assertTrue(bitmap & (1 << HOOKS_BEFORE_SWAP_OFFSET) != 0, "beforeSwap should be enabled");
        assertTrue(bitmap & (1 << HOOKS_AFTER_SWAP_OFFSET) != 0, "afterSwap should be enabled");
        assertTrue(bitmap & (1 << HOOKS_BEFORE_INITIALIZE_OFFSET) == 0, "beforeInitialize should be disabled");
        assertTrue(bitmap & (1 << HOOKS_AFTER_INITIALIZE_OFFSET) == 0, "afterInitialize should be disabled");
        assertTrue(bitmap & (1 << HOOKS_BEFORE_ADD_LIQUIDITY_OFFSET) == 0, "beforeAddLiquidity should be disabled");
        assertTrue(bitmap & (1 << HOOKS_AFTER_ADD_LIQUIDITY_OFFSET) == 0, "afterAddLiquidity should be disabled");
        assertTrue(
            bitmap & (1 << HOOKS_BEFORE_REMOVE_LIQUIDITY_OFFSET) == 0, "beforeRemoveLiquidity should be disabled"
        );
        assertTrue(
            bitmap & (1 << HOOKS_AFTER_REMOVE_LIQUIDITY_OFFSET) == 0, "afterRemoveLiquidity should be disabled"
        );
        assertTrue(bitmap & (1 << HOOKS_BEFORE_DONATE_OFFSET) == 0, "beforeDonate should be disabled");
        assertTrue(bitmap & (1 << HOOKS_AFTER_DONATE_OFFSET) == 0, "afterDonate should be disabled");
    }

    function testConstructorZeroOwnerReverts() public {
        vm.mockCall(poolManager, abi.encodeWithSelector(IProtocolFees.vault.selector), abi.encode(vaultAddr));
        vm.expectRevert("PancakeSwapInfinityHook: Owner cannot be zero address");
        new PancakeSwapInfinityHook(ICLPoolManager(poolManager), address(reflexRouter), configIdFixture, address(0), wethAddr);
    }

    // ========== afterSwap Tests ==========

    function testAfterSwap() public {
        PoolKey memory key = _createPoolKey();
        ICLPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(-500e6, 250e18);

        vm.prank(poolManager);
        (bytes4 selector, int128 hookDelta) = hook.afterSwap(alice, key, params, delta, "");

        assertEq(selector, hook.afterSwap.selector);
        assertEq(hookDelta, 0);
    }

    function testAfterSwapParameterMapping() public {
        PoolKey memory key = _createPoolKey();
        ICLPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
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
        assertEq(call.configId, configIdFixture);
    }

    function testAfterSwapZeroForOneTrue() public {
        PoolKey memory key = _createPoolKey();
        ICLPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
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
        ICLPoolManager.SwapParams memory params = _createSwapParams(false, -1000e18);
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
        ICLPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        // Bob is tx.origin — profits go to tx.origin
        vm.prank(poolManager, bob);
        hook.afterSwap(alice, key, params, delta, "");

        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.recipient, bob);
    }

    function testAfterSwapOnlyPoolManager() public {
        PoolKey memory key = _createPoolKey();
        ICLPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        vm.prank(attacker);
        vm.expectRevert("PancakeSwapInfinityHook: Caller is not the PoolManager");
        hook.afterSwap(alice, key, params, delta, "");
    }

    // ========== ReflexAfterSwap Integration Tests ==========

    function testProfitExtractionFlow() public {
        PoolKey memory key = _createPoolKey();
        ICLPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
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
        ICLPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        // Should not revert even if router fails
        vm.prank(poolManager, alice);
        (bytes4 selector,) = hook.afterSwap(alice, key, params, delta, "");

        assertEq(selector, hook.afterSwap.selector);
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
        vm.expectRevert("PancakeSwapInfinityHook: Caller is not the owner");
        hook.setReflexRouter(makeAddr("newRouter"));
    }

    function testSetReflexConfigId() public {
        bytes32 newConfigId = keccak256("new-config");

        hook.setReflexConfigId(newConfigId);

        assertEq(hook.getConfigId(), newConfigId);
    }

    function testSetReflexConfigIdUnauthorized() public {
        vm.prank(attacker);
        vm.expectRevert("PancakeSwapInfinityHook: Caller is not the owner");
        hook.setReflexConfigId(keccak256("new-config"));
    }

    function testSetReflexRouterZeroAddress() public {
        vm.expectRevert("Invalid router address");
        hook.setReflexRouter(address(0));
    }

    // ========== ConfigId Tests ==========

    function configIdFixturePassedToTriggerBackrun() public {
        PoolKey memory key = _createPoolKey();
        ICLPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        vm.prank(poolManager, alice);
        hook.afterSwap(alice, key, params, delta, "");

        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.configId, configIdFixture);
    }

    // ========== No-op Hook Tests ==========

    function testBeforeInitializeNoOp() public view {
        PoolKey memory key = _createPoolKey();
        bytes4 selector = hook.beforeInitialize(address(0), key, 0);
        assertEq(selector, hook.beforeInitialize.selector);
    }

    function testAfterInitializeNoOp() public view {
        PoolKey memory key = _createPoolKey();
        bytes4 selector = hook.afterInitialize(address(0), key, 0, 0);
        assertEq(selector, hook.afterInitialize.selector);
    }

    function testBeforeSwapNonRouterNoOverride() public {
        PoolKey memory key = _createPoolKey();
        ICLPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        vm.prank(poolManager);
        (bytes4 selector, BeforeSwapDelta beforeDelta, uint24 fee) = hook.beforeSwap(address(0), key, params, "");
        assertEq(selector, hook.beforeSwap.selector);
        assertEq(BeforeSwapDelta.unwrap(beforeDelta), 0);
        assertEq(fee, 0);
    }

    function testBeforeSwapRouterGets100PctDiscount() public {
        PoolKey memory key = _createPoolKey();
        ICLPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        vm.prank(poolManager);
        (bytes4 selector, BeforeSwapDelta beforeDelta, uint24 fee) =
            hook.beforeSwap(address(reflexRouter), key, params, "");
        assertEq(selector, hook.beforeSwap.selector);
        assertEq(BeforeSwapDelta.unwrap(beforeDelta), 0);
        assertEq(fee, LPFeeLibrary.OVERRIDE_FEE_FLAG);
    }

    function testBeforeSwapArbitrarySenderNoDiscount() public {
        PoolKey memory key = _createPoolKey();
        ICLPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        vm.prank(poolManager);
        (bytes4 selector, BeforeSwapDelta beforeDelta, uint24 fee) = hook.beforeSwap(alice, key, params, "");
        assertEq(selector, hook.beforeSwap.selector);
        assertEq(BeforeSwapDelta.unwrap(beforeDelta), 0);
        assertEq(fee, 0);
    }

    function testBeforeSwapOnlyPoolManager() public {
        PoolKey memory key = _createPoolKey();
        ICLPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        vm.prank(attacker);
        vm.expectRevert("PancakeSwapInfinityHook: Caller is not the PoolManager");
        hook.beforeSwap(alice, key, params, "");
    }

    function testBeforeDonateNoOp() public view {
        PoolKey memory key = _createPoolKey();
        bytes4 selector = hook.beforeDonate(address(0), key, 0, 0, "");
        assertEq(selector, hook.beforeDonate.selector);
    }

    function testAfterDonateNoOp() public view {
        PoolKey memory key = _createPoolKey();
        bytes4 selector = hook.afterDonate(address(0), key, 0, 0, "");
        assertEq(selector, hook.afterDonate.selector);
    }

    // ========== Fuzz Tests ==========

    function testFuzzAfterSwap(int128 amount0, int128 amount1, bool zeroForOne) public {
        // Ensure the input side is negative to avoid underflow
        if (zeroForOne) {
            vm.assume(amount0 <= 0);
        } else {
            vm.assume(amount1 <= 0);
        }

        PoolKey memory key = _createPoolKey();
        ICLPoolManager.SwapParams memory params = _createSwapParams(zeroForOne, -1000e18);
        BalanceDelta delta = toBalanceDelta(amount0, amount1);

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        vm.prank(poolManager, alice);
        (bytes4 selector, int128 hookDelta) = hook.afterSwap(alice, key, params, delta, "");

        assertEq(selector, hook.afterSwap.selector);
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

        bytes32 parameters = bytes32(uint256(EXPECTED_BITMAP));
        parameters = CLPoolParametersHelper.setTickSpacing(parameters, tickSpacing);

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(_token0),
            currency1: Currency.wrap(_token1),
            hooks: IHooks(address(hook)),
            poolManager: IPoolManager(poolManager),
            fee: fee,
            parameters: parameters
        });

        ICLPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        vm.prank(poolManager, alice);
        (bytes4 selector,) = hook.afterSwap(alice, key, params, delta, "");
        assertEq(selector, hook.afterSwap.selector);

        // Pool ID should be unique per pool key
        MockReflexRouter.TriggerBackrunCall memory call = reflexRouter.getTriggerBackrunCall(0);
        assertEq(call.triggerPoolId, PoolId.unwrap(key.toId()));
    }

    function testFuzzSwapDirections(bool zeroForOne, int128 absAmount0, int128 absAmount1) public {
        vm.assume(absAmount0 > 0 && absAmount1 > 0);

        PoolKey memory key = _createPoolKey();
        ICLPoolManager.SwapParams memory params = _createSwapParams(zeroForOne, -1000e18);

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
        returns (PancakeSwapInfinityHook donateHook, MockReflexRouter donateRouter)
    {
        donateRouter = MockReflexRouter(TestUtils.createMockReflexRouter(admin, _profitTokenAddr));

        vm.mockCall(poolManager, abi.encodeWithSelector(IProtocolFees.vault.selector), abi.encode(vaultAddr));

        donateHook = new PancakeSwapInfinityHook(
            ICLPoolManager(poolManager), address(donateRouter), configIdFixture, address(this), wethAddr
        );
    }

    /// @notice Helper: mock PoolManager donate and Vault sync/settle for ERC20 donations
    function _mockPoolManagerForDonate(uint256 donateAmount, bool) internal {
        // Mock donate to return BalanceDelta
        vm.mockCall(poolManager, abi.encodeWithSelector(ICLPoolManager.donate.selector), abi.encode(int256(0)));

        // Mock vault sync
        vm.mockCall(vaultAddr, abi.encodeWithSelector(IVault.sync.selector), "");

        // Mock vault settle (no value — ERC20 path)
        vm.mockCall(vaultAddr, 0, abi.encodeWithSelector(IVault.settle.selector), abi.encode(donateAmount));
    }

    function testAfterSwapDonatesProfitToLps() public {
        // Use profitToken as currency1 so it matches the pool
        address otherToken = address(0x0001);
        // profitToken address > otherToken, so currency0=otherToken, currency1=profitToken
        require(address(profitToken) > otherToken, "test setup: need profitToken > otherToken");

        (PancakeSwapInfinityHook donateHook, MockReflexRouter donateRouter) = _setupDonateHook(address(profitToken));

        uint256 lpShare = 200e18;
        donateRouter.setMockLpShare(lpShare);

        _mockPoolManagerForDonate(lpShare, false);

        bytes32 parameters = bytes32(uint256(EXPECTED_BITMAP));
        parameters = CLPoolParametersHelper.setTickSpacing(parameters, 60);

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(otherToken),
            currency1: Currency.wrap(address(profitToken)),
            hooks: IHooks(address(donateHook)),
            poolManager: IPoolManager(poolManager),
            fee: 3000,
            parameters: parameters
        });
        ICLPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        vm.prank(poolManager, alice);
        donateHook.afterSwap(alice, key, params, delta, "");

        // Hook should have donated its entire LP share — balance should be 0
        assertEq(profitToken.balanceOf(address(donateHook)), 0);
        // vault should have received the tokens via safeTransfer
        assertEq(profitToken.balanceOf(vaultAddr), lpShare);
    }

    function testAfterSwapProfitTokenMatchesCurrency0() public {
        // Use profitToken as currency0
        address otherToken = address(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
        // profitToken address < otherToken
        require(address(profitToken) < otherToken, "test setup: need profitToken < otherToken");

        (PancakeSwapInfinityHook donateHook, MockReflexRouter donateRouter) = _setupDonateHook(address(profitToken));

        uint256 lpShare = 300e18;
        donateRouter.setMockLpShare(lpShare);

        _mockPoolManagerForDonate(lpShare, true);

        bytes32 parameters = bytes32(uint256(EXPECTED_BITMAP));
        parameters = CLPoolParametersHelper.setTickSpacing(parameters, 60);

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(profitToken)),
            currency1: Currency.wrap(otherToken),
            hooks: IHooks(address(donateHook)),
            poolManager: IPoolManager(poolManager),
            fee: 3000,
            parameters: parameters
        });
        ICLPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        vm.prank(poolManager, alice);
        donateHook.afterSwap(alice, key, params, delta, "");

        // Hook donated everything
        assertEq(profitToken.balanceOf(address(donateHook)), 0);
        assertEq(profitToken.balanceOf(vaultAddr), lpShare);
    }

    function testAfterSwapDonatesWethAsNativeEth() public {
        // Deploy hook with profitToken acting as WETH
        address wethToken = address(profitToken);
        MockReflexRouter wethRouter = MockReflexRouter(TestUtils.createMockReflexRouter(admin, wethToken));

        vm.mockCall(poolManager, abi.encodeWithSelector(IProtocolFees.vault.selector), abi.encode(vaultAddr));

        PancakeSwapInfinityHook wethHook = new PancakeSwapInfinityHook(
            ICLPoolManager(poolManager), address(wethRouter), configIdFixture, address(this), wethToken
        );

        uint256 lpShare = 100e18;
        wethRouter.setMockLpShare(lpShare);

        bytes32 parameters = bytes32(uint256(EXPECTED_BITMAP));
        parameters = CLPoolParametersHelper.setTickSpacing(parameters, 60);

        // Pool with native ETH (address(0)) as currency0
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(0x3333)),
            hooks: IHooks(address(wethHook)),
            poolManager: IPoolManager(poolManager),
            fee: 3000,
            parameters: parameters
        });

        // Mock donate
        vm.mockCall(poolManager, abi.encodeWithSelector(ICLPoolManager.donate.selector), abi.encode(int256(0)));

        // Mock WETH withdraw
        vm.mockCall(wethToken, abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256)"))), "");

        // Give hook ETH for settlement (since mocked withdraw won't actually unwrap)
        vm.deal(address(wethHook), lpShare);

        // Mock vault settle with value (native ETH path)
        vm.mockCall(vaultAddr, lpShare, abi.encodeWithSelector(IVault.settle.selector), abi.encode(lpShare));

        // Verify the WETH path is taken: withdraw called, then vault.settle with ETH value
        vm.expectCall(wethToken, abi.encodeWithSelector(bytes4(keccak256("withdraw(uint256)")), lpShare));
        vm.expectCall(vaultAddr, lpShare, abi.encodeWithSelector(IVault.settle.selector));

        ICLPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        vm.prank(poolManager, alice);
        wethHook.afterSwap(alice, key, params, delta, "");
    }

    function testAfterSwapProfitTokenDoesNotMatchPool() public {
        // profitToken doesn't match either pool currency — should transfer to tx.origin
        (PancakeSwapInfinityHook donateHook, MockReflexRouter donateRouter) = _setupDonateHook(address(profitToken));

        uint256 lpShare = 150e18;
        donateRouter.setMockLpShare(lpShare);

        // Pool currencies are 0x1111 and 0x2222 — neither matches profitToken
        PoolKey memory key = _createPoolKey();

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        ICLPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
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

        (PancakeSwapInfinityHook donateHook, MockReflexRouter donateRouter) = _setupDonateHook(address(profitToken));

        uint256 lpShare = 250e18;
        donateRouter.setMockLpShare(lpShare);

        // Mock donate to REVERT (e.g., no in-range liquidity)
        vm.mockCallRevert(
            poolManager, abi.encodeWithSelector(ICLPoolManager.donate.selector), "no in-range liquidity"
        );

        bytes32 parameters = bytes32(uint256(EXPECTED_BITMAP));
        parameters = CLPoolParametersHelper.setTickSpacing(parameters, 60);

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(otherToken),
            currency1: Currency.wrap(address(profitToken)),
            hooks: IHooks(address(donateHook)),
            poolManager: IPoolManager(poolManager),
            fee: 3000,
            parameters: parameters
        });

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        ICLPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        vm.prank(poolManager, alice);
        donateHook.afterSwap(alice, key, params, delta, "");

        // Hook should have 0 balance — LP share fell back to tx.origin
        assertEq(profitToken.balanceOf(address(donateHook)), 0);
        // alice gets both user share and LP share (fallback)
        assertEq(profitToken.balanceOf(alice) - aliceInitialBalance, donateRouter.mockProfit() + lpShare);
    }

    function testAfterSwapRouterFailsSwapStillWorks() public {
        reflexRouter.setShouldRevert(true);
        reflexRouter.setMockLpShare(500e18);

        PoolKey memory key = _createPoolKey();
        ICLPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        vm.prank(poolManager, alice);
        (bytes4 selector,) = hook.afterSwap(alice, key, params, delta, "");

        assertEq(selector, hook.afterSwap.selector);
        // No tokens moved since router reverted
        assertEq(profitToken.balanceOf(alice), aliceInitialBalance);
        assertEq(profitToken.balanceOf(address(hook)), 0);
    }

    function testAfterSwapZeroProfitNoAction() public {
        // Set mock profit and LP share to 0
        reflexRouter.setMockProfit(0);
        reflexRouter.setMockLpShare(0);

        PoolKey memory key = _createPoolKey();
        ICLPoolManager.SwapParams memory params = _createSwapParams(true, -1000e18);
        BalanceDelta delta = toBalanceDelta(-500e6, 250e6);

        uint256 aliceInitialBalance = profitToken.balanceOf(alice);

        vm.prank(poolManager, alice);
        (bytes4 selector,) = hook.afterSwap(alice, key, params, delta, "");

        assertEq(selector, hook.afterSwap.selector);
        // No tokens moved
        assertEq(profitToken.balanceOf(alice), aliceInitialBalance);
        assertEq(profitToken.balanceOf(address(hook)), 0);
    }

    function testDonateToPoolOnlySelfCall() public {
        PoolKey memory key = _createPoolKey();

        vm.expectRevert("PancakeSwapInfinityHook: Only self-call");
        hook._donateToPool(key, token0, true, 100);
    }
}
