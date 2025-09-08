import { ethers } from 'ethers';
import { ReflexSDK } from '../ReflexSDK';
import { ExecuteParams, BackrunParams } from '../types';

// Mock provider setup
const provider = new ethers.JsonRpcProvider('http://localhost:8545');
const signer = new ethers.Wallet('your-private-key', provider);

// Initialize ReflexSDK
const reflexSDK = new ReflexSDK(provider, signer, {
  routerAddress: '0x1234567890123456789012345678901234567890',
});

async function basicExample() {
  try {
    // Set up execute parameters
    const executeParams: ExecuteParams = {
      target: '0xA0b86a33E6441d7c0AD4f7b2A36E82F6D7ca40A7',
      callData: '0x',
      value: BigInt(0),
    };

    // Set up backrun parameters (now as array)
    const backrunParams: BackrunParams[] = [
      {
        triggerPoolId: '0xB1b86a33E6441d7c0AD4f7b2A36E82F6D7ca40B8',
        swapAmountIn: BigInt(1000000), // 1 token with 6 decimals
        token0In: true,
        recipient: '0xC2c86a33E6441d7c0AD4f7b2A36E82F6D7ca40C9',
      },
    ];

    // Execute with backrun
    const result = await reflexSDK.backrunedExecute(
      executeParams,
      backrunParams,
      {
        gasLimit: BigInt(300000),
      }
    );

    if (result.success) {
      console.log('Execution successful!');
      console.log(`Profits: ${result.profits.map(p => p.toString())}`);
      console.log(`Profit tokens: ${result.profitTokens}`);
    } else {
      console.log('Execution failed:', result.returnData);
    }
  } catch (error) {
    console.error('Error:', error);
  }
}

export { basicExample };
