/**
 * Core type definitions for the Reflex Trading Agent
 */

/**
 * Uniswap V3 swap event data with calculated slippage
 */
export interface SwapEventData {
  poolAddress: string;
  blockNumber: number;
  timestamp: number;
  sender: string;
  recipient: string;
  amount0: bigint;
  amount1: bigint;
  sqrtPriceX96: bigint;
  liquidity: bigint;
  tick: number;
  token0Address: string;
  token1Address: string;
  feeTier: number; // 500, 3000, 10000 (0.05%, 0.3%, 1%)
  txHash: string;
  
  // Slippage Analysis
  effectiveSlippagePercent: number;
  priceImpactPercent: number;
  zeroForOne: boolean; // Swap direction
}

/**
 * Pool metadata (tokens, fee tier, etc.)
 */
export interface PoolMetadata {
  poolAddress: string;
  token0: string;
  token1: string;
  fee: number;
  token0Symbol: string;
  token1Symbol: string;
  token0Decimals: number;
  token1Decimals: number;
}

/**
 * Pool statistics and opportunity metrics
 */
export interface PoolStatistics {
  poolAddress: string;
  poolId: string; // bytes32 for Reflex Router
  
  // Volume metrics
  swapCount: number;
  totalVolumeUSD: number;
  avgSwapSizeUSD: number;
  largestSwapUSD: number;
  
  // Slippage metrics
  avgSlippage: number;
  maxSlippage: number;
  highSlippageCount: number;
  
  // Direction bias
  zeroForOneCount: number;
  oneForZeroCount: number;
  directionBias: number; // -1 to 1
  
  // Volatility
  priceVolatility: number;
  
  // Opportunity metrics
  opportunityScore: number; // 0-100
  recommendedAmount: bigint;
  recommendedDirection: boolean; // token0In
  
  // Metadata
  lastUpdateBlock: number;
  firstSeenBlock: number;
}

/**
 * Backrun execution result
 */
export interface BackrunResult {
  success: boolean;
  txHash: string;
  profit: bigint;
  profitToken: string;
  gasUsed: bigint;
  executionTime: number;
  error?: string;
}

/**
 * Gas price strategy
 */
export interface GasPriceStrategy {
  gasPrice?: bigint;
  maxFeePerGas?: bigint;
  maxPriorityFeePerGas?: bigint;
  strategy: 'aggressive' | 'normal' | 'conservative';
}
