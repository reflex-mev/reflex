import { config } from '../config';
import { logger } from '../utils/logger';
import { SwapEventData, PoolStatistics, PoolMetadata } from '../types';
import { addressToPoolId } from '../utils/poolId';

/**
 * In-Memory Pool Cache
 * 
 * Stores swap events and calculates pool statistics in real-time.
 * Automatically prunes old data to manage memory usage.
 */
export class InMemoryPoolCache {
  // In-memory storage
  private swapsByPool: Map<string, SwapEventData[]> = new Map();
  private poolStats: Map<string, PoolStatistics> = new Map();
  
  // Configuration
  private maxSwapsPerPool: number = 1000;
  private maxBlockAge: number;
  
  constructor() {
    this.maxBlockAge = config.statisticsWindowBlocks;
  }

  /**
   * Add a new swap event to the cache
   */
  addSwapEvent(event: SwapEventData): void {
    // Get or create swap list for this pool
    const swaps = this.swapsByPool.get(event.poolAddress) || [];
    swaps.push(event);
    
    // Limit size to prevent memory overflow
    if (swaps.length > this.maxSwapsPerPool) {
      swaps.shift(); // Remove oldest
    }
    
    this.swapsByPool.set(event.poolAddress, swaps);
    
    // Update statistics
    this.updatePoolStats(event);
  }

  /**
   * Get recent swaps for a pool
   */
  getRecentSwaps(poolAddress: string, blocks: number): SwapEventData[] {
    const swaps = this.swapsByPool.get(poolAddress) || [];
    
    if (swaps.length === 0) return [];
    
    const latestBlock = Math.max(...swaps.map(s => s.blockNumber));
    const cutoffBlock = latestBlock - blocks;
    
    return swaps.filter(s => s.blockNumber >= cutoffBlock);
  }

  /**
   * Get pool statistics
   */
  getPoolStats(poolAddress: string): PoolStatistics | undefined {
    return this.poolStats.get(poolAddress);
  }

  /**
   * Get all pools ranked by opportunity score
   */
  getAllPoolsRanked(): PoolStatistics[] {
    return Array.from(this.poolStats.values())
      .sort((a, b) => b.opportunityScore - a.opportunityScore);
  }

  /**
   * Get top N pools by opportunity score
   */
  getTopPools(n: number): PoolStatistics[] {
    return this.getAllPoolsRanked().slice(0, n);
  }

  /**
   * Update pool statistics when a new swap is added
   */
  private updatePoolStats(event: SwapEventData): void {
    const stats = this.poolStats.get(event.poolAddress) || this.createEmptyStats(event);
    
    // Update counters
    stats.swapCount++;
    stats.lastUpdateBlock = event.blockNumber;
    
    // Track swap direction
    if (event.zeroForOne) {
      stats.zeroForOneCount++;
    } else {
      stats.oneForZeroCount++;
    }
    
    // Calculate direction bias (-1 to 1)
    const total = stats.zeroForOneCount + stats.oneForZeroCount;
    stats.directionBias = (stats.zeroForOneCount - stats.oneForZeroCount) / total;
    
    // Update slippage metrics
    const swaps = this.swapsByPool.get(event.poolAddress) || [];
    const slippages = swaps.map(s => s.effectiveSlippagePercent);
    stats.avgSlippage = slippages.reduce((a, b) => a + b, 0) / slippages.length;
    stats.maxSlippage = Math.max(...slippages);
    stats.highSlippageCount = slippages.filter(s => s > config.slippageThreshold).length;
    
    // Update volume metrics (simplified - would need USD prices in production)
    const recentSwaps = this.getRecentSwaps(event.poolAddress, config.blocksToAnalyze);
    stats.totalVolumeUSD = recentSwaps.length * 10000; // Placeholder: $10k per swap
    stats.avgSwapSizeUSD = stats.totalVolumeUSD / recentSwaps.length;
    stats.largestSwapUSD = stats.avgSwapSizeUSD * 5; // Placeholder
    
    // Calculate volatility (simplified)
    const prices = swaps.map(s => Number(s.sqrtPriceX96));
    if (prices.length > 1) {
      const mean = prices.reduce((a, b) => a + b, 0) / prices.length;
      const variance = prices.reduce((sum, price) => sum + Math.pow(price - mean, 2), 0) / prices.length;
      stats.priceVolatility = Math.sqrt(variance) / mean * 100;
    }
    
    // Calculate opportunity score
    stats.opportunityScore = this.calculateOpportunityScore(stats);
    
    // Calculate recommended amount and direction
    stats.recommendedAmount = BigInt(Math.floor(stats.avgSwapSizeUSD * 0.1)); // 10% of avg swap
    stats.recommendedDirection = stats.directionBias > 0; // Follow dominant direction
    
    this.poolStats.set(event.poolAddress, stats);
  }

  /**
   * Create empty statistics for a new pool
   */
  private createEmptyStats(event: SwapEventData): PoolStatistics {
    return {
      poolAddress: event.poolAddress,
      poolId: addressToPoolId(event.poolAddress),
      swapCount: 0,
      totalVolumeUSD: 0,
      avgSwapSizeUSD: 0,
      largestSwapUSD: 0,
      avgSlippage: 0,
      maxSlippage: 0,
      highSlippageCount: 0,
      zeroForOneCount: 0,
      oneForZeroCount: 0,
      directionBias: 0,
      priceVolatility: 0,
      opportunityScore: 0,
      recommendedAmount: 0n,
      recommendedDirection: true,
      lastUpdateBlock: event.blockNumber,
      firstSeenBlock: event.blockNumber,
    };
  }

  /**
   * Calculate opportunity score (0-100)
   * 
   * MVP scoring formula:
   * - 40% weight on volume
   * - 40% weight on slippage
   * - 20% weight on recency
   */
  private calculateOpportunityScore(stats: PoolStatistics): number {
    // Normalize volume (0-100)
    const maxVolumeUSD = 1000000; // $1M
    const volumeScore = Math.min(stats.totalVolumeUSD / maxVolumeUSD * 100, 100);
    
    // Normalize slippage (0-100)
    const maxSlippage = 10; // 10%
    const slippageScore = Math.min(stats.avgSlippage / maxSlippage * 100, 100);
    
    // Recency score (100 if updated in last 5 blocks, 50 otherwise)
    const blocksSinceUpdate = Date.now() - stats.lastUpdateBlock; // Placeholder
    const recencyScore = blocksSinceUpdate < 5 ? 100 : 50;
    
    // Weighted combination
    const score = (
      volumeScore * 0.4 +
      slippageScore * 0.4 +
      recencyScore * 0.2
    );
    
    return Math.round(score);
  }

  /**
   * Prune old data to free memory
   */
  pruneOldData(currentBlock: number): void {
    const cutoffBlock = currentBlock - this.maxBlockAge;
    let prunedPools = 0;
    
    for (const [poolAddress, swaps] of this.swapsByPool) {
      const recentSwaps = swaps.filter(s => s.blockNumber >= cutoffBlock);
      
      if (recentSwaps.length === 0) {
        // Remove pool entirely if no recent swaps
        this.swapsByPool.delete(poolAddress);
        this.poolStats.delete(poolAddress);
        prunedPools++;
      } else {
        // Update with only recent swaps
        this.swapsByPool.set(poolAddress, recentSwaps);
      }
    }
    
    if (prunedPools > 0) {
      logger.debug(`Pruned ${prunedPools} inactive pools from cache`);
    }
  }

  /**
   * Get cache statistics for monitoring
   */
  getCacheStats(): { pools: number; totalSwaps: number; memoryUsageMB: number } {
    let totalSwaps = 0;
    for (const swaps of this.swapsByPool.values()) {
      totalSwaps += swaps.length;
    }
    
    // Rough memory estimate (each swap ~1KB)
    const memoryUsageMB = (totalSwaps * 1024) / (1024 * 1024);
    
    return {
      pools: this.poolStats.size,
      totalSwaps,
      memoryUsageMB: Math.round(memoryUsageMB * 100) / 100,
    };
  }
}
