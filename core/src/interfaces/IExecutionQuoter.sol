// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.7.6;
pragma abicoder v2;

/**
 * @title IExecutionQuoter
 * @notice Interface for the ExecutionQuoter contract that provides price quotes and arbitrage route calculations
 * @dev This interface defines the contract responsible for analyzing potential arbitrage opportunities
 * and generating the necessary swap data for profitable trades across different DEX protocols
 */
interface IExecutionQuoter {
    /**
     * @notice Data structure containing decoded swap route information
     * @dev This struct encapsulates all the necessary information to execute a multi-hop arbitrage swap
     * @param pools Array of pool addresses to swap through in the arbitrage route
     * @param dexType Array indicating the DEX protocol type for each pool (e.g., UniswapV2, UniswapV3, etc.)
     * @param dexMeta Array containing additional metadata for each DEX interaction
     * @param amount The amount of tokens to use in the arbitrage trade
     * @param tokens Array of token addresses involved in the swap route
     */
    struct SwapDecodedData {
        address[] pools; // Pool addresses for each hop in the swap route
        uint8[] dexType; // DEX type identifiers (UniswapV2=1, UniswapV3=2, etc.)
        uint8[] dexMeta; // Additional DEX-specific metadata
        uint112 amount; // Amount to swap (fits in 112 bits for gas efficiency)
        address[] tokens; // Token addresses in the swap path
    }

    /**
     * @notice Calculate arbitrage profit and generate swap route data for a given pool and asset
     * @dev This function analyzes potential arbitrage opportunities by comparing prices across
     * different DEX protocols and returns the optimal swap route if profitable
     * @param pool The address of the pool that triggered the arbitrage opportunity
     * @param assetId Identifier for the asset to arbitrage (0 for token0, 1 for token1)
     * @param swapAmountIn The amount of input tokens to use for the arbitrage calculation
     * @return profit The expected profit from executing the arbitrage (in wei)
     * @return decoded Structured data containing the complete swap route information
     * @return amountsOut Array of expected output amounts for each hop in the swap route
     * @return initialHopIndex Index indicating which hop in the route should be executed first
     */
    function getQuote(address pool, uint8 assetId, uint256 swapAmountIn)
        external
        view
        returns (uint256 profit, SwapDecodedData memory decoded, uint256[] memory amountsOut, uint256 initialHopIndex);
}
