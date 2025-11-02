#!/usr/bin/env ts-node
/**
 * Simple script to test backrunedExecute on blockchain
 *
 * Usage:
 *   REFLEX_ROUTER_ADDRESS=0x... \
 *   TEST_POOL_ADDRESS=0x... \
 *   npx ts-node scripts/test-blockchain.ts
 */

import { ethers } from 'ethers';
import { ReflexSDK } from '../src/ReflexSDK';
import { ExecuteParams, BackrunParams } from '../src/types';

// Uniswap V3 SwapRouter ABI for exactInputSingle
const SWAP_ROUTER_ABI = [
  {
    inputs: [
      {
        components: [
          {
            internalType: 'address',
            name: 'tokenIn',
            type: 'address',
          },
          {
            internalType: 'address',
            name: 'tokenOut',
            type: 'address',
          },
          {
            internalType: 'uint24',
            name: 'fee',
            type: 'uint24',
          },
          {
            internalType: 'address',
            name: 'recipient',
            type: 'address',
          },
          {
            internalType: 'uint256',
            name: 'deadline',
            type: 'uint256',
          },
          {
            internalType: 'uint256',
            name: 'amountIn',
            type: 'uint256',
          },
          {
            internalType: 'uint256',
            name: 'amountOutMinimum',
            type: 'uint256',
          },
          {
            internalType: 'uint160',
            name: 'sqrtPriceLimitX96',
            type: 'uint160',
          },
        ],
        internalType: 'struct ISwapRouter.ExactInputSingleParams',
        name: 'params',
        type: 'tuple',
      },
    ],
    name: 'exactInputSingle',
    outputs: [
      {
        internalType: 'uint256',
        name: 'amountOut',
        type: 'uint256',
      },
    ],
    stateMutability: 'payable',
    type: 'function',
  },
];

// ERC20 ABI for approve function
const ERC20_ABI = [
  {
    inputs: [
      { internalType: 'address', name: 'spender', type: 'address' },
      { internalType: 'uint256', name: 'amount', type: 'uint256' },
    ],
    name: 'approve',
    outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
    stateMutability: 'nonpayable',
    type: 'function',
  },
  {
    inputs: [{ internalType: 'address', name: 'account', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [],
    name: 'symbol',
    outputs: [{ internalType: 'string', name: '', type: 'string' }],
    stateMutability: 'view',
    type: 'function',
  },
];

// Configuration
const config = {
  rpcUrl: process.env.TEST_RPC_URL || 'http://localhost:8545',
  privateKey:
    process.env.TEST_PRIVATE_KEY ||
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80', // Default Anvil key
  routerAddress: process.env.REFLEX_ROUTER_ADDRESS,
  poolAddress: process.env.TEST_POOL_ADDRESS,
  // Uniswap V3 SwapRouter address (mainnet/forks)
  swapRouterAddress:
    process.env.SWAP_ROUTER_ADDRESS ||
    '0xE592427A0AEce92De3Edee1F18E0157C05861564',
  // Swap parameters
  tokenIn: process.env.TOKEN_IN, // Token to swap from
  tokenOut: process.env.TOKEN_OUT, // Token to swap to
  swapFee: process.env.SWAP_FEE || '500', // Pool fee (500, 3000, 10000)
  swapAmountIn: process.env.SWAP_AMOUNT_IN || '0.01', // Amount to swap
  minAmountOut: process.env.MIN_AMOUNT_OUT || '480000', // Minimum output (0 for testing)
  // Optional config ID for profit splitting
  configId: process.env.TEST_CONFIG_ID,
};

/**
 * Converts a value to bytes32 format by padding with zeros if needed
 * @param value - Ethereum address or bytes32 string
 * @returns bytes32 representation (0x prefixed, 32 bytes)
 */
function toBytes32(value: string): string {
  // Remove 0x prefix if present
  const cleanValue = value.toLowerCase().replace(/^0x/, '');

  // If already 64 characters (32 bytes), just return with 0x prefix
  if (cleanValue.length === 64) {
    return '0x' + cleanValue;
  }

  // If it's an address (40 characters / 20 bytes), pad to 32 bytes
  if (cleanValue.length === 40) {
    // Pad with zeros at the start to make it 32 bytes (64 hex chars)
    return '0x' + '0'.repeat(24) + cleanValue;
  }

  // For any other length, pad with zeros at the start
  if (cleanValue.length < 64) {
    return '0x' + '0'.repeat(64 - cleanValue.length) + cleanValue;
  }

  // If longer than 64 characters, truncate from the left (keep rightmost 64 chars)
  return '0x' + cleanValue.slice(-64);
}

async function main() {
  console.log('🚀 Testing backrunedExecute\n');

  // Validate required configuration
  if (!config.routerAddress) {
    console.error(
      '❌ Error: REFLEX_ROUTER_ADDRESS environment variable is required'
    );
    console.log('\nUsage:');
    console.log(
      '  REFLEX_ROUTER_ADDRESS=0x... TEST_POOL_ADDRESS=0x... npx ts-node scripts/test-blockchain.ts\n'
    );
    process.exit(1);
  }

  if (!config.poolAddress) {
    console.error(
      '❌ Error: TEST_POOL_ADDRESS environment variable is required'
    );
    console.log('\nUsage:');
    console.log(
      '  REFLEX_ROUTER_ADDRESS=0x... TEST_POOL_ADDRESS=0x... npx ts-node scripts/test-blockchain.ts\n'
    );
    process.exit(1);
  }

  try {
    // Initialize provider and signer
    console.log('📡 Connecting to blockchain...');
    const provider = new ethers.JsonRpcProvider(config.rpcUrl);
    const signer = new ethers.Wallet(config.privateKey, provider);

    const network = await provider.getNetwork();
    const signerAddress = await signer.getAddress();
    const balance = await provider.getBalance(signerAddress);

    console.log(
      `✅ Connected to ${network.name} (chainId: ${network.chainId})`
    );
    console.log(`👤 Account: ${signerAddress}`);
    console.log(`💰 Balance: ${ethers.formatEther(balance)} ETH\n`);

    if (balance === 0n) {
      throw new Error('Test account has no balance');
    }

    // Initialize SDK
    console.log(`🎯 Initializing ReflexSDK...`);
    console.log(`   Router: ${config.routerAddress}`);
    const sdk = new ReflexSDK(provider, signer, config.routerAddress);

    // Prepare execute parameters - encode Uniswap V3 swap
    let executeParams: ExecuteParams;

    if (config.tokenIn && config.tokenOut) {
      // Encode exactInputSingle swap
      const swapInterface = new ethers.Interface(SWAP_ROUTER_ABI);
      const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes

      // Determine swap direction based on token addresses
      const token0 =
        config.tokenIn.toLowerCase() < config.tokenOut.toLowerCase()
          ? config.tokenIn
          : config.tokenOut;
      const isToken0In = config.tokenIn.toLowerCase() === token0.toLowerCase();

      // Use Uniswap V3 min/max sqrt price limit values
      // MIN_SQRT_RATIO + 1 and MAX_SQRT_RATIO - 1 from Uniswap V3
      const MIN_SQRT_RATIO = BigInt('4295128739') + 1n;
      const MAX_SQRT_RATIO =
        BigInt('1461446703485210103287273052203988822378723970342') - 1n;

      // Set sqrtPriceLimitX96 based on swap direction
      // If selling token0 for token1: use max (allow price to go up)
      // If selling token1 for token0: use min (allow price to go down)
      const sqrtPriceLimitX96 = isToken0In ? MAX_SQRT_RATIO : MIN_SQRT_RATIO;

      const swapParams = {
        tokenIn: config.tokenIn,
        tokenOut: config.tokenOut,
        fee: parseInt(config.swapFee),
        recipient: signerAddress,
        deadline: deadline,
        amountIn: ethers.parseEther(config.swapAmountIn),
        amountOutMinimum: BigInt(config.minAmountOut),
        sqrtPriceLimitX96: sqrtPriceLimitX96,
      };

      const swapCallData = swapInterface.encodeFunctionData(
        'exactInputSingle',
        [swapParams]
      );

      executeParams = {
        target: config.swapRouterAddress,
        value: 0n, // Set to amountIn if tokenIn is WETH and you want to use ETH
        callData: swapCallData,
      };

      console.log(`\n💱 Swap Configuration:`);
      console.log(`   Token In: ${config.tokenIn}`);
      console.log(`   Token Out: ${config.tokenOut}`);
      console.log(`   Fee Tier: ${config.swapFee}`);
      console.log(`   Amount In: ${config.swapAmountIn} tokens`);
      console.log(`   Min Amount Out: ${config.minAmountOut} tokens`);
      console.log(
        `   Price Limit: ${isToken0In ? 'MAX' : 'MIN'} (no price restriction)`
      );
    } else {
      // No swap, empty execute
      executeParams = {
        target: ethers.ZeroAddress,
        value: 0n,
        callData: '0x',
      };
      console.log(`\n⏭️  No swap configured (TOKEN_IN and TOKEN_OUT not set)`);
    }

    // Prepare backrun parameters
    const backrunParams: BackrunParams[] = [
      {
        triggerPoolId: toBytes32(config.poolAddress),
        swapAmountIn: ethers.parseEther(config.swapAmountIn),
        token0In: true,
        recipient: signerAddress,
        ...(config.configId !== undefined && { configId: config.configId }),
      },
    ];

    console.log(`\n📋 Execute Parameters:`);
    console.log(`   Target: ${executeParams.target}`);
    console.log(`   Value: ${ethers.formatEther(executeParams.value)} ETH`);
    console.log(`   CallData: ${executeParams.callData}`);

    console.log(`\n📋 Backrun Parameters:`);
    backrunParams.forEach((params, i) => {
      console.log(`   [${i}] Pool: ${params.triggerPoolId}`);
      console.log(
        `       Swap Amount: ${ethers.formatEther(params.swapAmountIn)} ETH`
      );
      console.log(`       Token0In: ${params.token0In}`);
      console.log(`       Recipient: ${params.recipient}`);
      if (params.configId !== undefined) {
        console.log(`       Config ID: ${params.configId}`);
      }
    });

    // Approve tokens for Reflex Router if needed
    if (config.tokenIn && config.tokenOut) {
      console.log(`\n🔓 Approving tokens for Reflex Router...`);

      const tokenInContract = new ethers.Contract(
        config.tokenIn,
        ERC20_ABI,
        signer
      );

      // Get token symbol for better logging
      let tokenSymbol = 'TOKEN';
      try {
        tokenSymbol = await tokenInContract.symbol();
      } catch (e) {
        // Ignore if symbol() not available
      }

      // Check current balance
      const balance = await tokenInContract.balanceOf(signerAddress);
      const amountNeeded = ethers.parseEther(config.swapAmountIn);

      console.log(`   Token: ${config.tokenIn} (${tokenSymbol})`);
      console.log(`   Balance: ${ethers.formatEther(balance)} ${tokenSymbol}`);
      console.log(
        `   Amount Needed: ${ethers.formatEther(amountNeeded)} ${tokenSymbol}`
      );

      if (balance < amountNeeded) {
        throw new Error(
          `Insufficient ${tokenSymbol} balance. Have: ${ethers.formatEther(balance)}, Need: ${ethers.formatEther(amountNeeded)}`
        );
      }

      // Approve Reflex Router to spend tokens
      console.log(`   Approving Reflex Router to spend ${tokenSymbol}...`);
      const approveTx = await tokenInContract.approve(
        config.routerAddress,
        amountNeeded
      );

      console.log(`   Approval tx: ${approveTx.hash}`);
      await approveTx.wait();
      console.log(`   ✅ Approval confirmed`);
    }

    // Execute transaction
    console.log(`\n🔧 Executing backrunedExecute...`);
    const result = await sdk.backrunedExecute(executeParams, backrunParams);

    console.log(`\n✅ Transaction successful!`);
    console.log(`   Hash: ${result.transactionHash}`);
    console.log(`   Success: ${result.success}`);
    console.log(`   Return Data: ${result.returnData}`);

    if (result.profits.length > 0) {
      console.log(`\n💰 Profits:`);
      result.profits.forEach((profit, i) => {
        console.log(`   [${i}] ${ethers.formatEther(profit)} tokens`);
        console.log(`       Token: ${result.profitTokens[i]}`);
      });
    } else {
      console.log(`\n⚠️  No profits recorded`);
    }

    console.log(`\n✨ Test completed successfully!\n`);
  } catch (error: any) {
    console.error(`\n❌ Test failed: ${error.message}`);
    if (error.stack) {
      console.error(`\nStack trace:`);
      console.error(error.stack);
    }
    process.exit(1);
  }
}

// Run the test
main().catch(error => {
  console.error('Fatal error:', error);
  process.exit(1);
});
