import { ethers } from 'ethers';
import { ReflexSDK } from '../ReflexSDK';
import { ExecuteParams, BackrunParams } from '../types';

/**
 * Uniswap V3 backrunn    const multiHopResult = await reflexSDK.backrunedExecute(multiHopExecute, [multiHopBackrun]);
    console.log("✅ Multi-hop result:", {
      success: multiHopResult.success,
      profits: multiHopResult.profits.map(p => ethers.formatEther(p)),
      profitTokens: multiHopResult.profitTokens,
    });ample using Reflex SDK
 * 
 * This example demonstrates:
 * - Monitoring Uniswap V3 concentrated liquidity swaps
 * - Executing arbitrage on V3 pools with different fee tiers
 * - Handling V3's tick-based liquidity system
 * - Cross-tier arbitrage (0.05%, 0.3%, 1% fee pools)
 */

// Uniswap V3 Router address on mainnet
const UNISWAP_V3_ROUTER = '0xE592427A0AEce92De3Edee1F18E0157C05861564';
const UNISWAP_V3_ROUTER_V2 = '0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45';

// Common Uniswap V3 pools with different fee tiers
const WETH_USDC_V3_005 = '0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640'; // 0.05% fee
const WETH_USDC_V3_03 = '0x8ad599c3A0ff1De082011EFDDc58f1908eb6e6D8'; // 0.3% fee
const WETH_USDC_V3_1 = '0x7BeA39867e4169DBe237d55C8242a8f2fcDcc387'; // 1% fee

const WETH_USDT_V3_03 = '0x4e68Ccd3E89f51C3074ca5072bbAC773960dFa36'; // 0.3% fee
const WETH_USDT_V3_1 = '0xF0bf4Db7Ff6c0F0e6Bb71B7F7C1BdC0d4AcC5c6E'; // 1% fee

async function uniswapV3Example() {
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
    defaultGasLimit: 1000000n, // Higher gas limit for V3 operations
    gasPriceMultiplier: 1.3, // Higher multiplier for V3 MEV due to competition
  });

  try {
    console.log('🌊 Starting Uniswap V3 backrunning example...');

    // Example 1: Backrun a V3 exact input swap
    console.log('\n📝 Example 1: Backrunning V3 Exact Input Swap');

    // Simulate swapping 1 ETH for USDC on V3 (0.05% fee tier)
    const exactInputParams = {
      tokenIn: '0xC02aaA39b223FE8d0A0e5C4F27eAD9083C756Cc2', // WETH
      tokenOut: '0xA0b86a33E6441Bc0b32a3e6e2c1e01b6e1e5E2f0', // USDC
      fee: 500, // 0.05%
      recipient: wallet.address,
      deadline: Math.floor(Date.now() / 1000) + 1800,
      amountIn: ethers.parseEther('1'),
      amountOutMinimum: ethers.parseUnits('3000', 6), // Min 3000 USDC
      sqrtPriceLimitX96: 0,
    };

    const swapCalldata = new ethers.Interface([
      'function exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160)) external payable returns (uint256)',
    ]).encodeFunctionData('exactInputSingle', [exactInputParams]);

    const executeParams: ExecuteParams = {
      target: UNISWAP_V3_ROUTER,
      value: ethers.parseEther('1'), // 1 ETH
      callData: swapCalldata,
    };

    const backrunParams: BackrunParams = {
      triggerPoolId: WETH_USDC_V3_005, // 0.05% fee tier pool
      swapAmountIn: ethers.parseEther('0.8'), // 0.8 ETH arbitrage
      token0In: false, // USDC is token0, WETH is token1 in this pool
      recipient: wallet.address,
    };

    console.log('Executing V3 backruned execute...');
    const result = await reflexSDK.backrunedExecute(executeParams, [
      backrunParams,
    ]);
    console.log('✅ V3 backrun result:', {
      profits: result.profits.map(p => ethers.formatEther(p)),
      profitTokens: result.profitTokens,
      txHash: result.transactionHash,
    });

    // Example 2: Cross-tier arbitrage setup (0.05% vs 0.3% fee pools)
    console.log('\n⚖️ Example 2: Cross-Tier Arbitrage Setup');

    // Create execute params for different fee tier swap
    const crossTierCalldata = new ethers.Interface([
      'function exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))',
    ]).encodeFunctionData('exactInputSingle', [
      {
        tokenIn: '0xC02aaA39b223FE8d0A0e5C4F27eAD9083C756Cc2', // WETH
        tokenOut: '0xA0b86a33E6441Bc0b32a3e6e2c1e01b6e1e5E2f0', // USDC
        fee: 500, // 0.05% fee tier
        recipient: wallet.address,
        deadline: Math.floor(Date.now() / 1000) + 1800,
        amountIn: ethers.parseEther('1'),
        amountOutMinimum: 0,
        sqrtPriceLimitX96: 0,
      },
    ]);

    const executeParams2: ExecuteParams = {
      target: UNISWAP_V3_ROUTER,
      value: ethers.parseEther('0'),
      callData: crossTierCalldata,
    };

    const backrunParams2: BackrunParams = {
      triggerPoolId: WETH_USDC_V3_005,
      swapAmountIn: ethers.parseEther('2'),
      token0In: false, // Use USDC as input
      recipient: wallet.address,
    };

    const crossTierResult = await reflexSDK.backrunedExecute(executeParams2, [
      backrunParams2,
    ]);
    console.log('✅ Cross-tier arbitrage result:', {
      profits: crossTierResult.profits.map(p => ethers.formatEther(p)),
      profitTokens: crossTierResult.profitTokens,
      txHash: crossTierResult.transactionHash,
    });

    // Example 3: V3 Multi-hop swap backrun
    console.log('\n🔗 Example 3: Multi-hop Swap Backrun');

    // Multi-hop: WETH -> USDC -> USDT
    const multiHopParams = {
      path: ethers.solidityPacked(
        ['address', 'uint24', 'address', 'uint24', 'address'],
        [
          '0xC02aaA39b223FE8d0A0e5C4F27eAD9083C756Cc2', // WETH
          500, // 0.05% fee
          '0xA0b86a33E6441Bc0b32a3e6e2c1e01b6e1e5E2f0', // USDC
          500, // 0.05% fee
          '0xdAC17F958D2ee523a2206206994597C13D831ec7', // USDT
        ]
      ),
      recipient: wallet.address,
      deadline: Math.floor(Date.now() / 1000) + 1800,
      amountIn: ethers.parseEther('2'),
      amountOutMinimum: ethers.parseUnits('6000', 6), // Min 6000 USDT
    };

    const multiHopCalldata = new ethers.Interface([
      'function exactInput((bytes,address,uint256,uint256,uint256)) external payable returns (uint256)',
    ]).encodeFunctionData('exactInput', [multiHopParams]);

    const multiHopExecute: ExecuteParams = {
      target: UNISWAP_V3_ROUTER,
      value: ethers.parseEther('2'),
      callData: multiHopCalldata,
    };

    const multiHopBackrun: BackrunParams = {
      triggerPoolId: WETH_USDT_V3_03, // Final pool in the path
      swapAmountIn: ethers.parseEther('1.5'),
      token0In: true,
      recipient: wallet.address,
    };

    console.log('Executing multi-hop swap + backrun...');
    const multiHopResult = await reflexSDK.backrunedExecute(multiHopExecute, [
      multiHopBackrun,
    ]);
    console.log('✅ Multi-hop backrun result:', {
      success: multiHopResult.success,
      profits: multiHopResult.profits.map(p => ethers.formatEther(p)),
      profitTokens: multiHopResult.profitTokens,
    });

    // Example 4: Monitor V3 pools across fee tiers
    console.log('\n👁️ Example 4: Monitoring V3 Pools');

    const v3Pools = [WETH_USDC_V3_005, WETH_USDC_V3_03, WETH_USDC_V3_1];
    const feeTiers = ['0.05%', '0.3%', '1%'];

    const unsubscribe = reflexSDK.watchBackrunExecuted((event: any) => {
      const poolIndex = v3Pools.findIndex(
        pool => pool.toLowerCase() === event.triggerPoolId.toLowerCase()
      );
      const feeTier = poolIndex >= 0 ? feeTiers[poolIndex] : 'Unknown';

      console.log('🌊 V3 backrun detected:', {
        feeTier,
        poolId: event.triggerPoolId,
        profit: ethers.formatEther(event.profit),
        profitToken: event.profitToken,
        profitUSD:
          event.profitToken.toLowerCase().includes('usdc') ||
          event.profitToken.toLowerCase().includes('usdt')
            ? ethers.formatUnits(event.profit, 6)
            : 'N/A',
      });
    });

    console.log('✅ Monitoring V3 pools across fee tiers...');

    // Example 5: Gas estimation for backruned execute
    console.log('\n📊 Example 5: Gas Estimation');

    // Get gas estimate for backruned execute
    const gasEstimate = await reflexSDK.estimateBackrunedExecuteGas(
      executeParams2,
      [backrunParams2]
    );
    console.log('✅ Backruned execute gas estimate:', gasEstimate.toString());

    // Example 6: Function encoding for batch operations
    console.log('\n📦 Example 6: Function Encoding');

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
      console.log('🛑 V3 monitoring stopped');
    }, 45000);
  } catch (error) {
    console.error('❌ Uniswap V3 example error:', error);
  }
}

// Helper function to encode V3 path for multi-hop swaps
function encodeV3Path(tokens: string[], fees: number[]): string {
  if (tokens.length !== fees.length + 1) {
    throw new Error('Invalid path: tokens length must be fees length + 1');
  }

  let path = tokens[0];
  for (let i = 0; i < fees.length; i++) {
    path += fees[i].toString(16).padStart(6, '0') + tokens[i + 1].slice(2);
  }

  return path;
}

// Helper function to calculate V3 pool address
function computeV3PoolAddress(
  tokenA: string,
  tokenB: string,
  fee: number,
  factory: string = '0x1F98431c8aD98523631AE4a59f267346ea31F984'
): string {
  // Sort tokens
  const [token0, token1] =
    tokenA.toLowerCase() < tokenB.toLowerCase()
      ? [tokenA, tokenB]
      : [tokenB, tokenA];

  // Compute CREATE2 address
  const salt = ethers.solidityPackedKeccak256(
    ['address', 'address', 'uint24'],
    [token0, token1, fee]
  );

  const initCodeHash =
    '0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54';

  return ethers.getCreate2Address(factory, salt, initCodeHash);
}

// Helper function to create V3 exact input swap calldata
function createV3ExactInputCalldata(
  tokenIn: string,
  tokenOut: string,
  fee: number,
  recipient: string,
  deadline: number,
  amountIn: bigint,
  amountOutMinimum: bigint,
  sqrtPriceLimitX96: bigint = 0n
): string {
  const routerInterface = new ethers.Interface([
    'function exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160)) external payable returns (uint256)',
  ]);

  return routerInterface.encodeFunctionData('exactInputSingle', [
    {
      tokenIn,
      tokenOut,
      fee,
      recipient,
      deadline,
      amountIn,
      amountOutMinimum,
      sqrtPriceLimitX96,
    },
  ]);
}

// Run example if this file is executed directly
if (require.main === module) {
  uniswapV3Example().catch(console.error);
}

export {
  uniswapV3Example,
  encodeV3Path,
  computeV3PoolAddress,
  createV3ExactInputCalldata,
};
