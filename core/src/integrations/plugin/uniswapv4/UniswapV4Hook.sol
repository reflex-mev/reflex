// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {LPFeeLibrary} from "v4-core/src/libraries/LPFeeLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IWETH9} from "v4-periphery/src/interfaces/external/IWETH9.sol";
import "../ReflexAfterSwap.sol";

contract UniswapV4Hook is IHooks, ReflexAfterSwap {
    using PoolIdLibrary for PoolKey;
    using SafeERC20 for IERC20;

    IPoolManager public immutable poolManager;
    address public immutable owner;
    address public immutable weth;

    modifier onlyPoolManager() {
        require(msg.sender == address(poolManager), "UniswapV4Hook: Caller is not the PoolManager");
        _;
    }

    receive() external payable {}

    constructor(IPoolManager _poolManager, address _reflexRouter, bytes32 _configId, address _owner, address _weth)
        ReflexAfterSwap(_reflexRouter, _configId)
    {
        require(_owner != address(0), "UniswapV4Hook: Owner cannot be zero address");
        poolManager = _poolManager;
        owner = _owner;
        weth = _weth;

        Hooks.validateHookPermissions(
            IHooks(address(this)),
            Hooks.Permissions({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: false,
                afterAddLiquidity: false,
                beforeRemoveLiquidity: false,
                afterRemoveLiquidity: false,
                beforeSwap: true,
                afterSwap: true,
                beforeDonate: false,
                afterDonate: false,
                beforeSwapReturnDelta: false,
                afterSwapReturnDelta: false,
                afterAddLiquidityReturnDelta: false,
                afterRemoveLiquidityReturnDelta: false
            })
        );
    }

    function beforeInitialize(address, PoolKey calldata, uint160) external pure override returns (bytes4) {
        return IHooks.beforeInitialize.selector;
    }

    function afterInitialize(address, PoolKey calldata, uint160, int24) external pure override returns (bytes4) {
        return IHooks.afterInitialize.selector;
    }

    function beforeAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IHooks.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure override returns (bytes4, BalanceDelta) {
        return (IHooks.afterAddLiquidity.selector, BalanceDelta.wrap(0));
    }

    function beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IHooks.beforeRemoveLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        IPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure override returns (bytes4, BalanceDelta) {
        return (IHooks.afterRemoveLiquidity.selector, BalanceDelta.wrap(0));
    }

    function beforeSwap(address sender, PoolKey calldata, IPoolManager.SwapParams calldata, bytes calldata)
        external
        view
        override
        onlyPoolManager
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        uint24 lpFeeOverride = sender == getRouter() ? LPFeeLibrary.OVERRIDE_FEE_FLAG : 0;
        return (IHooks.beforeSwap.selector, BeforeSwapDelta.wrap(0), lpFeeOverride);
    }

    function afterSwap(
        address,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata
    ) external override onlyPoolManager returns (bytes4, int128) {
        bytes32 triggerPoolId = PoolId.unwrap(key.toId());

        // In V4, negative delta = tokens transferred into the pool (amount in)
        uint256 amountIn;
        if (params.zeroForOne) {
            amountIn = uint256(-int256(delta.amount0()));
        } else {
            amountIn = uint256(-int256(delta.amount1()));
        }

        // Router sends user's share to tx.origin, LP share to hook (based on configId)
        (, address profitToken) = _reflexAfterSwap(triggerPoolId, amountIn, params.zeroForOne, tx.origin);

        // Distribute LP share (hook's balance) to pool LPs or fallback to tx.origin
        if (profitToken != address(0)) {
            _distributeLpShare(key, profitToken);
        }

        return (IHooks.afterSwap.selector, 0);
    }

    /// @notice Checks hook's balance and donates to pool LPs or falls back to tx.origin
    function _distributeLpShare(PoolKey calldata key, address profitToken) internal {
        uint256 lpAmount = IERC20(profitToken).balanceOf(address(this));
        if (lpAmount == 0) return;

        // Match profitToken to a pool currency (check both raw address AND WETH<>native ETH equivalence)
        bool matchesCurrency0 = _matchesCurrency(profitToken, key.currency0);
        bool matchesCurrency1 = _matchesCurrency(profitToken, key.currency1);

        if (matchesCurrency0 || matchesCurrency1) {
            try this._donateToPool(key, profitToken, matchesCurrency0, lpAmount) {}
            catch {
                // Donate failed (e.g., no in-range liquidity) — send to tx.origin as fallback
                IERC20(profitToken).safeTransfer(tx.origin, lpAmount);
            }
        } else {
            // profitToken doesn't match any pool currency — send to tx.origin
            IERC20(profitToken).safeTransfer(tx.origin, lpAmount);
        }
    }

    /// @notice Checks if profitToken matches a pool currency (including WETH<>native ETH)
    function _matchesCurrency(address profitToken, Currency currency) internal view returns (bool) {
        address currencyAddr = Currency.unwrap(currency);
        return profitToken == currencyAddr || (currencyAddr == address(0) && profitToken == weth);
    }

    /// @notice Donates profit tokens to in-range LPs via PoolManager.donate()
    /// @dev Must be external so it can be called via try-catch from afterSwap.
    ///      Only callable by this contract itself.
    /// @param key The pool key to donate to
    /// @param profitToken The profit token address (may be WETH for native ETH pools)
    /// @param isCurrency0 Whether the profit token matches currency0 (false = currency1)
    /// @param amount The amount to donate
    function _donateToPool(PoolKey calldata key, address profitToken, bool isCurrency0, uint256 amount) external {
        require(msg.sender == address(this), "UniswapV4Hook: Only self-call");

        Currency currency = isCurrency0 ? key.currency0 : key.currency1;

        // Create debt on hook via donate
        poolManager.donate(key, isCurrency0 ? amount : 0, isCurrency0 ? 0 : amount, "");

        if (Currency.unwrap(currency) == address(0) && profitToken == weth) {
            // Native ETH pool + WETH profit: unwrap then settle with ETH value
            IWETH9(weth).withdraw(amount);
            poolManager.settle{value: amount}();
        } else {
            // ERC20 pool: sync, transfer, settle
            poolManager.sync(currency);
            IERC20(profitToken).safeTransfer(address(poolManager), amount);
            poolManager.settle();
        }
    }

    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IHooks.beforeDonate.selector;
    }

    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IHooks.afterDonate.selector;
    }

    /// @inheritdoc ReflexAfterSwap
    function _onlyReflexAdmin() internal view override {
        require(msg.sender == owner, "UniswapV4Hook: Caller is not the owner");
    }
}
