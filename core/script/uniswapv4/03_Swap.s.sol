// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {PoolKey} from "v4-core/src/types/PoolKey.sol";

import {UniswapV4BaseScript} from "./base/UniswapV4BaseScript.sol";

/**
 * @title Swap
 * @notice Executes a test swap on a Uniswap V4 pool using hookmate's V4Router.
 *
 * Run with:
 *   POOL_MANAGER_ADDRESS=0x... SWAP_ROUTER_ADDRESS=0x... \
 *   TOKEN0_ADDRESS=0x... TOKEN1_ADDRESS=0x... HOOK_ADDRESS=0x... \
 *     forge script script/uniswapv4/03_Swap.s.sol \
 *     --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
 *
 * Environment Variables (Required):
 * - SWAP_ROUTER_ADDRESS, TOKEN0_ADDRESS, TOKEN1_ADDRESS, HOOK_ADDRESS
 *
 * Environment Variables (Optional):
 * - LP_FEE: Pool fee in pips (default: 3000 = 0.30%)
 * - TICK_SPACING: Tick spacing (default: 60)
 * - SWAP_AMOUNT: Amount to swap (default: 1e18)
 * - ZERO_FOR_ONE: Swap direction, "true" or "false" (default: true)
 */
contract Swap is UniswapV4BaseScript {
    uint24 public lpFee;
    int24 public tickSpacing;
    uint256 public swapAmount;
    bool public zeroForOne;

    function setUp() public {
        // Validate required addresses
        require(address(swapRouter) != address(0), "SWAP_ROUTER_ADDRESS not set");
        require(address(token0) != address(0), "TOKEN0_ADDRESS not set");
        require(address(token1) != address(0), "TOKEN1_ADDRESS not set");
        require(address(hookContract) != address(0), "HOOK_ADDRESS not set");

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

        try vm.envUint("SWAP_AMOUNT") returns (uint256 amt) {
            swapAmount = amt;
        } catch {
            swapAmount = 1e18;
        }

        try vm.envBool("ZERO_FOR_ONE") returns (bool dir) {
            zeroForOne = dir;
        } catch {
            zeroForOne = true;
        }
    }

    function run() external {
        PoolKey memory poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: lpFee,
            tickSpacing: tickSpacing,
            hooks: hookContract
        });
        bytes memory hookData = new bytes(0);

        vm.startBroadcast();

        // Approve tokens to the swap router
        token0.approve(address(swapRouter), type(uint256).max);
        token1.approve(address(swapRouter), type(uint256).max);

        // Execute swap
        swapRouter.swapExactTokensForTokens({
            amountIn: swapAmount,
            amountOutMin: 0,
            zeroForOne: zeroForOne,
            poolKey: poolKey,
            hookData: hookData,
            receiver: deployerAddress,
            deadline: block.timestamp + 30
        });

        vm.stopBroadcast();
    }
}
