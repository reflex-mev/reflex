import { ethers } from "ethers";
import { ReflexSDK } from "../src/ReflexSDK";
import { ExecuteParams, BackrunParams } from "../src/types";

/**
 * Basic example usage of the Reflex SDK for MEV backrunning
 *
 * This example demonstrates:
 * - SDK initialization
 * - Basic backruned execute operation
 * - Standalone backrun trigger
 * - Gas estimation
 * - Event listening
 * - Admin functions
 */
async function basicExample() {
  // Set up provider and signer
  const provider = new ethers.JsonRpcProvider(
    "https://eth-mainnet.alchemyapi.io/v2/YOUR_API_KEY"
  );
  const wallet = new ethers.Wallet("YOUR_PRIVATE_KEY", provider);

  // Initialize the Reflex SDK
  const reflexSDK = new ReflexSDK(provider, wallet, {
    routerAddress: "0x1234567890123456789012345678901234567890", // Replace with actual Reflex Router address
    defaultGasLimit: 500000n,
    gasPriceMultiplier: 1.1,
  });

  try {
    console.log("🚀 Starting basic Reflex SDK example...");

    // Example 1: Execute a transaction and then backrun
    console.log("\n📝 Example 1: Backruned Execute");
    const executeParams: ExecuteParams = {
      target: "0xA0b86a33E6441Bc0b32a3e6e2c1e01b6e1e5E2f0", // Target contract
      value: ethers.parseEther("0.1"), // 0.1 ETH
      callData:
        "0x095ea7b3000000000000000000000000a0b86a33e6441bc0b32a3e6e2c1e01b6e1e5e2f00000000000000000000000000000000000000000000000000de0b6b3a7640000", // Example approval call
    };

    const backrunParams: BackrunParams = {
      triggerPoolId: "0xabcdef1234567890abcdef1234567890abcdef12", // Pool ID that triggered the opportunity
      swapAmountIn: ethers.parseEther("1"), // 1 token to swap
      token0In: true, // Use token0 as input
      recipient: wallet.address, // Send profits to wallet
    };

    console.log("Executing backruned execute...");
    const result = await reflexSDK.backrunedExecute(
      executeParams,
      backrunParams
    );
    console.log("✅ Backruned execute result:", {
      success: result.success,
      profit: ethers.formatEther(result.profit),
      profitToken: result.profitToken,
      txHash: result.transactionHash,
    });

    // Example 2: Standalone backrun trigger
    console.log("\n🎯 Example 2: Standalone Backrun");
    console.log("Triggering standalone backrun...");
    const backrunResult = await reflexSDK.triggerBackrun(
      "0xabcdef1234567890abcdef1234567890abcdef12",
      ethers.parseEther("0.5"),
      false, // Use token1 as input
      wallet.address
    );
    console.log("✅ Backrun result:", {
      profit: ethers.formatEther(backrunResult.profit),
      profitToken: backrunResult.profitToken,
      txHash: backrunResult.transactionHash,
    });

    // Example 3: Gas estimation
    console.log("\n⛽ Example 3: Gas Estimation");
    const gasEstimate = await reflexSDK.estimateBackrunedExecuteGas(
      executeParams,
      backrunParams
    );
    console.log("✅ Estimated gas:", gasEstimate.toString());

    const backrunGasEstimate = await reflexSDK.estimateTriggerBackrunGas(
      "0xabcdef1234567890abcdef1234567890abcdef12",
      ethers.parseEther("0.5"),
      false,
      wallet.address
    );
    console.log("✅ Backrun gas estimate:", backrunGasEstimate.toString());

    // Example 4: Get contract information
    console.log("\n📋 Example 4: Contract Information");
    const admin = await reflexSDK.getAdmin();
    console.log("✅ Current admin:", admin);

    const quoter = await reflexSDK.getQuoter();
    console.log("✅ Current quoter:", quoter);

    // Example 5: Listen for BackrunExecuted events
    console.log("\n👂 Example 5: Event Listening");
    console.log("Setting up event listener...");
    const unsubscribe = reflexSDK.watchBackrunExecuted(
      (event) => {
        console.log("🎉 Backrun executed:", {
          poolId: event.triggerPoolId,
          profit: ethers.formatEther(event.profit),
          profitToken: event.profitToken,
          recipient: event.recipient,
        });
      },
      {
        recipient: wallet.address, // Only listen for events where we're the recipient
      }
    );

    console.log("✅ Event listener active. Waiting for events...");

    // Clean up after 60 seconds
    setTimeout(() => {
      unsubscribe();
      console.log("🛑 Event listener stopped");
    }, 60000);

    // Example 6: Function encoding (for batch transactions)
    console.log("\n🔧 Example 6: Function Encoding");
    const encodedBackrun = reflexSDK.encodeBackrunedExecute(
      executeParams,
      backrunParams
    );
    console.log(
      "✅ Encoded backruned execute:",
      encodedBackrun.slice(0, 20) + "..."
    );

    const encodedTrigger = reflexSDK.encodeTriggerBackrun(
      "0xabcdef1234567890abcdef1234567890abcdef12",
      ethers.parseEther("0.5"),
      false,
      wallet.address
    );
    console.log(
      "✅ Encoded trigger backrun:",
      encodedTrigger.slice(0, 20) + "..."
    );
  } catch (error) {
    console.error("❌ Error:", error);
  }
}

// Run example if this file is executed directly
if (require.main === module) {
  basicExample().catch(console.error);
}

export { basicExample };
