#!/usr/bin/env ts-node
/**
 * Universal Integration Test Script
 *
 * This script demonstrates how to use the UniversalIntegration SDK to execute
 * swaps on any DEX (UniswapV2, UniswapV3, etc.) with integrated MEV backrun capture.
 *
 * Supports:
 * - UniswapV2 style swaps (swapExactTokensForTokens - Token to Token)
 * - UniswapV3 style swaps (exactInputSingle, exactInput, etc.)
 * - Automatic token approvals
 * - Multi-pool backrun configurations
 *
 * Usage:
 *   SWAP_PROXY_ADDRESS=0x... \
 *   REFLEX_ROUTER_ADDRESS=0x... \
 *   TARGET_ROUTER_ADDRESS=0x... \
 *   ROUTER_TYPE=v2|v3 \
 *   TOKEN_IN=0x... \
 *   TOKEN_OUT=0x... \
 *   TEST_POOL_ADDRESS=0x... \
 *   npx ts-node scripts/test-universal.ts
 */

// Load environment variables from .env file
import dotenv from 'dotenv';
dotenv.config();

import { ethers } from 'ethers';
import { UniversalIntegration } from '../integrations/UniversalIntegration';

// ERC20 ABI for token operations
const ERC20_ABI = [
  'function approve(address spender, uint256 amount) returns (bool)',
  'function balanceOf(address account) view returns (uint256)',
  'function symbol() view returns (string)',
  'function decimals() view returns (uint8)',
  'function allowance(address owner, address spender) view returns (uint256)',
];

// UniswapV2 Router ABI
const UNISWAP_V2_ROUTER_ABI = [
  'function swapExactTokensForTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external returns (uint[] memory amounts)',
  'function getAmountsOut(uint amountIn, address[] calldata path) view returns (uint[] memory amounts)',
];

// UniswapV3 SwapRouter ABI
const UNISWAP_V3_ROUTER_ABI = [
  'function exactInputSingle((address tokenIn, address tokenOut, uint24 fee, address recipient, uint256 deadline, uint256 amountIn, uint256 amountOutMinimum, uint160 sqrtPriceLimitX96)) external payable returns (uint256 amountOut)',
  'function exactInput((bytes path, address recipient, uint256 deadline, uint256 amountIn, uint256 amountOutMinimum)) external payable returns (uint256 amountOut)',
];

// Uniswap Pair ABI (V2 and V3 both have token0/token1)
const PAIR_ABI = [
  'function token0() external view returns (address)',
  'function token1() external view returns (address)',
];

// Configuration
const config = {
  rpcUrl: process.env.TEST_RPC_URL || 'http://localhost:8545',
  privateKey:
    process.env.TEST_PRIVATE_KEY ||
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80', // Default Anvil key
  swapProxyAddress: process.env.SWAP_PROXY_ADDRESS,
  reflexRouterAddress: process.env.REFLEX_ROUTER_ADDRESS,
  routerType: (process.env.ROUTER_TYPE || 'v3').toLowerCase() as 'v2' | 'v3',
  poolAddress: process.env.TEST_POOL_ADDRESS,
  // Swap parameters
  tokenIn: process.env.TOKEN_IN,
  tokenOut: process.env.TOKEN_OUT,
  swapFee: process.env.SWAP_FEE || '500', // V3 pool fee (500, 3000, 10000) or ignored for V2
  swapAmountIn: process.env.SWAP_AMOUNT_IN || '0.01',
  minAmountOut: process.env.MIN_AMOUNT_OUT || '0',
  // Backrun parameters
  configId: process.env.TEST_CONFIG_ID || ethers.ZeroHash,
};

/**
 * Converts a value to bytes32 format
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

/**
 * Build UniswapV2 style swap calldata (Token → Token only)
 */
function buildV2SwapCalldata(
  tokenIn: string,
  tokenOut: string,
  amountIn: bigint,
  minAmountOut: string,
  recipient: string
): { calldata: string; value: bigint } {
  const routerInterface = new ethers.Interface(UNISWAP_V2_ROUTER_ABI);
  const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes
  const path = [tokenIn, tokenOut];

  console.log(`\n🔧 Building UniswapV2 swap calldata...`);
  console.log(`   Path: ${path.join(' → ')}`);
  console.log(`   Type: Token → Token`);

  const calldata = routerInterface.encodeFunctionData(
    'swapExactTokensForTokens',
    [amountIn, minAmountOut, path, recipient, deadline]
  );

  return { calldata, value: 0n };
}

/**
 * Build UniswapV3 style swap calldata
 */
function buildV3SwapCalldata(
  tokenIn: string,
  tokenOut: string,
  fee: number,
  amountIn: bigint,
  minAmountOut: string,
  recipient: string
): { calldata: string; value: bigint } {
  const routerInterface = new ethers.Interface(UNISWAP_V3_ROUTER_ABI);
  const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes

  console.log(`\n🔧 Building UniswapV3 swap calldata...`);
  console.log(`   Fee Tier: ${fee / 10000}%`);

  const swapParams = {
    tokenIn,
    tokenOut,
    fee,
    recipient,
    deadline,
    amountIn,
    amountOutMinimum: minAmountOut,
    sqrtPriceLimitX96: 0,
  };

  const calldata = routerInterface.encodeFunctionData('exactInputSingle', [
    swapParams,
  ]);

  console.log(`   Type: exactInputSingle`);

  return { calldata, value: 0n };
}

async function main() {
  console.log('🚀 Universal Integration Test\n');

  // Validate required configuration
  if (!config.swapProxyAddress) {
    console.error(
      '❌ Error: SWAP_PROXY_ADDRESS environment variable is required'
    );
    console.log('\nUsage:');
    console.log('  SWAP_PROXY_ADDRESS=0x... \\');
    console.log('  REFLEX_ROUTER_ADDRESS=0x... \\');
    console.log('  TARGET_ROUTER_ADDRESS=0x... \\');
    console.log('  ROUTER_TYPE=v2|v3 \\');
    console.log('  TOKEN_IN=0x... \\');
    console.log('  TOKEN_OUT=0x... \\');
    console.log('  TEST_POOL_ADDRESS=0x... \\');
    console.log('  npx ts-node scripts/test-universal.ts\n');
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

    // Initialize UniversalIntegration SDK
    console.log('🎯 Initializing UniversalIntegration SDK...');
    const integration = new UniversalIntegration(
      provider,
      signer,
      config.swapProxyAddress,
      config.reflexRouterAddress
    );

    console.log(`   Swap Proxy: ${config.swapProxyAddress}`);
    console.log(`   Reflex Router: ${config.reflexRouterAddress}`);
    console.log(`   Router Type: UniswapV${config.routerType.toUpperCase()}`);

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

    // Parse amounts
    const amountIn = ethers.parseUnits(config.swapAmountIn, tokenInDecimals);

    // Query pool to determine token0In
    console.log(`\n🔍 Querying pool for token order...`);
    const pairContract = new ethers.Contract(
      config.poolAddress,
      PAIR_ABI,
      provider
    );
    const token0 = await pairContract.token0();
    const token0In = config.tokenIn.toLowerCase() === token0.toLowerCase();
    console.log(`   Pool Token0: ${token0}`);
    console.log(`   Token In is Token0: ${token0In}`);

    // Check token balance
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
    console.log(`\n🔓 Approving tokens...`);
    await integration.approveTokens([
      {
        tokenAddress: config.tokenIn,
        amount: ethers.MaxUint256,
      },
    ]);
    console.log(`   ✅ ${tokenInSymbol} approved`);

    // Build swap calldata based on router type
    let swapCalldata: string;
    let swapValue: bigint;

    if (config.routerType === 'v2') {
      const result = buildV2SwapCalldata(
        config.tokenIn,
        config.tokenOut,
        amountIn,
        config.minAmountOut,
        signerAddress
      );
      swapCalldata = result.calldata;
      swapValue = result.value;
    } else {
      const result = buildV3SwapCalldata(
        config.tokenIn,
        config.tokenOut,
        parseInt(config.swapFee),
        amountIn,
        config.minAmountOut,
        signerAddress
      );
      swapCalldata = result.calldata;
      swapValue = result.value;
    }

    console.log(`   Amount In: ${config.swapAmountIn} ${tokenInSymbol}`);
    console.log(`   Min Amount Out: ${config.minAmountOut} ${tokenOutSymbol}`);
    console.log(`   Recipient: ${signerAddress}`);

    // Prepare swap metadata
    const swapMetadata = {
      swapTxCallData: swapCalldata,
      tokenIn: config.tokenIn,
      amountIn: amountIn,
      tokenOut: config.tokenOut,
      recipient: signerAddress,
    };

    // Prepare backrun parameters
    const backrunParams = [
      {
        triggerPoolId: toBytes32(config.poolAddress),
        swapAmountIn: amountIn, // Use same amount as swap
        token0In: token0In, // Use calculated token0In from pool query
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

    // Execute swap with backrun using SDK
    console.log(`\n🔧 Executing swap with backrun...`);
    console.log(`   This will:`);
    console.log(
      `   1. Transfer ${config.swapAmountIn} ${tokenInSymbol} from you to SwapProxy`
    );
    console.log(
      `   2. Execute swap on ${config.routerType.toUpperCase()} router`
    );
    console.log(`   3. Execute backrun operations on ReflexRouter`);
    console.log(`   4. Distribute profits to you`);
    console.log(`   5. Return any leftover tokens/ETH to you\n`);

    // Get balances before
    const [tokenInBalanceBefore, tokenOutBalanceBefore] = await Promise.all([
      tokenInContract.balanceOf(signerAddress),
      tokenOutContract.balanceOf(signerAddress),
    ]);

    // const gasEstimate = await integration.estimateGas(
    //   swapCalldata,
    //   swapMetadata,
    //   backrunParams
    // );

    // return gasEstimate;

    // Execute transaction using SDK
    const result = await integration.swapWithBackrun(
      swapCalldata,
      swapMetadata,
      backrunParams,
      swapValue > 0n ? { value: swapValue } : undefined
    );

    console.log(`\n✅ Transaction confirmed!`);
    console.log(`   Transaction: ${result.transactionHash}`);
    console.log(`   Block: ${result.blockNumber}`);
    console.log(`   Gas Used: ${result.gasUsed.toString()}`);

    // Display results
    console.log(`\n📊 Backrun Results:`);
    console.log(`   Profits: ${result.profits.length}`);
    result.profits.forEach((profit, i) => {
      const token = result.profitTokens[i];
      console.log(`   [${i}] ${ethers.formatEther(profit)} (${token})`);
    });

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
        provider.getBalance(config.swapProxyAddress as any),
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
