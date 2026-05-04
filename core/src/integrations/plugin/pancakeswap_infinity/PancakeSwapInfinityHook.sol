// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {
    ICLHooks,
    HOOKS_AFTER_INITIALIZE_OFFSET,
    HOOKS_BEFORE_SWAP_OFFSET,
    HOOKS_AFTER_SWAP_OFFSET
} from "infinity-core/src/pool-cl/interfaces/ICLHooks.sol";
import {ICLPoolManager} from "infinity-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {IVault} from "infinity-core/src/interfaces/IVault.sol";
import {PoolKey} from "infinity-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "infinity-core/src/types/PoolId.sol";
import {BalanceDelta} from "infinity-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "infinity-core/src/types/BeforeSwapDelta.sol";
import {Currency} from "infinity-core/src/types/Currency.sol";
import {LPFeeLibrary} from "infinity-core/src/libraries/LPFeeLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import "../ReflexAfterSwap.sol";

interface IWETH9 {
    function deposit() external payable;
    function withdraw(uint256) external;
}

contract PancakeSwapInfinityHook is ICLHooks, ReflexAfterSwap, Ownable2Step {
    using PoolIdLibrary for PoolKey;
    using SafeERC20 for IERC20;

    ICLPoolManager public immutable poolManager;
    IVault public immutable vault;
    address public immutable weth;

    modifier onlyPoolManager() {
        require(msg.sender == address(poolManager), "PancakeSwapInfinityHook: Caller is not the PoolManager");
        _;
    }

    receive() external payable {}

    constructor(ICLPoolManager _poolManager, address _reflexRouter, bytes32 _configId, address _owner, address _weth)
        ReflexAfterSwap(_reflexRouter, _configId)
        Ownable(_owner)
    {
        poolManager = _poolManager;
        vault = _poolManager.vault();
        weth = _weth;
    }

    /// @notice Returns the hook registration bitmap for PancakeSwap Infinity
    /// @dev Enables afterInitialize (bit 1), beforeSwap (bit 6), afterSwap (bit 7)
    function getHooksRegistrationBitmap() external pure override returns (uint16) {
        return
            uint16(
                (1 << HOOKS_AFTER_INITIALIZE_OFFSET) | (1 << HOOKS_BEFORE_SWAP_OFFSET) | (1 << HOOKS_AFTER_SWAP_OFFSET)
            );
    }

    function beforeInitialize(address, PoolKey calldata, uint160) external pure override returns (bytes4) {
        return this.beforeInitialize.selector;
    }

    /// @notice Rejects pool initialization unless the pool is configured with the dynamic-fee flag.
    /// @dev The hook's fee-discount mechanism overrides the LP fee via beforeSwap, which is only
    ///      honored by the pool manager on dynamic-fee pools. Without this check, the hook would
    ///      silently no-op on static-fee pools.
    function afterInitialize(address, PoolKey calldata key, uint160, int24)
        external
        view
        override
        onlyPoolManager
        returns (bytes4)
    {
        require(LPFeeLibrary.isDynamicLPFee(key.fee), "PancakeSwapInfinityHook: Dynamic-fee pool required");
        return this.afterInitialize.selector;
    }

    function beforeAddLiquidity(
        address,
        PoolKey calldata,
        ICLPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.beforeAddLiquidity.selector;
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata,
        ICLPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure override returns (bytes4, BalanceDelta) {
        return (this.afterAddLiquidity.selector, BalanceDelta.wrap(0));
    }

    function beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        ICLPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return this.beforeRemoveLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        ICLPoolManager.ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure override returns (bytes4, BalanceDelta) {
        return (this.afterRemoveLiquidity.selector, BalanceDelta.wrap(0));
    }

    function beforeSwap(address sender, PoolKey calldata key, ICLPoolManager.SwapParams calldata, bytes calldata)
        external
        view
        override
        onlyPoolManager
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        bytes32 poolId = PoolId.unwrap(key.toId());
        uint24 lpFeeOverride = _hasDiscount(poolId, sender) ? LPFeeLibrary.OVERRIDE_FEE_FLAG : 0;
        return (this.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, lpFeeOverride);
    }

    function afterSwap(
        address,
        PoolKey calldata key,
        ICLPoolManager.SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata
    ) external override onlyPoolManager returns (bytes4, int128) {
        bytes32 triggerPoolId = PoolId.unwrap(key.toId());

        // In PancakeSwap Infinity, negative delta = tokens transferred into the pool (amount in)
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

        return (this.afterSwap.selector, 0);
    }

    /// @notice Checks hook's balance and donates to pool LPs or falls back to tx.origin
    function _distributeLpShare(PoolKey calldata key, address profitToken) internal {
        uint256 lpAmount = IERC20(profitToken).balanceOf(address(this));
        if (lpAmount == 0) return;

        // Match profitToken to a pool currency (check both raw address AND WETH<>native ETH equivalence)
        bool matchesCurrency0 = _matchesCurrency(profitToken, key.currency0);
        bool matchesCurrency1 = _matchesCurrency(profitToken, key.currency1);

        if (matchesCurrency0 || matchesCurrency1) {
            try this.donateToPool(key, profitToken, matchesCurrency0, lpAmount) {}
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
    function donateToPool(PoolKey calldata key, address profitToken, bool isCurrency0, uint256 amount) external {
        require(msg.sender == address(this), "PancakeSwapInfinityHook: Only self-call");

        Currency currency = isCurrency0 ? key.currency0 : key.currency1;

        // Create debt on hook via donate
        poolManager.donate(key, isCurrency0 ? amount : 0, isCurrency0 ? 0 : amount, "");

        if (Currency.unwrap(currency) == address(0) && profitToken == weth) {
            // Native ETH pool + WETH profit: unwrap then settle with ETH value
            IWETH9(weth).withdraw(amount);
            vault.settle{value: amount}();
        } else {
            // ERC20 pool: sync, transfer to vault, settle
            vault.sync(currency);
            IERC20(profitToken).safeTransfer(address(vault), amount);
            vault.settle();
        }
    }

    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return this.beforeDonate.selector;
    }

    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return this.afterDonate.selector;
    }

    /// @inheritdoc ReflexAfterSwap
    function _onlyReflexAdmin() internal view override {
        require(msg.sender == owner(), "PancakeSwapInfinityHook: Caller is not the owner");
    }
}
