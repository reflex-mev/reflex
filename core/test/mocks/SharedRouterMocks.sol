// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/interfaces/IReflexQuoter.sol";
import "./MockToken.sol";

// Shared mock quoter that provides consistent quote calculations
contract SharedMockQuoter is IReflexQuoter {
    struct RouteConfig {
        uint256 profit;
        address[] pools;
        uint8[] dexTypes;
        uint8[] dexMeta;
        address[] tokens;
        uint256[] amounts;
        uint256 initialHopIndex;
        bool exists;
    }

    mapping(bytes32 => RouteConfig) public routes;
    bool public shouldRevert;

    function setQuote(
        address pool,
        uint8 assetId,
        uint256 swapAmountIn,
        uint256 profit,
        SwapDecodedData memory decoded,
        uint256[] memory amountsOut,
        uint256 initialHopIndex
    ) external {
        bytes32 key = keccak256(abi.encodePacked(pool, assetId, swapAmountIn));
        routes[key] = RouteConfig({
            profit: profit,
            pools: decoded.pools,
            dexTypes: decoded.dexType,
            dexMeta: decoded.dexMeta,
            tokens: decoded.tokens,
            amounts: amountsOut,
            initialHopIndex: initialHopIndex,
            exists: true
        });
    }

    function addRoute(
        address pool,
        uint8 assetId,
        uint256 swapAmountIn,
        uint256 profit,
        address[] memory pools,
        uint8[] memory dexTypes,
        uint8[] memory dexMeta,
        address[] memory tokens,
        uint256[] memory amounts,
        uint256 initialHopIndex
    ) external {
        bytes32 key = keccak256(abi.encodePacked(pool, assetId, swapAmountIn));
        routes[key] = RouteConfig({
            profit: profit,
            pools: pools,
            dexTypes: dexTypes,
            dexMeta: dexMeta,
            tokens: tokens,
            amounts: amounts,
            initialHopIndex: initialHopIndex,
            exists: true
        });
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function getQuote(address pool, uint8 assetId, uint256 swapAmountIn)
        external
        view
        override
        returns (uint256 profit, SwapDecodedData memory decoded, uint256[] memory amountsOut, uint256 initialHopIndex)
    {
        if (shouldRevert) revert("MockReflexQuoter: forced revert");

        bytes32 key = keccak256(abi.encodePacked(pool, assetId, swapAmountIn));
        RouteConfig memory route = routes[key];

        if (!route.exists) {
            return (
                0,
                SwapDecodedData({
                    pools: new address[](0),
                    dexType: new uint8[](0),
                    dexMeta: new uint8[](0),
                    amount: 0,
                    tokens: new address[](0)
                }),
                new uint256[](0),
                0
            );
        }

        return (
            route.profit,
            SwapDecodedData({
                pools: route.pools,
                dexType: route.dexTypes,
                dexMeta: route.dexMeta,
                amount: uint112(swapAmountIn),
                tokens: route.tokens
            }),
            route.amounts,
            route.initialHopIndex
        );
    }
}

// Shared Mock V2 Pool - complete implementation
contract SharedMockV2Pool {
    address public token0;
    address public token1;
    bool public shouldRevert;
    bytes public lastCallData;
    uint256 public reserve0;
    uint256 public reserve1;

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function setReserves(uint256 _reserve0, uint256 _reserve1) external {
        reserve0 = _reserve0;
        reserve1 = _reserve1;
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external virtual {
        if (shouldRevert) revert("SharedMockV2Pool: forced revert");
        lastCallData = data;

        // Give tokens to recipient
        if (amount0Out > 0) {
            MockToken(token0).mint(to, amount0Out);
        }
        if (amount1Out > 0) {
            MockToken(token1).mint(to, amount1Out);
        }

        // Call back if data provided
        if (data.length > 0) {
            bytes memory callData =
                abi.encodeWithSignature("uniswapV2Callback(uint256,uint256,bytes)", amount0Out, amount1Out, data);
            (bool success,) = msg.sender.call(callData);
            require(success, "Callback failed");
        }
    }

    function swap(uint256 amount0Out, uint256 amount1Out, address to) external {
        this.swap(amount0Out, amount1Out, to, "");
    }
}

// Shared V3 pool mock that provides realistic swap calculations
contract SharedMockV3Pool {
    address public token0;
    address public token1;
    uint256 public fee = 997; // 0.3% fee (997/1000)
    bool public shouldRevert;
    bytes public lastCallData;
    uint256 public price = 1050000000000000000; // 1.05 default price

    constructor(address _token0, address _token1) {
        token0 = _token0;
        token1 = _token1;
    }

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function setFee(uint256 _fee) external {
        fee = _fee;
    }

    function setPrice(uint256 _price) external {
        price = _price;
    }

    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1) {
        if (shouldRevert) revert("SharedMockV3Pool: forced revert");
        lastCallData = data;

        uint256 amountIn = uint256(amountSpecified);

        // Use 110% instead of fee to create profitable arbitrage opportunities
        if (zeroForOne) {
            amount0 = amountSpecified;
            uint256 amountOut = amountIn * 110 / 100; // 10% bonus for arbitrage
            amount1 = -int256(amountOut);
            MockToken(token1).mint(recipient, amountOut);
        } else {
            amount1 = amountSpecified;
            uint256 amountOut = amountIn * 110 / 100; // 10% bonus for arbitrage
            amount0 = -int256(amountOut);
            MockToken(token0).mint(recipient, amountOut);
        }

        // Callback
        if (data.length > 0) {
            bytes memory callData =
                abi.encodeWithSignature("uniswapV3SwapCallback(int256,int256,bytes)", amount0, amount1, data);
            (bool success,) = msg.sender.call(callData);
            require(success, "Callback failed");
        }
    }
}

// Helper library for setting up test scenarios
library RouterTestHelper {
    function calculateRealisticProfit(uint256 swapAmount, uint256 fee1, uint256 fee2)
        internal
        pure
        returns (uint256 profit, uint256[] memory amounts)
    {
        // Calculate realistic amounts based on fees
        amounts = new uint256[](3);
        amounts[0] = swapAmount;
        amounts[1] = swapAmount * fee1 / 1000; // First swap with fee
        amounts[2] = amounts[1] * fee2 / 1000; // Second swap with fee

        // Calculate profit (can be negative)
        if (amounts[2] > amounts[0]) {
            profit = amounts[2] - amounts[0];
        } else {
            profit = 0; // No profit if amount is less
        }
    }

    function setupProfitableRoute(uint256 swapAmount)
        internal
        pure
        returns (uint256 profit, uint256[] memory amounts)
    {
        // Setup a profitable route with realistic but favorable rates
        amounts = new uint256[](3);
        amounts[0] = swapAmount;
        amounts[1] = swapAmount * 98 / 100; // 2% slippage on first swap
        amounts[2] = amounts[1] * 105 / 100; // 5% bonus on second swap (arbitrage opportunity)

        profit = amounts[2] - amounts[0]; // Should be positive
    }
}
