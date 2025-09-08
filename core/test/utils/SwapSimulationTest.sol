// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.20;

import "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IUniswapV2Pair {
    function token0() external view returns (address);

    function token1() external view returns (address);

    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
}

interface IUniswapV3Pool {
    function swap(address recipient, bool zeroForOne, int256 amount, uint160 sqrtPriceLimitX96, bytes calldata data)
        external
        returns (int256 amount0, int256 amount1);
}

/**
 * @dev Utility contract to simulate Uniswap V2 & V3 swaps in Forge tests.
 */
abstract contract SwapSimulationTest is Test {
    address internal _expectedToken;
    address internal _callbackSender;

    /// @dev The minimum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MIN_TICK)
    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    /// @dev The maximum value that can be returned from #getSqrtRatioAtTick. Equivalent to getSqrtRatioAtTick(MAX_TICK)
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    /**
     * @notice Fund a trader with tokens and approve a pool.
     */
    function fundTrader(address token, address trader, address spender, uint256 amount) internal {
        deal(token, trader, amount);
        vm.prank(trader);
        IERC20(token).approve(spender, type(uint256).max);
    }

    /**
     * @notice Simulate a Uniswap V3 swap with fallback callback logic.
     */
    function simulateSwapV3(address pool, address trader, address tokenIn, int256 amountIn, bool zeroForOne) internal {
        // Set state for fallback
        _expectedToken = tokenIn;
        _callbackSender = pool;

        vm.startPrank(trader);

        bytes memory data = abi.encode(tokenIn); // optional, unused in fallback here
        uint160 sqrtPriceLimitX96 = zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1;
        IUniswapV3Pool(pool).swap(trader, zeroForOne, amountIn, sqrtPriceLimitX96, data);
        vm.stopPrank();

        _expectedToken = address(0);
        _callbackSender = address(0);
    }

    /**
     * @notice Simulate a Uniswap V3 swap with fallback callback logic.
     */
    function simulateSwapV3Out(address pool, address trader, address tokenIn, int256 amountOut, bool zeroForOne)
        internal
    {
        // Set state for fallback
        _expectedToken = tokenIn;
        _callbackSender = pool;

        vm.startPrank(trader);

        bytes memory data = abi.encode(tokenIn); // optional, unused in fallback here
        uint160 sqrtPriceLimitX96 = zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1;
        IUniswapV3Pool(pool).swap(trader, zeroForOne, amountOut, sqrtPriceLimitX96, data);
        vm.stopPrank();

        _expectedToken = address(0);
        _callbackSender = address(0);
    }

    /**
     * @notice Simulate a Uniswap V2 swap with unified params (like V3).
     */
    function simulateSwapV2(address pair, address trader, address tokenIn, int256 amountSpecified, bool zeroForOne)
        internal
    {
        IUniswapV2Pair pool = IUniswapV2Pair(pair);
        address token0 = pool.token0();
        address token1 = pool.token1();

        address tokenOut = zeroForOne ? token1 : token0;

        // Only support positive amountSpecified for V2 (amountIn)
        uint256 amountIn = uint256(amountSpecified);

        // Fund pair
        deal(tokenIn, trader, amountIn);
        vm.prank(trader);
        IERC20(tokenIn).transfer(pair, amountIn);

        uint256 amountOut = 1; // Placeholder, as before

        vm.prank(trader);
        pool.swap(zeroForOne ? 0 : amountOut, zeroForOne ? amountOut : 0, trader, "");
    }

    /**
     * @dev Generic fallback handler to mimic Uniswap V3 swap callback.
     */
    fallback() external payable {
        // Parse calldata manually
        (int256 amount0, int256 amount1,) = abi.decode(msg.data[4:], (int256, int256, address));
        console.log("Swap simulation callback called with amount0", amount0);
        console.log("Swap simulation callback called with amount1", amount1);
        uint256 amountToPay = uint256(amount0 > 0 ? amount0 : amount1);
        console.log("Swap simulation paying back to pool:", amountToPay);
        IERC20(_expectedToken).transfer(_callbackSender, amountToPay);
    }

    receive() external payable {}
}
