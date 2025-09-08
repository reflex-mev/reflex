import { BigNumberish, BytesLike } from "ethers";

/**
 * Parameters for executing arbitrary calldata before a backrun
 */
export interface ExecuteParams {
  /** Target contract address to call */
  target: string;
  /** ETH value to send with the call (in wei) */
  value: bigint;
  /** Encoded calldata to execute */
  callData: BytesLike;
}

/**
 * Parameters for triggering a backrun arbitrage
 */
export interface BackrunParams {
  /** Unique identifier of the pool that triggered the backrun opportunity */
  triggerPoolId: string;
  /** Amount of tokens to use as input for the arbitrage swap */
  swapAmountIn: BigNumberish;
  /** Whether to use token0 (true) or token1 (false) as the input token */
  token0In: boolean;
  /** Address that will receive the arbitrage profit */
  recipient: string;
}

/**
 * Result of a backruned execute operation
 */
export interface BackrunedExecuteResult {
  /** Whether the initial call was successful */
  success: boolean;
  /** Return data from the initial call */
  returnData: string;
  /** Array of profits generated from each arbitrage */
  profits: bigint[];
  /** Array of token addresses in which profits were generated */
  profitTokens: string[];
  /** Transaction hash */
  transactionHash: string;
}

/**
 * Configuration for the Reflex SDK
 */
export interface ReflexConfig {
  /** Address of the deployed Reflex Router contract */
  routerAddress: string;
  /** Optional address of the Reflex Quoter contract */
  quoterAddress?: string;
  /** Default gas limit for transactions (default: 500000) */
  defaultGasLimit?: bigint;
  /** Multiplier for gas price estimation (default: 1.1) */
  gasPriceMultiplier?: number;
}

/**
 * Transaction options for gas and fee configuration
 */
export interface TransactionOptions {
  /** Gas limit for the transaction */
  gasLimit?: bigint;
  /** Gas price for legacy transactions */
  gasPrice?: bigint;
  /** Maximum fee per gas for EIP-1559 transactions */
  maxFeePerGas?: bigint;
  /** Maximum priority fee per gas for EIP-1559 transactions */
  maxPriorityFeePerGas?: bigint;
  /** Transaction nonce */
  nonce?: number;
}

/**
 * Event emitted when a backrun is executed
 */
export interface BackrunExecutedEvent {
  /** Pool ID that triggered the backrun */
  triggerPoolId: string;
  /** Input swap amount */
  swapAmountIn: bigint;
  /** Whether token0 was used as input */
  token0In: boolean;
  /** Profit amount generated */
  profit: bigint;
  /** Token address in which profit was generated */
  profitToken: string;
  /** Address that received the profit */
  recipient: string;
}
