// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ExecutionRouter} from "../../src/base/ExecutionRouter.sol";

/**
 * @title DeployExecutionRouter
 * @notice Deployment script for ExecutionRouter contract
 * @dev Run with: forge script script/deploy-execution-router/DeployExecutionRouter.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
 *
 * Environment Variables (Optional):
 * - EXECUTION_QUOTER_ADDRESS: Address of the ExecutionQuoter contract to set after deployment
 * - VERIFY_CONTRACT: Set to "true" to verify on Etherscan
 * - ETHERSCAN_API_KEY: Required if VERIFY_CONTRACT is true
 * - GAS_PRICE: Gas price in gwei (optional)
 * - GAS_LIMIT: Gas limit (optional)
 *
 * Example Usage:
 * forge script script/deploy-execution-router/DeployExecutionRouter.s.sol \
 *   --rpc-url https://mainnet.infura.io/v3/YOUR-PROJECT-ID \
 *   --private-key $PRIVATE_KEY \
 *   --broadcast \
 *   --verify
 */
contract DeployExecutionRouter is Script {
    // Contract instance
    ExecutionRouter public executionRouter;

    // Optional configuration
    address public executionQuoterAddress;
    bool public shouldVerify;

    // Events
    event RouterDeployed(address indexed router, address indexed owner, address indexed quoter);

    event RouterConfigured(address indexed router, address indexed quoter);

    function setUp() public {
        // Load optional configuration from environment variables
        try vm.envAddress("EXECUTION_QUOTER_ADDRESS") returns (address quoter) {
            executionQuoterAddress = quoter;
            console.log("ExecutionQuoter address loaded:", quoter);
        } catch {
            console.log("No ExecutionQuoter address provided, will skip setting quoter");
        }

        try vm.envBool("VERIFY_CONTRACT") returns (bool verify) {
            shouldVerify = verify;
            console.log("Contract verification:", verify ? "enabled" : "disabled");
        } catch {
            shouldVerify = false;
            console.log("Contract verification: disabled (default)");
        }
    }

    function run() public {
        // Get deployer from msg.sender or environment
        address deployer = msg.sender;

        console.log("=== ExecutionRouter Deployment ===");
        console.log("Deployer address:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Block number:", block.number);

        // Check deployer balance (skip requirement for simulation)
        uint256 balance = deployer.balance;
        console.log("Deployer balance:", balance / 1e18, "ETH");
        if (balance == 0) {
            console.log("Warning: Deployer has zero balance (simulation mode)");
        }

        // Start broadcasting transactions
        vm.startBroadcast();

        // Deploy ExecutionRouter
        console.log("\n--- Deploying ExecutionRouter ---");
        executionRouter = new ExecutionRouter();

        console.log("ExecutionRouter deployed at:", address(executionRouter));
        console.log("Owner set to:", executionRouter.owner());

        // Set ExecutionQuoter if provided
        if (executionQuoterAddress != address(0)) {
            console.log("\n--- Configuring ExecutionQuoter ---");
            console.log("Setting ExecutionQuoter to:", executionQuoterAddress);

            executionRouter.setExecutionQuoter(executionQuoterAddress);

            console.log("ExecutionQuoter configured successfully");
            emit RouterConfigured(address(executionRouter), executionQuoterAddress);
        }

        vm.stopBroadcast();

        // Emit deployment event
        emit RouterDeployed(address(executionRouter), executionRouter.owner(), executionRouter.executionQuoter());

        // Log deployment summary
        console.log("\n=== Deployment Summary ===");
        console.log("ExecutionRouter:", address(executionRouter));
        console.log("Owner:", executionRouter.owner());

        if (executionRouter.executionQuoter() != address(0)) {
            console.log("ExecutionQuoter:", executionRouter.executionQuoter());
        } else {
            console.log("ExecutionQuoter: Not set (can be set later via setExecutionQuoter)");
        }

        // Verification instructions
        if (shouldVerify) {
            console.log("\n=== Verification Command ===");
            console.log("forge verify-contract", address(executionRouter));
            console.log("  --chain-id", block.chainid);
            console.log("  --constructor-args $(cast abi-encode \"constructor()\")");
            console.log("  src/base/ExecutionRouter.sol:ExecutionRouter");
            console.log("  --etherscan-api-key $ETHERSCAN_API_KEY");
        }

        // Post-deployment instructions
        console.log("\n=== Next Steps ===");
        console.log("1. Verify the contract on Etherscan (if not done automatically)");

        if (executionRouter.executionQuoter() == address(0)) {
            console.log("2. Set ExecutionQuoter address via: setExecutionQuoter(address)");
        }

        console.log("3. Fund the router if needed for gas costs");
        console.log("4. Test the router functionality");
        console.log("5. Configure any dependent contracts to use this router");

        // Save deployment info
        _saveDeploymentInfo();
    }

    /**
     * @notice Save deployment information to a file
     * @dev Creates a JSON file with deployment details for reference
     */
    function _saveDeploymentInfo() internal {
        string memory deploymentInfo = string.concat(
            "{\n",
            '  "contract": "ExecutionRouter",\n',
            '  "address": "',
            vm.toString(address(executionRouter)),
            '",\n',
            '  "owner": "',
            vm.toString(executionRouter.owner()),
            '",\n',
            '  "quoter": "',
            vm.toString(executionRouter.executionQuoter()),
            '",\n',
            '  "chainId": ',
            vm.toString(block.chainid),
            ",\n",
            '  "blockNumber": ',
            vm.toString(block.number),
            ",\n",
            '  "timestamp": ',
            vm.toString(block.timestamp),
            "\n",
            "}\n"
        );

        string memory filename = string.concat(
            "deployment-execution-router-", vm.toString(block.chainid), "-", vm.toString(block.timestamp), ".json"
        );

        vm.writeFile(string.concat("deployments/", filename), deploymentInfo);

        console.log("Deployment info saved to:", filename);
    }

    /**
     * @notice Verify deployment was successful
     * @dev Call this function to verify the deployment
     */
    function verifyDeployment() public view {
        require(address(executionRouter) != address(0), "ExecutionRouter not deployed");
        require(executionRouter.owner() != address(0), "Owner not set");

        console.log("[SUCCESS] ExecutionRouter deployment verified successfully");
        console.log("Address:", address(executionRouter));
        console.log("Owner:", executionRouter.owner());

        if (executionRouter.executionQuoter() != address(0)) {
            console.log("Quoter:", executionRouter.executionQuoter());
        }
    }
}
