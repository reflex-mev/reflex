/**
 * Reflex SDK Examples
 *
 * This directory contains comprehensive examples of using the Reflex SDK
 * for various MEV backrunning scenarios.
 */

export { basicExample } from './basic';
export {
  uniswapV2Example,
  getV2PairAddress,
  createV2SwapCalldata,
} from './uniswapv2';
export {
  uniswapV3Example,
  encodeV3Path,
  computeV3PoolAddress,
  createV3ExactInputCalldata,
} from './uniswapv3';

/**
 * Run all examples in sequence
 */
export async function runAllExamples() {
  console.log('🚀 Running all Reflex SDK examples...\n');

  try {
    const { basicExample } = await import('./basic');
    await basicExample();

    console.log('\n' + '='.repeat(50) + '\n');

    const { uniswapV2Example } = await import('./uniswapv2');
    await uniswapV2Example();

    console.log('\n' + '='.repeat(50) + '\n');

    const { uniswapV3Example } = await import('./uniswapv3');
    await uniswapV3Example();

    console.log('\n✅ All examples completed successfully!');
  } catch (error) {
    console.error('❌ Error running examples:', error);
  }
}

// Run all examples if this file is executed directly
if (require.main === module) {
  runAllExamples().catch(console.error);
}
