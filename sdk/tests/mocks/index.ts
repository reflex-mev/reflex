export class MockProvider {
  async getFeeData() {
    return {
      gasPrice: BigInt(20000000000), // 20 gwei
      maxFeePerGas: BigInt(30000000000),
      maxPriorityFeePerGas: BigInt(2000000000),
      toJSON: () => ({}),
    };
  }

  async getNetwork() {
    return {
      name: "localhost",
      chainId: 31337n,
      toJSON: () => ({}),
    };
  }
}

export class MockSigner {
  provider = new MockProvider() as any;

  async getAddress() {
    return "0x1234567890123456789012345678901234567890";
  }

  async signTransaction(transaction: any) {
    return "0xsigned_transaction_hash";
  }
}

export class MockContract {
  interface = {
    parseLog: (log: any) => {
      if (log.topics[0] === "0xbackrun_executed_topic") {
        return {
          name: "BackrunExecuted",
          args: {
            profit: BigInt(1000000),
            profitToken: "0xA0b86a33E6441e8DD31e74c518e7b8B1C62b8e80",
          },
        };
      }
      return null;
    },
    encodeFunctionData: (functionName: string, params: any[]) => {
      return "0xencoded_function_data";
    },
  };

  filters = {
    BackrunExecuted: () => "backrun_filter",
  };

  async backrunedExecute(
    executeParams: any,
    backrunParams: any,
    options: any
  ): Promise<MockTransactionResponse> {
    return new MockTransactionResponse();
  }

  async getReflexAdmin() {
    return "0xadmin_address";
  }

  async reflexQuoter() {
    return "0xquoter_address";
  }

  on(filter: any, callback: any) {
    // Mock event listener
  }

  removeAllListeners(filter: any) {
    // Mock remove listeners
  }
}

export class MockTransactionResponse {
  hash = "0xtransaction_hash";

  async wait() {
    return {
      status: 1,
      logs: [
        {
          topics: ["0xbackrun_executed_topic"],
          data: "0xevent_data",
        },
      ],
    };
  }
}

export const mockExecuteParams = {
  target: "0x1234567890123456789012345678901234567890",
  value: BigInt(0),
  callData: "0x1234",
};

export const mockBackrunParams = [
  {
    triggerPoolId:
      "0x1234567890123456789012345678901234567890123456789012345678901234",
    swapAmountIn: BigInt(1000000),
    token0In: true,
    recipient: "0x1234567890123456789012345678901234567890",
  },
];

export const mockConfig = {
  routerAddress: "0x1234567890123456789012345678901234567890",
  defaultGasLimit: 500000n,
  gasPriceMultiplier: 1.1,
};
