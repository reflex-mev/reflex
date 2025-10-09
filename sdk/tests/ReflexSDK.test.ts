/// <reference types="jest" />
import { ReflexSDK } from '../src/ReflexSDK';
import {
  MockProvider,
  MockSigner,
  MockContract,
  mockExecuteParams,
  mockBackrunParams,
  mockRouterAddress,
} from './mocks';

// Mock the ethers Contract
jest.mock('ethers', () => ({
  ...jest.requireActual('ethers'),
  Contract: jest.fn().mockImplementation(() => new MockContract()),
}));

describe('ReflexSDK', () => {
  let sdk: ReflexSDK;
  let mockProvider: MockProvider;
  let mockSigner: MockSigner;

  beforeEach(() => {
    mockProvider = new MockProvider();
    mockSigner = new MockSigner();
    sdk = new ReflexSDK(
      mockProvider as any,
      mockSigner as any,
      mockRouterAddress
    );
  });

  describe('constructor', () => {
    it('should initialize with correct configuration', () => {
      expect(sdk).toBeInstanceOf(ReflexSDK);
    });

    it('should initialize with router address', () => {
      const newSdk = new ReflexSDK(
        mockProvider as any,
        mockSigner as any,
        mockRouterAddress
      );
      expect(newSdk).toBeInstanceOf(ReflexSDK);
    });
  });

  describe('backrunedExecute', () => {
    it('should execute backruned transaction successfully', async () => {
      const result = await sdk.backrunedExecute(
        mockExecuteParams,
        mockBackrunParams
      );

      expect(result).toMatchObject({
        success: true,
        returnData: '0x',
        profits: [BigInt(1000000)],
        profitTokens: ['0xA0b86a33E6441e8DD31e74c518e7b8B1C62b8e80'],
        transactionHash: '0xtransaction_hash',
      });
    });

    it('should handle transaction options', async () => {
      const options = {
        gasLimit: BigInt(600000),
        gasPrice: BigInt(25000000000),
      };

      const result = await sdk.backrunedExecute(
        mockExecuteParams,
        mockBackrunParams,
        options
      );

      expect(result.success).toBe(true);
    });

    it('should handle transaction failure', async () => {
      // Mock failed transaction
      const mockContract = new MockContract();
      const mockFn = jest
        .fn()
        .mockRejectedValue(new Error('Transaction failed'));
      mockContract.backrunedExecute = Object.assign(mockFn, {
        estimateGas: jest.fn().mockResolvedValue(BigInt(500000)),
      });

      (require('ethers').Contract as jest.Mock).mockImplementation(
        () => mockContract
      );

      const failingSdk = new ReflexSDK(
        mockProvider as any,
        mockSigner as any,
        mockRouterAddress
      );

      await expect(
        failingSdk.backrunedExecute(mockExecuteParams, mockBackrunParams)
      ).rejects.toThrow('Backruned execute failed');
    });
  });

  describe('estimateBackrunedExecuteGas', () => {
    it('should estimate gas correctly', async () => {
      const mockContract = new MockContract();
      (mockContract as any).backrunedExecute.estimateGas = jest
        .fn()
        .mockResolvedValue(BigInt(500000));

      (require('ethers').Contract as jest.Mock).mockImplementation(
        () => mockContract
      );

      const sdkWithGasEstimate = new ReflexSDK(
        mockProvider as any,
        mockSigner as any,
        mockRouterAddress
      );

      const gasEstimate = await sdkWithGasEstimate.estimateBackrunedExecuteGas(
        mockExecuteParams,
        mockBackrunParams
      );

      expect(gasEstimate).toBe(BigInt(500000));
    });

    it('should handle gas estimation failure', async () => {
      const mockContract = new MockContract();
      (mockContract as any).backrunedExecute.estimateGas = jest
        .fn()
        .mockRejectedValue(new Error('Gas estimation failed'));

      (require('ethers').Contract as jest.Mock).mockImplementation(
        () => mockContract
      );

      const sdkWithFailingGas = new ReflexSDK(
        mockProvider as any,
        mockSigner as any,
        mockRouterAddress
      );

      await expect(
        sdkWithFailingGas.estimateBackrunedExecuteGas(
          mockExecuteParams,
          mockBackrunParams
        )
      ).rejects.toThrow('Gas estimation failed');
    });
  });

  describe('getAdmin', () => {
    it('should return admin address', async () => {
      const admin = await sdk.getAdmin();
      expect(admin).toBe('0xadmin_address');
    });
  });

  describe('encodeBackrunedExecute', () => {
    it('should encode function data correctly', () => {
      const encoded = sdk.encodeBackrunedExecute(
        mockExecuteParams,
        mockBackrunParams
      );

      // Check that it returns a valid hex string
      expect(encoded).toMatch(/^0x[a-fA-F0-9]+$/);
      expect(encoded.length).toBeGreaterThan(10); // Should be substantial encoded data
    });
  });

  describe('watchBackrunExecuted', () => {
    it('should set up event listener', () => {
      const callback = jest.fn();
      const unsubscribe = sdk.watchBackrunExecuted(callback);

      expect(typeof unsubscribe).toBe('function');
    });

    it('should set up event listener with filters', () => {
      const callback = jest.fn();
      const options = {
        triggerPoolId: '0x1234',
        profitToken: '0x5678',
        recipient: '0x9abc',
      };

      const unsubscribe = sdk.watchBackrunExecuted(callback, options);
      expect(typeof unsubscribe).toBe('function');
    });
  });

  describe('error handling', () => {
    it('should format error with reason', () => {
      const error = { reason: 'Custom error reason' };
      const sdk = new ReflexSDK(
        mockProvider as any,
        mockSigner as any,
        mockRouterAddress
      );

      // Access private method for testing
      const formatError = (sdk as any).formatError(error);
      expect(formatError).toBe('Custom error reason');
    });

    it('should format error with message', () => {
      const error = { message: 'Custom error message' };
      const sdk = new ReflexSDK(
        mockProvider as any,
        mockSigner as any,
        mockRouterAddress
      );

      const formatError = (sdk as any).formatError(error);
      expect(formatError).toBe('Custom error message');
    });

    it('should format error as string fallback', () => {
      const error = 'Simple error string';
      const sdk = new ReflexSDK(
        mockProvider as any,
        mockSigner as any,
        mockRouterAddress
      );

      const formatError = (sdk as any).formatError(error);
      expect(formatError).toBe('Simple error string');
    });
  });
});
