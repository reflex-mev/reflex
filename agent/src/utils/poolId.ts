import { keccak256, toUtf8Bytes } from 'ethers';

/**
 * Convert a pool address to a bytes32 pool ID for Reflex Router
 * 
 * For MVP, we'll use a simple hash of the pool address.
 * In production, this should match the exact poolId format expected by Reflex Router.
 * 
 * @param poolAddress - The pool address
 * @returns bytes32 pool ID
 */
export function addressToPoolId(poolAddress: string): string {
  // Ensure address is lowercase and has 0x prefix
  const normalizedAddress = poolAddress.toLowerCase();
  
  // For MVP: Use keccak256 hash of the address
  // This creates a unique bytes32 identifier
  const poolId = keccak256(toUtf8Bytes(normalizedAddress));
  
  return poolId;
}

/**
 * Validate that a string is a valid Ethereum address
 * 
 * @param address - The address to validate
 * @returns True if valid
 */
export function isValidAddress(address: string): boolean {
  return /^0x[0-9a-fA-F]{40}$/.test(address);
}
