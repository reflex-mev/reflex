import {
  ExecuteParams,
  BackrunParams,
  BackrunedExecuteResult,
  ReflexConfig,
  TransactionOptions,
  BackrunExecutedEvent,
} from "../src/types";

describe("Types", () => {
  describe("ExecuteParams", () => {
    it("should accept valid execute parameters", () => {
      const executeParams: ExecuteParams = {
        target: "0x1234567890123456789012345678901234567890",
        value: BigInt(1000000),
        callData: "0x1234",
      };

      expect(executeParams.target).toBeDefined();
      expect(executeParams.value).toBeDefined();
      expect(executeParams.callData).toBeDefined();
    });
  });

  describe("BackrunParams", () => {
    it("should accept valid backrun parameters", () => {
      const backrunParams: BackrunParams = {
        triggerPoolId:
          "0x1234567890123456789012345678901234567890123456789012345678901234",
        swapAmountIn: BigInt(1000000),
        token0In: true,
        recipient: "0x1234567890123456789012345678901234567890",
      };

      expect(backrunParams.triggerPoolId).toBeDefined();
      expect(backrunParams.swapAmountIn).toBeDefined();
      expect(backrunParams.token0In).toBeDefined();
      expect(backrunParams.recipient).toBeDefined();
    });

    it("should accept swapAmountIn as number", () => {
      const backrunParams: BackrunParams = {
        triggerPoolId:
          "0x1234567890123456789012345678901234567890123456789012345678901234",
        swapAmountIn: 1000000,
        token0In: false,
        recipient: "0x1234567890123456789012345678901234567890",
      };

      expect(typeof backrunParams.swapAmountIn).toBe("number");
    });
  });

  describe("BackrunedExecuteResult", () => {
    it("should have correct result structure", () => {
      const result: BackrunedExecuteResult = {
        success: true,
        returnData: "0x",
        profits: [BigInt(1000000), BigInt(2000000)],
        profitTokens: [
          "0x1234567890123456789012345678901234567890",
          "0x9876543210987654321098765432109876543210",
        ],
        transactionHash: "0xtransactionhash",
      };

      expect(result.success).toBe(true);
      expect(result.profits).toHaveLength(2);
      expect(result.profitTokens).toHaveLength(2);
      expect(result.transactionHash).toBeDefined();
    });
  });

  describe("ReflexConfig", () => {
    it("should accept minimal configuration", () => {
      const config: ReflexConfig = {
        routerAddress: "0x1234567890123456789012345678901234567890",
      };

      expect(config.routerAddress).toBeDefined();
    });

    it("should accept full configuration", () => {
      const config: ReflexConfig = {
        routerAddress: "0x1234567890123456789012345678901234567890",
        defaultGasLimit: BigInt(500000),
        gasPriceMultiplier: 1.2,
      };

      expect(config.routerAddress).toBeDefined();
      expect(config.defaultGasLimit).toBeDefined();
      expect(config.gasPriceMultiplier).toBeDefined();
    });
  });

  describe("TransactionOptions", () => {
    it("should accept empty options", () => {
      const options: TransactionOptions = {};
      expect(options).toBeDefined();
    });

    it("should accept gas options", () => {
      const options: TransactionOptions = {
        gasLimit: BigInt(600000),
        gasPrice: BigInt(20000000000),
        maxFeePerGas: BigInt(30000000000),
        maxPriorityFeePerGas: BigInt(2000000000),
      };

      expect(options.gasLimit).toBeDefined();
      expect(options.gasPrice).toBeDefined();
      expect(options.maxFeePerGas).toBeDefined();
      expect(options.maxPriorityFeePerGas).toBeDefined();
    });
  });

  describe("BackrunExecutedEvent", () => {
    it("should have correct event structure", () => {
      const event: BackrunExecutedEvent = {
        triggerPoolId:
          "0x1234567890123456789012345678901234567890123456789012345678901234",
        swapAmountIn: BigInt(1000000),
        token0In: true,
        profit: BigInt(50000),
        profitToken: "0x1234567890123456789012345678901234567890",
        recipient: "0x9876543210987654321098765432109876543210",
      };

      expect(event.triggerPoolId).toBeDefined();
      expect(event.swapAmountIn).toBeDefined();
      expect(event.token0In).toBeDefined();
      expect(event.profit).toBeDefined();
      expect(event.profitToken).toBeDefined();
      expect(event.recipient).toBeDefined();
    });
  });
});
