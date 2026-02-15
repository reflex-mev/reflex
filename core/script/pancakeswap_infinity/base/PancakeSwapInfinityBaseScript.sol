// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {IHooks} from "infinity-core/src/interfaces/IHooks.sol";
import {ICLPoolManager} from "infinity-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {Currency} from "infinity-core/src/types/Currency.sol";
import {PoolKey} from "infinity-core/src/types/PoolKey.sol";
import {CLPoolParametersHelper} from "infinity-core/src/pool-cl/libraries/CLPoolParametersHelper.sol";

import {ICLPositionManager} from "infinity-periphery/src/pool-cl/interfaces/ICLPositionManager.sol";
import {IMulticall} from "infinity-periphery/src/interfaces/IMulticall.sol";

/// @notice Shared base script for all PancakeSwap Infinity deployment scripts.
///         Loads configuration from environment variables.
contract PancakeSwapInfinityBaseScript is Script {
    // Canonical Permit2 address
    address constant CANONICAL_PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    ICLPoolManager public clPoolManager;
    ICLPositionManager public clPositionManager;
    address public universalRouter;
    address public permit2;

    IERC20 public token0;
    IERC20 public token1;
    bool public token0Set;
    bool public token1Set;
    Currency public currency0;
    Currency public currency1;

    IHooks public hookContract;

    address public reflexRouterAddress;
    bytes32 public configId;
    address public deployerAddress;

    constructor() {
        // Required: CL Pool Manager
        try vm.envAddress("CL_POOL_MANAGER_ADDRESS") returns (address addr) {
            clPoolManager = ICLPoolManager(addr);
        } catch {}

        // Optional: CL Position Manager
        try vm.envAddress("CL_POSITION_MANAGER_ADDRESS") returns (address addr) {
            clPositionManager = ICLPositionManager(addr);
        } catch {}

        // Optional: Universal Router
        try vm.envAddress("UNIVERSAL_ROUTER_ADDRESS") returns (address addr) {
            universalRouter = addr;
        } catch {}

        // Optional: Permit2 (defaults to canonical)
        try vm.envAddress("PERMIT2_ADDRESS") returns (address addr) {
            permit2 = addr;
        } catch {
            permit2 = CANONICAL_PERMIT2;
        }

        // Optional: Tokens (address(0) = native ETH)
        try vm.envAddress("TOKEN0_ADDRESS") returns (address addr) {
            token0 = IERC20(addr);
            token0Set = true;
        } catch {}
        try vm.envAddress("TOKEN1_ADDRESS") returns (address addr) {
            token1 = IERC20(addr);
            token1Set = true;
        } catch {}

        // Sort currencies when at least one token is configured
        if (token0Set || token1Set) {
            if (address(token0) <= address(token1)) {
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

        // Deployer: use wallet from --private-key/--mnemonic, fall back to msg.sender
        address[] memory wallets = vm.getWallets();
        deployerAddress = wallets.length > 0 ? wallets[0] : msg.sender;
    }

    /// @notice Builds a PancakeSwap Infinity CL PoolKey with parameters encoding
    function _buildPoolKey(uint24 fee, int24 tickSpacing) internal view returns (PoolKey memory) {
        bytes32 parameters = bytes32(uint256(hookContract.getHooksRegistrationBitmap()));
        parameters = CLPoolParametersHelper.setTickSpacing(parameters, tickSpacing);

        return PoolKey({
            currency0: currency0,
            currency1: currency1,
            hooks: hookContract,
            poolManager: clPoolManager,
            fee: fee,
            parameters: parameters
        });
    }
}
