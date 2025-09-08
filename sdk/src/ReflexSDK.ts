import {
  ethers,
  Contract,
  Provider,
  Signer,
  BigNumberish,
  BytesLike,
  TransactionReceipt,
  TransactionResponse,
  ContractTransactionResponse,
  Interface,
} from "ethers";
import { REFLEX_ROUTER_ABI } from "./abi";
import {
  ExecuteParams,
  BackrunParams,
  BackrunedExecuteResult,
  ReflexConfig,
  TransactionOptions,
  BackrunExecutedEvent,
} from "./types";

/**
 * Reflex SDK - TypeScript SDK for interacting with Reflex Router
 *
 * This SDK provides a simple interface for executing MEV backruns using the Reflex Router contract.
 * It supports both standalone backruns and combined execute + backrun operations.
 */
export class ReflexSDK {
  private provider: Provider;
  private signer: Signer;
  private config: ReflexConfig;
  private contract: Contract;

  /**
   * Creates a new instance of the Reflex SDK
   *
   * @param provider - Ethers provider for reading blockchain data
   * @param signer - Ethers signer for sending transactions
   * @param config - Configuration for the Reflex Router
   */
  constructor(provider: Provider, signer: Signer, config: ReflexConfig) {
    this.provider = provider;
    this.signer = signer;
    this.config = {
      defaultGasLimit: 500000n,
      gasPriceMultiplier: 1.1,
      ...config,
    };

    this.contract = new Contract(
      this.config.routerAddress,
      REFLEX_ROUTER_ABI,
      this.signer
    );
  }

  /**
   * Executes arbitrary calldata on a target contract and then triggers multiple backruns
   *
   * @param executeParams - Parameters for the execute call (target, value, callData)
   * @param backrunParams - Array of parameters for each backrun trigger
   * @param options - Transaction options (gas, etc.)
   * @returns Promise with execution results including profit information for each backrun
   */
  async backrunedExecute(
    executeParams: ExecuteParams,
    backrunParams: BackrunParams[],
    options: TransactionOptions = {}
  ): Promise<BackrunedExecuteResult> {
    try {
      // Prepare transaction parameters
      const txOptions = await this.prepareTxOptions(
        options,
        executeParams.value
      );

      // Execute the backruned execute transaction
      const tx: ContractTransactionResponse =
        await this.contract.backrunedExecute(
          executeParams,
          backrunParams,
          txOptions
        );

      // Wait for transaction receipt
      const receipt = await tx.wait();
      if (!receipt || receipt.status !== 1) {
        throw new Error("Transaction failed");
      }

      // Parse the transaction receipt to get return values
      const result = await this.parseBackrunedExecuteResult(tx.hash, receipt);

      return {
        ...result,
        transactionHash: tx.hash,
      };
    } catch (error) {
      throw new Error(`Backruned execute failed: ${this.formatError(error)}`);
    }
  }

  /**
   * Estimates gas for a backruned execute operation
   *
   * @param executeParams - Parameters for the execute call
   * @param backrunParams - Array of parameters for each backrun trigger
   * @returns Estimated gas limit
   */
  async estimateBackrunedExecuteGas(
    executeParams: ExecuteParams,
    backrunParams: BackrunParams[]
  ): Promise<bigint> {
    try {
      const gasEstimate = await this.contract.backrunedExecute.estimateGas(
        executeParams,
        backrunParams,
        { value: executeParams.value }
      );
      return gasEstimate;
    } catch (error) {
      throw new Error(`Gas estimation failed: ${this.formatError(error)}`);
    }
  }

  /**
   * Gets the current owner/admin of the Reflex Router
   *
   * @returns The address of the current admin
   */
  async getAdmin(): Promise<string> {
    return await this.contract.getReflexAdmin();
  }

  /**
   * Gets the current ReflexQuoter address
   *
   * @returns The address of the ReflexQuoter contract
   */
  async getQuoter(): Promise<string> {
    return await this.contract.reflexQuoter();
  }

  /**
   * Listens for BackrunExecuted events
   *
   * @param callback - Function to call when an event is received
   * @param options - Event filter options
   */
  watchBackrunExecuted(
    callback: (event: BackrunExecutedEvent) => void,
    options: {
      triggerPoolId?: string;
      profitToken?: string;
      recipient?: string;
    } = {}
  ) {
    const filter = this.contract.filters.BackrunExecuted(
      options.triggerPoolId,
      undefined, // swapAmountIn
      undefined, // token0In
      undefined, // profit
      options.profitToken,
      options.recipient
    );

    this.contract.on(
      filter,
      (
        triggerPoolId: string,
        swapAmountIn: bigint,
        token0In: boolean,
        profit: bigint,
        profitToken: string,
        recipient: string,
        event: any
      ) => {
        callback({
          triggerPoolId,
          swapAmountIn,
          token0In,
          profit,
          profitToken,
          recipient,
        });
      }
    );

    // Return unsubscribe function
    return () => {
      this.contract.removeAllListeners(filter);
    };
  }

  /**
   * Encodes function data for backruned execute (useful for batch transactions)
   *
   * @param executeParams - Execute parameters
   * @param backrunParams - Array of backrun parameters
   * @returns Encoded function data
   */
  encodeBackrunedExecute(
    executeParams: ExecuteParams,
    backrunParams: BackrunParams[]
  ): string {
    const iface = new Interface(REFLEX_ROUTER_ABI);
    return iface.encodeFunctionData("backrunedExecute", [
      executeParams,
      backrunParams,
    ]);
  }

  // Private helper methods

  private async prepareTxOptions(
    options: TransactionOptions,
    value: bigint = BigInt(0)
  ): Promise<any> {
    const txOptions: any = {
      value,
      ...options,
    };

    // Set default gas limit if not provided
    if (!txOptions.gasLimit && !txOptions.gas) {
      txOptions.gasLimit = this.config.defaultGasLimit;
    }

    // Handle gas price with multiplier
    if (
      !txOptions.gasPrice &&
      !txOptions.maxFeePerGas &&
      this.config.gasPriceMultiplier
    ) {
      const feeData = await this.provider.getFeeData();
      if (feeData.gasPrice) {
        txOptions.gasPrice = BigInt(
          Math.floor(Number(feeData.gasPrice) * this.config.gasPriceMultiplier)
        );
      }
    }

    return txOptions;
  }

  private async parseBackrunedExecuteResult(
    hash: string,
    receipt: any
  ): Promise<Omit<BackrunedExecuteResult, "transactionHash">> {
    // For ethers, we need to parse events or simulate the call to get return values
    try {
      // Parse all BackrunExecuted events from the receipt
      const backrunEvents = receipt.logs
        .map((log: any) => {
          try {
            const parsedLog = this.contract.interface.parseLog(log);
            return parsedLog?.name === "BackrunExecuted" ? parsedLog : null;
          } catch {
            return null;
          }
        })
        .filter((event: any) => event !== null);

      if (backrunEvents.length > 0) {
        const profits: bigint[] = [];
        const profitTokens: string[] = [];

        for (const event of backrunEvents) {
          profits.push(event.args?.profit || BigInt(0));
          profitTokens.push(
            event.args?.profitToken ||
              "0x0000000000000000000000000000000000000000"
          );
        }

        return {
          success: true,
          returnData: "0x",
          profits,
          profitTokens,
        };
      }

      return {
        success: receipt.status === 1,
        returnData: "0x",
        profits: [],
        profitTokens: [],
      };
    } catch (error) {
      throw new Error(`Failed to parse backruned execute result: ${error}`);
    }
  }

  private formatError(error: any): string {
    if (error.reason) {
      return error.reason;
    }
    if (error.message) {
      return error.message;
    }
    return String(error);
  }
}
