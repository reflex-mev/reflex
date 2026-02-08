// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {StateLibrary} from "v4-core/src/libraries/StateLibrary.sol";

import {LiquidityAmounts} from "v4-periphery/src/libraries/LiquidityAmounts.sol";

import {LiquidityHelpers} from "./base/LiquidityHelpers.sol";

/**
 * @title AddLiquidity
 * @notice Adds liquidity to an existing Uniswap V4 pool.
 *
 * Run with:
 *   POOL_MANAGER_ADDRESS=0x... POSITION_MANAGER_ADDRESS=0x... \
 *   TOKEN0_ADDRESS=0x... TOKEN1_ADDRESS=0x... HOOK_ADDRESS=0x... \
 *     forge script script/uniswapv4/02_AddLiquidity.s.sol \
 *     --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
 *
 * Environment Variables (Required):
 * - POOL_MANAGER_ADDRESS, POSITION_MANAGER_ADDRESS, PERMIT2_ADDRESS (or canonical default)
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
    using StateLibrary for IPoolManager;

    uint24 public lpFee;
    int24 public tickSpacing;
    uint256 public token0Amount;
    uint256 public token1Amount;

    function setUp() public {
        // Validate required addresses
        require(address(token0) != address(0), "TOKEN0_ADDRESS not set");
        require(address(token1) != address(0), "TOKEN1_ADDRESS not set");
        require(address(hookContract) != address(0), "HOOK_ADDRESS not set");
        require(address(positionManager) != address(0), "POSITION_MANAGER_ADDRESS not set");
        require(address(permit2) != address(0), "PERMIT2_ADDRESS not set");
        require(address(poolManager) != address(0), "POOL_MANAGER_ADDRESS not set");

        // Load configurable parameters with defaults
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
        PoolKey memory poolKey = _buildPoolKey();
        bytes[] memory params = _buildMulticallParams(poolKey);

        uint256 valueToPass = currency0.isAddressZero() ? token0Amount + 1 : 0;

        vm.startBroadcast();
        tokenApprovals();
        positionManager.multicall{value: valueToPass}(params);
        vm.stopBroadcast();
    }

    function _buildPoolKey() internal view returns (PoolKey memory) {
        return PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: lpFee,
            tickSpacing: tickSpacing,
            hooks: hookContract
        });
    }

    function _buildMulticallParams(PoolKey memory poolKey) internal view returns (bytes[] memory params) {
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(poolKey.toId());

        int24 currentTick = TickMath.getTickAtSqrtPrice(sqrtPriceX96);
        int24 tickLower = truncateTickSpacing((currentTick - 1000 * tickSpacing), tickSpacing);
        int24 tickUpper = truncateTickSpacing((currentTick + 1000 * tickSpacing), tickSpacing);

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
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
            positionManager.modifyLiquidities.selector, abi.encode(actions, mintParams), block.timestamp + 60
        );
    }
}
