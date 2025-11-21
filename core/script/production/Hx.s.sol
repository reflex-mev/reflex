//  // SPDX-License-Identifier: BUSL-1.1
// pragma solidity >=0.8.20;

// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import {IAlgebraPool} from "@cryptoalgebra/core/interfaces/IAlgebraPool.sol";
// import {AlgebraBasePluginV3} from "@reflex/integrations/algebra/full/AlgebraBasePluginV3.sol";
// import {IFundsSplitter} from "@reflex/integrations/FundsSplitter/IFundsSplitter.sol";
// import {IReflexRouter} from "@reflex/interfaces/IReflexRouter.sol";
// import "@reflex/../test/utils/SwapSimulationTest.sol";

// interface IAlgebraBaseV3Plugin {
//     function initializePlugin() external;
// }

// contract HxSwapSimulationSpecs is SwapSimulationTest {
//     using stdJson for string;

//     address ownerEOA = address(0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38);
//     address profitShareHolder1 = 0x4069c99e708b9395c7A519f97F7c09644f1B471C;
//     address profitShareHolder2 = 0xFF9FD2d95d8959C8C6f0ca88D32eCFB89aF6D546;
//     address reflexRouterAddress = 0x0189D64B45f88380F8d2247963F8c571110Cc33b; // Reflex Router on hyperliquid-evm
//     address algebraPoolFactoryOwner = 0xFF9FD2d95d8959C8C6f0ca88D32eCFB89aF6D546; // Pool factory owner, needed to set plugin
//     string internal constant RPC_URL = "https://rpc.hypurrscan.io";

//     function setUp() public {}

//     function setUpPoolFromScratch(address poolAddress) public {
//         // Deploy the AlgebraBasePluginV3 plugin
//         vm.createSelectFork(RPC_URL);
//         address factoryAddress = IAlgebraPool(poolAddress).factory();
//         address pluginFactoryAddress = address(0x772452bF8437831A5B879aA860C7EB0ae180929E); // Mock plugin factory for testing
//         uint16 baseFee = 3000; // 3% base fee
//         vm.startPrank(algebraPoolFactoryOwner);

//         AlgebraBasePluginV3 plugin =
//             new AlgebraBasePluginV3(poolAddress, factoryAddress, pluginFactoryAddress, baseFee, reflexRouterAddress);
//         IAlgebraPool(poolAddress).setPlugin(address(plugin));
//         vm.stopPrank();
//         // vm.startPrank(poolAddress);
//         (, int24 tick,,,,) = IAlgebraPool(poolAddress).globalState();
//         plugin.initializePlugin();
//         // vm.stopPrank();
//         address reflexAdmin = IReflexRouter(reflexRouterAddress).getReflexAdmin();
//         vm.startPrank(reflexAdmin);
//         address[] memory shareHolders = new address[](2);
//         shareHolders[0] = profitShareHolder1;
//         shareHolders[1] = profitShareHolder2;
//         uint256[] memory shares = new uint256[](2);
//         shares[0] = 5000;
//         shares[1] = 5000;
//         // TODO: Fund splitting functionality has been moved to ConfigurableRevenueDistributor
//         // IFundsSplitter(plugin).updateShares(shareHolders, shares);
//         vm.stopPrank();
//     }

//     function setUpPool(address poolAddress) public {
//         // Deploy the AlgebraBasePluginV3 plugin
//         vm.createSelectFork(RPC_URL);
//         // vm.startPrank(algebraPoolFactoryOwner);
//         // IAlgebraPool(poolAddress).setPlugin(0xbFCc47af8E20A6D9a5ec468923f80F6Bd60b7382);
//         // IAlgebraBaseV3Plugin(0xbFCc47af8E20A6D9a5ec468923f80F6Bd60b7382).initializePlugin();
//         // vm.stopPrank();
//     }

//     /**
//      * Test backrun validation for a specific cache entry
//      */
//     function executeFlow(address pool, uint8 assetId, uint256 amountIn)
//         external
//         returns (uint256 profit, address profitToken)
//     {
//         setUpPool(pool);
//         {
//             // Get pool tokens for funding

//             address token0 = IAlgebraPool(pool).token0();
//             address token1 = IAlgebraPool(pool).token1();
//             address tokenIn = assetId == 0 ? token0 : token1;
//             address trader = address(this);
//             // Fund the trader with enough tokens
//             uint256 fundingAmount = uint256(amountIn) * 10; // Fund with 10x the swap amount
//             fundTrader(tokenIn, trader, pool, fundingAmount);

//             // Record logs to capture event data
//             vm.recordLogs();

//             // Execute the trigger swap
//             simulateSwapV3(pool, trader, tokenIn, int256(amountIn), assetId == 0);
//         }

//         // Get the recorded logs
//         Vm.Log[] memory logs = vm.getRecordedLogs();

//         // // Find and parse the BackrunExecuted event
//         for (uint256 i = 0; i < logs.length; i++) {
//             if (
//                 logs[i].emitter == reflexRouterAddress
//                     && logs[i].topics[0] == keccak256("BackrunExecuted(bytes32,uint112,bool,uint256,address,address)")
//             ) {
//                 // Parse event data
//                 bytes32 actualTriggerPoolId = logs[i].topics[1];
//                 address actualRecipient = address(uint160(uint256(logs[i].topics[2])));

//                 // Decode non-indexed parameters
//                 (uint112 actualSwapAmountIn, bool actualToken0In, uint256 actualProfit, address actualProfitToken) =
//                     abi.decode(logs[i].data, (uint112, bool, uint256, address));

//                 // Log the actual values
//                 console.log("=== BackrunExecuted Event ===");
//                 console.log("Trigger Pool ID:", vm.toString(actualTriggerPoolId));
//                 console.log("Swap Amount In:", actualSwapAmountIn);
//                 console.log("Token0 In:", actualToken0In);
//                 console.log("Profit:", actualProfit);
//                 console.log("Profit Token:", actualProfitToken);
//                 console.log("Recipient:", actualRecipient);

//                 // Return the actual profit values
//                 profit = actualProfit;
//                 profitToken = actualProfitToken;
//                 assertEq(
//                     IERC20(actualProfitToken).balanceOf(profitShareHolder1), actualProfit / 2, "Profit balance mismatch"
//                 );
//                 assertEq(
//                     IERC20(actualProfitToken).balanceOf(profitShareHolder2), actualProfit / 2, "Profit balance mismatch"
//                 );

//                 // // Verify expected values
//                 // assertEq(actualTriggerPoolId, pool, "Trigger pool ID mismatch");
//                 // assertEq(actualSwapAmountIn, amountIn, "Swap amount mismatch");
//                 // assertEq(actualToken0In, assetId == 0, "Token0In flag mismatch");

//                 break;
//             }
//         }
//     }

//     function testPool0xE9f6862A346F4DbA5e001A372366A2aE360360d1Asset0Input_62258704853291671() public {
//         this.executeFlow(0xE9f6862A346F4DbA5e001A372366A2aE360360d1, 0, 62258704853291671);
//     }

//     function testPool0xE9f6862A346F4DbA5e001A372366A2aE360360d1Asset0Input_1000000000000000000000() public {
//         this.executeFlow(0xE9f6862A346F4DbA5e001A372366A2aE360360d1, 0, 1000000000000000000000);
//         require(false, "Test completed");
//     }

//     function testPool0xE9f6862A346F4DbA5e001A372366A2aE360360d1Asset1Input_10000000() public {
//         this.executeFlow(0xE9f6862A346F4DbA5e001A372366A2aE360360d1, 1, 10000000);
//     }

//     function testPool0xE9f6862A346F4DbA5e001A372366A2aE360360d1Asset1Input_1000000000() public {
//         this.executeFlow(0xE9f6862A346F4DbA5e001A372366A2aE360360d1, 1, 1000000000);
//     }

//     function testPool0xE9f6862A346F4DbA5e001A372366A2aE360360d1Asset1Input_10000000000() public {
//         this.executeFlow(0xE9f6862A346F4DbA5e001A372366A2aE360360d1, 1, 10000000000);
//     }

//     function testPool0xE9f6862A346F4DbA5e001A372366A2aE360360d1Asset1Input_50000000000() public {
//         this.executeFlow(0xE9f6862A346F4DbA5e001A372366A2aE360360d1, 1, 50000000000);
//     }
// }
