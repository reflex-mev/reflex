import { TradingAgent } from './Agent';
import { logger } from './utils/logger';

/**
 * Main entry point for the Reflex Trading Agent
 */
async function main() {
  try {
    // Create and start the trading agent
    const agent = new TradingAgent();
    await agent.start();
  } catch (error) {
    logger.error('Fatal error', error);
    process.exit(1);
  }
}

// Run the agent
main();
