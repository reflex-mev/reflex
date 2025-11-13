import dotenv from 'dotenv';

// Load environment variables
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
  pollingIntervalMs: number;
  
  // Monitoring
  blocksToAnalyze: number;
  topPoolsCount: number;
  minSwapSizeUSD: number;
  
  // Execution
  executionIntervalMs: number;
  maxGasPrice: string;
  minProfitThresholdUSD: number;
  maxConcurrentTxs: number;
  
  // Analytics
  statisticsWindowBlocks: number;
  slippageThreshold: number;
  
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
  pollingIntervalMs: parseInt(process.env.POLLING_INTERVAL_MS || '12000'),
  
  // Monitoring
  blocksToAnalyze: parseInt(process.env.BLOCKS_TO_ANALYZE || '10'),
  topPoolsCount: parseInt(process.env.TOP_POOLS_COUNT || '10'),
  minSwapSizeUSD: parseFloat(process.env.MIN_SWAP_SIZE_USD || '1000'),
  
  // Execution
  executionIntervalMs: parseInt(process.env.EXECUTION_INTERVAL_MS || '30000'),
  maxGasPrice: process.env.MAX_GAS_PRICE_GWEI || '100',
  minProfitThresholdUSD: parseFloat(process.env.MIN_PROFIT_THRESHOLD_USD || '10'),
  maxConcurrentTxs: parseInt(process.env.MAX_CONCURRENT_TXS || '3'),
  
  // Analytics
  statisticsWindowBlocks: parseInt(process.env.STATISTICS_WINDOW_BLOCKS || '100'),
  slippageThreshold: parseFloat(process.env.SLIPPAGE_THRESHOLD || '5'),
  
  // Logging
  logLevel: (process.env.LOG_LEVEL as any) || 'info',
};

/**
 * Validates the configuration and throws an error if required fields are missing
 */
export function validateConfig(): void {
  const errors: string[] = [];
  
  if (!config.rpcUrl) {
    errors.push('RPC_URL is required');
  }
  
  if (!config.reflexRouterAddress) {
    errors.push('REFLEX_ROUTER_ADDRESS is required');
  }
  
  if (!config.privateKey) {
    errors.push('PRIVATE_KEY is required');
  }
  
  if (!config.useWebSocket && !config.usePolling) {
    errors.push('At least one event source (WebSocket or Polling) must be enabled');
  }
  
  if (config.chainId <= 0) {
    errors.push('CHAIN_ID must be a positive integer');
  }
  
  if (config.executionIntervalMs < 1000) {
    errors.push('EXECUTION_INTERVAL_MS must be at least 1000ms');
  }
  
  if (errors.length > 0) {
    throw new Error('Configuration validation failed:\n' + errors.join('\n'));
  }
}
