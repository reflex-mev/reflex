// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {CurrencyLibrary, Currency} from "infinity-core/src/types/Currency.sol";
import {Actions} from "infinity-periphery/src/libraries/Actions.sol";

import {IMulticall} from "infinity-periphery/src/interfaces/IMulticall.sol";

import {PancakeSwapInfinityBaseScript} from "./base/PancakeSwapInfinityBaseScript.sol";

/**
 * @title RemoveLiquidity
 * @notice Burns a PancakeSwap Infinity CL position NFT, withdrawing all liquidity and collecting fees.
 *         CL_BURN_POSITION automatically decreases liquidity to 0 before burning.
 *
 * Run with:
 *   CL_POSITION_MANAGER_ADDRESS=0x... TOKEN_ID=<id> \
 *     forge script script/pancakeswap_infinity/04_RemoveLiquidity.s.sol \
 *     --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
 *
 * Environment Variables (Required):
 * - CL_POSITION_MANAGER_ADDRESS: Address of the PancakeSwap Infinity CLPositionManager
 * - TOKEN_ID: The position NFT token ID to burn
 *
 * Environment Variables (Optional):
 * - TOKEN0_ADDRESS, TOKEN1_ADDRESS: For native ETH handling (set TOKEN0 to address(0) for ETH)
 */
contract RemoveLiquidity is PancakeSwapInfinityBaseScript {
    using CurrencyLibrary for Currency;

    uint256 public tokenId;

    function setUp() public {
        require(address(clPositionManager) != address(0), "CL_POSITION_MANAGER_ADDRESS not set");

        try vm.envUint("TOKEN_ID") returns (uint256 id) {
            tokenId = id;
        } catch {
            revert("TOKEN_ID not set");
        }
    }

    function run() external {
        bytes memory actions =
            abi.encodePacked(uint8(Actions.CL_BURN_POSITION), uint8(Actions.TAKE_PAIR));

        bytes[] memory params = new bytes[](2);
        // CL_BURN_POSITION: (tokenId, amount0Min, amount1Min, hookData)
        params[0] = abi.encode(tokenId, uint128(0), uint128(0), new bytes(0));
        // TAKE_PAIR: (currency0, currency1, recipient)
        params[1] = abi.encode(currency0, currency1, deployerAddress);

        bytes[] memory multicallParams = new bytes[](1);
        multicallParams[0] = abi.encodeWithSelector(
            clPositionManager.modifyLiquidities.selector, abi.encode(actions, params), block.timestamp + 60
        );

        vm.startBroadcast();
        IMulticall(address(clPositionManager)).multicall(multicallParams);
        vm.stopBroadcast();
    }
}
