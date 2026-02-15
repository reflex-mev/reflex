// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

import {console} from "forge-std/console.sol";
import {Script} from "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

import {ICLPoolManager} from "infinity-core/src/pool-cl/interfaces/ICLPoolManager.sol";
import {IHooks} from "infinity-core/src/interfaces/IHooks.sol";
import {PoolKey} from "infinity-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "infinity-core/src/types/Currency.sol";
import {CLPoolParametersHelper} from "infinity-core/src/pool-cl/libraries/CLPoolParametersHelper.sol";
import {LPFeeLibrary} from "infinity-core/src/libraries/LPFeeLibrary.sol";
import {TickMath} from "infinity-core/src/pool-cl/libraries/TickMath.sol";

import {ICLPositionManager} from "infinity-periphery/src/pool-cl/interfaces/ICLPositionManager.sol";
import {IMulticall} from "infinity-periphery/src/interfaces/IMulticall.sol";
import {Actions} from "infinity-periphery/src/libraries/Actions.sol";
import {LiquidityAmounts} from "infinity-periphery/src/pool-cl/libraries/LiquidityAmounts.sol";

import {PancakeSwapInfinityHook} from "@reflex/integrations/plugin/pancakeswap_infinity/PancakeSwapInfinityHook.sol";

/**
 * @title DeployHookAndCreatePool
 * @notice Combined script: deploys PancakeSwapInfinityHook, creates a BNB/USDT pool, and adds initial liquidity.
 *
 * Run with:
 *   forge script script/pancakeswap_infinity/DeployHookAndCreatePool.s.sol \
 *     --rpc-url https://bsc-dataseed.binance.org/ \
 *     --private-key <PRIVATE_KEY> \
 *     --broadcast
 *
 * Environment Variables (Optional — all have BSC Mainnet defaults):
 * - BNB_PRICE_USDT: BNB price in USDT (default: 634). Used for starting pool price.
 * - USDT_AMOUNT: USDT liquidity to add (default: 10e18 = 10 USDT)
 * - TICK_SPACING: Tick spacing (default: 10)
 * - CONFIG_ID: Reflex config ID (default: bytes32(0))
 */
contract DeployHookAndCreatePool is Script {
    using CurrencyLibrary for Currency;

    // ========== BSC Mainnet Addresses ==========
    ICLPoolManager constant CL_POOL_MANAGER = ICLPoolManager(0xa0FfB9c1CE1Fe56963B0321B32E7A0302114058b);
    ICLPositionManager constant CL_POSITION_MANAGER = ICLPositionManager(0x55f4c8abA71A1e923edC303eb4fEfF14608cC226);
    address constant PERMIT2 = 0x31c2F6fcFf4F8759b3Bd5Bf0e1084A055615c768;
    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant REFLEX_ROUTER = 0xDc90e57577D95a2209dfb57F850b03C7ce36ecB2;

    // ========== Pool Currencies (sorted: address(0) < USDT) ==========
    Currency constant CURRENCY0 = Currency.wrap(address(0)); // Native BNB
    Currency constant CURRENCY1 = Currency.wrap(USDT);

    // ========== Configurable Parameters ==========
    uint256 public bnbPriceUsdt;
    uint256 public usdtAmount;
    int24 public tickSpacing;
    bytes32 public configId;

    // ========== Deployed Contracts ==========
    PancakeSwapInfinityHook public hook;

    function setUp() public {
        try vm.envUint("BNB_PRICE_USDT") returns (uint256 price) {
            bnbPriceUsdt = price;
        } catch {
            bnbPriceUsdt = 634;
        }

        try vm.envUint("USDT_AMOUNT") returns (uint256 amt) {
            usdtAmount = amt;
        } catch {
            usdtAmount = 10e18; // 10 USDT
        }

        try vm.envInt("TICK_SPACING") returns (int256 ts) {
            tickSpacing = int24(ts);
        } catch {
            tickSpacing = 10;
        }

        try vm.envBytes32("CONFIG_ID") returns (bytes32 cid) {
            configId = cid;
        } catch {
            configId = bytes32(0);
        }
    }

    function run() external {
        address deployer = msg.sender;

        // Compute pricing
        uint160 startingPrice = _computeSqrtPriceX96(bnbPriceUsdt);
        uint256 bnbAmount = usdtAmount / bnbPriceUsdt;

        console.log("=== PancakeSwap Infinity: Deploy Hook + Create BNB/USDT Pool ===");
        console.log("Deployer:", deployer);
        console.log("Chain ID:", block.chainid);
        console.log("");
        console.log("Parameters:");
        console.log("- BNB price (USDT):", bnbPriceUsdt);
        console.log("- USDT amount:", usdtAmount / 1e18, "USDT");
        console.log("- BNB amount:", bnbAmount / 1e15, "* 1e-3 BNB");
        console.log("- Starting sqrtPriceX96:", uint256(startingPrice));
        console.log("- Tick spacing:", uint256(int256(tickSpacing)));
        console.log("");

        vm.startBroadcast();

        // ===== Step 1: Deploy Hook =====
        console.log("--- Step 1: Deploying PancakeSwapInfinityHook ---");
        hook = new PancakeSwapInfinityHook(CL_POOL_MANAGER, REFLEX_ROUTER, configId, deployer, WBNB);
        console.log("Hook deployed at:", address(hook));
        console.log("Hook bitmap:", hook.getHooksRegistrationBitmap());

        // ===== Step 2: Build Pool Key =====
        PoolKey memory poolKey = _buildPoolKey();
        console.log("\n--- Step 2: Pool Key Built ---");

        // ===== Step 3: Approve USDT via Permit2 =====
        console.log("\n--- Step 3: Token Approvals ---");
        IERC20(USDT).approve(PERMIT2, type(uint256).max);
        (bool ok,) = PERMIT2.call(
            abi.encodeWithSignature(
                "approve(address,address,uint160,uint48)",
                USDT,
                address(CL_POSITION_MANAGER),
                type(uint160).max,
                type(uint48).max
            )
        );
        require(ok, "Permit2 approve failed");

        // ===== Step 4: Initialize Pool + Add Liquidity via Multicall =====
        console.log("\n--- Step 4: Initialize Pool + Add Liquidity ---");
        bytes[] memory multicallParams = _buildMulticallParams(poolKey, startingPrice, bnbAmount);

        // Send BNB as msg.value for native currency settlement
        uint256 valueToPass = bnbAmount + 1;
        IMulticall(address(CL_POSITION_MANAGER)).multicall{value: valueToPass}(multicallParams);

        vm.stopBroadcast();

        // ===== Summary =====
        console.log("\n=== Deployment Complete ===");
        console.log("Hook:", address(hook));
        console.log("Pool: BNB/USDT");
        console.log("  currency0: BNB (native)");
        console.log("  currency1: USDT", USDT);
        console.log("  fee: DYNAMIC_FEE_FLAG");
        console.log("  tickSpacing:", uint256(int256(tickSpacing)));
        console.log("  hook:", address(hook));
        console.log("Reflex Router:", REFLEX_ROUTER);
        console.log("Config ID:", vm.toString(configId));
        console.log("");
        console.log("Next: Set HOOK_ADDRESS=", address(hook));
        console.log("Then run 03_Swap.s.sol to test the afterSwap callback");

        // Save deployment info
        _saveDeploymentInfo();
    }

    function _buildPoolKey() internal view returns (PoolKey memory) {
        bytes32 parameters = bytes32(uint256(hook.getHooksRegistrationBitmap()));
        parameters = CLPoolParametersHelper.setTickSpacing(parameters, tickSpacing);

        return PoolKey({
            currency0: CURRENCY0,
            currency1: CURRENCY1,
            hooks: IHooks(address(hook)),
            poolManager: CL_POOL_MANAGER,
            fee: uint24(LPFeeLibrary.DYNAMIC_FEE_FLAG),
            parameters: parameters
        });
    }

    function _buildMulticallParams(PoolKey memory poolKey, uint160 startingPrice, uint256 bnbAmount)
        internal
        view
        returns (bytes[] memory params)
    {
        int24 currentTick = TickMath.getTickAtSqrtRatio(startingPrice);
        int24 tickLower = _truncateTick(currentTick - 750 * tickSpacing, tickSpacing);
        int24 tickUpper = _truncateTick(currentTick + 750 * tickSpacing, tickSpacing);

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            startingPrice,
            TickMath.getSqrtRatioAtTick(tickLower),
            TickMath.getSqrtRatioAtTick(tickUpper),
            bnbAmount,
            usdtAmount
        );

        uint256 amount0Max = bnbAmount + 1;
        uint256 amount1Max = usdtAmount + 1;

        // Build mint actions: CL_MINT_POSITION + SETTLE_PAIR + SWEEP + SWEEP
        bytes memory actions = abi.encodePacked(
            uint8(Actions.CL_MINT_POSITION),
            uint8(Actions.SETTLE_PAIR),
            uint8(Actions.SWEEP),
            uint8(Actions.SWEEP)
        );

        address deployer = msg.sender;
        bytes[] memory mintParams = new bytes[](4);
        mintParams[0] = abi.encode(
            poolKey, tickLower, tickUpper, liquidity, amount0Max, amount1Max, deployer, new bytes(0)
        );
        mintParams[1] = abi.encode(poolKey.currency0, poolKey.currency1);
        mintParams[2] = abi.encode(poolKey.currency0, deployer);
        mintParams[3] = abi.encode(poolKey.currency1, deployer);

        params = new bytes[](2);
        params[0] = abi.encodeWithSelector(CL_POSITION_MANAGER.initializePool.selector, poolKey, startingPrice);
        params[1] = abi.encodeWithSelector(
            CL_POSITION_MANAGER.modifyLiquidities.selector,
            abi.encode(actions, mintParams),
            block.timestamp + 3600
        );
    }

    /// @notice Compute sqrtPriceX96 from a human-readable price (token1/token0)
    /// @dev Both tokens have 18 decimals, so raw price = human price
    ///      sqrtPriceX96 = sqrt(price) * 2^96 = sqrt(price * 2^192)
    function _computeSqrtPriceX96(uint256 price) internal pure returns (uint160) {
        return uint160(Math.sqrt(price << 192));
    }

    function _truncateTick(int24 tick, int24 ts) internal pure returns (int24) {
        return (tick / ts) * ts;
    }

    function _saveDeploymentInfo() internal {
        string memory deploymentInfo = string.concat(
            "{\n",
            '  "contract": "PancakeSwapInfinityHook",\n',
            '  "hook": "',
            vm.toString(address(hook)),
            '",\n',
            '  "pool": "BNB/USDT",\n',
            '  "clPoolManager": "',
            vm.toString(address(CL_POOL_MANAGER)),
            '",\n',
            '  "reflexRouter": "',
            vm.toString(REFLEX_ROUTER),
            '",\n',
            '  "wbnb": "',
            vm.toString(WBNB),
            '",\n',
            '  "usdt": "',
            vm.toString(USDT),
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
            "\n}\n"
        );

        string memory dirpath = "deployments";
        vm.createDir(dirpath, true);
        string memory filepath = string.concat(
            dirpath, "/deployment-pancakeswap-infinity-bnb-usdt-", vm.toString(block.chainid), ".json"
        );
        vm.writeFile(filepath, deploymentInfo);
        console.log("\nDeployment info saved to:", filepath);
    }
}
