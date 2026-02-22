// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";

import {IV4Router} from "v4-periphery/src/interfaces/IV4Router.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";

import {UniswapV4BaseScript} from "./base/UniswapV4BaseScript.sol";

/// @notice Minimal interface for the Uniswap Universal Router execute function
interface IUniversalRouter {
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;
}

/**
 * @title Swap
 * @notice Executes a swap on a Uniswap V4 pool via the Universal Router.
 *
 * Run with:
 *   POOL_MANAGER_ADDRESS=0x... UNIVERSAL_ROUTER_ADDRESS=0x... \
 *   TOKEN0_ADDRESS=0x... TOKEN1_ADDRESS=0x... HOOK_ADDRESS=0x... \
 *     forge script script/uniswapv4/03_Swap.s.sol \
 *     --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
 *
 * Environment Variables (Required):
 * - UNIVERSAL_ROUTER_ADDRESS, TOKEN0_ADDRESS, TOKEN1_ADDRESS, HOOK_ADDRESS
 *
 * Environment Variables (Optional):
 * - LP_FEE: Pool fee in pips (default: 3000 = 0.30%)
 * - TICK_SPACING: Tick spacing (default: 60)
 * - SWAP_AMOUNT: Amount to swap (default: 1e18)
 * - ZERO_FOR_ONE: Swap direction, "true" or "false" (default: true)
 */
contract Swap is UniswapV4BaseScript {
    using CurrencyLibrary for Currency;

    uint24 public lpFee;
    int24 public tickSpacing;
    uint256 public swapAmount;
    bool public zeroForOne;

    function setUp() public {
        // Validate required addresses
        require(universalRouter != address(0), "UNIVERSAL_ROUTER_ADDRESS not set");
        require(token0Set && token1Set, "TOKEN0_ADDRESS and TOKEN1_ADDRESS must be set");
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
            currency0: currency0, currency1: currency1, fee: lpFee, tickSpacing: tickSpacing, hooks: hookContract
        });

        // Determine input/output currencies
        Currency inputCurrency = zeroForOne ? currency0 : currency1;
        Currency outputCurrency = zeroForOne ? currency1 : currency0;
        bool inputIsNative = inputCurrency.isAddressZero();

        // --- Build V4 actions (processed inside PoolManager.unlock callback) ---
        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        bytes[] memory params = new bytes[](3);
        // SWAP_EXACT_IN_SINGLE params
        params[0] = abi.encode(
            IV4Router.ExactInputSingleParams({
                poolKey: poolKey,
                zeroForOne: zeroForOne,
                amountIn: uint128(swapAmount),
                amountOutMinimum: uint128(0),
                hookData: new bytes(0)
            })
        );
        // SETTLE_ALL: (inputCurrency, maxAmountIn)
        params[1] = abi.encode(inputCurrency, swapAmount);
        // TAKE_ALL: (outputCurrency, minAmountOut)
        params[2] = abi.encode(outputCurrency, uint256(0));

        // --- Wrap in Universal Router execute ---
        bytes memory commands = abi.encodePacked(uint8(0x10)); // V4_SWAP
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(actions, params);

        vm.startBroadcast();

        // Approve ERC20 input token via Permit2
        if (!inputIsNative) {
            IERC20(Currency.unwrap(inputCurrency)).approve(address(permit2), type(uint256).max);
            permit2.approve(
                Currency.unwrap(inputCurrency), universalRouter, type(uint160).max, uint48(block.timestamp + 3600)
            );
        }

        uint256 ethValue = inputIsNative ? swapAmount : 0;
        IUniversalRouter(universalRouter).execute{value: ethValue}(commands, inputs, block.timestamp + 60);

        vm.stopBroadcast();
    }
}
