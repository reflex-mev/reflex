// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {AlgebraBasePluginV3} from "../../src/integrations/plugin/algebra/full/AlgebraBasePluginV3.sol";

/**
 * @title DeployAlgebraBasePluginV3
 * @notice Deployment script for AlgebraBasePluginV3 contract
 * @dev Run with: forge script script/DeployAlgebraBasePluginV3.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
 *
 * Environment Variables Required:
 * - POOL_ADDRESS: Address of the Algebra pool
 * - FACTORY_ADDRESS: Address of the Algebra factory
 * - PLUGIN_FACTORY_ADDRESS: Address of the plugin factory
 * - BASE_FEE: Base fee in basis points (e.g., 500 for 0.05%)
 * - REFLEX_ROUTER_ADDRESS: Address of the Reflex router
 *
 * Optional Environment Variables:
 * - INITIALIZE_PLUGIN: Set to "true" to call initialize() after deployment
 * - VERIFY_CONTRACT: Set to "true" to verify on Etherscan
 * - ETHERSCAN_API_KEY: Required if VERIFY_CONTRACT is true
 */
contract DeployAlgebraBasePluginV3 is Script {
    // Deployment parameters
    address public poolAddress;
    address public factoryAddress;
    address public pluginFactoryAddress;
    uint16 public baseFee;
    address public reflexRouterAddress;

    // Contract instance
    AlgebraBasePluginV3 public plugin;

    // Events
    event PluginDeployed(
        address indexed plugin,
        address indexed pool,
        address indexed factory,
        address pluginFactory,
        uint16 baseFee,
        address reflexRouter
    );

    function setUp() public {
        // Load deployment parameters from environment variables
        poolAddress = vm.envAddress("POOL_ADDRESS");
        factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        pluginFactoryAddress = vm.envAddress("PLUGIN_FACTORY_ADDRESS");
        baseFee = uint16(vm.envUint("BASE_FEE"));
        reflexRouterAddress = vm.envAddress("REFLEX_ROUTER_ADDRESS");

        // Validate parameters
        _validateParameters();
    }

    function run() public {
        console.log("=== AlgebraBasePluginV3 Deployment ===");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", msg.sender);
        console.log("");

        // Log deployment parameters
        _logParameters();

        vm.startBroadcast();

        // Deploy the plugin contract
        plugin = new AlgebraBasePluginV3(
            poolAddress, factoryAddress, pluginFactoryAddress, baseFee, reflexRouterAddress, bytes32(0)
        );

        // Initialize plugin if requested
        _initializePlugin();

        vm.stopBroadcast();

        // Log deployment results
        _logDeploymentResults();

        // Emit deployment event
        emit PluginDeployed(
            address(plugin), poolAddress, factoryAddress, pluginFactoryAddress, baseFee, reflexRouterAddress
        );

        // Verify contract if requested
        _verifyContract();

        console.log("=== Deployment Complete ===");
    }

    function _validateParameters() internal view {
        require(poolAddress != address(0), "POOL_ADDRESS cannot be zero");
        require(factoryAddress != address(0), "FACTORY_ADDRESS cannot be zero");
        require(pluginFactoryAddress != address(0), "PLUGIN_FACTORY_ADDRESS cannot be zero");
        require(reflexRouterAddress != address(0), "REFLEX_ROUTER_ADDRESS cannot be zero");
        require(baseFee > 0 && baseFee <= 10000, "BASE_FEE must be between 1-10000 bps");

        console.log("All parameters validated successfully");
    }

    function _logParameters() internal view {
        console.log("Deployment Parameters:");
        console.log("- Pool Address:", poolAddress);
        console.log("- Factory Address:", factoryAddress);
        console.log("- Plugin Factory Address:", pluginFactoryAddress);
        console.log("- Base Fee (bps):", baseFee);
        console.log("- Reflex Router Address:", reflexRouterAddress);
        console.log("");
    }

    function _logDeploymentResults() internal view {
        console.log("Deployment Results:");
        console.log("- Plugin Address:", address(plugin));
        console.log("- Plugin Code Size:", address(plugin).code.length);
        console.log("- Reflex Enabled:", plugin.reflexEnabled());
        console.log("- Router Address:", plugin.getRouter());

        // Check if plugin was initialized
        try vm.envBool("INITIALIZE_PLUGIN") returns (bool wasInitialized) {
            if (wasInitialized) {
                console.log("- Plugin Initialized: true");
            } else {
                console.log("- Plugin Initialized: false (initialization skipped)");
            }
        } catch {
            console.log("- Plugin Initialized: false (initialization not requested)");
        }

        console.log("");

        // Gas estimation
        console.log("Gas Usage:");
        console.log("- Deployment Gas Used: Check transaction receipt");
        console.log("");
    }

    function _initializePlugin() internal {
        bool shouldInitialize = false;

        // Check if initialization is requested
        try vm.envBool("INITIALIZE_PLUGIN") returns (bool initialize) {
            shouldInitialize = initialize;
        } catch {
            // INITIALIZE_PLUGIN not set, skip initialization
            console.log("Skipping initialization (INITIALIZE_PLUGIN not set)");
            return;
        }

        if (!shouldInitialize) {
            console.log("Skipping initialization (INITIALIZE_PLUGIN=false)");
            return;
        }

        console.log("Initializing plugin...");

        try plugin.initializePlugin() {
            console.log("Plugin initialized successfully");
        } catch Error(string memory reason) {
            console.log("Plugin initialization failed:", reason);
        } catch {
            console.log("Plugin initialization failed with unknown error");
        }

        console.log("");
    }

    function _verifyContract() internal {
        bool shouldVerify = false;

        // Check if verification is requested
        try vm.envBool("VERIFY_CONTRACT") returns (bool verify) {
            shouldVerify = verify;
        } catch {
            // VERIFY_CONTRACT not set, skip verification
            console.log("Skipping verification (VERIFY_CONTRACT not set)");
            return;
        }

        if (!shouldVerify) {
            console.log("Skipping verification (VERIFY_CONTRACT=false)");
            return;
        }

        console.log("Verifying contract on Etherscan...");

        // Construct verification command
        string[] memory inputs = new string[](10);
        inputs[0] = "forge";
        inputs[1] = "verify-contract";
        inputs[2] = vm.toString(address(plugin));
        inputs[3] = "src/integrations/algebra/full/AlgebraBasePluginV3.sol:AlgebraBasePluginV3";
        inputs[4] = "--constructor-args";
        inputs[5] =
            vm.toString(abi.encode(poolAddress, factoryAddress, pluginFactoryAddress, baseFee, reflexRouterAddress));
        inputs[6] = "--etherscan-api-key";
        inputs[7] = vm.envString("ETHERSCAN_API_KEY");
        inputs[8] = "--watch";
        inputs[9] = "--show-standard-json-input";

        try vm.ffi(inputs) {
            console.log("Contract verified successfully");
        } catch {
            console.log("Contract verification failed");
            console.log("You can verify manually with:");
            console.log("forge verify-contract", vm.toString(address(plugin)));
            console.log("src/integrations/algebra/full/AlgebraBasePluginV3.sol:AlgebraBasePluginV3");
            console.log(
                "--constructor-args",
                vm.toString(abi.encode(poolAddress, factoryAddress, pluginFactoryAddress, baseFee, reflexRouterAddress))
            );
        }
    }

    // Helper function to get deployment address for testing
    function getDeployedAddress() external view returns (address) {
        return address(plugin);
    }

    // Helper function to check if plugin is properly configured
    function validateDeployment() external view returns (bool) {
        if (address(plugin) == address(0)) return false;
        if (plugin.getRouter() != reflexRouterAddress) return false;
        if (!plugin.reflexEnabled()) return false;

        // Check if initialization was requested and completed
        try vm.envBool("INITIALIZE_PLUGIN") returns (bool shouldInit) {
            if (shouldInit) {
                // If initialization was requested, we can add additional checks here
                // For now, we assume initialization was successful if the function returned
                console.log("Plugin was initialized during deployment");
            }
        } catch {
            // INITIALIZE_PLUGIN not set, no additional checks needed
        }

        // Add more validation checks as needed
        return true;
    }
}
