// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";

import {UniswapV4BaseScript} from "./base/UniswapV4BaseScript.sol";

/**
 * @title RemoveLiquidity
 * @notice Burns a V4 position NFT, withdrawing all liquidity and collecting fees.
 *         BURN_POSITION automatically decreases liquidity to 0 before burning.
 *
 * Run with:
 *   POSITION_MANAGER_ADDRESS=0x... TOKEN_ID=<id> \
 *     forge script script/uniswapv4/04_RemoveLiquidity.s.sol \
 *     --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
 *
 * Environment Variables (Required):
 * - POSITION_MANAGER_ADDRESS: Address of the V4 PositionManager
 * - TOKEN_ID: The position NFT token ID to burn
 *
 * Environment Variables (Optional):
 * - TOKEN0_ADDRESS, TOKEN1_ADDRESS: For native ETH handling (set TOKEN0 to address(0) for ETH)
 */
contract RemoveLiquidity is UniswapV4BaseScript {
    using CurrencyLibrary for Currency;

    uint256 public tokenId;

    function setUp() public {
        require(address(positionManager) != address(0), "POSITION_MANAGER_ADDRESS not set");

        try vm.envUint("TOKEN_ID") returns (uint256 id) {
            tokenId = id;
        } catch {
            revert("TOKEN_ID not set");
        }
    }

    function run() external {
        bytes memory actions = abi.encodePacked(uint8(Actions.BURN_POSITION), uint8(Actions.TAKE_PAIR));

        bytes[] memory params = new bytes[](2);
        // BURN_POSITION: (tokenId, amount0Min, amount1Min, hookData)
        params[0] = abi.encode(tokenId, uint128(0), uint128(0), new bytes(0));
        // TAKE_PAIR: (currency0, currency1, recipient)
        params[1] = abi.encode(currency0, currency1, deployerAddress);

        bytes[] memory multicallParams = new bytes[](1);
        multicallParams[0] = abi.encodeWithSelector(
            positionManager.modifyLiquidities.selector, abi.encode(actions, params), block.timestamp + 60
        );

        vm.startBroadcast();
        positionManager.multicall(multicallParams);
        vm.stopBroadcast();
    }
}
