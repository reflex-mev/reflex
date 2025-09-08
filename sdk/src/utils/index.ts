/**
 * Utility functions for the Reflex SDK
 */

/**
 * Validates an Ethereum address format
 * @param address - The address to validate
 * @returns True if the address is valid
 */
export function isValidAddress(address: string): boolean {
  return /^0x[a-fA-F0-9]{40}$/.test(address);
}

/**
 * Validates a bytes32 value (like pool ID)
 * @param bytes32 - The bytes32 value to validate
 * @returns True if the value is valid
 */
export function isValidBytes32(bytes32: string): boolean {
  return /^0x[a-fA-F0-9]{64}$/.test(bytes32);
}

/**
 * Formats a BigInt value to a human-readable string with decimals
 * @param value - The BigInt value
 * @param decimals - Number of decimal places (default: 18)
 * @returns Formatted string
 */
export function formatTokenAmount(
  value: bigint,
  decimals: number = 18
): string {
  const divisor = BigInt(10 ** decimals);
  const whole = value / divisor;
  const remainder = value % divisor;

  if (remainder === 0n) {
    return whole.toString();
  }

  const remainderStr = remainder.toString().padStart(decimals, '0');
  const trimmedRemainder = remainderStr.replace(/0+$/, '');

  return `${whole}.${trimmedRemainder}`;
}

/**
 * Parses a token amount string to BigInt
 * @param amount - Amount as string (e.g., "1.5")
 * @param decimals - Number of decimal places (default: 18)
 * @returns BigInt representation
 */
export function parseTokenAmount(
  amount: string,
  decimals: number = 18
): bigint {
  const [whole = '0', fraction = ''] = amount.split('.');
  const wholeBigInt = BigInt(whole) * BigInt(10 ** decimals);

  if (!fraction) {
    return wholeBigInt;
  }

  const fractionPadded = fraction.padEnd(decimals, '0').slice(0, decimals);
  const fractionBigInt = BigInt(fractionPadded);

  return wholeBigInt + fractionBigInt;
}

/**
 * Calculates the percentage profit
 * @param profit - Profit amount
 * @param investment - Initial investment amount
 * @returns Percentage profit as number
 */
export function calculateProfitPercentage(
  profit: bigint,
  investment: bigint
): number {
  if (investment === 0n) return 0;
  return Number((profit * 10000n) / investment) / 100; // Return percentage with 2 decimal precision
}
