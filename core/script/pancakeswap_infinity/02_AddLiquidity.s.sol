// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {ICLPoolManager} from "infinity-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {PoolKey} from "infinity-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "infinity-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "infinity-core/src/types/Currency.sol";
import {TickMath} from "infinity-core/src/pool-cl/libraries/TickMath.sol";

import {LiquidityAmounts} from "infinity-periphery/src/pool-cl/libraries/LiquidityAmounts.sol";

import {IMulticall} from "infinity-periphery/src/interfaces/IMulticall.sol";

import {LiquidityHelpers} from "./base/LiquidityHelpers.sol";

/**
 * @title AddLiquidity
 * @notice Adds liquidity to an existing PancakeSwap Infinity CL pool.
 *
 * Run with:
 *   CL_POOL_MANAGER_ADDRESS=0x... CL_POSITION_MANAGER_ADDRESS=0x... \
 *   TOKEN0_ADDRESS=0x... TOKEN1_ADDRESS=0x... HOOK_ADDRESS=0x... \
 *     forge script script/pancakeswap_infinity/02_AddLiquidity.s.sol \
 *     --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
 *
 * Environment Variables (Required):
 * - CL_POOL_MANAGER_ADDRESS, CL_POSITION_MANAGER_ADDRESS, PERMIT2_ADDRESS (or canonical default)
 * - TOKEN0_ADDRESS, TOKEN1_ADDRESS, HOOK_ADDRESS
 *
 * Environment Variables (Optional):
 * - LP_FEE: Pool fee in pips (default: 3000 = 0.30%)
 * - TICK_SPACING: Tick spacing (default: 60)
 * - TOKEN0_AMOUNT: Token0 liquidity to add (default: 1e18)
 * - TOKEN1_AMOUNT: Token1 liquidity to add (default: 1e18)
 */
contract AddLiquidity is LiquidityHelpers {
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    uint24 public lpFee;
    int24 public tickSpacing;
    uint256 public token0Amount;
    uint256 public token1Amount;

    function setUp() public {
        require(token0Set && token1Set, "TOKEN0_ADDRESS and TOKEN1_ADDRESS must be set");
        require(address(hookContract) != address(0), "HOOK_ADDRESS not set");
        require(address(clPositionManager) != address(0), "CL_POSITION_MANAGER_ADDRESS not set");
        require(permit2 != address(0), "PERMIT2_ADDRESS not set");
        require(address(clPoolManager) != address(0), "CL_POOL_MANAGER_ADDRESS not set");

        try vm.envUint("LP_FEE") returns (uint256 fee) {
            lpFee = uint24(fee);
        } catch {
            lpFee = 3000;
        }

        try vm.envInt("TICK_SPACING") returns (int256 ts) {
            tickSpacing = int24(ts);
        } catch {
            tickSpacing = 60;
        }

        try vm.envUint("TOKEN0_AMOUNT") returns (uint256 amt) {
            token0Amount = amt;
        } catch {
            token0Amount = 1e18;
        }

        try vm.envUint("TOKEN1_AMOUNT") returns (uint256 amt) {
            token1Amount = amt;
        } catch {
            token1Amount = 1e18;
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
        (uint160 sqrtPriceX96,,,) = clPoolManager.getSlot0(poolKey.toId());

        int24 currentTick = TickMath.getTickAtSqrtRatio(sqrtPriceX96);
        int24 tickLower = truncateTickSpacing((currentTick - 1000 * tickSpacing), tickSpacing);
        int24 tickUpper = truncateTickSpacing((currentTick + 1000 * tickSpacing), tickSpacing);

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            token0Amount,
            token1Amount
        );

        uint256 amount0Max = token0Amount + 1 wei;
        uint256 amount1Max = token1Amount + 1 wei;

        (bytes memory actions, bytes[] memory mintParams) = _mintLiquidityParams(
            poolKey, tickLower, tickUpper, liquidity, amount0Max, amount1Max, deployerAddress, new bytes(0)
        );

        params = new bytes[](1);
        params[0] = abi.encodeWithSelector(
            clPositionManager.modifyLiquidities.selector, abi.encode(actions, mintParams), block.timestamp + 60
        );
    }
}
