import {
  Contract,
  Provider,
  Signer,
  ContractTransactionResponse,
  Overrides,
  TransactionReceipt,
  Interface,
} from 'ethers';
import { SWAP_PROXY_ABI, ERC20_ABI, REFLEX_ROUTER_ABI } from '../abi';
import {
  SwapMetadata,
  BackrunParams,
  TokenApproval,
  SwapWithBackrunResult,
} from './types';

/**
 * UniversalIntegration - SDK for integrating Reflex MEV capture with any DEX
 *
 * This class provides a TypeScript interface for the BackrunEnabledSwapProxy pattern,
 * enabling MEV capture on any DEX without requiring router modifications.
 *
 * @example
 * ```typescript
 * const integration = new UniversalIntegration(
 *   provider,
 *   signer,
 *   swapProxyAddress,
 *   reflexRouterAddress
 * );
 *
 * await integration.swapWithBackrun(
 *   swapCalldata,
 *   swapMetadata,
 *   backrunParams
 * );
 * ```
 */
export class UniversalIntegration {
  private provider: Provider;
  private signer: Signer;
  private swapProxyContract: Contract;
  private reflexRouterContract: Contract;
  private swapProxyAddress: string;
  private reflexRouterAddress: string;

  /**
   * Creates a new UniversalIntegration instance
   *
   * @param provider - Ethers provider for reading blockchain data
   * @param signer - Ethers signer for sending transactions
   * @param swapProxyAddress - Address of the BackrunEnabledSwapProxy contract
   * @param reflexRouterAddress - Address of the ReflexRouter contract
   */
  constructor(
    provider: Provider,
    signer: Signer,
    swapProxyAddress: string,
    reflexRouterAddress: string
  ) {
    this.provider = provider;
    this.signer = signer;
    this.swapProxyAddress = swapProxyAddress;
    this.reflexRouterAddress = reflexRouterAddress;

    this.swapProxyContract = new Contract(
      swapProxyAddress,
      SWAP_PROXY_ABI,
      this.signer
    );

    this.reflexRouterContract = new Contract(
      reflexRouterAddress,
      REFLEX_ROUTER_ABI,
      this.provider
    );
  }

  /**
   * Execute a swap through the target DEX with automatic MEV backrun capture
   *
   * @param swapTxCallData - Hex-encoded calldata for the target DEX router call
   * @param swapMetadata - Metadata about the swap transaction
   * @param backrunParams - Array of backrun configurations (supports multi-pool backruns)
   * @param overrides - Optional transaction overrides (gasLimit, maxFeePerGas, etc.)
   * @returns Promise with swap results and MEV profit information
   *
   * @example
   * ```typescript
   * const result = await integration.swapWithBackrun(
   *   swapCalldata,
   *   {
   *     swapTxCallData: swapCalldata,
   *     tokenIn: "0xTokenIn",
   *     amountIn: ethers.parseEther("1.0"),
   *     tokenOut: "0xTokenOut",
   *     recipient: userAddress
   *   },
   *   [{
   *     triggerPoolId: poolAddress,
   *     swapAmountIn: ethers.parseEther("1.0"),
   *     token0In: true,
   *     recipient: userAddress,
   *     configId: ethers.ZeroHash
   *   }],
   *   { gasLimit: 1500000n }
   * );
   * ```
   */
  async swapWithBackrun(
    swapTxCallData: string,
    swapMetadata: SwapMetadata,
    backrunParams: BackrunParams[],
    overrides?: Overrides
  ): Promise<SwapWithBackrunResult> {
    try {
      // Set default gas limit if not provided
      const txOptions: Overrides = overrides || {};
      if (!txOptions.gasLimit) {
        txOptions.gasLimit = await this.estimateGas(
          swapTxCallData,
          swapMetadata,
          backrunParams
        );
      }

      // Execute the swap with backrun transaction
      const tx: ContractTransactionResponse =
        await this.swapProxyContract.swapWithBackrun(
          swapTxCallData,
          swapMetadata,
          backrunParams,
          txOptions
        );

      // Wait for transaction receipt
      const receipt: TransactionReceipt | null = await tx.wait();
      if (!receipt || receipt.status !== 1) {
        throw new Error('Transaction failed');
      }

      // Parse the result from the transaction
      const result = await this.parseSwapWithBackrunResult(receipt);

      return {
        transactionHash: tx.hash,
        blockNumber: receipt.blockNumber,
        gasUsed: receipt.gasUsed,
        ...result,
      };
    } catch (error) {
      console.error('SwapWithBackrun failed:', error);
      throw error;
    }
  }

  /**
   * Approve tokens for spending by the SwapProxy contract
   *
   * @param approvals - Array of token approvals to execute
   * @returns Array of approval transaction receipts
   *
   * @example
   * ```typescript
   * // Approve unlimited
   * await integration.approveTokens([
   *   {
   *     tokenAddress: "0xUSDC",
   *     amount: ethers.MaxUint256
   *   }
   * ]);
   *
   * // Approve multiple tokens
   * await integration.approveTokens([
   *   { tokenAddress: "0xUSDC", amount: ethers.MaxUint256 },
   *   { tokenAddress: "0xWETH", amount: ethers.MaxUint256 }
   * ]);
   * ```
   */
  async approveTokens(
    approvals: TokenApproval[]
  ): Promise<TransactionReceipt[]> {
    const receipts: TransactionReceipt[] = [];

    for (const approval of approvals) {
      const tokenContract = new Contract(
        approval.tokenAddress,
        ERC20_ABI,
        this.signer
      );

      const tx: ContractTransactionResponse = await tokenContract.approve(
        this.swapProxyAddress,
        approval.amount
      );

      const receipt = await tx.wait();
      if (!receipt) {
        throw new Error(`Token approval failed for ${approval.tokenAddress}`);
      }
      receipts.push(receipt);
    }

    return receipts;
  }

  /**
   * Check if a token has sufficient approval for the SwapProxy
   *
   * @param tokenAddress - Address of the token to check
   * @param amount - Amount to check approval for
   * @returns True if approved for at least the specified amount
   *
   * @example
   * ```typescript
   * const isApproved = await integration.isTokenApproved(
   *   "0xUSDC",
   *   ethers.parseUnits("100", 6)
   * );
   *
   * if (!isApproved) {
   *   await integration.approveTokens([
   *     { tokenAddress: "0xUSDC", amount: ethers.MaxUint256 }
   *   ]);
   * }
   * ```
   */
  async isTokenApproved(
    tokenAddress: string,
    amount: bigint
  ): Promise<boolean> {
    const tokenContract = new Contract(tokenAddress, ERC20_ABI, this.provider);

    const signerAddress = await this.signer.getAddress();
    const allowance: bigint = await tokenContract.allowance(
      signerAddress,
      this.swapProxyAddress
    );

    return allowance >= amount;
  }

  /**
   * Estimate gas required for a swap with backrun operation
   *
   * @param swapTxCallData - Hex-encoded calldata for the swap
   * @param swapMetadata - Swap metadata
   * @param backrunParams - Backrun parameters
   * @returns Estimated gas with 20% buffer included
   *
   * @example
   * ```typescript
   * const estimatedGas = await integration.estimateGas(
   *   swapCalldata,
   *   swapMetadata,
   *   backrunParams
   * );
   *
   * console.log("Estimated gas:", estimatedGas.toString());
   * ```
   */
  async estimateGas(
    swapTxCallData: string,
    swapMetadata: SwapMetadata,
    backrunParams: BackrunParams[]
  ): Promise<bigint> {
    try {
      const gasEstimate =
        await this.swapProxyContract.swapWithBackrun.estimateGas(
          swapTxCallData,
          swapMetadata,
          backrunParams
        );

      // Add 20% buffer for safety
      return (gasEstimate * 120n) / 100n;
    } catch (error) {
      console.error('Gas estimation failed:', error);
      // Return a safe default if estimation fails
      return 1500000n;
    }
  }

  /**
   * Get the SwapProxy contract address
   *
   * @returns Address of the BackrunEnabledSwapProxy contract
   */
  getSwapProxyAddress(): string {
    return this.swapProxyAddress;
  }

  /**
   * Get the ReflexRouter contract address
   *
   * @returns Address of the ReflexRouter contract
   */
  getReflexRouterAddress(): string {
    return this.reflexRouterAddress;
  }

  /**
   * Get the target DEX router address from the SwapProxy
   *
   * @returns Address of the target DEX router
   */
  async getTargetRouterAddress(): Promise<string> {
    return await this.swapProxyContract.targetRouter();
  }

  /**
   * Parse the swap with backrun result from transaction receipt
   *
   * @private
   * @param receipt - Transaction receipt
   * @returns Parsed result with profits and return data
   */
  private async parseSwapWithBackrunResult(
    receipt: TransactionReceipt
  ): Promise<{
    swapReturnData: string;
    profits: bigint[];
    profitTokens: string[];
  }> {
    // Parse logs to extract return data and profits
    const reflexRouterInterface = new Interface(REFLEX_ROUTER_ABI);

    const profits: bigint[] = [];
    const profitTokens: string[] = [];
    let swapReturnData = '0x';

    for (const log of receipt.logs) {
      try {
        // Try to parse as BackrunExecuted event from ReflexRouter
        if (
          log.address.toLowerCase() === this.reflexRouterAddress.toLowerCase()
        ) {
          const parsedLog = reflexRouterInterface.parseLog({
            topics: [...log.topics],
            data: log.data,
          });

          if (parsedLog && parsedLog.name === 'BackrunExecuted') {
            profits.push(parsedLog.args.profit);
            profitTokens.push(parsedLog.args.profitToken);
          }
        }
      } catch (e) {
        // Log doesn't match expected format, skip
        continue;
      }
    }

    return {
      swapReturnData,
      profits,
      profitTokens,
    };
  }
}
