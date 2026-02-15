// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";
import {ICLPoolManager} from "infinity-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {PancakeSwapInfinityHook} from "@reflex/integrations/plugin/pancakeswap_infinity/PancakeSwapInfinityHook.sol";

import {PancakeSwapInfinityBaseScript} from "./base/PancakeSwapInfinityBaseScript.sol";

/**
 * @title DeployHook
 * @notice Deployment script for PancakeSwapInfinityHook
 * @dev PancakeSwap Infinity uses bitmap-based hook permissions (getHooksRegistrationBitmap),
 *      so NO CREATE2 salt mining is needed. Standard deployment via `new`.
 *
 * Run with:
 *   CL_POOL_MANAGER_ADDRESS=0x... REFLEX_ROUTER_ADDRESS=0x... WETH_ADDRESS=0x... \
 *     forge script script/pancakeswap_infinity/00_DeployHook.s.sol \
 *     --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
 *
 * Environment Variables (Required):
 * - CL_POOL_MANAGER_ADDRESS: Address of the deployed PancakeSwap Infinity CLPoolManager
 * - REFLEX_ROUTER_ADDRESS: Address of the deployed Reflex Router
 * - WETH_ADDRESS: Address of the WETH contract (for LP donate via native ETH pools)
 *
 * Environment Variables (Optional):
 * - CONFIG_ID: bytes32 config ID (defaults to bytes32(0))
 * - VERIFY_CONTRACT: Set to "true" to log Etherscan verification command
 */
contract DeployHook is PancakeSwapInfinityBaseScript {
    PancakeSwapInfinityHook public hook;

    address public wethAddress;
    bool public shouldVerify;

    event HookDeployed(
        address indexed hook,
        address indexed poolManager,
        address indexed reflexRouter,
        bytes32 configId,
        address owner
    );

    function setUp() public {
        require(address(clPoolManager) != address(0), "CL_POOL_MANAGER_ADDRESS not set");
        require(reflexRouterAddress != address(0), "REFLEX_ROUTER_ADDRESS not set");

        wethAddress = vm.envAddress("WETH_ADDRESS");
        require(wethAddress != address(0), "WETH_ADDRESS not set");

        try vm.envBool("VERIFY_CONTRACT") returns (bool verify) {
            shouldVerify = verify;
        } catch {
            shouldVerify = false;
        }
    }

    function run() public {
        address deployer = msg.sender;

        console.log("=== PancakeSwapInfinityHook Deployment ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Block number:", block.number);
        console.log("");

        _logParameters();

        uint256 balance = deployer.balance;
        console.log("Deployer balance:", balance / 1e18, "ETH");
        if (balance == 0) {
            console.log("Warning: Deployer has zero balance (simulation mode)");
        }

        vm.startBroadcast();

        console.log("\n--- Deploying PancakeSwapInfinityHook ---");
        hook = new PancakeSwapInfinityHook(clPoolManager, reflexRouterAddress, configId, deployer, wethAddress);

        vm.stopBroadcast();

        _verifyDeployment();

        emit HookDeployed(address(hook), address(clPoolManager), reflexRouterAddress, configId, deployer);

        _logDeploymentSummary();

        if (shouldVerify) {
            _logVerificationCommand();
        }

        _logNextSteps();
        _saveDeploymentInfo();
    }

    function _logParameters() internal view {
        console.log("Deployment Parameters:");
        console.log("- CL Pool Manager:", address(clPoolManager));
        console.log("- Reflex Router:", reflexRouterAddress);
        console.log("- WETH:", wethAddress);
        console.log("- Config ID:", vm.toString(configId));
        console.log("");
    }

    function _verifyDeployment() internal view {
        require(address(hook) != address(0), "Hook not deployed");
        require(address(hook.poolManager()) == address(clPoolManager), "Pool manager mismatch");
        require(hook.getRouter() == reflexRouterAddress, "Router mismatch");
        require(hook.getConfigId() == configId, "Config ID mismatch");
        require(hook.owner() == msg.sender, "Owner mismatch");
        require(hook.weth() == wethAddress, "WETH mismatch");

        // Verify hook bitmap has beforeSwap + afterSwap
        uint16 bitmap = hook.getHooksRegistrationBitmap();
        require(bitmap & (1 << 6) != 0, "beforeSwap not enabled in bitmap");
        require(bitmap & (1 << 7) != 0, "afterSwap not enabled in bitmap");

        console.log("\n[SUCCESS] PancakeSwapInfinityHook deployment verified successfully");
    }

    function _logDeploymentSummary() internal view {
        console.log("\n=== Deployment Summary ===");
        console.log("PancakeSwapInfinityHook:", address(hook));
        console.log("CL Pool Manager:", address(hook.poolManager()));
        console.log("Vault:", address(hook.vault()));
        console.log("Reflex Router:", hook.getRouter());
        console.log("WETH:", hook.weth());
        console.log("Config ID:", vm.toString(hook.getConfigId()));
        console.log("Owner:", hook.owner());
        console.log("Hook Bitmap:", hook.getHooksRegistrationBitmap());
        console.log("Chain ID:", block.chainid);
        console.log("Block Number:", block.number);
        console.log("Timestamp:", block.timestamp);
    }

    function _logVerificationCommand() internal view {
        console.log("\n=== Verification Command ===");
        console.log("forge verify-contract", address(hook));
        console.log("  --chain-id", block.chainid);
        console.log(
            "  --constructor-args $(cast abi-encode \"constructor(address,address,bytes32,address,address)\"",
            address(clPoolManager),
            reflexRouterAddress
        );
        console.log("    ", vm.toString(configId), msg.sender);
        console.log("    ", wethAddress, ")");
        console.log(
            "  src/integrations/plugin/pancakeswap_infinity/PancakeSwapInfinityHook.sol:PancakeSwapInfinityHook"
        );
        console.log("  --etherscan-api-key $ETHERSCAN_API_KEY");
    }

    function _logNextSteps() internal view {
        console.log("\n=== Next Steps ===");
        console.log("1. Set HOOK_ADDRESS=", address(hook));
        console.log("2. Run 01_CreatePoolAndAddLiquidity.s.sol to initialize a pool");
        console.log("3. Run 03_Swap.s.sol to test the afterSwap callback");
        console.log("4. Monitor ReflexRouter backrun operations");
    }

    function _saveDeploymentInfo() internal {
        string memory deploymentInfo = string.concat(
            "{\n",
            '  "contract": "PancakeSwapInfinityHook",\n',
            '  "address": "',
            vm.toString(address(hook)),
            '",\n',
            '  "clPoolManager": "',
            vm.toString(address(clPoolManager)),
            '",\n',
            '  "vault": "',
            vm.toString(address(hook.vault())),
            '",\n',
            '  "reflexRouter": "',
            vm.toString(reflexRouterAddress),
            '",\n',
            '  "weth": "',
            vm.toString(wethAddress),
            '",\n',
            '  "configId": "',
            vm.toString(configId),
            '",\n',
            '  "owner": "',
            vm.toString(msg.sender),
            '",\n',
            '  "chainId": ',
            vm.toString(block.chainid),
            ",\n",
            '  "blockNumber": ',
            vm.toString(block.number),
            ",\n",
            '  "timestamp": ',
            vm.toString(block.timestamp),
            ",\n",
            '  "deployer": "',
            vm.toString(msg.sender),
            '"\n',
            "}\n"
        );

        string memory filename = string.concat(
            "deployment-pancakeswap-infinity-hook-",
            vm.toString(block.chainid),
            "-",
            vm.toString(block.timestamp),
            ".json"
        );

        string memory dirpath = "deployments";
        vm.createDir(dirpath, true);

        string memory filepath = string.concat(dirpath, "/", filename);
        vm.writeFile(filepath, deploymentInfo);

        console.log("\nDeployment info saved to:", filepath);
    }
}
