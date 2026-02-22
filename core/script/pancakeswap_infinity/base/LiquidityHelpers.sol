// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {PoolKey} from "infinity-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "infinity-core/src/types/Currency.sol";
import {Actions} from "infinity-periphery/src/libraries/Actions.sol";

import {PancakeSwapInfinityBaseScript} from "./PancakeSwapInfinityBaseScript.sol";

/// @notice Helpers for minting liquidity positions and token approvals on PancakeSwap Infinity.
contract LiquidityHelpers is PancakeSwapInfinityBaseScript {
    using CurrencyLibrary for Currency;

    function _mintLiquidityParams(
        PoolKey memory poolKey,
        int24 _tickLower,
        int24 _tickUpper,
        uint256 liquidity,
        uint256 amount0Max,
        uint256 amount1Max,
        address recipient,
        bytes memory hookData
    ) internal pure returns (bytes memory, bytes[] memory) {
        bytes memory actions = abi.encodePacked(
            uint8(Actions.CL_MINT_POSITION), uint8(Actions.SETTLE_PAIR), uint8(Actions.SWEEP), uint8(Actions.SWEEP)
        );

        bytes[] memory params = new bytes[](4);
        params[0] = abi.encode(poolKey, _tickLower, _tickUpper, liquidity, amount0Max, amount1Max, recipient, hookData);
        params[1] = abi.encode(poolKey.currency0, poolKey.currency1);
        params[2] = abi.encode(poolKey.currency0, recipient);
        params[3] = abi.encode(poolKey.currency1, recipient);

        return (actions, params);
    }

    function tokenApprovals() public {
        if (!currency0.isNative()) {
            token0.approve(permit2, type(uint256).max);
            // Approve permit2 -> positionManager
            (bool success,) = permit2.call(
                abi.encodeWithSignature(
                    "approve(address,address,uint160,uint48)",
                    address(token0),
                    address(clPositionManager),
                    type(uint160).max,
                    type(uint48).max
                )
            );
            require(success, "Permit2 approve failed for token0");
        }

        if (!currency1.isNative()) {
            token1.approve(permit2, type(uint256).max);
            (bool success,) = permit2.call(
                abi.encodeWithSignature(
                    "approve(address,address,uint160,uint48)",
                    address(token1),
                    address(clPositionManager),
                    type(uint160).max,
                    type(uint48).max
                )
            );
            require(success, "Permit2 approve failed for token1");
        }
    }

    function truncateTickSpacing(int24 tick, int24 tickSpacing) internal pure returns (int24) {
        return ((tick / tickSpacing) * tickSpacing);
    }
}
