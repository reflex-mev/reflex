// SPDX-License-Identifier: MIT
pragma solidity =0.8.20;

import "forge-std/Script.sol";
import "forge-std/console.sol";
import {BasePluginV1Factory} from "../../src/integrations/algebra/v1/BasePluginV1Factory.sol";
import {AlgebraFeeConfiguration} from "@cryptoalgebra/plugin/base/AlgebraFeeConfiguration.sol";

/**
 * @title DeployBasePluginV1Factory
 * @notice Deployment script for BasePluginV1Factory contract
 * @dev Run with: forge script script/DeployBasePluginV1Factory.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
 *
 * Environment Variables Required:
 * - ALGEBRA_FACTORY_ADDRESS: Address of the Algebra factory
 * - REFLEX_ROUTER_ADDRESS: Address of the Reflex router
 *
 * Optional Environment Variables:
 * - FARMING_ADDRESS: Address for farming (can be set later)
 * - VERIFY_CONTRACT: Set to "true" to verify on Etherscan
 * - ETHERSCAN_API_KEY: Required if VERIFY_CONTRACT is true
 * - CUSTOM_FEE_CONFIG: Set to "true" to use custom fee configuration
 * - ALPHA1, ALPHA2, BETA1, BETA2, GAMMA1, GAMMA2, BASE_FEE: Custom fee parameters (if CUSTOM_FEE_CONFIG=true)
 */
contract DeployBasePluginV1Factory is Script {
    // Deployment parameters
    address public algebraFactoryAddress;
    address public reflexRouterAddress;
    address public farmingAddress;

    // Custom fee configuration parameters
    bool public useCustomFeeConfig;
    AlgebraFeeConfiguration public customFeeConfig;

    // Contract instance
    BasePluginV1Factory public factory;

    // Events
    event FactoryDeployed(
        address indexed factory, address indexed algebraFactory, address reflexRouter, address farmingAddress
    );

    function setUp() public {
        // Load required deployment parameters from environment variables
        algebraFactoryAddress = vm.envAddress("ALGEBRA_FACTORY_ADDRESS");
        reflexRouterAddress = vm.envAddress("REFLEX_ROUTER_ADDRESS");

        // Load optional parameters
        try vm.envAddress("FARMING_ADDRESS") returns (address _farmingAddress) {
            farmingAddress = _farmingAddress;
        } catch {
            farmingAddress = address(0);
        }

        // Check if custom fee configuration is requested
        try vm.envBool("CUSTOM_FEE_CONFIG") returns (bool custom) {
            useCustomFeeConfig = custom;
            if (useCustomFeeConfig) {
                _loadCustomFeeConfig();
            }
        } catch {
            useCustomFeeConfig = false;
        }

        // Validate parameters
        _validateParameters();
    }

    function run() public {
        console.log("=== BasePluginV1Factory Deployment ===");
        console.log("Chain ID:", block.chainid);
        console.log("Deployer:", msg.sender);
        console.log("");

        // Log deployment parameters
        _logParameters();

        vm.startBroadcast();

        // Deploy the factory contract
        factory = new BasePluginV1Factory(algebraFactoryAddress, reflexRouterAddress, bytes32(0));

        // Configure the factory
        _configureFactory();

        vm.stopBroadcast();

        // Log deployment results
        _logDeploymentResults();

        // Emit deployment event
        emit FactoryDeployed(address(factory), algebraFactoryAddress, reflexRouterAddress, farmingAddress);

        // Verify contract if requested
        _verifyContract();

        console.log("=== Deployment Complete ===");
    }

    function _loadCustomFeeConfig() internal {
        customFeeConfig = AlgebraFeeConfiguration({
            alpha1: uint16(vm.envUint("ALPHA1")),
            alpha2: uint16(vm.envUint("ALPHA2")),
            beta1: uint32(vm.envUint("BETA1")),
            beta2: uint32(vm.envUint("BETA2")),
            gamma1: uint16(vm.envUint("GAMMA1")),
            gamma2: uint16(vm.envUint("GAMMA2")),
            baseFee: uint16(vm.envUint("BASE_FEE"))
        });

        console.log("Custom fee configuration loaded:");
        console.log("- Alpha1:", customFeeConfig.alpha1);
        console.log("- Alpha2:", customFeeConfig.alpha2);
        console.log("- Beta1:", customFeeConfig.beta1);
        console.log("- Beta2:", customFeeConfig.beta2);
        console.log("- Gamma1:", customFeeConfig.gamma1);
        console.log("- Gamma2:", customFeeConfig.gamma2);
        console.log("- Base Fee:", customFeeConfig.baseFee);
    }

    function _validateParameters() internal view {
        require(algebraFactoryAddress != address(0), "ALGEBRA_FACTORY_ADDRESS cannot be zero");
        require(reflexRouterAddress != address(0), "REFLEX_ROUTER_ADDRESS cannot be zero");

        // Validate custom fee configuration if provided
        if (useCustomFeeConfig) {
            require(customFeeConfig.alpha1 > 0, "Alpha1 must be greater than 0");
            require(customFeeConfig.alpha2 > 0, "Alpha2 must be greater than 0");
            require(customFeeConfig.beta1 > 0, "Beta1 must be greater than 0");
            require(customFeeConfig.beta2 > 0, "Beta2 must be greater than 0");
            require(customFeeConfig.gamma1 > 0, "Gamma1 must be greater than 0");
            require(customFeeConfig.gamma2 > 0, "Gamma2 must be greater than 0");
            require(
                customFeeConfig.baseFee > 0 && customFeeConfig.baseFee <= 10000, "Base fee must be between 1-10000 bps"
            );
        }

        console.log("All parameters validated successfully");
    }

    function _logParameters() internal view {
        console.log("Deployment Parameters:");
        console.log("- Algebra Factory Address:", algebraFactoryAddress);
        console.log("- Reflex Router Address:", reflexRouterAddress);

        if (farmingAddress != address(0)) {
            console.log("- Farming Address:", farmingAddress);
        } else {
            console.log("- Farming Address: Not set (can be configured later)");
        }

        if (useCustomFeeConfig) {
            console.log("- Fee Configuration: Custom");
        } else {
            console.log(
                "- Fee Configuration: Default (alpha1=2900, alpha2=12000, beta1=360, beta2=60000, gamma1=59, gamma2=8500, baseFee=100)"
            );
        }
        console.log("");
    }

    function _configureFactory() internal {
        console.log("Configuring factory...");

        // Set farming address if provided
        if (farmingAddress != address(0)) {
            factory.setFarmingAddress(farmingAddress);
            console.log("Farming address set");
        }

        // Set custom fee configuration if provided
        if (useCustomFeeConfig) {
            factory.setDefaultFeeConfiguration(customFeeConfig);
            console.log("Custom fee configuration set");
        }

        console.log("Factory configuration complete");
        console.log("");
    }

    function _logDeploymentResults() internal view {
        console.log("Deployment Results:");
        console.log("- Factory Address:", address(factory));
        console.log("- Factory Code Size:", address(factory).code.length);
        console.log("- Algebra Factory:", factory.algebraFactory());
        console.log("- Reflex Router:", factory.reflexRouter());

        if (factory.farmingAddress() != address(0)) {
            console.log("- Farming Address:", factory.farmingAddress());
        } else {
            console.log("- Farming Address: Not set");
        }

        // Log default fee configuration
        (uint16 alpha1, uint16 alpha2, uint32 beta1, uint32 beta2, uint16 gamma1, uint16 gamma2, uint16 baseFee) =
            factory.defaultFeeConfiguration();
        console.log("- Default Fee Config:");
        console.log("  - Alpha1:", alpha1);
        console.log("  - Alpha2:", alpha2);
        console.log("  - Beta1:", beta1);
        console.log("  - Beta2:", beta2);
        console.log("  - Gamma1:", gamma1);
        console.log("  - Gamma2:", gamma2);
        console.log("  - Base Fee:", baseFee);

        console.log("");

        // Gas estimation
        console.log("Gas Usage:");
        console.log("- Deployment Gas Used: Check transaction receipt");
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
        string[] memory inputs = new string[](8);
        inputs[0] = "forge";
        inputs[1] = "verify-contract";
        inputs[2] = vm.toString(address(factory));
        inputs[3] = "src/integrations/algebra/v1/BasePluginV1Factory.sol:BasePluginV1Factory";
        inputs[4] = "--constructor-args";
        inputs[5] = vm.toString(abi.encode(algebraFactoryAddress, reflexRouterAddress));
        inputs[6] = "--etherscan-api-key";
        inputs[7] = vm.envString("ETHERSCAN_API_KEY");

        try vm.ffi(inputs) {
            console.log("Contract verified successfully");
        } catch {
            console.log("Contract verification failed");
            console.log("You can verify manually with:");
            console.log("forge verify-contract", vm.toString(address(factory)));
            console.log("src/integrations/algebra/v1/BasePluginV1Factory.sol:BasePluginV1Factory");
            console.log("--constructor-args", vm.toString(abi.encode(algebraFactoryAddress, reflexRouterAddress)));
        }
    }

    // Helper function to get deployment address for testing
    function getDeployedAddress() external view returns (address) {
        return address(factory);
    }

    // Helper function to check if factory is properly configured
    function validateDeployment() external view returns (bool) {
        if (address(factory) == address(0)) return false;
        if (factory.algebraFactory() != algebraFactoryAddress) return false;
        if (factory.reflexRouter() != reflexRouterAddress) return false;

        // Check farming address if it was set
        if (farmingAddress != address(0)) {
            if (factory.farmingAddress() != farmingAddress) return false;
        }

        // Verify fee configuration is set (should have non-zero values)
        (uint16 alpha1,,,,,,) = factory.defaultFeeConfiguration();
        if (alpha1 == 0) return false;

        return true;
    }

    // Helper function to create a plugin for testing
    function createTestPlugin(address token0, address token1) external returns (address) {
        require(address(factory) != address(0), "Factory not deployed");
        return factory.createPluginForExistingPool(token0, token1);
    }
}
