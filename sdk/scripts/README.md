# Blockchain Integration Test Script

Simple TypeScript script to test the ReflexSDK `backrunedExecute` function against an actual blockchain network.

## Prerequisites

1. **Node.js and TypeScript** - ts-node is included in the SDK dependencies
2. **Running Ethereum Node** - Local fork (Anvil/Hardhat) or testnet
3. **Deployed Reflex Router** - Contract must be deployed on the network
4. **Test Account with Funds** - For gas and transaction execution
5. **Configured Pool** - A pool address where backrun will be executed

## Quick Start

```bash
REFLEX_ROUTER_ADDRESS=0xYourRouterAddress \
TEST_POOL_ADDRESS=0xYourPoolAddress \
npx ts-node scripts/test-blockchain.ts
```

## Environment Variables

| Variable                | Required | Default                 | Description                             |
| ----------------------- | -------- | ----------------------- | --------------------------------------- |
| `REFLEX_ROUTER_ADDRESS` | ✅ Yes   | -                       | Deployed Reflex Router contract address |
| `TEST_POOL_ADDRESS`     | ✅ Yes   | -                       | Pool address for backrun trigger        |
| `TEST_RPC_URL`          | No       | `http://localhost:8545` | RPC endpoint URL                        |
| `TEST_PRIVATE_KEY`      | No       | Anvil default key       | Private key for test account            |
| `TEST_TARGET_ADDRESS`   | No       | `0x0`                   | Target contract for execute call        |
| `TEST_EXECUTE_VALUE`    | No       | `0`                     | ETH value to send (in ETH)              |
| `TEST_SWAP_AMOUNT`      | No       | `0.01`                  | Amount to swap in backrun (in ETH)      |
| `TEST_CONFIG_ID`        | No       | -                       | Config ID for profit splitting          |

## What It Does

The script executes a complete `backrunedExecute` flow:

1. **Connects** to the blockchain and verifies account balance
2. **Initializes** ReflexSDK with the router address
3. **Prepares** execute and backrun parameters
4. **Estimates** gas for the transaction
5. **Executes** the backrunedExecute transaction
6. **Displays** transaction results and profits

## Usage Examples

### Local Anvil Fork

```bash
# Terminal 1: Start Anvil
anvil --fork-url https://mainnet.infura.io/v3/YOUR_KEY

# Terminal 2: Run test
REFLEX_ROUTER_ADDRESS=0x5FbDB2315678afecb367f032d93F642f64180aa3 \
TEST_POOL_ADDRESS=0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640 \
npx ts-node scripts/test-blockchain.ts
```

### With Custom Parameters

```bash
REFLEX_ROUTER_ADDRESS=0x... \
TEST_POOL_ADDRESS=0x... \
TEST_TARGET_ADDRESS=0x... \
TEST_SWAP_AMOUNT=0.1 \
TEST_CONFIG_ID=customConfig123 \
npx ts-node scripts/test-blockchain.ts
```

### Using .env File

Create `.env`:

```bash
TEST_RPC_URL=http://localhost:8545
TEST_PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
REFLEX_ROUTER_ADDRESS=0x5FbDB2315678afecb367f032d93F642f64180aa3
TEST_POOL_ADDRESS=0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640
TEST_SWAP_AMOUNT=0.05
```

Then run:

```bash
export $(cat .env | xargs) && npx ts-node scripts/test-blockchain.ts
```

## Example Output

```
🚀 Testing backrunedExecute

📡 Connecting to blockchain...
✅ Connected to localhost (chainId: 31337)
👤 Account: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
💰 Balance: 10000.0 ETH

🎯 Initializing ReflexSDK...
   Router: 0x5FbDB2315678afecb367f032d93F642f64180aa3

� Execute Parameters:
   Target: 0x0000000000000000000000000000000000000000
   Value: 0.0 ETH
   CallData: 0x

� Backrun Parameters:
   [0] Pool: 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640
       Swap Amount: 0.01 ETH
       Token0In: true
       Recipient: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266

⛽ Estimating gas...
✅ Gas estimate: 250000

� Executing backrunedExecute...

✅ Transaction successful!
   Hash: 0xabc123...
   Success: true
   Return Data: 0x

💰 Profits:
   [0] 0.005 tokens
       Token: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2

✨ Test completed successfully!
```

## Customizing the Script

You can modify the script to test different scenarios:

### Execute with Target Contract

```typescript
// In the script, modify executeParams:
const executeParams: ExecuteParams = {
  target: '0xYourTargetContract',
  value: ethers.parseEther('0.1'), // Send 0.1 ETH
  callData: iface.encodeFunctionData('yourFunction', [args]),
};
```

### Multiple Backruns

```typescript
// Add more backrun params:
const backrunParams: BackrunParams[] = [
  {
    triggerPoolId: config.poolAddress,
    swapAmountIn: ethers.parseEther('0.01'),
    token0In: true,
    recipient: signerAddress,
  },
  {
    triggerPoolId: anotherPoolAddress,
    swapAmountIn: ethers.parseEther('0.02'),
    token0In: false,
    recipient: signerAddress,
  },
];
```

## Troubleshooting

### "Test account has no balance"

- Fund your test account with ETH
- Use default Anvil account (has 10000 ETH pre-funded)

### "Gas estimation failed"

- Verify pool address is correct
- Ensure pool has liquidity
- Check that router contract is properly configured

### "Transaction failed"

- Check pool configuration allows backruns
- Verify swap amounts are reasonable for pool liquidity
- Ensure target contract (if specified) doesn't revert

### Connection Issues

- Verify RPC URL is correct
- Ensure Ethereum node is running
- Check network connectivity

## Security Note

⚠️ **Never commit private keys for accounts with real funds!**

The default Anvil private key is safe only for local testing.

## Next Steps

After successful execution:

- Monitor profits in different market conditions
- Test with multiple pools simultaneously
- Implement custom execute logic
- Add event monitoring for real-time updates
