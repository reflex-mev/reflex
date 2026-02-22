// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {PoolKey} from "infinity-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "infinity-core/src/types/Currency.sol";
import {TickMath} from "infinity-core/src/pool-cl/libraries/TickMath.sol";
import {LPFeeLibrary} from "infinity-core/src/libraries/LPFeeLibrary.sol";

import {LiquidityAmounts} from "infinity-periphery/src/pool-cl/libraries/LiquidityAmounts.sol";

import {IMulticall} from "infinity-periphery/src/interfaces/IMulticall.sol";

import {LiquidityHelpers} from "./base/LiquidityHelpers.sol";

/**
 * @title CreatePoolAndAddLiquidity
 * @notice Atomically creates a PancakeSwap Infinity CL pool and adds initial liquidity
 *         via CLPositionManager multicall.
 *
 * Run with:
 *   CL_POOL_MANAGER_ADDRESS=0x... CL_POSITION_MANAGER_ADDRESS=0x... \
 *   TOKEN0_ADDRESS=0x... TOKEN1_ADDRESS=0x... HOOK_ADDRESS=0x... \
 *     forge script script/pancakeswap_infinity/01_CreatePoolAndAddLiquidity.s.sol \
 *     --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
 *
 * Environment Variables (Required):
 * - CL_POOL_MANAGER_ADDRESS, CL_POSITION_MANAGER_ADDRESS, PERMIT2_ADDRESS (or canonical default)
 * - TOKEN0_ADDRESS, TOKEN1_ADDRESS, HOOK_ADDRESS
 *
 * Environment Variables (Optional):
 * - LP_FEE: Pool fee in pips (default: DYNAMIC_FEE_FLAG for hook fee overrides)
 * - TICK_SPACING: Tick spacing (default: 60)
 * - STARTING_PRICE: sqrtPriceX96 (default: 2^96 = price 1:1)
 * - TOKEN0_AMOUNT: Initial token0 liquidity (default: 100e18)
 * - TOKEN1_AMOUNT: Initial token1 liquidity (default: 100e18)
 */
contract CreatePoolAndAddLiquidity is LiquidityHelpers {
    using CurrencyLibrary for Currency;

    uint24 public lpFee;
    int24 public tickSpacing;
    uint160 public startingPrice;
    uint256 public token0Amount;
    uint256 public token1Amount;

    function setUp() public {
        require(token0Set && token1Set, "TOKEN0_ADDRESS and TOKEN1_ADDRESS must be set");
        require(address(hookContract) != address(0), "HOOK_ADDRESS not set");
        require(address(clPositionManager) != address(0), "CL_POSITION_MANAGER_ADDRESS not set");
        require(permit2 != address(0), "PERMIT2_ADDRESS not set");

        try vm.envUint("LP_FEE") returns (uint256 fee) {
            lpFee = uint24(fee);
        } catch {
            lpFee = uint24(LPFeeLibrary.DYNAMIC_FEE_FLAG);
        }

        try vm.envInt("TICK_SPACING") returns (int256 ts) {
            tickSpacing = int24(ts);
        } catch {
            tickSpacing = 60;
        }

        try vm.envUint("STARTING_PRICE") returns (uint256 price) {
            startingPrice = uint160(price);
        } catch {
            startingPrice = 2 ** 96; // 1:1 price
        }

        try vm.envUint("TOKEN0_AMOUNT") returns (uint256 amt) {
            token0Amount = amt;
        } catch {
            token0Amount = 100e18;
        }

        try vm.envUint("TOKEN1_AMOUNT") returns (uint256 amt) {
            token1Amount = amt;
        } catch {
            token1Amount = 100e18;
        }
    }

    function run() external {
        PoolKey memory poolKey = _buildPoolKey(lpFee, tickSpacing);
        bytes[] memory params = _buildMulticallParams(poolKey);

        uint256 valueToPass = currency0.isNative() ? token0Amount + 1 : 0;

        vm.startBroadcast();
        tokenApprovals();
        IMulticall(address(clPositionManager)).multicall{value: valueToPass}(params);
        vm.stopBroadcast();
    }

    function _buildMulticallParams(PoolKey memory poolKey) internal view returns (bytes[] memory params) {
        int24 currentTick = TickMath.getTickAtSqrtRatio(startingPrice);
        int24 tickLower = truncateTickSpacing((currentTick - 750 * tickSpacing), tickSpacing);
        int24 tickUpper = truncateTickSpacing((currentTick + 750 * tickSpacing), tickSpacing);

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            startingPrice,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            token0Amount,
            token1Amount
        );

        uint256 amount0Max = token0Amount + 1;
        uint256 amount1Max = token1Amount + 1;

        (bytes memory actions, bytes[] memory mintParams) = _mintLiquidityParams(
            poolKey, tickLower, tickUpper, liquidity, amount0Max, amount1Max, deployerAddress, new bytes(0)
        );

        params = new bytes[](2);
        params[0] = abi.encodeWithSelector(clPositionManager.initializePool.selector, poolKey, startingPrice);
        params[1] = abi.encodeWithSelector(
            clPositionManager.modifyLiquidities.selector, abi.encode(actions, mintParams), block.timestamp + 3600
        );
    }
}
