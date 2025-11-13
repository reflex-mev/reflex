import { EventEmitter } from 'events';
import { 
  JsonRpcProvider, 
  WebSocketProvider, 
  Log, 
  Interface,
  Contract
} from 'ethers';
import { config } from '../config';
import { logger } from '../utils/logger';
import { SwapEventData, PoolMetadata } from '../types';
import { SWAP_EVENT_TOPIC, UNISWAP_V3_POOL_ABI, ERC20_ABI } from '../constants/uniswapV3';
import { calculateSlippage, calculatePriceImpact, getSwapDirection } from '../utils/slippage';
import { addressToPoolId } from '../utils/poolId';

/**
 * Dual Event Listener - Supports both WebSocket and Polling modes
 * 
 * This service listens for Uniswap V3 Swap events using either:
 * 1. WebSocket for real-time events
 * 2. Block polling for reliability
 * 3. Both for redundancy
 */
export class DualEventListener extends EventEmitter {
  private wsProvider?: WebSocketProvider;
  private httpProvider: JsonRpcProvider;
  private pollingInterval?: NodeJS.Timeout;
  private lastPolledBlock: number = 0;
  private poolMetadataCache: Map<string, PoolMetadata> = new Map();
  private swapInterface: Interface;
  private isRunning: boolean = false;

  constructor() {
    super();
    
    // HTTP provider (required)
    this.httpProvider = new JsonRpcProvider(config.rpcUrl);
    
    // WebSocket provider (optional)
    if (config.rpcWsUrl && config.useWebSocket) {
      this.wsProvider = new WebSocketProvider(config.rpcWsUrl);
    }
    
    // Interface for decoding events
    this.swapInterface = new Interface(UNISWAP_V3_POOL_ABI);
  }

  /**
   * Initialize the event listener
   */
  async initialize(): Promise<void> {
    logger.info('Initializing DualEventListener...');
    
    // Get current block to start from
    this.lastPolledBlock = await this.httpProvider.getBlockNumber();
    logger.info(`Starting from block ${this.lastPolledBlock}`);
    
    this.isRunning = true;
  }

  /**
   * Subscribe to Swap events via WebSocket
   */
  async subscribeToSwapEventsWS(): Promise<void> {
    if (!this.wsProvider) {
      logger.warn('WebSocket provider not configured, skipping WS subscription');
      return;
    }

    logger.info('Subscribing to Swap events via WebSocket...');

    // Listen for all Swap events
    const filter = {
      topics: [SWAP_EVENT_TOPIC]
    };

    this.wsProvider.on(filter, async (log: Log) => {
      try {
        const swapData = await this.decodeSwapEvent(log);
        this.emit('swap', swapData);
      } catch (error) {
        logger.error('Error processing WebSocket swap event', { error, txHash: log.transactionHash });
      }
    });

    logger.info('✅ WebSocket subscription active');
  }

  /**
   * Start polling for new blocks
   */
  startPolling(): void {
    if (!config.usePolling) {
      return;
    }

    logger.info(`Starting block polling (interval: ${config.pollingIntervalMs}ms)...`);

    // Poll immediately
    this.pollLatestBlockLogs().catch(err => {
      logger.error('Error in initial polling', err);
    });

    // Then poll on interval
    this.pollingInterval = setInterval(async () => {
      await this.pollLatestBlockLogs();
    }, config.pollingIntervalMs);

    logger.info('✅ Block polling started');
  }

  /**
   * Poll for logs in the latest blocks
   */
  private async pollLatestBlockLogs(): Promise<void> {
    if (!this.isRunning) return;

    try {
      const currentBlock = await this.httpProvider.getBlockNumber();

      // Only poll if new blocks have been mined
      if (currentBlock <= this.lastPolledBlock) {
        return;
      }

      const fromBlock = this.lastPolledBlock + 1;
      const toBlock = currentBlock;

      logger.debug(`Polling blocks ${fromBlock} to ${toBlock}...`);

      // Query logs for Swap events
      const logs = await this.httpProvider.getLogs({
        fromBlock,
        toBlock,
        topics: [SWAP_EVENT_TOPIC],
      });

      logger.debug(`Found ${logs.length} swap events in blocks ${fromBlock}-${toBlock}`);

      // Process each log
      for (const log of logs) {
        try {
          const swapData = await this.decodeSwapEvent(log);
          this.emit('swap', swapData);
        } catch (error) {
          logger.error('Error processing polled swap event', { error, txHash: log.transactionHash });
        }
      }

      this.lastPolledBlock = currentBlock;
    } catch (error) {
      logger.error('Error polling latest blocks', error);
    }
  }

  /**
   * Decode a swap event log into structured data
   */
  private async decodeSwapEvent(log: Log): Promise<SwapEventData> {
    // Decode the event
    const decoded = this.swapInterface.parseLog({
      topics: log.topics as string[],
      data: log.data,
    });

    if (!decoded) {
      throw new Error('Failed to decode swap event');
    }

    const poolAddress = log.address;
    
    // Get pool metadata (cached)
    const metadata = await this.getPoolMetadata(poolAddress);

    // Extract event parameters
    const sender = decoded.args.sender as string;
    const recipient = decoded.args.recipient as string;
    const amount0 = decoded.args.amount0 as bigint;
    const amount1 = decoded.args.amount1 as bigint;
    const sqrtPriceX96 = decoded.args.sqrtPriceX96 as bigint;
    const liquidity = decoded.args.liquidity as bigint;
    const tick = decoded.args.tick as number;

    // Determine swap direction
    const zeroForOne = getSwapDirection(amount0, amount1);

    // Get block info for timestamp
    const block = await this.httpProvider.getBlock(log.blockNumber);
    const timestamp = block?.timestamp || 0;

    // Calculate slippage (we need sqrtPriceX96Before, for now use 0 as placeholder)
    // In a full implementation, we'd query the pool state before the swap
    const sqrtPriceX96Before = sqrtPriceX96; // Placeholder - would need to fetch actual pre-swap price
    const effectiveSlippagePercent = calculateSlippage(
      amount0,
      amount1,
      sqrtPriceX96Before,
      sqrtPriceX96,
      zeroForOne
    );

    const priceImpactPercent = calculatePriceImpact(sqrtPriceX96Before, sqrtPriceX96);

    const swapData: SwapEventData = {
      poolAddress,
      blockNumber: log.blockNumber,
      timestamp,
      sender,
      recipient,
      amount0,
      amount1,
      sqrtPriceX96,
      liquidity,
      tick,
      token0Address: metadata.token0,
      token1Address: metadata.token1,
      feeTier: metadata.fee,
      txHash: log.transactionHash || '',
      effectiveSlippagePercent,
      priceImpactPercent,
      zeroForOne,
    };

    return swapData;
  }

  /**
   * Get pool metadata (with caching)
   */
  private async getPoolMetadata(poolAddress: string): Promise<PoolMetadata> {
    // Check cache
    const cached = this.poolMetadataCache.get(poolAddress);
    if (cached) {
      return cached;
    }

    // Fetch from blockchain
    const poolContract = new Contract(poolAddress, UNISWAP_V3_POOL_ABI, this.httpProvider);

    try {
      const [token0, token1, fee] = await Promise.all([
        poolContract.token0() as Promise<string>,
        poolContract.token1() as Promise<string>,
        poolContract.fee() as Promise<number>,
      ]);

      // Get token metadata
      const token0Contract = new Contract(token0, ERC20_ABI, this.httpProvider);
      const token1Contract = new Contract(token1, ERC20_ABI, this.httpProvider);

      const [token0Symbol, token0Decimals, token1Symbol, token1Decimals] = await Promise.all([
        token0Contract.symbol() as Promise<string>,
        token0Contract.decimals() as Promise<number>,
        token1Contract.symbol() as Promise<string>,
        token1Contract.decimals() as Promise<number>,
      ]);

      const metadata: PoolMetadata = {
        poolAddress,
        token0,
        token1,
        fee,
        token0Symbol,
        token1Symbol,
        token0Decimals,
        token1Decimals,
      };

      // Cache it
      this.poolMetadataCache.set(poolAddress, metadata);

      logger.debug(`Fetched metadata for pool ${poolAddress}`, {
        token0Symbol,
        token1Symbol,
        fee,
      });

      return metadata;
    } catch (error) {
      logger.error(`Error fetching pool metadata for ${poolAddress}`, error);
      
      // Return minimal metadata
      return {
        poolAddress,
        token0: '',
        token1: '',
        fee: 0,
        token0Symbol: 'UNKNOWN',
        token1Symbol: 'UNKNOWN',
        token0Decimals: 18,
        token1Decimals: 18,
      };
    }
  }

  /**
   * Stop all event listeners
   */
  stop(): void {
    logger.info('Stopping DualEventListener...');
    this.isRunning = false;

    if (this.pollingInterval) {
      clearInterval(this.pollingInterval);
    }

    if (this.wsProvider) {
      this.wsProvider.removeAllListeners();
      this.wsProvider.destroy();
    }

    this.removeAllListeners();
    logger.info('✅ DualEventListener stopped');
  }
}
