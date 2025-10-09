import { ReflexSDK } from '../src/ReflexSDK';
import {
  ExecuteParams,
  BackrunParams,
  isValidAddress,
  formatTokenAmount,
  parseTokenAmount,
} from '../src';

describe('Integration Tests', () => {
  describe('SDK exports', () => {
    it('should export all main components', () => {
      expect(ReflexSDK).toBeDefined();
      expect(typeof ReflexSDK).toBe('function'); // Constructor
    });

    it('should export types and interfaces', () => {
      // Test that we can create objects with the exported types
      const executeParams: ExecuteParams = {
        target: '0x1234567890123456789012345678901234567890',
        value: BigInt(0),
        callData: '0x1234',
      };

      const backrunParams: BackrunParams = {
        triggerPoolId:
          '0x1234567890123456789012345678901234567890123456789012345678901234',
        swapAmountIn: BigInt(1000000),
        token0In: true,
        recipient: '0x1234567890123456789012345678901234567890',
      };

      expect(executeParams).toBeDefined();
      expect(backrunParams).toBeDefined();
    });

    it('should export utility functions', () => {
      expect(isValidAddress).toBeDefined();
      expect(formatTokenAmount).toBeDefined();
      expect(parseTokenAmount).toBeDefined();

      expect(typeof isValidAddress).toBe('function');
      expect(typeof formatTokenAmount).toBe('function');
      expect(typeof parseTokenAmount).toBe('function');
    });
  });

  describe('End-to-end workflow simulation', () => {
    it('should demonstrate a complete SDK workflow', () => {
      // 1. Validate addresses
      const routerAddress = '0x1234567890123456789012345678901234567890';
      const recipientAddress = '0x9876543210987654321098765432109876543210';

      expect(isValidAddress(routerAddress)).toBe(true);
      expect(isValidAddress(recipientAddress)).toBe(true);

      // 2. Parse token amounts
      const swapAmount = parseTokenAmount('1.5'); // 1.5 tokens
      expect(swapAmount).toBe(BigInt('1500000000000000000'));

      // 3. Create parameters
      const executeParams: ExecuteParams = {
        target: routerAddress,
        value: BigInt(0),
        callData: '0x1234',
      };

      const backrunParams: BackrunParams[] = [
        {
          triggerPoolId:
            '0x1234567890123456789012345678901234567890123456789012345678901234',
          swapAmountIn: swapAmount,
          token0In: true,
          recipient: recipientAddress,
        },
      ];

      // 4. Validate the workflow parameters
      expect(executeParams.target).toBe(routerAddress);
      expect(backrunParams[0].swapAmountIn).toBe(swapAmount);
      expect(backrunParams[0].recipient).toBe(recipientAddress);

      // 5. Format results (simulate profit)
      const simulatedProfit = BigInt('75000000000000000'); // 0.075 tokens
      const formattedProfit = formatTokenAmount(simulatedProfit);
      expect(formattedProfit).toBe('0.075');
    });
  });

  describe('Configuration validation', () => {
    it('should validate typical configuration values', () => {
      const config = {
        routerAddress: '0x1234567890123456789012345678901234567890',
        defaultGasLimit: BigInt(500000),
        gasPriceMultiplier: 1.1,
      };

      expect(isValidAddress(config.routerAddress)).toBe(true);
      expect(config.defaultGasLimit).toBeGreaterThan(0n);
      expect(config.gasPriceMultiplier).toBeGreaterThan(0);
    });

    it('should handle edge cases in configuration', () => {
      // Test with minimal configuration
      const minimalConfig = {
        routerAddress: '0x1234567890123456789012345678901234567890',
      };

      expect(isValidAddress(minimalConfig.routerAddress)).toBe(true);
    });
  });
});
