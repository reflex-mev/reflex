/**
 * Type definitions for UniversalIntegration SDK
 */

/**
 * Metadata about the swap transaction
 */
export interface SwapMetadata {
  /** Hex-encoded calldata for the target DEX router */
  swapTxCallData: string;
  /** Address of input token */
  tokenIn: string;
  /** Amount of input token (full swap amount) */
  amountIn: bigint;
  /** Address of output token */
  tokenOut: string;
  /** Address to receive swap output and MEV profits */
  recipient: string;
}

/**
 * Configuration for a single backrun operation
 */
export interface BackrunParams {
  /** Address of the pool being traded on */
  triggerPoolId: string;
  /** Full swap amount (same as SwapMetadata.amountIn) */
  swapAmountIn: bigint;
  /** Swap direction (true = token0→token1, false = token1→token0) */
  token0In: boolean;
  /** Address to receive MEV profits */
  recipient: string;
  /** Configuration ID (use ethers.ZeroHash for default) */
  configId: string;
}

/**
 * Token approval parameters
 */
export interface TokenApproval {
  /** Address of token to approve */
  tokenAddress: string;
  /** Amount to approve */
  amount: bigint;
}

/**
 * Result of a swap with backrun operation
 */
export interface SwapWithBackrunResult {
  /** Transaction hash */
  transactionHash: string;
  /** Block number where tx was mined */
  blockNumber: number;
  /** Actual gas used */
  gasUsed: bigint;
  /** Return data from DEX swap call */
  swapReturnData: string;
  /** MEV profits captured (one per backrun) */
  profits: bigint[];
  /** Token addresses for each profit */
  profitTokens: string[];
}
