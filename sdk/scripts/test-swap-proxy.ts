#!/usr/bin/env ts-node
/**
 * Test script for BackrunEnabledSwapProxy contract
 *
 * This script demonstrates how to use the BackrunEnabledSwapProxy to execute
 * swaps on a target router with integrated backrun functionality.
 *
 * Usage:
 *   SWAP_PROXY_ADDRESS=0x... \
 *   TARGET_ROUTER_ADDRESS=0x... \
 *   REFLEX_ROUTER_ADDRESS=0x... \
 *   TOKEN_IN=0x... \
 *   TOKEN_OUT=0x... \
 *   TEST_POOL_ADDRESS=0x... \
 *   npx ts-node scripts/test-swap-proxy.ts
 */

import { ethers } from 'ethers';
import { BackrunParams } from '../src/types';

// BackrunEnabledSwapProxy ABI
const SWAP_PROXY_ABI = [
  {
    inputs: [
      { internalType: 'address', name: '_targetRouter', type: 'address' },
    ],
    stateMutability: 'nonpayable',
    type: 'constructor',
  },
  {
    inputs: [],
    name: 'ETHTransferFailed',
    type: 'error',
  },
  {
    inputs: [
      { internalType: 'address', name: 'token', type: 'address' },
      { internalType: 'uint256', name: 'required', type: 'uint256' },
      { internalType: 'uint256', name: 'actual', type: 'uint256' },
    ],
    name: 'InsufficientAllowance',
    type: 'error',
  },
  {
    inputs: [
      { internalType: 'address', name: 'token', type: 'address' },
      { internalType: 'uint256', name: 'required', type: 'uint256' },
      { internalType: 'uint256', name: 'actual', type: 'uint256' },
    ],
    name: 'InsufficientBalance',
    type: 'error',
  },
  {
    inputs: [],
    name: 'InvalidAmountIn',
    type: 'error',
  },
  {
    inputs: [],
    name: 'InvalidReflexRouter',
    type: 'error',
  },
  {
    inputs: [],
    name: 'InvalidTarget',
    type: 'error',
  },
  {
    inputs: [],
    name: 'InvalidTokenIn',
    type: 'error',
  },
  {
    inputs: [{ internalType: 'uint256', name: 'amount', type: 'uint256' }],
    name: 'LeftoverETHBalance',
    type: 'error',
  },
  {
    inputs: [
      { internalType: 'address', name: 'token', type: 'address' },
      { internalType: 'uint256', name: 'amount', type: 'uint256' },
    ],
    name: 'LeftoverTokenBalance',
    type: 'error',
  },
  {
    inputs: [],
    name: 'ReentrancyGuardReentrantCall',
    type: 'error',
  },
  {
    inputs: [{ internalType: 'bytes', name: 'returnData', type: 'bytes' }],
    name: 'SwapCallFailed',
    type: 'error',
  },
  {
    inputs: [
      { internalType: 'bytes', name: 'swapTxCallData', type: 'bytes' },
      { internalType: 'address', name: 'tokenIn', type: 'address' },
      { internalType: 'uint256', name: 'amountIn', type: 'uint256' },
      { internalType: 'address', name: 'reflexRouter', type: 'address' },
      {
        components: [
          { internalType: 'bytes32', name: 'triggerPoolId', type: 'bytes32' },
          { internalType: 'uint112', name: 'swapAmountIn', type: 'uint112' },
          { internalType: 'bool', name: 'token0In', type: 'bool' },
          { internalType: 'address', name: 'recipient', type: 'address' },
          { internalType: 'bytes32', name: 'configId', type: 'bytes32' },
        ],
        internalType: 'struct IReflexRouter.BackrunParams[]',
        name: 'backrunParams',
        type: 'tuple[]',
      },
    ],
    name: 'swapWithbackrun',
    outputs: [
      { internalType: 'bytes', name: 'swapReturnData', type: 'bytes' },
      { internalType: 'uint256[]', name: 'profits', type: 'uint256[]' },
      { internalType: 'address[]', name: 'profitTokens', type: 'address[]' },
    ],
    stateMutability: 'payable',
    type: 'function',
  },
  {
    inputs: [],
    name: 'targetRouter',
    outputs: [{ internalType: 'address', name: '', type: 'address' }],
    stateMutability: 'view',
    type: 'function',
  },
];

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

// ERC20 ABI
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
  {
    inputs: [],
    name: 'decimals',
    outputs: [{ internalType: 'uint8', name: '', type: 'uint8' }],
    stateMutability: 'view',
    type: 'function',
  },
  {
    inputs: [
      { internalType: 'address', name: 'owner', type: 'address' },
      { internalType: 'address', name: 'spender', type: 'address' },
    ],
    name: 'allowance',
    outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
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
  swapProxyAddress: process.env.SWAP_PROXY_ADDRESS,
  reflexRouterAddress: process.env.REFLEX_ROUTER_ADDRESS,
  poolAddress: process.env.TEST_POOL_ADDRESS,
  // Uniswap V3 SwapRouter address (mainnet/forks)
  swapRouterAddress:
    process.env.SWAP_ROUTER_ADDRESS ||
    '0xE592427A0AEce92De3Edee1F18E0157C05861564',
  // Swap parameters
  tokenIn: process.env.TOKEN_IN,
  tokenOut: process.env.TOKEN_OUT,
  swapFee: process.env.SWAP_FEE || '500', // Pool fee (500, 3000, 10000)
  swapAmountIn: process.env.SWAP_AMOUNT_IN || '0.01', // in ETH
  minAmountOut: process.env.MIN_AMOUNT_OUT || '0', // in wei
  // Backrun parameters
  backrunAmount: process.env.BACKRUN_AMOUNT || '0.01',
  token0In: process.env.TOKEN_0_IN !== 'false', // default true
  // Optional config ID for profit splitting
  configId: process.env.TEST_CONFIG_ID || ethers.ZeroHash,
};

/**
 * Converts a value to bytes32 format by padding with zeros if needed
 */
function toBytes32(value: string): string {
  const cleanValue = value.toLowerCase().replace(/^0x/, '');
  if (cleanValue.length === 64) {
    return '0x' + cleanValue;
  }
  if (cleanValue.length === 40) {
    return '0x' + '0'.repeat(24) + cleanValue;
  }
  if (cleanValue.length < 64) {
    return '0x' + '0'.repeat(64 - cleanValue.length) + cleanValue;
  }
  return '0x' + cleanValue.slice(-64);
}

async function main() {
  console.log('🚀 Testing BackrunEnabledSwapProxy\n');

  // Validate required configuration
  if (!config.swapProxyAddress) {
    console.error(
      '❌ Error: SWAP_PROXY_ADDRESS environment variable is required'
    );
    console.log('\nUsage:');
    console.log('  SWAP_PROXY_ADDRESS=0x... \\');
    console.log('  REFLEX_ROUTER_ADDRESS=0x... \\');
    console.log('  TOKEN_IN=0x... \\');
    console.log('  TOKEN_OUT=0x... \\');
    console.log('  TEST_POOL_ADDRESS=0x... \\');
    console.log('  npx ts-node scripts/test-swap-proxy.ts\n');
    process.exit(1);
  }

  if (!config.reflexRouterAddress) {
    console.error(
      '❌ Error: REFLEX_ROUTER_ADDRESS environment variable is required'
    );
    process.exit(1);
  }

  if (!config.tokenIn || !config.tokenOut) {
    console.error(
      '❌ Error: TOKEN_IN and TOKEN_OUT environment variables are required'
    );
    process.exit(1);
  }

  if (!config.poolAddress) {
    console.error(
      '❌ Error: TEST_POOL_ADDRESS environment variable is required'
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

    // Initialize contracts
    console.log('🎯 Initializing contracts...');
    const swapProxy = new ethers.Contract(
      config.swapProxyAddress,
      SWAP_PROXY_ABI,
      signer
    );

    // Verify target router
    console.log(`   Swap Proxy: ${config.swapProxyAddress}`);
    console.log(`   Reflex Router: ${config.reflexRouterAddress}`);

    // Get token information
    console.log('\n💱 Token Information:');
    const tokenInContract = new ethers.Contract(
      config.tokenIn,
      ERC20_ABI,
      signer
    );
    const tokenOutContract = new ethers.Contract(
      config.tokenOut,
      ERC20_ABI,
      signer
    );

    const [tokenInSymbol, tokenInDecimals, tokenOutSymbol, tokenOutDecimals] =
      await Promise.all([
        tokenInContract.symbol().catch(() => 'TOKEN'),
        tokenInContract.decimals().catch(() => 18),
        tokenOutContract.symbol().catch(() => 'TOKEN'),
        tokenOutContract.decimals().catch(() => 18),
      ]);

    console.log(`   Token In: ${config.tokenIn} (${tokenInSymbol})`);
    console.log(`   Token Out: ${config.tokenOut} (${tokenOutSymbol})`);

    // Check token balance
    const amountIn = ethers.parseUnits(config.swapAmountIn, tokenInDecimals);
    const tokenBalance = await tokenInContract.balanceOf(signerAddress);

    console.log(`\n💰 Token Balances:`);
    console.log(
      `   ${tokenInSymbol}: ${ethers.formatUnits(tokenBalance, tokenInDecimals)}`
    );

    if (tokenBalance < amountIn) {
      throw new Error(
        `Insufficient ${tokenInSymbol} balance. Have: ${ethers.formatUnits(tokenBalance, tokenInDecimals)}, Need: ${config.swapAmountIn}`
      );
    }

    // Approve swap proxy to spend tokens
    console.log(`\n🔓 Approving SwapProxy to spend ${tokenInSymbol}...`);
    const currentAllowance = await tokenInContract.allowance(
      signerAddress,
      config.swapProxyAddress
    );

    if (currentAllowance < amountIn) {
      const approveTx = await tokenInContract.approve(
        config.swapProxyAddress,
        amountIn
      );
      console.log(`   Approval tx: ${approveTx.hash}`);
      await approveTx.wait();
      console.log(`   ✅ Approval confirmed`);
    } else {
      console.log(`   ✅ Already approved`);
    }

    // Encode swap calldata for target router (Uniswap V3 style)
    console.log(`\n🔧 Encoding swap calldata...`);
    const routerInterface = new ethers.Interface(SWAP_ROUTER_ABI);
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

    const minAmountOut = ethers.parseUnits(
      config.minAmountOut,
      tokenOutDecimals
    );

    const swapParams = {
      tokenIn: config.tokenIn,
      tokenOut: config.tokenOut,
      fee: parseInt(config.swapFee),
      recipient: signerAddress,
      deadline: deadline,
      amountIn: amountIn,
      amountOutMinimum: config.minAmountOut,
      sqrtPriceLimitX96: 0,
    };

    const swapCallData = routerInterface.encodeFunctionData(
      'exactInputSingle',
      [swapParams]
    );

    console.log(`   Function: exactInputSingle`);
    console.log(`   Amount In: ${config.swapAmountIn} ${tokenInSymbol}`);
    console.log(`   Min Amount Out: ${config.minAmountOut} ${tokenOutSymbol}`);
    console.log(`   Fee Tier: ${config.swapFee}`);
    console.log(`   Token0In: ${isToken0In}`);
    console.log(`   Recipient: ${signerAddress}`);

    // Prepare backrun parameters
    const backrunAmount = ethers.parseUnits(
      config.backrunAmount,
      tokenInDecimals
    );
    const backrunParams: BackrunParams[] = [
      {
        triggerPoolId: toBytes32(config.poolAddress),
        swapAmountIn: backrunAmount,
        token0In: config.token0In,
        recipient: signerAddress,
        configId: toBytes32(config.configId),
      },
    ];

    console.log(`\n📋 Backrun Parameters:`);
    backrunParams.forEach((params, i) => {
      console.log(`   [${i}] Pool: ${params.triggerPoolId}`);
      console.log(
        `       Swap Amount: ${ethers.formatUnits(params.swapAmountIn, tokenInDecimals)} ${tokenInSymbol}`
      );
      console.log(`       Token0In: ${params.token0In}`);
      console.log(`       Recipient: ${params.recipient}`);
      console.log(`       Config ID: ${params.configId}`);
    });

    // Execute swap with backrun
    console.log(`\n🔧 Executing swapWithbackrun...`);
    console.log(`   This will:`);
    console.log(
      `   1. Transfer ${config.swapAmountIn} ${tokenInSymbol} from you to SwapProxy`
    );
    console.log(`   3. Return any leftover tokens/ETH to you`);
    console.log(`   4. Execute backrun operations on ReflexRouter`);
    console.log(`   5. Distribute profits (if any)\n`);

    // Get balances before
    const [tokenInBalanceBefore, tokenOutBalanceBefore] = await Promise.all([
      tokenInContract.balanceOf(signerAddress),
      tokenOutContract.balanceOf(signerAddress),
    ]);

    // Execute transaction
    const tx = await swapProxy.swapWithbackrun(
      swapCallData,
      config.tokenIn,
      amountIn,
      config.reflexRouterAddress,
      backrunParams
    );

    console.log(`   Transaction hash: ${tx.hash}`);
    console.log(`   Waiting for confirmation...`);

    const receipt = await tx.wait();

    console.log(`\n✅ Transaction confirmed!`);
    console.log(`   Block: ${receipt.blockNumber}`);
    console.log(`   Gas Used: ${receipt.gasUsed.toString()}`);
    console.log(
      `   Gas Price: ${ethers.formatUnits(receipt.gasPrice || 0n, 'gwei')} gwei`
    );

    // Reset approval to zero for security
    console.log(`\n🔒 Resetting token approval to zero...`);
    const approveTx = await tokenInContract.approve(config.swapProxyAddress, 0);
    await approveTx.wait();

    // Decode return values from logs if available
    // Note: The actual values are returned from the function call, not events
    console.log(`\n📊 Results:`);

    // Get balances after
    const [tokenInBalanceAfter, tokenOutBalanceAfter] = await Promise.all([
      tokenInContract.balanceOf(signerAddress),
      tokenOutContract.balanceOf(signerAddress),
    ]);

    const tokenInDelta = tokenInBalanceAfter - tokenInBalanceBefore;
    const tokenOutDelta = tokenOutBalanceAfter - tokenOutBalanceBefore;

    console.log(`\n💱 Token Balance Changes:`);
    console.log(
      `   ${tokenInSymbol}: ${tokenInDelta >= 0n ? '+' : ''}${ethers.formatUnits(tokenInDelta, tokenInDecimals)}`
    );
    console.log(
      `   ${tokenOutSymbol}: ${tokenOutDelta >= 0n ? '+' : ''}${ethers.formatUnits(tokenOutDelta, tokenOutDecimals)}`
    );

    // Verify no leftover balances in proxy
    const [proxyTokenInBalance, proxyTokenOutBalance, proxyETHBalance] =
      await Promise.all([
        tokenInContract.balanceOf(config.swapProxyAddress),
        tokenOutContract.balanceOf(config.swapProxyAddress),
        provider.getBalance(config.swapProxyAddress),
      ]);

    console.log(`\n🔍 Proxy Balance Verification:`);
    console.log(
      `   ${tokenInSymbol} in proxy: ${ethers.formatUnits(proxyTokenInBalance, tokenInDecimals)}`
    );
    console.log(
      `   ${tokenOutSymbol} in proxy: ${ethers.formatUnits(proxyTokenOutBalance, tokenOutDecimals)}`
    );
    console.log(`   ETH in proxy: ${ethers.formatEther(proxyETHBalance)}`);

    if (
      proxyTokenInBalance > 0n ||
      proxyTokenOutBalance > 0n ||
      proxyETHBalance > 0n
    ) {
      console.log(`   ⚠️  WARNING: Proxy has leftover balances!`);
    } else {
      console.log(`   ✅ No leftover balances (as expected)`);
    }

    console.log(`\n✨ Test completed successfully!\n`);
  } catch (error: any) {
    console.error(`\n❌ Test failed: ${error.message}`);

    // Try to decode custom errors
    if (error.data) {
      try {
        const proxyInterface = new ethers.Interface(SWAP_PROXY_ABI);
        const decodedError = proxyInterface.parseError(error.data);
        if (decodedError) {
          console.error(`\nCustom Error: ${decodedError.name}`);
          if (decodedError.args.length > 0) {
            console.error(`Arguments:`, decodedError.args);
          }
        }
      } catch (e) {
        // Ignore decoding errors
      }
    }

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
