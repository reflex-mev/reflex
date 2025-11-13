import { JsonRpcProvider, Wallet, parseUnits, Contract } from 'ethers';
import { config } from '../config';
import { logger } from '../utils/logger';
import { BackrunResult, GasPriceStrategy } from '../types';
import { REFLEX_ROUTER_ABI } from '../constants/reflexRouterAbi';

/**
 * Reflex Executor
 * 
 * Direct contract interaction for executing backrun transactions
 * Using plain ethers.js without SDK
 */
export class ReflexExecutor {
  private provider: JsonRpcProvider;
  private wallet: Wallet;
  private contract: Contract;
  private pendingTxCount: number = 0;

  constructor() {
    // Initialize provider and wallet
    this.provider = new JsonRpcProvider(config.rpcUrl);
    this.wallet = new Wallet(config.privateKey, this.provider);
    
    // Initialize Reflex Router contract
    this.contract = new Contract(
      config.reflexRouterAddress,
      REFLEX_ROUTER_ABI,
      this.wallet
    );
    
    logger.info('ReflexExecutor initialized', {
      wallet: this.wallet.address,
      router: config.reflexRouterAddress,
    });
  }

  /**
   * Get current block number
   */
  async getCurrentBlock(): Promise<number> {
    return await this.provider.getBlockNumber();
  }

  /**
   * Get current pending transaction count
   */
  getPendingTxCount(): number {
    return this.pendingTxCount;
  }

  /**
   * Execute a single backrun transaction
   */
  async executeBackrun(
    poolId: string,
    swapAmountIn: bigint,
    token0In: boolean,
  ): Promise<BackrunResult> {
    const startTime = Date.now();
    
    try {
      this.pendingTxCount++;
      
      // Get gas price strategy
      const gasStrategy = await this.getOptimalGasPrice();
      
      logger.debug('Executing backrun', {
        poolId,
        amount: swapAmountIn.toString(),
        token0In,
        gasStrategy: gasStrategy.strategy,
      });

      // Prepare transaction options
      const txOptions: any = {};
      if (gasStrategy.maxFeePerGas) {
        txOptions.maxFeePerGas = gasStrategy.maxFeePerGas;
        txOptions.maxPriorityFeePerGas = gasStrategy.maxPriorityFeePerGas;
      } else if (gasStrategy.gasPrice) {
        txOptions.gasPrice = gasStrategy.gasPrice;
      }

      // Execute triggerBackrun directly on contract
      const tx = await this.contract.triggerBackrun(
        poolId,
        swapAmountIn,
        token0In,
        this.wallet.address,
        '0x0000000000000000000000000000000000000000000000000000000000000000', // Default config ID
        txOptions
      );

      // Wait for transaction to be mined
      const receipt = await tx.wait();

      if (!receipt || receipt.status !== 1) {
        throw new Error('Transaction failed');
      }

      const executionTime = Date.now() - startTime;

      // Parse the BackrunExecuted event to get profit info
      let profit = 0n;
      let profitToken = '';

      for (const log of receipt.logs) {
        try {
          const parsedLog = this.contract.interface.parseLog({
            topics: log.topics as string[],
            data: log.data,
          });

          if (parsedLog && parsedLog.name === 'BackrunExecuted') {
            profit = parsedLog.args.profit;
            profitToken = parsedLog.args.profitToken;
            break;
          }
        } catch (e) {
          // Not a BackrunExecuted event, continue
        }
      }

      return {
        success: true,
        txHash: receipt.hash,
        profit,
        profitToken,
        gasUsed: receipt.gasUsed,
        executionTime,
      };
    } catch (error: any) {
      const executionTime = Date.now() - startTime;
      
      logger.error('Backrun execution failed', {
        poolId,
        error: error.message,
      });

      return {
        success: false,
        txHash: '',
        profit: 0n,
        profitToken: '',
        gasUsed: 0n,
        executionTime,
        error: error.message,
      };
    } finally {
      this.pendingTxCount--;
    }
  }

  /**
   * Calculate optimal gas price strategy
   */
  private async getOptimalGasPrice(): Promise<GasPriceStrategy> {
    try {
      const feeData = await this.provider.getFeeData();
      
      // Get max gas price from config
      const maxGasPriceGwei = parseFloat(config.maxGasPrice);
      const maxGasPrice = parseUnits(maxGasPriceGwei.toString(), 'gwei');
      
      // Use EIP-1559 if available
      if (feeData.maxFeePerGas && feeData.maxPriorityFeePerGas) {
        // Cap at max gas price
        const maxFeePerGas = feeData.maxFeePerGas > maxGasPrice 
          ? maxGasPrice 
          : feeData.maxFeePerGas;
        
        const maxPriorityFeePerGas = feeData.maxPriorityFeePerGas;
        
        return {
          maxFeePerGas,
          maxPriorityFeePerGas,
          strategy: 'normal',
        };
      }
      
      // Fallback to legacy gas price
      if (feeData.gasPrice) {
        const gasPrice = feeData.gasPrice > maxGasPrice 
          ? maxGasPrice 
          : feeData.gasPrice;
        
        return {
          gasPrice,
          strategy: 'normal',
        };
      }
      
      // Last resort: use max gas price
      return {
        gasPrice: maxGasPrice,
        strategy: 'conservative',
      };
    } catch (error) {
      logger.error('Error getting gas price', error);
      
      // Emergency fallback
      return {
        gasPrice: parseUnits('50', 'gwei'),
        strategy: 'conservative',
      };
    }
  }

  /**
   * Get wallet balance for monitoring
   */
  async getWalletBalance(): Promise<bigint> {
    return await this.provider.getBalance(this.wallet.address);
  }
}
