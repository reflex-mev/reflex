import { ethers } from 'ethers';
import { ReflexSDK } from '../ReflexSDK';
import { ExecuteParams, BackrunParams } from '../types';

/**
 * Uniswap V2 backrunning example using Reflex SDK
 *
 * This example demonstrates:
 * - Monitoring Uniswap V2 swaps
 * - Executing arbitrage on Uniswap V2 pools
 * - Sandwich attacks on V2 transactions
 * - Cross-DEX arbitrage opportunities
 */

// Uniswap V2 Router address on mainnet
const UNISWAP_V2_ROUTER = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';

// Common Uniswap V2 pairs
const WETH_USDC_V2 = '0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc';
const WETH_USDT_V2 = '0x0d4a11d5EEaaC28EC3F61d100daF4d40471f1852';

async function uniswapV2Example() {
  // Set up provider and signer
  const provider = new ethers.JsonRpcProvider(
    process.env.RPC_URL || 'https://eth-mainnet.alchemyapi.io/v2/YOUR_API_KEY'
  );
  const wallet = new ethers.Wallet(
    process.env.PRIVATE_KEY || 'YOUR_PRIVATE_KEY',
    provider
  );

  // Initialize the Reflex SDK
  const reflexSDK = new ReflexSDK(provider, wallet, {
    routerAddress:
      process.env.REFLEX_ROUTER || '0x1234567890123456789012345678901234567890',
    defaultGasLimit: 800000n, // Higher gas limit for V2 operations
    gasPriceMultiplier: 1.2, // Slightly higher multiplier for MEV
  });

  try {
    console.log('🦄 Starting Uniswap V2 backrunning example...');

    // Example 1: Backrun a Uniswap V2 swap
    console.log('\n📝 Example 1: Backrunning Uniswap V2 Swap');

    // Simulate swapping 1 ETH for USDC on Uniswap V2
    const swapCalldata = new ethers.Interface([
      'function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)',
    ]).encodeFunctionData('swapExactETHForTokens', [
      ethers.parseUnits('3000', 6), // Min 3000 USDC out
      [
        '0xC02aaA39b223FE8d0A0e5C4F27eAD9083C756Cc2',
        '0xA0b86a33E6441Bc0b32a3e6e2c1e01b6e1e5E2f0',
      ], // WETH -> USDC
      wallet.address,
      Math.floor(Date.now() / 1000) + 1800, // 30 minutes deadline
    ]);

    const executeParams: ExecuteParams = {
      target: UNISWAP_V2_ROUTER,
      value: ethers.parseEther('1'), // 1 ETH
      callData: swapCalldata,
    };

    const backrunParams: BackrunParams = {
      triggerPoolId: WETH_USDC_V2, // WETH/USDC V2 pair
      swapAmountIn: ethers.parseEther('0.5'), // 0.5 ETH arbitrage
      token0In: true, // WETH is token0 in most pairs
      recipient: wallet.address,
    };

    console.log('Executing backruned execute...');
    const result = await reflexSDK.backrunedExecute(executeParams, [
      backrunParams,
    ]);
    console.log('✅ V2 backrun result:', {
      success: result.success,
      profits: result.profits.map(p => ethers.formatEther(p)),
      profitTokens: result.profitTokens,
      txHash: result.transactionHash,
    });

    // Example 2: Multiple pool backrun execution
    console.log('\n🔄 Example 2: Multiple Pool Backrun');

    // Execute backrun on another V2 pair using a different swap
    const swapCalldata2 = new ethers.Interface([
      'function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)',
    ]).encodeFunctionData('swapExactETHForTokens', [
      ethers.parseUnits('2000', 6), // Min 2000 USDT out
      [
        '0xC02aaA39b223FE8d0A0e5C4F27eAD9083C756Cc2',
        '0xdAC17F958D2ee523a2206206994597C13D831ec7',
      ], // WETH -> USDT
      wallet.address,
      Math.floor(Date.now() / 1000) + 1200, // 20 minutes from now
    ]);

    const executeParams2: ExecuteParams = {
      target: UNISWAP_V2_ROUTER,
      value: ethers.parseEther('1'), // 1 ETH swap
      callData: swapCalldata2,
    };

    const backrunParams2: BackrunParams = {
      triggerPoolId: WETH_USDT_V2,
      swapAmountIn: ethers.parseEther('2'),
      token0In: false, // Use USDT as input
      recipient: wallet.address,
    };

    const arbitrageResult = await reflexSDK.backrunedExecute(executeParams2, [
      backrunParams2,
    ]);

    console.log('✅ Multiple pool backrun result:', {
      profits: arbitrageResult.profits.map(p => ethers.formatEther(p)),
      profitTokens: arbitrageResult.profitTokens,
      txHash: arbitrageResult.transactionHash,
    });

    // Example 3: Gas estimation for backruned execute
    console.log('\n⛽ Example 3: Gas Estimation');

    const gasEstimate = await reflexSDK.estimateBackrunedExecuteGas(
      executeParams2,
      [backrunParams2]
    );
    console.log('✅ Backruned execute gas estimate:', gasEstimate.toString());

    // Example 4: Monitor V2 pair events
    console.log('\n👁️ Example 4: Monitoring V2 Pair Events');

    const unsubscribe = reflexSDK.watchBackrunExecuted(
      (event: any) => {
        console.log('🎯 V2 backrun detected:', {
          poolId: event.triggerPoolId,
          profit: ethers.formatEther(event.profit),
          profitToken: event.profitToken,
          isWETHUSDC:
            event.triggerPoolId.toLowerCase() === WETH_USDC_V2.toLowerCase(),
          isWETHUSDT:
            event.triggerPoolId.toLowerCase() === WETH_USDT_V2.toLowerCase(),
        });
      },
      {
        // Filter for our target V2 pairs
        triggerPoolId: WETH_USDC_V2,
      }
    );

    console.log('✅ Monitoring V2 pairs for backrun opportunities...');

    // Example 5: Function encoding for batch operations
    console.log('\n📦 Example 5: Function Encoding');

    // Encode backruned execute operation
    const encodedOperation = reflexSDK.encodeBackrunedExecute(executeParams2, [
      backrunParams2,
    ]);
    console.log(
      '✅ Encoded backruned execute operation:',
      encodedOperation.slice(0, 20) + '...'
    );

    // Clean up after demonstration
    setTimeout(() => {
      unsubscribe();
      console.log('🛑 V2 monitoring stopped');
    }, 30000);
  } catch (error) {
    console.error('❌ Uniswap V2 example error:', error);
  }
}

// Helper function to get V2 pair address
function getV2PairAddress(tokenA: string, tokenB: string): string {
  // This is a simplified version - in practice you'd use the factory contract
  // to compute the pair address or query it from a subgraph
  const factory = '0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f';
  // Implementation would calculate CREATE2 address here
  return ethers
    .solidityPackedKeccak256(
      ['bytes'],
      [
        ethers.solidityPacked(
          ['address', 'address', 'address'],
          [factory, tokenA, tokenB]
        ),
      ]
    )
    .slice(0, 42);
}

// Helper function to create V2 swap calldata
function createV2SwapCalldata(
  amountIn: bigint,
  amountOutMin: bigint,
  path: string[],
  to: string,
  deadline: number
): string {
  const routerInterface = new ethers.Interface([
    'function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)',
    'function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)',
    'function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)',
  ]);

  return routerInterface.encodeFunctionData('swapExactTokensForTokens', [
    amountIn,
    amountOutMin,
    path,
    to,
    deadline,
  ]);
}

// Run example if this file is executed directly
if (require.main === module) {
  uniswapV2Example().catch(console.error);
}

export { uniswapV2Example, getV2PairAddress, createV2SwapCalldata };
