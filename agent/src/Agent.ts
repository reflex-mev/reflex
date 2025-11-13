import { config, validateConfig } from './config';
import { logger } from './utils/logger';
import { DualEventListener } from './services/DualEventListener';
import { InMemoryPoolCache } from './services/PoolCache';
import { ReflexExecutor } from './execution/ReflexExecutor';
import { SwapEventData, PoolStatistics } from './types';
import { formatEther } from 'ethers';

/**
 * Trading Agent - Main Orchestrator
 * 
 * Coordinates event collection, analysis, and execution
 */
export class TradingAgent {
  private eventListener!: DualEventListener;
  private poolCache!: InMemoryPoolCache;
  private reflexExecutor!: ReflexExecutor;
  private executionTimer?: NodeJS.Timeout;
  private isRunning: boolean = false;

  /**
   * Start the trading agent
   */
  async start(): Promise<void> {
    logger.info('🚀 Starting Reflex Trading Agent (MVP Mode)');
    logger.info('Configuration:', {
      chainId: config.chainId,
      useWebSocket: config.useWebSocket,
      usePolling: config.usePolling,
      executionInterval: `${config.executionIntervalMs}ms`,
      topPools: config.topPoolsCount,
    });

    try {
      // 1. Validate configuration
      validateConfig();
      logger.info('✅ Configuration validated');

      // 2. Initialize services
      await this.initialize();

      // 3. Start background event collection
      await this.startEventCollection();

      // 4. Start interval-based execution timer
      this.startExecutionTimer();

      // 5. Setup graceful shutdown
      this.setupShutdownHandlers();

      this.isRunning = true;
      logger.info('✅ Trading Agent started successfully');
    } catch (error) {
      logger.error('Failed to start Trading Agent', error);
      process.exit(1);
    }
  }

  /**
   * Initialize all services
   */
  private async initialize(): Promise<void> {
    logger.info('Initializing services...');

    // Initialize event listener (dual mode)
    this.eventListener = new DualEventListener();
    await this.eventListener.initialize();

    // Initialize in-memory cache
    this.poolCache = new InMemoryPoolCache();

    // Initialize Reflex executor
    this.reflexExecutor = new ReflexExecutor();

    // Wire up event handlers
    this.eventListener.on('swap', (swapData: SwapEventData) => {
      this.poolCache.addSwapEvent(swapData);
      logger.debug('Swap event cached', {
        pool: swapData.poolAddress,
        block: swapData.blockNumber,
        slippage: swapData.effectiveSlippagePercent.toFixed(2) + '%',
      });
    });

    logger.info('✅ Services initialized');
  }

  /**
   * Start background event collection
   */
  private async startEventCollection(): Promise<void> {
    logger.info('Starting event collection...');

    // Start WebSocket listener (if enabled)
    if (config.useWebSocket) {
      await this.eventListener.subscribeToSwapEventsWS();
      logger.info('✅ WebSocket listener started');
    }

    // Start polling (if enabled)
    if (config.usePolling) {
      this.eventListener.startPolling();
      logger.info(`✅ Polling started (interval: ${config.pollingIntervalMs}ms)`);
    }
  }

  /**
   * Start the execution timer
   */
  private startExecutionTimer(): void {
    logger.info('Starting execution timer...');
    logger.info(`⏰ Execution interval: ${config.executionIntervalMs}ms (${config.executionIntervalMs / 1000}s)`);

    // Execute immediately on start
    this.executeBackrunCycle().catch((err) => {
      logger.error('Error in initial execution cycle', err);
    });

    // Then execute on interval
    this.executionTimer = setInterval(async () => {
      await this.executeBackrunCycle();
    }, config.executionIntervalMs);
  }

  /**
   * Main execution cycle - runs periodically
   */
  private async executeBackrunCycle(): Promise<void> {
    if (!this.isRunning) return;

    try {
      const currentBlock = await this.reflexExecutor.getCurrentBlock();

      logger.info('🔄 Starting backrun execution cycle', { block: currentBlock });

      // Log cache statistics
      const cacheStats = this.poolCache.getCacheStats();
      logger.info('Cache stats', cacheStats);

      // 1. Query cache for top pools
      const topPools = this.poolCache.getTopPools(config.topPoolsCount);

      if (topPools.length === 0) {
        logger.info('No pools in cache yet, skipping execution');
        return;
      }

      logger.info(`Found ${topPools.length} pools in cache`);

      // 2. Filter by minimum profit threshold
      const profitablePools = topPools.filter((pool) => {
        const estimatedProfitUSD = this.estimateProfitUSD(pool);
        return estimatedProfitUSD >= config.minProfitThresholdUSD;
      });

      if (profitablePools.length === 0) {
        logger.info('No profitable opportunities found (all below threshold)');
        return;
      }

      logger.info(`Found ${profitablePools.length} profitable opportunities`);

      // Log top opportunities
      profitablePools.slice(0, 3).forEach((pool, i) => {
        logger.info(`Top ${i + 1}:`, {
          pool: pool.poolAddress.slice(0, 10) + '...',
          score: pool.opportunityScore.toFixed(2),
          volume: `$${pool.totalVolumeUSD.toFixed(0)}`,
          slippage: pool.avgSlippage.toFixed(2) + '%',
          estimatedProfit: `$${this.estimateProfitUSD(pool).toFixed(2)}`,
        });
      });

      // 3. Execute backruns (up to max concurrent)
      const pendingCount = this.reflexExecutor.getPendingTxCount();
      const availableSlots = config.maxConcurrentTxs - pendingCount;
      
      if (availableSlots <= 0) {
        logger.info('Max concurrent transactions reached, skipping execution');
        return;
      }

      const poolsToExecute = profitablePools.slice(0, availableSlots);

      for (const pool of poolsToExecute) {
        await this.executeBackrunForPool(pool);
      }

      // 4. Prune old data from cache
      this.poolCache.pruneOldData(currentBlock);
    } catch (error) {
      logger.error('Error in execution cycle', error);
    }
  }

  /**
   * Execute backrun for a single pool
   */
  private async executeBackrunForPool(pool: PoolStatistics): Promise<void> {
    try {
      logger.info('Executing backrun', {
        pool: pool.poolAddress.slice(0, 10) + '...',
        score: pool.opportunityScore.toFixed(2),
        amount: pool.recommendedAmount.toString(),
        direction: pool.recommendedDirection ? 'token0→token1' : 'token1→token0',
      });

      // Execute via Reflex Router
      const result = await this.reflexExecutor.executeBackrun(
        pool.poolId,
        pool.recommendedAmount,
        pool.recommendedDirection
      );

      if (result.success) {
        logger.info('✅ Backrun successful', {
          pool: pool.poolAddress.slice(0, 10) + '...',
          txHash: result.txHash.slice(0, 10) + '...',
          profit: formatEther(result.profit),
          profitToken: result.profitToken.slice(0, 10) + '...',
          gasUsed: result.gasUsed.toString(),
          executionTime: `${result.executionTime}ms`,
        });
      } else {
        logger.warn('❌ Backrun failed', {
          pool: pool.poolAddress.slice(0, 10) + '...',
          error: result.error,
        });
      }
    } catch (error) {
      logger.error('Error executing backrun', {
        pool: pool.poolAddress,
        error,
      });
    }
  }

  /**
   * Simple profit estimation based on volume and slippage
   * MVP: Simple heuristic
   */
  private estimateProfitUSD(pool: PoolStatistics): number {
    // Profit potential = volume * slippage * capture_rate
    const captureRate = 0.3; // Assume we can capture 30% of slippage value
    return pool.totalVolumeUSD * (pool.avgSlippage / 100) * captureRate;
  }

  /**
   * Setup graceful shutdown handlers
   */
  private setupShutdownHandlers(): void {
    const shutdown = async () => {
      logger.info('Shutting down...');
      this.isRunning = false;

      // Stop execution timer
      if (this.executionTimer) {
        clearInterval(this.executionTimer);
      }

      // Stop event listeners
      this.eventListener.stop();

      // Log final statistics
      const cacheStats = this.poolCache.getCacheStats();
      logger.info('Final cache stats', cacheStats);

      const balance = await this.reflexExecutor.getWalletBalance();
      logger.info('Final wallet balance', { balance: formatEther(balance) });

      logger.info('✅ Shutdown complete');
      process.exit(0);
    };

    process.on('SIGINT', shutdown);
    process.on('SIGTERM', shutdown);
  }
}
