import { Q96 } from '../constants/uniswapV3';

/**
 * Calculate effective slippage from a Uniswap V3 swap
 * 
 * @param amount0 - Amount of token0 (negative if sold, positive if bought)
 * @param amount1 - Amount of token1 (negative if sold, positive if bought)
 * @param sqrtPriceX96Before - sqrtPriceX96 before the swap
 * @param sqrtPriceX96After - sqrtPriceX96 after the swap
 * @param zeroForOne - True if swapping token0 for token1
 * @returns Slippage percentage (always positive)
 */
export function calculateSlippage(
  amount0: bigint,
  amount1: bigint,
  sqrtPriceX96Before: bigint,
  sqrtPriceX96After: bigint,
  zeroForOne: boolean
): number {
  try {
    // Calculate effective price from the swap
    // Price = amount1 / amount0 (how much token1 per token0)
    const amount0Abs = amount0 < 0n ? -amount0 : amount0;
    const amount1Abs = amount1 < 0n ? -amount1 : amount1;
    
    if (amount0Abs === 0n || amount1Abs === 0n) {
      return 0;
    }
    
    // Convert to numbers for calculation (may lose precision for very large amounts)
    const effectivePrice = Number(amount1Abs) / Number(amount0Abs);
    
    // Calculate expected price from sqrtPriceX96Before
    // Price = (sqrtPriceX96 / 2^96)^2 = sqrtPriceX96^2 / 2^192
    const priceBefore = Number(sqrtPriceX96Before * sqrtPriceX96Before) / Number(Q96 * Q96);
    
    // Slippage = abs((effectivePrice - expectedPrice) / expectedPrice) * 100
    const slippage = Math.abs((effectivePrice - priceBefore) / priceBefore) * 100;
    
    // Cap at 100% to avoid unrealistic values
    return Math.min(slippage, 100);
  } catch (error) {
    // If calculation fails, return 0
    return 0;
  }
}

/**
 * Calculate price impact from sqrtPrice change
 * 
 * @param sqrtPriceX96Before - sqrtPriceX96 before the swap
 * @param sqrtPriceX96After - sqrtPriceX96 after the swap
 * @returns Price impact percentage (always positive)
 */
export function calculatePriceImpact(
  sqrtPriceX96Before: bigint,
  sqrtPriceX96After: bigint
): number {
  try {
    const priceBefore = Number(sqrtPriceX96Before * sqrtPriceX96Before) / Number(Q96 * Q96);
    const priceAfter = Number(sqrtPriceX96After * sqrtPriceX96After) / Number(Q96 * Q96);
    
    const priceImpact = Math.abs((priceAfter - priceBefore) / priceBefore) * 100;
    
    return Math.min(priceImpact, 100);
  } catch (error) {
    return 0;
  }
}

/**
 * Determine swap direction from amounts
 * 
 * @param amount0 - Amount of token0
 * @param amount1 - Amount of token1
 * @returns True if swapping token0 for token1 (zeroForOne)
 */
export function getSwapDirection(amount0: bigint, amount1: bigint): boolean {
  // If amount0 is negative, token0 is being sold (zeroForOne = true)
  // If amount1 is negative, token1 is being sold (zeroForOne = false)
  return amount0 < 0n;
}
