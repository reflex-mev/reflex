# Reflex Trading Agent - MVP Implementation Plan (Hackathon Edition)

## Overview
A TypeScript-based trading agent MVP that monitors Uniswap V3 swap events, identifies MEV opportunities through statistical analysis, and executes backrun transactions via the Reflex Router.

**MVP Mode:** Simplified architecture focused on core functionality with in-memory state, environment-based configuration, and dual event sourcing (WebSocket + polling).

---

## MVP Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                   Trading Agent (MVP)                         │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌─────────────────────────────┐    ┌────────────────────┐  │
│  │   Dual Event Listener       │───▶│  Execution Timer   │  │
│  │  (WebSocket + Block Poll)   │    │  (Interval-based)  │  │
│  └─────────────────────────────┘    └────────────────────┘  │
│         │                                      │              │
│         ▼                                      ▼              │
│  ┌─────────────────────────────┐    ┌────────────────────┐  │
│  │  In-Memory Pool Cache       │───▶│  Reflex SDK        │  │
│  │  (Swaps + Stats + Slippage) │    │  Executor          │  │
│  └─────────────────────────────┘    └────────────────────┘  │
│                                                                │
└──────────────────────────────────────────────────────────────┘
         │                                      │
         ▼                                      ▼
    Blockchain Events                   Blockchain Execution
    (WS + RPC Polling)                  (via Reflex Router)

All Config from .env | All State in Memory | Simplified Flow
```

---

## Phase 1: Project Setup & Infrastructure

### 1.1 Project Initialization
**Files to create:**
- `agent/package.json` - Dependencies and scripts
- `agent/tsconfig.json` - TypeScript configuration
- `agent/.env.example` - Environment variables template
- `agent/README.md` - Documentation

**Dependencies (MVP - Minimal):**
```json
{
  "dependencies": {
    "@reflex-mev/sdk": "workspace:*",
    "ethers": "^6.x",
    "dotenv": "^16.x",
    "winston": "^3.x"
  },
  "devDependencies": {
    "typescript": "^5.x",
    "@types/node": "^20.x",
    "ts-node": "^10.x",
    "tsx": "^4.x"
  }
}
```

**Note:** Removed `ws` (using ethers WebSocket), `ioredis` (in-memory only), `nodemon` (using `tsx` instead)

### 1.2 Configuration System (Environment-Based)
**File:** `agent/src/config/index.ts`

**All configuration loaded from environment variables:**

```typescript
import dotenv from 'dotenv';
dotenv.config();

export interface AgentConfig {
  // Blockchain Connection
  rpcUrl: string;
  rpcWsUrl: string | null;
  chainId: number;
  
  // Reflex Integration
  reflexRouterAddress: string;
  privateKey: string;
  
  // Event Sourcing
  useWebSocket: boolean;
  usePolling: boolean;
  pollingIntervalMs: number; // How often to poll for new blocks
  
  // Monitoring
  blocksToAnalyze: number; // How many recent blocks to analyze
  topPoolsCount: number; // Top N pools to execute on
  minSwapSizeUSD: number; // Minimum swap size to track (in USD)
  
  // Execution
  executionIntervalMs: number; // How often to check cache and execute
  maxGasPrice: string; // In gwei
  minProfitThresholdUSD: number; // Min profit to execute (in USD)
  maxConcurrentTxs: number;
  
  // Analytics
  statisticsWindowBlocks: number; // How many blocks to keep in memory
  slippageThreshold: number; // Alert if slippage > this %
  
  // Logging
  logLevel: 'debug' | 'info' | 'warn' | 'error';
}

export const config: AgentConfig = {
  // Blockchain
  rpcUrl: process.env.RPC_URL || '',
  rpcWsUrl: process.env.RPC_WS_URL || null,
  chainId: parseInt(process.env.CHAIN_ID || '1'),
  
  // Reflex
  reflexRouterAddress: process.env.REFLEX_ROUTER_ADDRESS || '',
  privateKey: process.env.PRIVATE_KEY || '',
  
  // Event Sourcing
  useWebSocket: process.env.USE_WEBSOCKET === 'true',
  usePolling: process.env.USE_POLLING !== 'false', // Default true
  pollingIntervalMs: parseInt(process.env.POLLING_INTERVAL_MS || '12000'), // 12s (1 block)
  
  // Monitoring
  blocksToAnalyze: parseInt(process.env.BLOCKS_TO_ANALYZE || '10'),
  topPoolsCount: parseInt(process.env.TOP_POOLS_COUNT || '10'),
  minSwapSizeUSD: parseFloat(process.env.MIN_SWAP_SIZE_USD || '1000'),
  
  // Execution
  executionIntervalMs: parseInt(process.env.EXECUTION_INTERVAL_MS || '30000'), // 30s
  maxGasPrice: process.env.MAX_GAS_PRICE_GWEI || '100',
  minProfitThresholdUSD: parseFloat(process.env.MIN_PROFIT_THRESHOLD_USD || '10'),
  maxConcurrentTxs: parseInt(process.env.MAX_CONCURRENT_TXS || '3'),
  
  // Analytics
  statisticsWindowBlocks: parseInt(process.env.STATISTICS_WINDOW_BLOCKS || '100'),
  slippageThreshold: parseFloat(process.env.SLIPPAGE_THRESHOLD || '5'), // 5%
  
  // Logging
  logLevel: (process.env.LOG_LEVEL as any) || 'info',
};

// Validation
export function validateConfig(): void {
  if (!config.rpcUrl) throw new Error('RPC_URL is required');
  if (!config.reflexRouterAddress) throw new Error('REFLEX_ROUTER_ADDRESS is required');
  if (!config.privateKey) throw new Error('PRIVATE_KEY is required');
  if (!config.useWebSocket && !config.usePolling) {
    throw new Error('At least one event source (WebSocket or Polling) must be enabled');
  }
}
```

**File:** `agent/.env.example`

```bash
# Blockchain Connection
RPC_URL=https://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
RPC_WS_URL=wss://eth-mainnet.g.alchemy.com/v2/YOUR_KEY
CHAIN_ID=1

# Reflex Integration
REFLEX_ROUTER_ADDRESS=0x1234567890123456789012345678901234567890
PRIVATE_KEY=0xYOUR_PRIVATE_KEY_HERE

# Event Sourcing
USE_WEBSOCKET=true
USE_POLLING=true
POLLING_INTERVAL_MS=12000

# Monitoring
BLOCKS_TO_ANALYZE=10
TOP_POOLS_COUNT=10
MIN_SWAP_SIZE_USD=1000

# Execution
EXECUTION_INTERVAL_MS=30000
MAX_GAS_PRICE_GWEI=100
MIN_PROFIT_THRESHOLD_USD=10
MAX_CONCURRENT_TXS=3

# Analytics
STATISTICS_WINDOW_BLOCKS=100
SLIPPAGE_THRESHOLD=5

# Logging
LOG_LEVEL=info
```

---

## Phase 2: Event Listening & Pool Monitoring

### 2.1 Dual Event Listener Service (WebSocket + Polling)
**File:** `agent/src/services/EventListener.ts`

**Responsibilities:**
- **WebSocket Mode:** Subscribe to real-time Uniswap V3 Swap events
- **Polling Mode:** Query latest block logs on interval
- **Hybrid Mode:** Use both for redundancy and catching missed events
- Decode pool addresses, amounts, swap directions, and **calculate slippage**
- Emit structured events for processing

**Key Components:**
```typescript
class DualEventListener {
  private wsProvider?: WebSocketProvider;
  private httpProvider: JsonRpcProvider;
  private pollingInterval?: NodeJS.Timeout;
  private lastPolledBlock: number = 0;
  
  // Initialize both event sources
  async initialize(): Promise<void>
  
  // WebSocket subscription
  async subscribeToSwapEventsWS(): Promise<void>
  
  // Polling for latest block logs
  async pollLatestBlockLogs(): Promise<void>
  
  // Start polling loop
  startPolling(): void
  
  // Stop all listeners
  stop(): void
  
  // Decode swap event data with slippage calculation
  async decodeSwapEvent(log: Log): Promise<SwapEventData>
  
  // Get pool metadata (tokens, fee tier) - cached in memory
  async getPoolMetadata(poolAddress: string): Promise<PoolMetadata>
  
  // Calculate effective slippage from swap
  calculateSlippage(
    amount0: bigint,
    amount1: bigint,
    sqrtPriceX96Before: bigint,
    sqrtPriceX96After: bigint,
    zeroForOne: boolean
  ): number
}

interface SwapEventData {
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
  
  // NEW: Slippage Analysis
  effectiveSlippagePercent: number; // Actual slippage experienced
  priceImpactPercent: number; // Price impact of the swap
  zeroForOne: boolean; // Swap direction
}

interface PoolMetadata {
  poolAddress: string;
  token0: string;
  token1: string;
  fee: number;
  token0Symbol: string;
  token1Symbol: string;
  token0Decimals: number;
  token1Decimals: number;
}
```

**Uniswap V3 Swap Event Signature:**
```solidity
event Swap(
  address indexed sender,
  address indexed recipient,
  int256 amount0,
  int256 amount1,
  uint160 sqrtPriceX96,
  uint128 liquidity,
  int24 tick
)
```

**Polling Implementation:**
```typescript
async pollLatestBlockLogs(): Promise<void> {
  const currentBlock = await this.httpProvider.getBlockNumber();
  
  // Only poll if new blocks have been mined
  if (currentBlock <= this.lastPolledBlock) return;
  
  const fromBlock = this.lastPolledBlock + 1;
  const toBlock = currentBlock;
  
  // Query logs for Swap events
  const logs = await this.httpProvider.getLogs({
    fromBlock,
    toBlock,
    topics: [SWAP_EVENT_TOPIC], // Swap event signature
  });
  
  // Process each log
  for (const log of logs) {
    const swapData = await this.decodeSwapEvent(log);
    this.emit('swap', swapData);
  }
  
  this.lastPolledBlock = currentBlock;
}
```

### 2.2 In-Memory Pool Cache (MVP)
**File:** `agent/src/services/PoolCache.ts`

**Responsibilities:**
- Store all swap events in memory (with size limits)
- Track pool statistics in real-time
- Maintain slippage metrics
- Provide fast queries for execution timer

**Key Components:**
```typescript
class InMemoryPoolCache {
  // In-memory storage (Map for O(1) access)
  private swapsByPool: Map<string, SwapEventData[]> = new Map();
  private poolStats: Map<string, PoolStatistics> = new Map();
  private poolMetadata: Map<string, PoolMetadata> = new Map();
  
  // Configuration
  private maxSwapsPerPool: number = 1000; // Limit memory usage
  private maxBlockAge: number; // From config.statisticsWindowBlocks
  
  // Add new swap event
  addSwapEvent(event: SwapEventData): void {
    // Store swap
    const swaps = this.swapsByPool.get(event.poolAddress) || [];
    swaps.push(event);
    
    // Limit size
    if (swaps.length > this.maxSwapsPerPool) {
      swaps.shift(); // Remove oldest
    }
    
    this.swapsByPool.set(event.poolAddress, swaps);
    
    // Update statistics
    this.updatePoolStats(event);
  }
  
  // Get recent swaps for a pool
  getRecentSwaps(poolAddress: string, blocks: number): SwapEventData[] {
    const swaps = this.swapsByPool.get(poolAddress) || [];
    const cutoffBlock = Math.max(...swaps.map(s => s.blockNumber)) - blocks;
    return swaps.filter(s => s.blockNumber >= cutoffBlock);
  }
  
  // Get pool statistics
  getPoolStats(poolAddress: string): PoolStatistics | undefined {
    return this.poolStats.get(poolAddress);
  }
  
  // Get all pools sorted by score
  getAllPoolsRanked(): PoolStatistics[] {
    return Array.from(this.poolStats.values())
      .sort((a, b) => b.opportunityScore - a.opportunityScore);
  }
  
  // Update pool statistics
  private updatePoolStats(event: SwapEventData): void {
    const stats = this.poolStats.get(event.poolAddress) || this.createEmptyStats(event.poolAddress);
    
    // Update metrics
    stats.swapCount++;
    stats.totalVolumeUSD += this.calculateSwapVolumeUSD(event);
    stats.avgSlippage = this.calculateAvgSlippage(event.poolAddress);
    stats.lastUpdateBlock = event.blockNumber;
    
    // Calculate opportunity score
    stats.opportunityScore = this.calculateOpportunityScore(stats);
    
    this.poolStats.set(event.poolAddress, stats);
  }
  
  // Prune old data to free memory
  pruneOldData(currentBlock: number): void {
    const cutoffBlock = currentBlock - this.maxBlockAge;
    
    for (const [poolAddress, swaps] of this.swapsByPool) {
      const recentSwaps = swaps.filter(s => s.blockNumber >= cutoffBlock);
      if (recentSwaps.length === 0) {
        this.swapsByPool.delete(poolAddress);
        this.poolStats.delete(poolAddress);
      } else {
        this.swapsByPool.set(poolAddress, recentSwaps);
      }
    }
  }
  
  // Get top N pools by opportunity score
  getTopPools(n: number): PoolStatistics[] {
    return this.getAllPoolsRanked().slice(0, n);
  }
}

interface PoolStatistics {
  poolAddress: string;
  poolId: string; // bytes32 for Reflex Router
  
  // Volume metrics
  swapCount: number;
  totalVolumeUSD: number;
  avgSwapSizeUSD: number;
  largestSwapUSD: number;
  
  // Slippage metrics (NEW)
  avgSlippage: number; // Average effective slippage
  maxSlippage: number; // Max slippage seen
  highSlippageCount: number; // # of swaps with slippage > threshold
  
  // Direction bias
  zeroForOneCount: number;
  oneForZeroCount: number;
  directionBias: number; // -1 to 1 (negative = 1->0, positive = 0->1)
  
  // Volatility
  priceVolatility: number;
  
  // Opportunity metrics
  opportunityScore: number; // Composite score (0-100)
  recommendedAmount: bigint; // Suggested backrun amount
  recommendedDirection: boolean; // Suggested direction (token0In)
  
  // Metadata
  lastUpdateBlock: number;
  firstSeenBlock: number;
}
```

---

## Phase 3: Analytics Engine

### 3.1 Statistics Calculator
**File:** `agent/src/analytics/StatisticsCalculator.ts`

**Responsibilities:**
- Calculate pool activity metrics
- Identify top pools by various criteria
- Detect patterns and anomalies

**Key Metrics:**
```typescript
class StatisticsCalculator {
  // Calculate volume metrics
  calculateVolumeMetrics(swaps: SwapEventData[]): VolumeMetrics
  
  // Calculate price impact and volatility
  calculateVolatility(swaps: SwapEventData[]): number
  
  // Identify unusual activity
  detectAnomalies(pool: PoolStatistics): AnomalyScore
  
  // Calculate swap direction bias
  getDirectionBias(swaps: SwapEventData[]): DirectionBias
}

interface VolumeMetrics {
  totalVolume: bigint;
  averageSwapSize: bigint;
  largestSwap: bigint;
  swapCount: number;
  volumeByDirection: {
    zeroToOne: bigint;
    oneToZero: bigint;
  };
}

interface DirectionBias {
  dominantDirection: boolean; // true = 0->1, false = 1->0
  biasPercentage: number; // 0-100
  imbalanceScore: number; // Higher = more imbalanced
}
```

### 3.2 Opportunity Analyzer
**File:** `agent/src/analytics/OpportunityAnalyzer.ts`

**Responsibilities:**
- Rank pools by MEV opportunity potential
- Determine optimal swap amounts
- Filter pools based on profitability criteria

**Key Components:**
```typescript
class OpportunityAnalyzer {
  // Analyze all pools and rank by opportunity
  analyzeOpportunities(
    allPools: Map<string, PoolStatistics>,
    currentBlock: number
  ): OpportunityRanking[]
  
  // Calculate optimal backrun amount
  calculateOptimalAmount(
    poolStats: PoolStatistics,
    recentSwaps: SwapEventData[]
  ): bigint
  
  // Filter profitable opportunities
  filterProfitableOpportunities(
    opportunities: OpportunityRanking[]
  ): OpportunityRanking[]
}

interface OpportunityRanking {
  poolAddress: string;
  poolId: string; // bytes32 for Reflex
  score: number; // 0-100 composite score
  metrics: {
    volume: bigint;
    volatility: number;
    swapFrequency: number;
    directionBias: number;
    avgProfitPotential: bigint;
  };
  recommendedSwapAmount: bigint;
  recommendedDirection: boolean; // token0In
}
```

### 3.3 Pattern Recognition
**File:** `agent/src/analytics/PatternRecognizer.ts`

**Responsibilities:**
- Identify recurring patterns in pool activity
- Track successful vs failed backruns
- Adapt strategy based on historical performance

**Key Components:**
```typescript
class PatternRecognizer {
  // Learn from historical data
  learnFromHistory(
    executions: BackrunExecution[],
    swapHistory: SwapEventData[]
  ): PatternInsights
  
  // Predict profitability
  predictProfitability(
    opportunity: OpportunityRanking
  ): ProfitabilityPrediction
  
  // Identify market regime
  detectMarketRegime(recentBlocks: SwapEventData[]): MarketRegime
}

interface PatternInsights {
  successRate: number;
  avgProfit: bigint;
  bestTimeOfDay: number[]; // Hour of day
  bestPoolTypes: string[]; // Fee tiers
  optimalSizeRange: { min: bigint; max: bigint };
}

type MarketRegime = 'calm' | 'volatile' | 'trending' | 'reversal';
```

---

## Phase 4: Execution Engine

### 4.1 Transaction Manager
**File:** `agent/src/execution/TransactionManager.ts`

**Responsibilities:**
- Queue and manage transactions
- Handle gas pricing and nonce management
- Retry failed transactions
- Monitor transaction status

**Key Components:**
```typescript
class TransactionManager {
  // Submit backrun transaction
  async submitBackrun(
    opportunity: OpportunityRanking
  ): Promise<BackrunExecution>
  
  // Estimate gas for backrun
  async estimateGas(params: BackrunParams): Promise<bigint>
  
  // Calculate optimal gas price
  async getOptimalGasPrice(): Promise<GasPriceStrategy>
  
  // Monitor pending transactions
  async monitorPendingTxs(): Promise<void>
  
  // Handle failed transactions
  async handleFailedTx(tx: BackrunExecution): Promise<void>
}

interface BackrunExecution {
  txHash: string;
  opportunity: OpportunityRanking;
  submittedAt: number;
  status: 'pending' | 'confirmed' | 'failed';
  gasUsed?: bigint;
  profit?: bigint;
  profitToken?: string;
  error?: string;
}

interface GasPriceStrategy {
  gasPrice?: bigint;
  maxFeePerGas?: bigint;
  maxPriorityFeePerGas?: bigint;
  strategy: 'aggressive' | 'normal' | 'conservative';
}
```

### 4.2 Reflex Executor
**File:** `agent/src/execution/ReflexExecutor.ts`

**Responsibilities:**
- Interface with Reflex SDK
- Execute triggerBackrun calls
- Handle profit distribution

**Key Components:**
```typescript
class ReflexExecutor {
  private sdk: ReflexSDK;
  
  // Execute single backrun
  async executeBackrun(
    poolId: string,
    swapAmountIn: bigint,
    token0In: boolean,
    gasStrategy: GasPriceStrategy
  ): Promise<BackrunResult>
  
  // Execute batch of backruns
  async executeBatchBackruns(
    opportunities: OpportunityRanking[]
  ): Promise<BackrunResult[]>
  
  // Dry run (simulate without executing)
  async simulateBackrun(params: BackrunParams): Promise<SimulationResult>
}

interface BackrunResult {
  success: boolean;
  txHash: string;
  profit: bigint;
  profitToken: string;
  gasUsed: bigint;
  executionTime: number;
}
```

---

## Phase 5: Main Agent Loop (MVP - Simplified)

### 5.1 Agent Orchestrator with Interval-Based Execution
**File:** `agent/src/Agent.ts`

**MVP Flow:**
1. **Background:** Continuously collect swap events (WebSocket + Polling)
2. **Interval Timer:** Every X seconds, query cache and execute backruns
3. **Simple Logic:** No complex ML, just volume + slippage based ranking

```typescript
class TradingAgent {
  private eventListener: DualEventListener;
  private poolCache: InMemoryPoolCache;
  private reflexExecutor: ReflexExecutor;
  private executionTimer?: NodeJS.Timeout;
  private logger: Logger;
  
  async start(): Promise<void> {
    this.logger.info('🚀 Starting Trading Agent (MVP Mode)');
    
    // 1. Validate configuration
    validateConfig();
    
    // 2. Initialize services
    await this.initialize();
    
    // 3. Start background event collection
    await this.startEventCollection();
    
    // 4. Start interval-based execution timer
    this.startExecutionTimer();
    
    // 5. Setup graceful shutdown
    this.setupShutdownHandlers();
  }
  
  async initialize(): Promise<void> {
    this.logger.info('Initializing services...');
    
    // Initialize event listener (dual mode)
    this.eventListener = new DualEventListener(config);
    
    // Initialize in-memory cache
    this.poolCache = new InMemoryPoolCache(config);
    
    // Initialize Reflex executor
    this.reflexExecutor = new ReflexExecutor(config);
    
    // Wire up event handlers
    this.eventListener.on('swap', (swapData: SwapEventData) => {
      this.poolCache.addSwapEvent(swapData);
      this.logger.debug('Swap event cached', {
        pool: swapData.poolAddress,
        block: swapData.blockNumber,
        slippage: swapData.effectiveSlippagePercent.toFixed(2) + '%'
      });
    });
    
    this.logger.info('✅ Services initialized');
  }
  
  async startEventCollection(): Promise<void> {
    this.logger.info('Starting event collection...');
    
    // Start WebSocket listener (if enabled)
    if (config.useWebSocket) {
      await this.eventListener.subscribeToSwapEventsWS();
      this.logger.info('✅ WebSocket listener started');
    }
    
    // Start polling (if enabled)
    if (config.usePolling) {
      this.eventListener.startPolling();
      this.logger.info('✅ Polling started (interval: ' + config.pollingIntervalMs + 'ms)');
    }
  }
  
  startExecutionTimer(): void {
    this.logger.info('Starting execution timer...');
    this.logger.info('⏰ Execution interval: ' + config.executionIntervalMs + 'ms');
    
    // Execute immediately on start
    this.executeBackrunCycle().catch(err => {
      this.logger.error('Error in initial execution cycle', err);
    });
    
    // Then execute on interval
    this.executionTimer = setInterval(async () => {
      await this.executeBackrunCycle();
    }, config.executionIntervalMs);
  }
  
  async executeBackrunCycle(): Promise<void> {
    const currentBlock = await this.reflexExecutor.getCurrentBlock();
    
    this.logger.info('🔄 Starting backrun execution cycle', { block: currentBlock });
    
    try {
      // 1. Query cache for top pools
      const topPools = this.poolCache.getTopPools(config.topPoolsCount);
      
      if (topPools.length === 0) {
        this.logger.info('No pools in cache yet, skipping execution');
        return;
      }
      
      this.logger.info(`Found ${topPools.length} potential pools`);
      
      // 2. Filter by minimum profit threshold
      const profitablePools = topPools.filter(pool => {
        const estimatedProfitUSD = this.estimateProfitUSD(pool);
        return estimatedProfitUSD >= config.minProfitThresholdUSD;
      });
      
      if (profitablePools.length === 0) {
        this.logger.info('No profitable opportunities found');
        return;
      }
      
      this.logger.info(`Found ${profitablePools.length} profitable opportunities`);
      
      // 3. Execute backruns (up to max concurrent)
      const poolsToExecute = profitablePools.slice(0, config.maxConcurrentTxs);
      
      for (const pool of poolsToExecute) {
        await this.executeBackrunForPool(pool);
      }
      
      // 4. Prune old data from cache
      this.poolCache.pruneOldData(currentBlock);
      
    } catch (error) {
      this.logger.error('Error in execution cycle', error);
    }
  }
  
  async executeBackrunForPool(pool: PoolStatistics): Promise<void> {
    try {
      this.logger.info('Executing backrun', {
        pool: pool.poolAddress,
        score: pool.opportunityScore.toFixed(2),
        amount: pool.recommendedAmount.toString(),
        direction: pool.recommendedDirection ? 'token0->token1' : 'token1->token0'
      });
      
      // Execute via Reflex Router
      const result = await this.reflexExecutor.executeBackrun(
        pool.poolId,
        pool.recommendedAmount,
        pool.recommendedDirection
      );
      
      if (result.success) {
        this.logger.info('✅ Backrun successful', {
          pool: pool.poolAddress,
          txHash: result.txHash,
          profit: result.profit.toString(),
          profitToken: result.profitToken,
          gasUsed: result.gasUsed.toString()
        });
      } else {
        this.logger.warn('❌ Backrun failed', {
          pool: pool.poolAddress,
          txHash: result.txHash
        });
      }
      
    } catch (error) {
      this.logger.error('Error executing backrun', {
        pool: pool.poolAddress,
        error
      });
    }
  }
  
  // Simple profit estimation based on volume and slippage
  private estimateProfitUSD(pool: PoolStatistics): number {
    // MVP: Simple heuristic
    // Profit potential = volume * slippage * capture_rate
    const captureRate = 0.3; // Assume we can capture 30% of slippage value
    return pool.totalVolumeUSD * (pool.avgSlippage / 100) * captureRate;
  }
  
  setupShutdownHandlers(): void {
    const shutdown = async () => {
      this.logger.info('Shutting down...');
      
      // Stop execution timer
      if (this.executionTimer) {
        clearInterval(this.executionTimer);
      }
      
      // Stop event listeners
      this.eventListener.stop();
      
      this.logger.info('✅ Shutdown complete');
      process.exit(0);
    };
    
    process.on('SIGINT', shutdown);
    process.on('SIGTERM', shutdown);
  }
}
```

---

## Phase 6: Monitoring & Logging

### 6.1 Performance Tracker
**File:** `agent/src/monitoring/PerformanceTracker.ts`

**Metrics to Track:**
- Total transactions submitted
- Success rate
- Total profit (by token)
- Gas costs
- Average execution time
- Opportunities detected vs executed

### 6.2 Logging System
**File:** `agent/src/utils/Logger.ts`

**Structured logging with Winston:**
- Event detection logs
- Opportunity analysis logs
- Transaction execution logs
- Error and warning logs
- Performance metrics

---

## Phase 7: Safety & Risk Management

### 7.1 Safety Checks
**File:** `agent/src/safety/SafetyManager.ts`

**Checks:**
- Maximum daily loss limit
- Maximum gas price threshold
- Minimum profit threshold
- Pool liquidity requirements
- Token whitelist/blacklist
- Circuit breaker on consecutive failures

### 7.2 Emergency Controls
```typescript
class SafetyManager {
  // Kill switch - stop all operations
  emergencyStop(): void
  
  // Pause operations temporarily
  pause(): void
  
  // Resume operations
  resume(): void
  
  // Check if operation is safe
  isSafeToOperate(): boolean
  
  // Validate opportunity before execution
  validateOpportunity(opp: OpportunityRanking): ValidationResult
}
```

---

## MVP Implementation Timeline (Hackathon - 2-3 Days)

### Day 1: Core Infrastructure (6-8 hours)
- [ ] Project setup (package.json, tsconfig, .env)
- [ ] Environment-based configuration
- [ ] Dual event listener (WebSocket + Polling)
- [ ] In-memory pool cache
- [ ] Basic logging with Winston
- [ ] Slippage calculation logic

### Day 2: Execution & Integration (6-8 hours)
- [ ] Reflex SDK integration
- [ ] Execution timer implementation
- [ ] Simple opportunity scoring (volume + slippage)
- [ ] Basic transaction submission
- [ ] Error handling and retry logic
- [ ] Testing with testnet/fork

### Day 3: Polish & Testing (4-6 hours)
- [ ] Safety checks (gas price, profit threshold)
- [ ] Performance logging and monitoring
- [ ] End-to-end testing
- [ ] Documentation
- [ ] Demo preparation

**Total: ~20 hours of focused development**

---

## MVP File Structure (Simplified)

```
agent/
├── package.json
├── tsconfig.json
├── .env.example
├── .env                              # Your local config (gitignored)
├── README.md
├── IMPLEMENTATION_PLAN.md (this file)
├── src/
│   ├── index.ts                      # Entry point - start agent
│   ├── Agent.ts                      # Main orchestrator with execution timer
│   ├── config.ts                     # All env-based configuration
│   ├── types.ts                      # All TypeScript interfaces
│   ├── services/
│   │   ├── DualEventListener.ts      # WebSocket + Polling event listener
│   │   └── PoolCache.ts              # In-memory pool cache
│   ├── execution/
│   │   └── ReflexExecutor.ts         # Reflex SDK wrapper
│   ├── utils/
│   │   ├── logger.ts                 # Winston logger setup
│   │   ├── slippage.ts               # Slippage calculation helpers
│   │   └── poolId.ts                 # Convert pool address to bytes32
│   └── constants/
│       └── uniswapV3.ts              # Uniswap V3 ABIs, event topics
└── tests/                            # Optional for MVP
    └── basic.test.ts
```

**Key Simplifications:**
- ✅ Single config file (env-based)
- ✅ Single types file
- ✅ No separate analytics folder (logic in PoolCache)
- ✅ No separate monitoring/safety folders (inline in Agent.ts)
- ✅ Minimal utils (only essential helpers)

---

## Key Technical Decisions

### 1. Event Subscription Method
**MVP Decision:** **Dual mode (WebSocket + Polling)** - Both enabled by default

**Why both?**
- WebSocket: Real-time events for instant reaction
- Polling: Catches missed events, more reliable
- Redundancy: If WS disconnects, polling continues
- Hackathon-proof: Works even with flaky connections

**Configuration:**
```bash
USE_WEBSOCKET=true   # Enable real-time events
USE_POLLING=true     # Enable block polling
POLLING_INTERVAL_MS=12000  # Poll every block (~12s)
```

### 2. State Management
**MVP Decision:** **In-memory only** (No database, no Redis)

**Why in-memory?**
- Simple: No external dependencies
- Fast: O(1) lookups with Map/Set
- Hackathon-friendly: Less setup, less to break
- Sufficient: With pruning, can handle 100+ blocks of data

**Implementation:**
- Use JavaScript `Map` for O(1) pool lookups
- Use arrays for swap history per pool
- Prune old data every execution cycle
- Accept that data is lost on restart (acceptable for MVP)

**Memory Management:**
- Max 1000 swaps per pool
- Keep last 100 blocks of data
- Estimated memory: ~50-100MB for 100 active pools

### 3. Opportunity Selection Strategy (MVP - Simplified)
**MVP Decision:** **Simple scoring formula** (no ML, no complex math)

**Scoring Formula:**
```typescript
opportunityScore = (
  (volumeScore * 0.4) +      // 40% weight on volume
  (slippageScore * 0.4) +    // 40% weight on slippage
  (recencyScore * 0.2)       // 20% weight on how recent
)

where:
  volumeScore = normalize(totalVolumeUSD, 0, maxVolumeUSD) * 100
  slippageScore = normalize(avgSlippage, 0, 10%) * 100
  recencyScore = (currentBlock - lastUpdateBlock < 5) ? 100 : 50
```

**Why this approach?**
- Simple to implement and debug
- Volume = opportunity size
- Slippage = inefficiency to exploit
- Recency = active market
- No training data needed
- Deterministic and explainable

### 4. Execution Strategy (MVP - Interval-Based)
**MVP Decision:** **Interval-based execution** (not event-driven)

**How it works:**
1. Background: Continuously collect swap events into cache
2. Timer: Every X seconds (e.g., 30s), wake up and:
   - Query cache for top N pools
   - Calculate scores and filter by profit threshold
   - Execute backruns for top opportunities
3. Prune old data and repeat

**Why interval-based?**
- Simpler than event-driven architecture
- Allows batching of analysis
- Prevents spam/over-execution
- More predictable resource usage
- Easier to debug and monitor

**Configuration:**
```bash
EXECUTION_INTERVAL_MS=30000  # Execute every 30 seconds
TOP_POOLS_COUNT=10           # Consider top 10 pools
MAX_CONCURRENT_TXS=3         # Execute max 3 backruns per cycle
```

**Execution Flow:**
```
[Swap Events] ──▶ [Cache] ──▶ [Timer Triggers] ──▶ [Query Top Pools] ──▶ [Execute Backruns]
                     ▲                                       │
                     └───────────[Prune Old Data]◀───────────┘
```

---

## Testing Strategy

### Unit Tests
- Event decoding accuracy
- Statistics calculations
- Opportunity ranking algorithm
- Gas price estimation

### Integration Tests
- Full event listener → analytics → execution flow
- Reflex SDK integration
- Error handling and recovery

### Simulation Tests
- Backtest against historical data
- Measure success rate and profitability
- Optimize parameters (thresholds, amounts, etc.)

---

## Deployment Checklist

- [ ] Environment variables configured
- [ ] Private key securely stored
- [ ] RPC endpoints tested
- [ ] Reflex Router address verified
- [ ] Initial wallet funded
- [ ] Monitoring dashboard setup
- [ ] Alert system configured
- [ ] Backup and recovery plan
- [ ] Rate limiting configured
- [ ] Circuit breaker tested

---

## Performance Optimization

### Optimization Opportunities
1. **Batch RPC calls** - Use multicall for pool data
2. **Cache pool metadata** - Reduce redundant calls
3. **Parallel processing** - Analyze multiple pools concurrently
4. **Memory management** - Prune old data regularly
5. **Connection pooling** - Reuse WebSocket connections

### Benchmarks to Track
- Event processing latency: < 100ms
- Opportunity analysis time: < 500ms
- Transaction submission time: < 1s
- Memory usage: < 500MB
- RPC call rate: < 100/minute

---

## Future Enhancements

### Phase 8+
1. **Multi-DEX support** - Sushiswap, Curve, Balancer
2. **Cross-chain** - Support multiple EVM chains
3. **Advanced ML** - Neural networks for prediction
4. **MEV bundles** - Flashbots integration
5. **Social signals** - Twitter, Discord sentiment
6. **Liquidity provision** - Automated LP management
7. **Dashboard** - Web UI for monitoring
8. **API** - REST/GraphQL API for external integrations

---

## Resources

### Documentation
- [Uniswap V3 Core](https://docs.uniswap.org/contracts/v3/overview)
- [Reflex SDK Documentation](../sdk/README.md)
- [Ethers.js Documentation](https://docs.ethers.org/v6/)

### Tools
- [Tenderly](https://tenderly.co/) - Transaction simulation
- [Dune Analytics](https://dune.com/) - Historical pool data
- [TheGraph](https://thegraph.com/) - Uniswap V3 subgraph

### Monitoring
- [Grafana](https://grafana.com/) - Metrics visualization
- [Prometheus](https://prometheus.io/) - Time-series metrics
- [Sentry](https://sentry.io/) - Error tracking

---

## MVP Slippage Calculation Details

### How to Calculate Effective Slippage

**Slippage** = Difference between expected price and actual execution price

**For Uniswap V3:**
```typescript
function calculateSlippage(
  amount0: bigint,
  amount1: bigint,
  sqrtPriceX96Before: bigint,
  sqrtPriceX96After: bigint,
  zeroForOne: boolean
): number {
  // Calculate effective price from the swap
  const effectivePrice = Math.abs(Number(amount1)) / Math.abs(Number(amount0));
  
  // Calculate expected price from sqrtPriceX96Before
  const Q96 = 2n ** 96n;
  const priceBefore = Number(sqrtPriceX96Before * sqrtPriceX96Before) / Number(Q96 * Q96);
  
  // Slippage = (effectivePrice - expectedPrice) / expectedPrice
  const slippage = ((effectivePrice - priceBefore) / priceBefore) * 100;
  
  return Math.abs(slippage);
}
```

**Why track slippage?**
- High slippage = inefficient swaps = backrun opportunity
- Slippage indicates price impact and liquidity depth
- Users paying high slippage = MEV we can capture

---

## Questions & Considerations (MVP)

1. **Which blockchain?** Start with Ethereum mainnet or a testnet (Goerli/Sepolia)
2. **Initial capital?** Small amount for MVP (~0.1-1 ETH)
3. **Risk per trade?** Conservative for MVP (max 10% of balance per tx)
4. **Gas price?** Set MAX_GAS_PRICE_GWEI to avoid overpaying
5. **Profit threshold?** Start high ($10-50 USD) to ensure profitability
6. **Token pairs?** Focus on major pairs (WETH/USDC, WETH/USDT) for MVP
7. **Private RPC?** Not needed for MVP, can add later for production

---

## Success Metrics

### Technical Metrics
- **Uptime:** > 99%
- **Event detection accuracy:** > 95%
- **Transaction success rate:** > 80%
- **Average latency:** < 2 seconds

### Business Metrics
- **Profitability:** Positive after gas costs
- **ROI:** > X% monthly
- **Win rate:** > 60%
- **Average profit per trade:** > minimum threshold

---

---

## MVP Core Features Summary

### ✅ What's Included (MVP)
1. **Dual event listening** (WebSocket + Polling)
2. **In-memory pool cache** with automatic pruning
3. **Slippage calculation** from swap events
4. **Interval-based execution** (query cache, execute backruns)
5. **Environment-based config** (all from .env)
6. **Basic logging** with Winston
7. **Reflex SDK integration** for backruns
8. **Simple opportunity scoring** (volume + slippage)
9. **Gas price protection**
10. **Profit threshold filtering**

### ❌ What's NOT Included (Post-Hackathon)
1. ~~Machine learning / Pattern recognition~~
2. ~~Database / Redis persistence~~
3. ~~Advanced analytics / anomaly detection~~
4. ~~Multi-DEX support~~
5. ~~Flashbots / MEV bundles~~
6. ~~Web dashboard~~
7. ~~Comprehensive testing suite~~
8. ~~Complex profit prediction~~

---

## Quick Start Guide (MVP)

```bash
# 1. Setup
cd agent
npm install

# 2. Configure
cp .env.example .env
# Edit .env with your values

# 3. Run
npm run dev

# 4. Monitor logs
# Watch for "✅ Backrun successful" messages
```

---

**Next Steps for Hackathon:**
1. ✅ Review this simplified MVP plan
2. Start Day 1: Setup project and event listener
3. Day 2: Integrate Reflex SDK and execution logic
4. Day 3: Test, polish, and prepare demo
5. 🎉 Demo your working MEV agent!

