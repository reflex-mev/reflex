// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Currency} from "v4-core/src/types/Currency.sol";

import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";

import {IUniswapV4Router04} from "hookmate/interfaces/router/IUniswapV4Router04.sol";

/// @notice Shared base script for all UniswapV4 deployment scripts.
///         Loads configuration from environment variables.
contract UniswapV4BaseScript is Script {
    // Canonical Permit2 address
    address constant CANONICAL_PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    IPoolManager public poolManager;
    IPositionManager public positionManager;
    IUniswapV4Router04 public swapRouter;
    IPermit2 public permit2;

    IERC20 public token0;
    IERC20 public token1;
    Currency public currency0;
    Currency public currency1;

    IHooks public hookContract;

    address public reflexRouterAddress;
    bytes32 public configId;
    address public deployerAddress;

    constructor() {
        // Required: Pool Manager
        try vm.envAddress("POOL_MANAGER_ADDRESS") returns (address addr) {
            poolManager = IPoolManager(addr);
        } catch {}

        // Optional: Position Manager
        try vm.envAddress("POSITION_MANAGER_ADDRESS") returns (address addr) {
            positionManager = IPositionManager(addr);
        } catch {}

        // Optional: Swap Router
        try vm.envAddress("SWAP_ROUTER_ADDRESS") returns (address addr) {
            swapRouter = IUniswapV4Router04(payable(addr));
        } catch {}

        // Optional: Permit2 (defaults to canonical)
        try vm.envAddress("PERMIT2_ADDRESS") returns (address addr) {
            permit2 = IPermit2(addr);
        } catch {
            permit2 = IPermit2(CANONICAL_PERMIT2);
        }

        // Optional: Tokens
        try vm.envAddress("TOKEN0_ADDRESS") returns (address addr) {
            token0 = IERC20(addr);
        } catch {}
        try vm.envAddress("TOKEN1_ADDRESS") returns (address addr) {
            token1 = IERC20(addr);
        } catch {}

        // Sort currencies
        if (address(token0) != address(0) && address(token1) != address(0)) {
            if (address(token0) < address(token1)) {
                currency0 = Currency.wrap(address(token0));
                currency1 = Currency.wrap(address(token1));
            } else {
                currency0 = Currency.wrap(address(token1));
                currency1 = Currency.wrap(address(token0));
            }
        }

        // Optional: Hook address
        try vm.envAddress("HOOK_ADDRESS") returns (address addr) {
            hookContract = IHooks(addr);
        } catch {}

        // Optional: Reflex Router
        try vm.envAddress("REFLEX_ROUTER_ADDRESS") returns (address addr) {
            reflexRouterAddress = addr;
        } catch {}

        // Optional: Config ID
        try vm.envBytes32("CONFIG_ID") returns (bytes32 cid) {
            configId = cid;
        } catch {
            configId = bytes32(0);
        }

        // Deployer
        deployerAddress = msg.sender;
    }
}
