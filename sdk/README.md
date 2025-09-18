# Reflex SDK

> **Part of the [Reflex MEV](../README.md) monorepo**

A TypeScript SDK for interacting with Reflex, enabling seamless execution of MEV capture and arbitrage opportunities.

The Reflex SDK provides a developer-friendly interface to the core Reflex MEV system, abstracting away the complexity of smart contract interactions while providing full type safety and comprehensive testing.

## Features

- 🚀 **Easy Integration**: Simple API for executing MEV capture and arbitrage
- 🔒 **Type Safety**: Full TypeScript support with comprehensive type definitions
- 🧪 **Well Tested**: 49+ tests covering all functionality
- 🛠 **Utility Functions**: Built-in helpers for address validation, token formatting, and more
- 📊 **Event Monitoring**: Real-time event watching capabilities
- ⚡ **Gas Optimization**: Built-in gas estimation and price optimization
- 🔗 **Monorepo Integration**: Works seamlessly with core contracts in `../core/`

## Installation

### From NPM (when published)

```bash
npm install @reflex-mev/sdk
```

### From Monorepo (development)

```bash
# Clone the entire Reflex monorepo
git clone --recursive https://github.com/reflex-mev/reflex.git
cd reflex/sdk

# Install dependencies
npm install

# Build the SDK
npm run build
```

## Quick Start

```typescript
import { ReflexSDK, ExecuteParams, BackrunParams } from '@reflex-mev/sdk';
import { ethers } from 'ethers';

// Initialize provider and signer
const provider = new ethers.JsonRpcProvider('YOUR_RPC_URL');
const signer = new ethers.Wallet('YOUR_PRIVATE_KEY', provider);

// Create SDK instance
const reflexSdk = new ReflexSDK(provider, signer, {
  routerAddress: '0xYourReflexRouterAddress',
  defaultGasLimit: 500000n,
  gasPriceMultiplier: 1.1,
});

// Execute a backruned transaction
const executeParams: ExecuteParams = {
  target: '0xTargetContract',
  value: BigInt(0),
  callData: '0x1234...',
};

const backrunParams: BackrunParams[] = [
  {
    triggerPoolId: '0x1234...5678',
    swapAmountIn: BigInt(1000000),
    token0In: true,
    recipient: '0xRecipientAddress',
  },
];

const result = await reflexSdk.backrunedExecute(executeParams, backrunParams);
console.log('Profits:', result.profits);
console.log('Profit tokens:', result.profitTokens);
```

## API Reference

### ReflexSDK

#### Constructor

```typescript
new ReflexSDK(provider: Provider, signer: Signer, config: ReflexConfig)
```

#### Methods

##### `backrunedExecute(executeParams, backrunParams, options?)`

Executes arbitrary calldata and triggers multiple MEV capture operations.

**Parameters:**

- `executeParams: ExecuteParams` - Parameters for the initial execution
- `backrunParams: BackrunParams[]` - Array of MEV capture parameters
- `options?: TransactionOptions` - Optional transaction settings

**Returns:** `Promise<BackrunedExecuteResult>`

##### `estimateBackrunedExecuteGas(executeParams, backrunParams)`

Estimates gas for a MEV capture execution operation.

**Returns:** `Promise<bigint>`

##### `getAdmin()`

Gets the current admin address of the Reflex Router.

**Returns:** `Promise<string>`

##### `getQuoter()`

Gets the current ReflexQuoter address.

**Returns:** `Promise<string>`

##### `watchBackrunExecuted(callback, options?)`

Listens for MEV capture executed events.

**Parameters:**

- `callback: (event: BackrunExecutedEvent) => void` - Event handler
- `options?: EventFilterOptions` - Optional event filters

**Returns:** `() => void` - Unsubscribe function

##### `encodeBackrunedExecute(executeParams, backrunParams)`

Encodes function data for batch transactions.

**Returns:** `string`

### Types

#### `ExecuteParams`

```typescript
interface ExecuteParams {
  target: string; // Target contract address
  value: bigint; // ETH value to send
  callData: BytesLike; // Encoded calldata
}
```

#### `BackrunParams`

```typescript
interface BackrunParams {
  triggerPoolId: string; // Pool ID that triggered the opportunity
  swapAmountIn: BigNumberish; // Input amount for arbitrage
  token0In: boolean; // Whether to use token0 as input
  recipient: string; // Address to receive profits
  configId?: string; // Configuration ID for profit splitting
}
```

#### `BackrunedExecuteResult`

```typescript
interface BackrunedExecuteResult {
  success: boolean; // Whether initial call succeeded
  returnData: string; // Return data from initial call
  profits: bigint[]; // Profit amounts from each MEV capture
  profitTokens: string[]; // Token addresses for each profit
  transactionHash: string; // Transaction hash
}
```

### Utility Functions

#### Address and Data Validation

```typescript
import { isValidAddress, isValidBytes32 } from '@reflex-mev/sdk';

isValidAddress('0x1234...5678'); // boolean
isValidBytes32('0x1234...5678'); // boolean
```

#### Token Amount Formatting

```typescript
import { formatTokenAmount, parseTokenAmount } from '@reflex-mev/sdk';

// Format BigInt to human-readable string
formatTokenAmount(BigInt('1500000000000000000')); // "1.5"

// Parse string to BigInt
parseTokenAmount('1.5'); // BigInt('1500000000000000000')
```

#### Profit Calculation

```typescript
import { calculateProfitPercentage } from '@reflex-mev/sdk';

calculateProfitPercentage(BigInt('100'), BigInt('1000')); // 10 (%)
```

## Event Monitoring

```typescript
// Watch for MEV capture events
const unsubscribe = reflexSdk.watchBackrunExecuted(
  event => {
    console.log('MEV capture executed:', event);
  },
  {
    triggerPoolId: '0x1234...', // Optional filter
    profitToken: '0x5678...', // Optional filter
    recipient: '0x9abc...', // Optional filter
  }
);

// Stop watching
unsubscribe();
```

## Error Handling

The SDK provides detailed error messages for common issues:

```typescript
try {
  const result = await reflexSdk.backrunedExecute(executeParams, backrunParams);
} catch (error) {
  console.error('MEV capture failed:', error.message);
}
```

## Testing

The SDK includes a comprehensive test suite with 49+ tests covering all functionality:

```bash
# Run all tests
npm test

# Run tests with coverage
npm run test:coverage

# Run specific test files
npm test -- tests/ReflexSDK.test.ts
npm test -- tests/utils.test.ts
npm test -- tests/integration.test.ts
```

### Test Coverage

- **ReflexSDK.test.ts**: Core SDK functionality (10+ tests)
- **utils.test.ts**: Utility functions (8+ tests)
- **types.test.ts**: Type definitions (4+ tests)
- **constants.test.ts**: Constants and ABI (3+ tests)
- **integration.test.ts**: End-to-end scenarios (3+ tests)

## Development

This SDK is part of the Reflex monorepo. For development:

```bash
# Navigate to the SDK directory
cd reflex/sdk

# Install dependencies
npm install

# Build the SDK
npm run build

# Run tests
npm test

# Run in development mode with watch
npm run dev
```

### Building

```bash
npm run build
```

## 📦 Publishing

### For Maintainers

The SDK uses automated publishing through GitHub Actions. There are two ways to publish:

#### Method 1: Git Tags (Recommended)

```bash
# Create and push a version tag
git tag sdk-v1.0.0
git push origin sdk-v1.0.0
```

This automatically triggers the publish workflow and creates a GitHub release.

#### Method 2: Manual Release Script

```bash
# Run the release script
./scripts/release.sh 1.0.0 latest

# For beta releases
./scripts/release.sh 1.0.0-beta.1 beta
```

#### Method 3: Manual Workflow Dispatch

Use the GitHub Actions interface to manually trigger a release with custom version and tag.

### Publishing Process

1. **Automated Checks**: Linting, testing, and building
2. **Version Update**: Updates package.json version
3. **NPM Publish**: Publishes to [@reflex-mev/sdk](https://www.npmjs.com/package/@reflex-mev/sdk)
4. **GitHub Release**: Creates release with changelog
5. **Git Tags**: Tags the release in git

### NPM Tags

- `latest`: Stable releases (default)
- `beta`: Beta releases for testing
- `alpha`: Alpha releases for early testing

```bash
# Install specific versions
npm install @reflex-mev/sdk@latest
npm install @reflex-mev/sdk@beta
npm install @reflex-mev/sdk@1.0.0
```

## License

MIT License - see LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

### Development Workflow

```bash
# Install dependencies
npm install

# Run tests in watch mode
npm run test -- --watch

# Lint and format code
npm run lint
npm run format

# Build for testing
npm run build

# Test publish (dry run)
npm run publish:dry
```

## Support

For issues and questions:

- GitHub Issues: [Create an issue](https://github.com/reflex-mev/reflex/issues)
- Documentation: [View docs](https://reflex-mev.github.io/reflex)
- NPM Package: [@reflex-mev/sdk](https://www.npmjs.com/package/@reflex-mev/sdk)
