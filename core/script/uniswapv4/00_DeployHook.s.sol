// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {UniswapV4Hook} from "@reflex/integrations/plugin/uniswapv4/UniswapV4Hook.sol";

import {UniswapV4BaseScript} from "./base/UniswapV4BaseScript.sol";

/**
 * @title DeployHook
 * @notice Deployment script for UniswapV4Hook with CREATE2 salt mining
 * @dev Uniswap V4 hooks must be deployed at addresses where specific permission bits are set.
 *      For our hook, AFTER_SWAP_FLAG (bit 6 = 0x40) must be set in the bottom 14 bits.
 *      This script mines a CREATE2 salt to find such an address.
 *
 * Run with:
 *   POOL_MANAGER_ADDRESS=0x... REFLEX_ROUTER_ADDRESS=0x... \
 *     forge script script/uniswapv4/00_DeployHook.s.sol \
 *     --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
 *
 * Environment Variables (Required):
 * - POOL_MANAGER_ADDRESS: Address of the deployed Uniswap V4 PoolManager
 * - REFLEX_ROUTER_ADDRESS: Address of the deployed Reflex Router
 *
 * Environment Variables (Optional):
 * - CONFIG_ID: bytes32 config ID (defaults to bytes32(0))
 * - VERIFY_CONTRACT: Set to "true" to log Etherscan verification command
 */
contract DeployHook is UniswapV4BaseScript {
    // Hook permission flags
    uint160 constant REQUIRED_FLAGS = Hooks.AFTER_SWAP_FLAG; // 1 << 6 = 0x40
    uint160 constant FLAG_MASK = Hooks.ALL_HOOK_MASK; // (1 << 14) - 1 = 0x3FFF

    // Contract instance
    UniswapV4Hook public hook;

    // Configuration
    bool public shouldVerify;

    // CREATE2 mining results
    bytes32 public minedSalt;
    address public expectedHookAddress;

    // Events
    event HookDeployed(
        address indexed hook,
        address indexed poolManager,
        address indexed reflexRouter,
        bytes32 configId,
        bytes32 salt,
        address owner
    );

    function setUp() public {
        // Validate required addresses
        require(address(poolManager) != address(0), "POOL_MANAGER_ADDRESS not set");
        require(reflexRouterAddress != address(0), "REFLEX_ROUTER_ADDRESS not set");

        // Load optional verification flag
        try vm.envBool("VERIFY_CONTRACT") returns (bool verify) {
            shouldVerify = verify;
        } catch {
            shouldVerify = false;
        }

        // Compute initcode and mine salt
        bytes memory initcode = abi.encodePacked(
            type(UniswapV4Hook).creationCode, abi.encode(poolManager, reflexRouterAddress, configId, msg.sender)
        );
        bytes32 initcodeHash = keccak256(initcode);

        // Mine CREATE2 salt: find salt where deployed address has exactly AFTER_SWAP_FLAG set in bottom 14 bits
        bool found = false;
        for (uint256 i = 0; i < type(uint256).max; i++) {
            bytes32 salt = bytes32(i);
            address addr = address(
                uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff), CREATE2_FACTORY, salt, initcodeHash))))
            );

            if (uint160(addr) & FLAG_MASK == REQUIRED_FLAGS) {
                minedSalt = salt;
                expectedHookAddress = addr;
                found = true;
                break;
            }
        }

        require(found, "Failed to mine CREATE2 salt");
        console.log("CREATE2 salt mined successfully");
        console.log("Salt:", vm.toString(minedSalt));
        console.log("Expected hook address:", expectedHookAddress);
    }

    function run() public {
        address deployer = msg.sender;

        console.log("=== UniswapV4Hook Deployment ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Block number:", block.number);
        console.log("");

        _logParameters();

        // Check deployer balance
        uint256 balance = deployer.balance;
        console.log("Deployer balance:", balance / 1e18, "ETH");
        if (balance == 0) {
            console.log("Warning: Deployer has zero balance (simulation mode)");
        }

        vm.startBroadcast();

        console.log("\n--- Deploying UniswapV4Hook ---");
        hook = new UniswapV4Hook{salt: minedSalt}(poolManager, reflexRouterAddress, configId, deployer);

        vm.stopBroadcast();

        // Verify deployed address matches expected
        require(address(hook) == expectedHookAddress, "Deployed address does not match expected hook address");

        // Verify hook state
        _verifyDeployment();

        // Emit event
        emit HookDeployed(address(hook), address(poolManager), reflexRouterAddress, configId, minedSalt, deployer);

        // Log summary
        _logDeploymentSummary();

        // Verification instructions
        if (shouldVerify) {
            _logVerificationCommand();
        }

        // Post-deployment instructions
        _logNextSteps();

        // Save deployment info
        _saveDeploymentInfo();
    }

    function _logParameters() internal view {
        console.log("Deployment Parameters:");
        console.log("- Pool Manager:", address(poolManager));
        console.log("- Reflex Router:", reflexRouterAddress);
        console.log("- Config ID:", vm.toString(configId));
        console.log("- Mined Salt:", vm.toString(minedSalt));
        console.log("- Expected Address:", expectedHookAddress);
        console.log("");
    }

    function _verifyDeployment() internal view {
        require(address(hook) != address(0), "Hook not deployed");
        require(address(hook.poolManager()) == address(poolManager), "Pool manager mismatch");
        require(hook.getRouter() == reflexRouterAddress, "Router mismatch");
        require(hook.getConfigId() == configId, "Config ID mismatch");
        require(hook.owner() == msg.sender, "Owner mismatch");

        // Verify hook flags
        uint160 hookFlags = uint160(address(hook)) & FLAG_MASK;
        require(hookFlags == REQUIRED_FLAGS, "Hook address flags mismatch");

        console.log("\n[SUCCESS] UniswapV4Hook deployment verified successfully");
    }

    function _logDeploymentSummary() internal view {
        console.log("\n=== Deployment Summary ===");
        console.log("UniswapV4Hook:", address(hook));
        console.log("Pool Manager:", address(hook.poolManager()));
        console.log("Reflex Router:", hook.getRouter());
        console.log("Config ID:", vm.toString(hook.getConfigId()));
        console.log("Owner:", hook.owner());
        console.log("Salt:", vm.toString(minedSalt));
        console.log("Chain ID:", block.chainid);
        console.log("Block Number:", block.number);
        console.log("Timestamp:", block.timestamp);
    }

    function _logVerificationCommand() internal view {
        console.log("\n=== Verification Command ===");
        console.log("forge verify-contract", address(hook));
        console.log("  --chain-id", block.chainid);
        console.log(
            "  --constructor-args $(cast abi-encode \"constructor(address,address,bytes32,address)\"",
            address(poolManager),
            reflexRouterAddress
        );
        console.log("    ", vm.toString(configId), msg.sender, ")");
        console.log("  src/integrations/plugin/uniswapv4/UniswapV4Hook.sol:UniswapV4Hook");
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
            '  "contract": "UniswapV4Hook",\n',
            '  "address": "',
            vm.toString(address(hook)),
            '",\n',
            '  "poolManager": "',
            vm.toString(address(poolManager)),
            '",\n',
            '  "reflexRouter": "',
            vm.toString(reflexRouterAddress),
            '",\n',
            '  "configId": "',
            vm.toString(configId),
            '",\n',
            '  "salt": "',
            vm.toString(minedSalt),
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
            "deployment-v4-hook-", vm.toString(block.chainid), "-", vm.toString(block.timestamp), ".json"
        );

        string memory dirpath = "deployments";
        vm.createDir(dirpath, true);

        string memory filepath = string.concat(dirpath, "/", filename);

        vm.writeFile(filepath, deploymentInfo);

        console.log("\nDeployment info saved to:", filepath);
    }
}
