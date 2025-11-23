#!/usr/bin/env ts-node
/**
 * Simple UniswapV2 Swap Test Script
 *
 * This script executes a basic UniswapV2 swap (Token to Token) directly on the router
 * without any MEV backrun functionality. Useful for testing and comparing with the
 * backrun-enabled swaps.
 *
 * Usage:
 *   TARGET_ROUTER_ADDRESS=0x... \
 *   TOKEN_IN=0x... \
 *   TOKEN_OUT=0x... \
 *   SWAP_AMOUNT_IN=0.01 \
 *   npx ts-node src/test-universal/test-swap-only.ts
 */

// Load environment variables from .env file
import dotenv from 'dotenv';
dotenv.config();

import { ethers } from 'ethers';

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

// Configuration
const config = {
  rpcUrl: process.env.TEST_RPC_URL || 'http://localhost:8545',
  privateKey:
    process.env.TEST_PRIVATE_KEY ||
    '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80', // Default Anvil key
  targetRouterAddress: process.env.TARGET_ROUTER_ADDRESS,
  // Swap parameters
  tokenIn: process.env.TOKEN_IN,
  tokenOut: process.env.TOKEN_OUT,
  swapAmountIn: process.env.SWAP_AMOUNT_IN || '0.01',
  slippageTolerance: parseFloat(process.env.SLIPPAGE_TOLERANCE || '0.5'), // 0.5%
};

async function main() {
  console.log('🚀 UniswapV2 Direct Swap Test\n');

  // Validate required configuration
  if (!config.targetRouterAddress) {
    console.error(
      '❌ Error: TARGET_ROUTER_ADDRESS environment variable is required'
    );
    console.log('\nUsage:');
    console.log('  TARGET_ROUTER_ADDRESS=0x... \\');
    console.log('  TOKEN_IN=0x... \\');
    console.log('  TOKEN_OUT=0x... \\');
    console.log('  SWAP_AMOUNT_IN=0.01 \\');
    console.log('  npx ts-node src/test-universal/test-swap-only.ts\n');
    process.exit(1);
  }

  if (!config.tokenIn || !config.tokenOut) {
    console.error(
      '❌ Error: TOKEN_IN and TOKEN_OUT environment variables are required'
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

    // Initialize router contract
    console.log('🎯 Initializing UniswapV2 Router...');
    const router = new ethers.Contract(
      config.targetRouterAddress,
      UNISWAP_V2_ROUTER_ABI,
      signer
    );
    console.log(`   Router: ${config.targetRouterAddress}\n`);

    // Get token information
    console.log('💱 Token Information:');
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

    // Check and approve router to spend tokens
    console.log(`\n🔓 Checking token approval...`);
    const currentAllowance = await tokenInContract.allowance(
      signerAddress,
      config.targetRouterAddress
    );

    if (currentAllowance < amountIn) {
      console.log(`   Current allowance insufficient, approving...`);
      const approveTx = await tokenInContract.approve(
        config.targetRouterAddress,
        ethers.MaxUint256
      );
      await approveTx.wait();
      console.log(`   ✅ ${tokenInSymbol} approved`);
    } else {
      console.log(
        `   ✅ ${tokenInSymbol} already approved (allowance: ${ethers.formatUnits(currentAllowance, tokenInDecimals)})`
      );
    }

    // Get expected output amount
    const path = [config.tokenIn, config.tokenOut];
    console.log(`\n🔍 Getting quote from router...`);
    const amountsOut = await router.getAmountsOut(amountIn, path);
    const expectedAmountOut = amountsOut[1];
    const minAmountOut =
      (expectedAmountOut *
        BigInt(Math.floor((100 - config.slippageTolerance) * 100))) /
      10000n;

    console.log(
      `   Expected ${tokenOutSymbol}: ${ethers.formatUnits(expectedAmountOut, tokenOutDecimals)}`
    );
    console.log(
      `   Min ${tokenOutSymbol} (${config.slippageTolerance}% slippage): ${ethers.formatUnits(minAmountOut, tokenOutDecimals)}`
    );

    // Get balances before
    const [tokenInBalanceBefore, tokenOutBalanceBefore] = await Promise.all([
      tokenInContract.balanceOf(signerAddress),
      tokenOutContract.balanceOf(signerAddress),
    ]);

    // Execute swap
    console.log(`\n🔧 Preparing swap...`);
    console.log(`   Path: ${tokenInSymbol} → ${tokenOutSymbol}`);
    console.log(`   Amount In: ${config.swapAmountIn} ${tokenInSymbol}`);
    console.log(
      `   Min Amount Out: ${ethers.formatUnits(minAmountOut, tokenOutDecimals)} ${tokenOutSymbol}`
    );

    const deadline = Math.floor(Date.now() / 1000) + 60 * 20; // 20 minutes

    // Estimate gas
    console.log(`\n⛽ Estimating gas...`);
    try {
      const gasEstimate = await router.swapExactTokensForTokens.estimateGas(
        amountIn,
        minAmountOut,
        path,
        signerAddress,
        deadline
      );
      console.log(`   Estimated gas: ${gasEstimate.toString()}`);
      console.log(
        `   Gas with 20% buffer: ${((gasEstimate * 120n) / 100n).toString()}`
      );
    } catch (error: any) {
      console.log(`   ⚠️  Gas estimation failed: ${error.message}`);
      console.log(`   Proceeding with transaction anyway...`);
    }

    console.log(`\n🚀 Executing swap...`);
    const tx = await router.swapExactTokensForTokens(
      amountIn,
      minAmountOut,
      path,
      signerAddress,
      deadline
    );

    console.log(`\n⏳ Waiting for confirmation...`);
    const receipt = await tx.wait();

    console.log(`\n✅ Transaction confirmed!`);
    console.log(`   Transaction: ${receipt.hash}`);
    console.log(`   Block: ${receipt.blockNumber}`);
    console.log(`   Gas Used: ${receipt.gasUsed.toString()}`);
    console.log(
      `   Gas Price: ${ethers.formatUnits(receipt.gasPrice || 0n, 'gwei')} gwei`
    );
    console.log(
      `   Total Cost: ${ethers.formatEther(receipt.gasUsed * (receipt.gasPrice || 0n))} ETH`
    );

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

    // Calculate actual output
    const actualOutput = tokenOutDelta;
    const priceImpactBps =
      expectedAmountOut > 0n
        ? (Number(expectedAmountOut - actualOutput) * 10000) /
          Number(expectedAmountOut)
        : 0;

    console.log(`\n📊 Swap Analysis:`);
    console.log(
      `   Expected Output: ${ethers.formatUnits(expectedAmountOut, tokenOutDecimals)} ${tokenOutSymbol}`
    );
    console.log(
      `   Actual Output: ${ethers.formatUnits(actualOutput, tokenOutDecimals)} ${tokenOutSymbol}`
    );
    console.log(`   Price Impact: ${(priceImpactBps / 100).toFixed(2)}%`);

    console.log(`\n✨ Swap completed successfully!\n`);
  } catch (error: any) {
    console.error(`\n❌ Swap failed: ${error.message}`);

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
