/**
 * Reflex SDK Examples Runner
 *
 * This file provides quick access to all SDK examples.
 * For detailed examples, see the ./examples/ directory.
 */

import { runAllExamples } from "./examples";

console.log("🚀 Reflex SDK Examples");
console.log("=".repeat(50));
console.log("Available examples:");
console.log("• Basic Usage: npx tsx examples/basic.ts");
console.log("• Uniswap V2: npx tsx examples/uniswapv2.ts");
console.log("• Uniswap V3: npx tsx examples/uniswapv3.ts");
console.log("• All Examples: npx tsx examples/index.ts");
console.log("=".repeat(50));

// Run all examples
if (require.main === module) {
  runAllExamples().catch(console.error);
}
