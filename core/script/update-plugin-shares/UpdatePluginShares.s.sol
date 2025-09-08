// // SPDX-License-Identifier: MIT
// pragma solidity =0.8.20;

// import "forge-std/Script.sol";
// import "forge-std/console.sol";
// import {AlgebraBasePluginV3} from "../src/integrations/algebra/full/AlgebraBasePluginV3.sol";

// /**
//  * @title UpdatePluginShares
//  * @notice Script to update profit sharing configuration on AlgebraBasePluginV3 contract(s)
//  * @dev Run with: forge script script/UpdatePluginShares.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
//  *
//  * Environment Variables Required:
//  * - PLUGIN_ADDRESSES: Comma-separated list of deployed AlgebraBasePluginV3 contract addresses (e.g., "0x123...,0x456...")
//  *   OR
//  * - PLUGIN_ADDRESS: Single address of the deployed AlgebraBasePluginV3 contract (for backward compatibility)
//  * - RECIPIENTS: Comma-separated list of recipient addresses (e.g., "0x123...,0x456...")
//  * - SHARES: Comma-separated list of share amounts in basis points (e.g., "5000,3000,2000")
//  *
//  * Optional Environment Variables:
//  * - DRY_RUN: Set to "true" to simulate without broadcasting
//  * - VERIFY_BEFORE_UPDATE: Set to "true" to verify current state before updating
//  *
//  * @dev Total shares must equal 10000 (100%)
//  * @dev Only the reflex admin can update shares
//  * @dev When using multiple plugin addresses, the same share configuration will be applied to all plugins
//  */
// contract UpdatePluginShares is Script {
//     // Contract references
//     AlgebraBasePluginV3[] public plugins;

//     // Update parameters
//     address[] public pluginAddresses;
//     address[] public recipients;
//     uint256[] public sharesBps;

//     // Configuration
//     bool public isDryRun;
//     bool public verifyBeforeUpdate;

//     // Events
//     event SharesUpdatePrepared(address indexed plugin, address[] recipients, uint256[] sharesBps, uint256 totalShares);

//     event SharesUpdated(address indexed plugin, address[] recipients, uint256[] sharesBps);

//     function setUp() public {
//         // Load plugin addresses (supports both single and multiple)
//         _loadPluginAddresses();

//         // Initialize plugin contract references
//         for (uint256 i = 0; i < pluginAddresses.length; i++) {
//             plugins.push(AlgebraBasePluginV3(pluginAddresses[i]));
//         }

//         // Parse recipients and shares from environment variables
//         _parseRecipientsAndShares();

//         // Load optional configuration
//         _loadConfiguration();

//         // Validate parameters
//         _validateParameters();
//     }

//     function run() public {
//         console.log("=== Update Plugin Shares ===");
//         console.log("Chain ID:", block.chainid);
//         console.log("Sender:", msg.sender);
//         console.log("Plugin Count:", pluginAddresses.length);
//         for (uint256 i = 0; i < pluginAddresses.length; i++) {
//             console.log("Plugin", i + 1, "Address:", pluginAddresses[i]);
//         }
//         console.log("");

//         // Verify current state if requested
//         if (verifyBeforeUpdate) {
//             _verifyCurrentState();
//         }

//         // Log update parameters
//         _logUpdateParameters();

//         if (isDryRun) {
//             console.log("DRY RUN MODE - No transactions will be broadcast");
//             _simulateUpdate();
//         } else {
//             _executeUpdate();
//         }

//         console.log("=== Update Complete ===");
//     }

//     function _loadPluginAddresses() internal {
//         // Try to load multiple plugin addresses first
//         try vm.envString("PLUGIN_ADDRESSES") returns (string memory addressesStr) {
//             string[] memory addressStrings = _splitString(addressesStr, ",");
//             pluginAddresses = new address[](addressStrings.length);
//             for (uint256 i = 0; i < addressStrings.length; i++) {
//                 pluginAddresses[i] = vm.parseAddress(_trim(addressStrings[i]));
//             }
//             console.log("Loaded", pluginAddresses.length, "plugin addresses from PLUGIN_ADDRESSES");
//         } catch {
//             // Fall back to single plugin address for backward compatibility
//             try vm.envAddress("PLUGIN_ADDRESS") returns (address singleAddress) {
//                 pluginAddresses = new address[](1);
//                 pluginAddresses[0] = singleAddress;
//                 console.log("Loaded single plugin address from PLUGIN_ADDRESS");
//             } catch {
//                 revert("Must provide either PLUGIN_ADDRESSES or PLUGIN_ADDRESS environment variable");
//             }
//         }
//     }

//     function _parseRecipientsAndShares() internal {
//         // Parse recipients
//         string memory recipientsStr = vm.envString("RECIPIENTS");
//         string[] memory recipientStrings = _splitString(recipientsStr, ",");

//         recipients = new address[](recipientStrings.length);
//         for (uint256 i = 0; i < recipientStrings.length; i++) {
//             recipients[i] = vm.parseAddress(_trim(recipientStrings[i]));
//         }

//         // Parse shares
//         string memory sharesStr = vm.envString("SHARES");
//         string[] memory shareStrings = _splitString(sharesStr, ",");

//         sharesBps = new uint256[](shareStrings.length);
//         for (uint256 i = 0; i < shareStrings.length; i++) {
//             sharesBps[i] = vm.parseUint(_trim(shareStrings[i]));
//         }
//     }

//     function _loadConfiguration() internal {
//         // Check for dry run mode
//         try vm.envBool("DRY_RUN") returns (bool dryRun) {
//             isDryRun = dryRun;
//         } catch {
//             isDryRun = false;
//         }

//         // Check for verification flag
//         try vm.envBool("VERIFY_BEFORE_UPDATE") returns (bool verify) {
//             verifyBeforeUpdate = verify;
//         } catch {
//             verifyBeforeUpdate = true; // Default to verification
//         }
//     }

//     function _validateParameters() internal view {
//         require(pluginAddresses.length > 0, "At least one plugin address required");
//         require(pluginAddresses.length <= 20, "Too many plugin addresses (max 20)");
//         require(recipients.length > 0, "At least one recipient required");
//         require(recipients.length == sharesBps.length, "Recipients and shares length mismatch");
//         require(recipients.length <= 10, "Too many recipients (max 10)");

//         // Validate plugin addresses are not zero
//         for (uint256 i = 0; i < pluginAddresses.length; i++) {
//             require(pluginAddresses[i] != address(0), "Plugin address cannot be zero");

//             // Check for duplicate plugin addresses
//             for (uint256 j = i + 1; j < pluginAddresses.length; j++) {
//                 require(pluginAddresses[i] != pluginAddresses[j], "Duplicate plugin address detected");
//             }
//         }

//         // Validate total shares equal 10000 (100%)
//         uint256 totalShares = 0;
//         for (uint256 i = 0; i < sharesBps.length; i++) {
//             require(recipients[i] != address(0), "Recipient cannot be zero address");
//             require(sharesBps[i] > 0, "Share must be greater than 0");
//             totalShares += sharesBps[i];
//         }
//         require(totalShares == 10000, "Total shares must equal 10000 (100%)");

//         // Check for duplicate recipients
//         for (uint256 i = 0; i < recipients.length; i++) {
//             for (uint256 j = i + 1; j < recipients.length; j++) {
//                 require(recipients[i] != recipients[j], "Duplicate recipient detected");
//             }
//         }

//         console.log("All parameters validated successfully");
//     }

//     function _verifyCurrentState() internal view {
//         console.log("Current Plugin States:");

//         for (uint256 p = 0; p < plugins.length; p++) {
//             console.log("");
//             console.log("Plugin", p + 1, "(", pluginAddresses[p], "):");
//             console.log("- Reflex Enabled:", plugins[p].reflexEnabled());
//             console.log("- Router Address:", plugins[p].getRouter());
//             console.log("- Reflex Admin:", plugins[p].getReflexAdmin());

//             // Get current recipients and shares
//             address[] memory currentRecipients = plugins[p].getRecipients();
//             console.log("- Current Recipients Count:", currentRecipients.length);

//             for (uint256 i = 0; i < currentRecipients.length; i++) {
//                 uint256[] memory shares = plugins[p].getShares(currentRecipients);
//                 console.log("  -", currentRecipients[i], ":", shares[i], "bps");
//             }
//         }
//         console.log("");
//     }

//     function _logUpdateParameters() internal view {
//         console.log("Update Parameters:");
//         console.log("- Recipients Count:", recipients.length);

//         uint256 totalShares = 0;
//         for (uint256 i = 0; i < recipients.length; i++) {
//             console.log("  - Recipient:", recipients[i]);
//             console.log("    Share:", sharesBps[i], "bps");
//             totalShares += sharesBps[i];
//         }
//         console.log("- Total Shares:", totalShares, "bps (100.00%)");
//         console.log("");
//     }

//     function _simulateUpdate() internal {
//         console.log("Simulating updateShares call for", plugins.length, "plugin(s)...");

//         for (uint256 p = 0; p < plugins.length; p++) {
//             console.log("Simulating Plugin", p + 1, "(", pluginAddresses[p], "):");

//             // Emit event for tracking
//             emit SharesUpdatePrepared(address(plugins[p]), recipients, sharesBps, _getTotalShares());

//             try plugins[p].updateShares(recipients, sharesBps) {
//                 console.log("  [ OK ] Simulation successful - updateShares would succeed");
//             } catch Error(string memory reason) {
//                 console.log("  [ FAIL ] Simulation failed:", reason);
//                 revert(string(abi.encodePacked("Simulation failed for plugin ", vm.toString(p + 1), ": ", reason)));
//             } catch {
//                 console.log("  [ FAIL ] Simulation failed with unknown error");
//                 revert(
//                     string(abi.encodePacked("Simulation failed for plugin ", vm.toString(p + 1), " with unknown error"))
//                 );
//             }
//         }

//         console.log("All simulations completed successfully");
//     }

//     function _executeUpdate() internal {
//         console.log("Executing updateShares transaction for", plugins.length, "plugin(s)...");

//         vm.startBroadcast();

//         bool allSuccessful = true;
//         uint256 successCount = 0;

//         for (uint256 p = 0; p < plugins.length; p++) {
//             console.log("Updating Plugin", p + 1, "(", pluginAddresses[p], "):");

//             try plugins[p].updateShares(recipients, sharesBps) {
//                 console.log("  [OK] Shares updated successfully");
//                 successCount++;

//                 // Emit event
//                 emit SharesUpdated(address(plugins[p]), recipients, sharesBps);
//             } catch Error(string memory reason) {
//                 console.log("  [FAIL] Update failed:", reason);
//                 allSuccessful = false;
//                 // Continue with other plugins instead of reverting
//             } catch {
//                 console.log("  [FAIL] Update failed with unknown error");
//                 allSuccessful = false;
//                 // Continue with other plugins instead of reverting
//             }
//         }

//         vm.stopBroadcast();

//         console.log("");
//         console.log("Update Summary:");
//         console.log("- Total Plugins:", plugins.length);
//         console.log("- Successful Updates:", successCount);
//         console.log("- Failed Updates:", plugins.length - successCount);

//         if (!allSuccessful) {
//             console.log("WARNING: Some plugin updates failed. Check logs above for details.");
//         }

//         // Verify successful updates
//         if (successCount > 0) {
//             _verifyUpdates();
//         }
//     }

//     function _verifyUpdates() internal view {
//         console.log("Verifying updates...");

//         for (uint256 p = 0; p < plugins.length; p++) {
//             console.log("Verifying Plugin", p + 1, "(", pluginAddresses[p], "):");

//             try plugins[p].getRecipients() returns (address[] memory newRecipients) {
//                 if (newRecipients.length != recipients.length) {
//                     console.log("  [FAIL] Recipient count mismatch - update may have failed");
//                     continue;
//                 }

//                 uint256[] memory newShares = plugins[p].getShares(newRecipients);
//                 uint256 totalShares = 0;
//                 bool sharesMatch = true;

//                 for (uint256 i = 0; i < newRecipients.length; i++) {
//                     bool found = false;
//                     for (uint256 j = 0; j < recipients.length; j++) {
//                         if (newRecipients[i] == recipients[j]) {
//                             if (newShares[i] != sharesBps[j]) {
//                                 sharesMatch = false;
//                             }
//                             found = true;
//                             break;
//                         }
//                     }
//                     if (!found) {
//                         sharesMatch = false;
//                     }
//                     totalShares += newShares[i];
//                 }

//                 if (totalShares == 10000 && sharesMatch) {
//                     console.log("  [OK] Update verified successfully");
//                 } else {
//                     console.log("  [FAIL] Verification failed - shares don't match expected values");
//                 }
//             } catch {
//                 console.log("  [FAIL] Verification failed - unable to read plugin state");
//             }
//         }
//     }

//     function _getTotalShares() internal view returns (uint256) {
//         uint256 total = 0;
//         for (uint256 i = 0; i < sharesBps.length; i++) {
//             total += sharesBps[i];
//         }
//         return total;
//     }

//     // Helper function to split string by delimiter
//     function _splitString(string memory str, string memory delimiter) internal pure returns (string[] memory) {
//         bytes memory strBytes = bytes(str);
//         bytes memory delimiterBytes = bytes(delimiter);

//         if (strBytes.length == 0) {
//             return new string[](0);
//         }

//         // Count occurrences of delimiter
//         uint256 count = 1;
//         for (uint256 i = 0; i <= strBytes.length - delimiterBytes.length; i++) {
//             bool isMatch = true;
//             for (uint256 j = 0; j < delimiterBytes.length; j++) {
//                 if (strBytes[i + j] != delimiterBytes[j]) {
//                     isMatch = false;
//                     break;
//                 }
//             }
//             if (isMatch) {
//                 count++;
//                 i += delimiterBytes.length - 1;
//             }
//         }

//         // Split the string
//         string[] memory result = new string[](count);
//         uint256 resultIndex = 0;
//         uint256 startIndex = 0;

//         for (uint256 i = 0; i <= strBytes.length - delimiterBytes.length; i++) {
//             bool isMatch = true;
//             for (uint256 j = 0; j < delimiterBytes.length; j++) {
//                 if (strBytes[i + j] != delimiterBytes[j]) {
//                     isMatch = false;
//                     break;
//                 }
//             }
//             if (isMatch) {
//                 result[resultIndex] = _substring(str, startIndex, i);
//                 resultIndex++;
//                 startIndex = i + delimiterBytes.length;
//                 i += delimiterBytes.length - 1;
//             }
//         }

//         // Add the last part
//         result[resultIndex] = _substring(str, startIndex, strBytes.length);

//         return result;
//     }

//     // Helper function to extract substring
//     function _substring(string memory str, uint256 start, uint256 end) internal pure returns (string memory) {
//         bytes memory strBytes = bytes(str);
//         bytes memory result = new bytes(end - start);
//         for (uint256 i = start; i < end; i++) {
//             result[i - start] = strBytes[i];
//         }
//         return string(result);
//     }

//     // Helper function to trim whitespace
//     function _trim(string memory str) internal pure returns (string memory) {
//         bytes memory strBytes = bytes(str);
//         if (strBytes.length == 0) return str;

//         uint256 start = 0;
//         uint256 end = strBytes.length;

//         // Trim leading whitespace
//         while (
//             start < end
//                 && (
//                     strBytes[start] == 0x20 || strBytes[start] == 0x09 || strBytes[start] == 0x0A || strBytes[start] == 0x0D
//                 )
//         ) {
//             start++;
//         }

//         // Trim trailing whitespace
//         while (
//             end > start
//                 && (
//                     strBytes[end - 1] == 0x20 || strBytes[end - 1] == 0x09 || strBytes[end - 1] == 0x0A
//                         || strBytes[end - 1] == 0x0D
//                 )
//         ) {
//             end--;
//         }

//         return _substring(str, start, end);
//     }

//     // Helper functions for testing and verification
//     function getUpdateParameters() external view returns (address[] memory, uint256[] memory) {
//         return (recipients, sharesBps);
//     }

//     function getPluginAddresses() external view returns (address[] memory) {
//         return pluginAddresses;
//     }

//     function getPluginCount() external view returns (uint256) {
//         return pluginAddresses.length;
//     }

//     function validateUpdateParameters() external view returns (bool) {
//         if (recipients.length == 0 || recipients.length != sharesBps.length) return false;

//         uint256 totalShares = 0;
//         for (uint256 i = 0; i < sharesBps.length; i++) {
//             if (recipients[i] == address(0) || sharesBps[i] == 0) return false;
//             totalShares += sharesBps[i];
//         }

//         return totalShares == 10000;
//     }
// }
