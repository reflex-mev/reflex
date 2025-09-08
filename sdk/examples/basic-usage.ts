import {
  ReflexSDK,
  ExecuteParams,
  BackrunParams,
  isValidAddress,
  formatTokenAmount,
} from "../src";
import { ethers } from "ethers";

async function main() {
  // Setup
  const provider = new ethers.JsonRpcProvider(
    process.env.RPC_URL || "http://localhost:8545"
  );
  const signer = new ethers.Wallet(
    process.env.PRIVATE_KEY || "0x" + "1".repeat(64),
    provider
  );

  // Initialize SDK
  const reflexSdk = new ReflexSDK(provider, signer, {
    routerAddress: "0x1234567890123456789012345678901234567890", // Replace with actual address
    defaultGasLimit: 500000n,
    gasPriceMultiplier: 1.1,
  });

  console.log("🚀 Reflex SDK Example");
  console.log("=====================");

  // Example 1: Basic Usage
  console.log("\n1. Basic SDK Setup");
  console.log("✅ SDK initialized successfully");
  console.log("📍 Router address:", reflexSdk);

  // Example 2: Address Validation
  console.log("\n2. Address Validation");
  const testAddress = "0x1234567890123456789012345678901234567890";
  console.log(`📋 Testing address: ${testAddress}`);
  console.log(`✅ Valid address: ${isValidAddress(testAddress)}`);

  // Example 3: Token Amount Formatting
  console.log("\n3. Token Amount Utilities");
  const amount = BigInt("1500000000000000000"); // 1.5 ETH in wei
  const formatted = formatTokenAmount(amount);
  console.log(`💰 Amount in wei: ${amount}`);
  console.log(`💰 Formatted amount: ${formatted} ETH`);

  // Example 4: Prepare Transaction Parameters
  console.log("\n4. Transaction Parameters");

  const executeParams: ExecuteParams = {
    target: "0x1234567890123456789012345678901234567890",
    value: BigInt(0),
    callData: "0x1234", // Example calldata
  };

  const backrunParams: BackrunParams[] = [
    {
      triggerPoolId:
        "0x1234567890123456789012345678901234567890123456789012345678901234",
      swapAmountIn: BigInt(1000000), // 1 USDC (6 decimals)
      token0In: true,
      recipient: await signer.getAddress(),
    },
  ];

  console.log("📋 Execute params:", {
    target: executeParams.target,
    value: executeParams.value.toString(),
    callData: executeParams.callData,
  });

  console.log("📋 Backrun params:", {
    triggerPoolId: backrunParams[0].triggerPoolId,
    swapAmountIn: backrunParams[0].swapAmountIn.toString(),
    token0In: backrunParams[0].token0In,
    recipient: backrunParams[0].recipient,
  });

  // Example 5: Gas Estimation
  console.log("\n5. Gas Estimation");
  try {
    const gasEstimate = await reflexSdk.estimateBackrunedExecuteGas(
      executeParams,
      backrunParams
    );
    console.log(`⛽ Estimated gas: ${gasEstimate.toString()}`);
  } catch (error) {
    console.log(
      "⚠️  Gas estimation failed (expected in example):",
      error instanceof Error ? error.message : error
    );
  }

  // Example 6: Event Monitoring Setup
  console.log("\n6. Event Monitoring");
  const unsubscribe = reflexSdk.watchBackrunExecuted(
    (event) => {
      console.log("🎉 Backrun executed!", {
        triggerPoolId: event.triggerPoolId,
        profit: formatTokenAmount(event.profit),
        profitToken: event.profitToken,
        recipient: event.recipient,
      });
    },
    {
      recipient: await signer.getAddress(), // Only watch events for our address
    }
  );

  console.log("👂 Event listener setup complete");

  // Example 7: Function Encoding
  console.log("\n7. Function Encoding");
  const encodedData = reflexSdk.encodeBackrunedExecute(
    executeParams,
    backrunParams
  );
  console.log(`📦 Encoded function data: ${encodedData.slice(0, 42)}...`);

  // Example 8: Get Contract Info
  console.log("\n8. Contract Information");
  try {
    const admin = await reflexSdk.getAdmin();
    const quoter = await reflexSdk.getQuoter();
    console.log(`👤 Router admin: ${admin}`);
    console.log(`🔍 Quoter address: ${quoter}`);
  } catch (error) {
    console.log(
      "⚠️  Contract info retrieval failed (expected in example):",
      error instanceof Error ? error.message : error
    );
  }

  // Clean up
  console.log("\n9. Cleanup");
  unsubscribe();
  console.log("🧹 Event listener cleaned up");

  console.log("\n🎯 Example completed successfully!");
  console.log(
    "\nNote: This example uses mock addresses and will not execute real transactions."
  );
  console.log(
    "Replace with actual contract addresses and ensure proper network setup for real usage."
  );
}

// Run example
if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error("❌ Example failed:", error);
      process.exit(1);
    });
}

export { main };
