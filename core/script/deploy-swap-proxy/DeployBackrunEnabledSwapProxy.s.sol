// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {BackrunEnabledSwapProxy} from "@reflex/integrations/BackrunEnabledSwapProxy.sol";

/**
 * @title DeployBackrunEnabledSwapProxy
 * @notice Deployment script for BackrunEnabledSwapProxy contract
 * @dev Run with: forge script script/deploy-swap-proxy/DeployBackrunEnabledSwapProxy.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
 *
 * Environment Variables (Required):
 * - TARGET_ROUTER_ADDRESS: Address of the target swap router contract
 *
 * Environment Variables (Optional):
 * - VERIFY_CONTRACT: Set to "true" to verify on Etherscan
 * - ETHERSCAN_API_KEY: Required if VERIFY_CONTRACT is true
 * - GAS_PRICE: Gas price in gwei (optional)
 * - GAS_LIMIT: Gas limit (optional)
 *
 * Example Usage:
 * forge script script/deploy-swap-proxy/DeployBackrunEnabledSwapProxy.s.sol \
 *   --rpc-url https://mainnet.infura.io/v3/YOUR-PROJECT-ID \
 *   --private-key $PRIVATE_KEY \
 *   --broadcast \
 *   --verify
 *
 * With environment variables:
 * TARGET_ROUTER_ADDRESS=0x1234... forge script script/deploy-swap-proxy/DeployBackrunEnabledSwapProxy.s.sol \
 *   --rpc-url $RPC_URL \
 *   --private-key $PRIVATE_KEY \
 *   --broadcast
 */
contract DeployBackrunEnabledSwapProxy is Script {
    // Contract instance
    BackrunEnabledSwapProxy public swapProxy;

    // Configuration
    address public targetRouterAddress;
    bool public shouldVerify;

    // Events
    event SwapProxyDeployed(address indexed proxy, address indexed targetRouter);

    function setUp() public {
        // Load required configuration from environment variables
        try vm.envAddress("TARGET_ROUTER_ADDRESS") returns (address router) {
            targetRouterAddress = router;
            console.log("Target router address loaded:", router);
        } catch {
            revert("TARGET_ROUTER_ADDRESS environment variable not set");
        }

        // Validate target router address
        require(targetRouterAddress != address(0), "Target router address cannot be zero");
        require(targetRouterAddress.code.length > 0, "Target router address must be a contract");

        // Load optional configuration
        try vm.envBool("VERIFY_CONTRACT") returns (bool verify) {
            shouldVerify = verify;
            console.log("Contract verification:", verify ? "enabled" : "disabled");
        } catch {
            shouldVerify = false;
            console.log("Contract verification: disabled (default)");
        }
    }

    function run() public {
        // Get deployer address
        address deployer = msg.sender;

        console.log("=== BackrunEnabledSwapProxy Deployment ===");
        console.log("Deployer address:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("Block number:", block.number);
        console.log("Target Router:", targetRouterAddress);

        // Check deployer balance
        uint256 balance = deployer.balance;
        console.log("Deployer balance:", balance / 1e18, "ETH");
        if (balance == 0) {
            console.log("Warning: Deployer has zero balance (simulation mode)");
        }

        // Start broadcasting transactions
        vm.startBroadcast();

        // Deploy BackrunEnabledSwapProxy
        console.log("\n--- Deploying BackrunEnabledSwapProxy ---");
        swapProxy = new BackrunEnabledSwapProxy(targetRouterAddress);

        console.log("BackrunEnabledSwapProxy deployed at:", address(swapProxy));
        console.log("Target Router configured:", swapProxy.targetRouter());

        vm.stopBroadcast();

        // Emit deployment event
        emit SwapProxyDeployed(address(swapProxy), targetRouterAddress);

        // Verify deployment
        _verifyDeployment();

        // Log deployment summary
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

    /**
     * @notice Verify deployment was successful
     * @dev Validates the deployment and logs confirmation
     */
    function _verifyDeployment() internal view {
        require(address(swapProxy) != address(0), "SwapProxy not deployed");
        require(swapProxy.targetRouter() == targetRouterAddress, "Target router mismatch");

        console.log("\n[SUCCESS] BackrunEnabledSwapProxy deployment verified successfully");
    }

    /**
     * @notice Log deployment summary
     */
    function _logDeploymentSummary() internal view {
        console.log("\n=== Deployment Summary ===");
        console.log("BackrunEnabledSwapProxy:", address(swapProxy));
        console.log("Target Router:", swapProxy.targetRouter());
        console.log("Chain ID:", block.chainid);
        console.log("Block Number:", block.number);
        console.log("Timestamp:", block.timestamp);
    }

    /**
     * @notice Log verification command
     */
    function _logVerificationCommand() internal view {
        console.log("\n=== Verification Command ===");
        console.log("forge verify-contract", address(swapProxy));
        console.log("  --chain-id", block.chainid);
        console.log(
            "  --constructor-args $(cast abi-encode \"constructor(address)\"",
            targetRouterAddress,
            ")"
        );
        console.log("  src/integrations/BackrunEnabledSwapProxy.sol:BackrunEnabledSwapProxy");
        console.log("  --etherscan-api-key $ETHERSCAN_API_KEY");
    }

    /**
     * @notice Log post-deployment instructions
     */
    function _logNextSteps() internal view {
        console.log("\n=== Next Steps ===");
        console.log("1. Verify the contract on Etherscan (if not done automatically)");
        console.log("2. Update frontend/SDK to use this proxy address");
        console.log("3. Test the proxy with sample swaps");
        console.log("4. Integrate with ReflexRouter for backrun operations");
        console.log("5. Monitor gas costs and optimize if needed");
        console.log("\n=== Integration Example ===");
        console.log("// Approve tokens to the swap proxy");
        console.log("tokenIn.approve(address(swapProxy), amountIn);");
        console.log("\n// Prepare swap calldata for target router");
        console.log("bytes memory swapCallData = abi.encodeWithSelector(...);");
        console.log("\n// Execute swap with backruns");
        console.log("swapProxy.swapWithbackrun(");
        console.log("    swapCallData,");
        console.log("    tokenIn,");
        console.log("    amountIn,");
        console.log("    reflexRouterAddress,");
        console.log("    backrunParams");
        console.log(");");
    }

    /**
     * @notice Save deployment information to a file
     * @dev Creates a JSON file with deployment details for reference
     */
    function _saveDeploymentInfo() internal {
        string memory deploymentInfo = string.concat(
            "{\n",
            '  "contract": "BackrunEnabledSwapProxy",\n',
            '  "address": "',
            vm.toString(address(swapProxy)),
            '",\n',
            '  "targetRouter": "',
            vm.toString(swapProxy.targetRouter()),
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
            "deployment-swap-proxy-",
            vm.toString(block.chainid),
            "-",
            vm.toString(block.timestamp),
            ".json"
        );

        string memory filepath = string.concat("deployments/", filename);

        vm.writeFile(filepath, deploymentInfo);

        console.log("\nDeployment info saved to:", filepath);
    }

    /**
     * @notice Helper function to verify an existing deployment
     * @param proxyAddress The address of the deployed proxy
     * @param expectedTargetRouter The expected target router address
     */
    function verifyExistingDeployment(address proxyAddress, address expectedTargetRouter) public view {
        require(proxyAddress != address(0), "Invalid proxy address");
        require(proxyAddress.code.length > 0, "No contract at proxy address");

        BackrunEnabledSwapProxy proxy = BackrunEnabledSwapProxy(payable(proxyAddress));

        require(proxy.targetRouter() == expectedTargetRouter, "Target router mismatch");

        console.log("[SUCCESS] Existing deployment verified successfully");
        console.log("Proxy Address:", proxyAddress);
        console.log("Target Router:", proxy.targetRouter());
    }
}
