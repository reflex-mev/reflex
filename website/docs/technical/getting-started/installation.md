---
sidebar_position: 1
---

# Installation

Get started with Reflex Protocol by setting up your development environment and installing the necessary dependencies.

## Prerequisites

Before you begin, ensure you have the following installed:

- **Node.js** (v18 or higher)
- **npm** or **yarn**
- **Git**
- **Foundry** (for smart contract development)

## Environment Setup

### 1. Install Foundry

Foundry is required for smart contract compilation and testing:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### 2. Clone the Repository

```bash
git clone https://github.com/reflex-mev/reflex.git
cd reflex
```

### 3. Install Dependencies

#### Smart Contracts (Core)

```bash
cd core
forge install
```

#### TypeScript SDK

```bash
cd sdk
npm install
# or
yarn install
```

#### Documentation (Optional)

```bash
cd website
npm install
# or
yarn install
```

## Package Installation

### Using npm

```bash
# Install the TypeScript SDK
npm install @reflex/sdk

# Install additional utilities (optional)
npm install @reflex/utils @reflex/types
```

### Using yarn

```bash
# Install the TypeScript SDK
yarn add @reflex/sdk

# Install additional utilities (optional)
yarn add @reflex/utils @reflex/types
```

## Verification

Verify your installation by running the test suites:

### Smart Contracts

```bash
cd core
forge test
```

Expected output:

```
Running 1 test for test/ReflexRouter.t.sol:ReflexRouterTest
[PASS] testTriggerBackrun() (gas: 150000)
Test result: ok. 1 passed; 0 failed; finished in 1.2s
```

### TypeScript SDK

```bash
cd sdk
npm test
```

Expected output:

```
✓ ReflexSDK initialization
✓ Contract interactions
✓ Event parsing
✓ Gas estimation

4 passing (2.3s)
```

## Configuration

### Environment Variables

Create a `.env` file in your project root:

```bash
# Network configuration
RPC_URL=https://mainnet.infura.io/v3/YOUR_PROJECT_ID
PRIVATE_KEY=your_private_key_here

# Contract addresses (mainnet)
REFLEX_ROUTER=0x...
REFLEX_QUOTER=0x...

# Optional: Development settings
DEBUG=true
GAS_LIMIT=500000
```

### Network Configuration

For development, you can use the following network configurations:

#### Hardhat Config

```javascript
// hardhat.config.js
require("@nomiclabs/hardhat-ethers");

module.exports = {
  solidity: "0.8.19",
  networks: {
    hardhat: {
      forking: {
        url: process.env.RPC_URL,
        blockNumber: 18500000,
      },
    },
    goerli: {
      url: "https://goerli.infura.io/v3/YOUR_PROJECT_ID",
      accounts: [process.env.PRIVATE_KEY],
    },
  },
};
```

#### Foundry Config

```toml
# foundry.toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]
solc = "0.8.19"
optimizer = true
optimizer_runs = 200

[rpc_endpoints]
mainnet = "${RPC_URL}"
goerli = "https://goerli.infura.io/v3/YOUR_PROJECT_ID"
```

## IDE Setup

### VS Code Extensions

Recommended extensions for development:

- **Solidity** (by Juan Blanco)
- **Hardhat for Visual Studio Code**
- **Better Comments**
- **GitLens**

### VS Code Settings

Add to your `.vscode/settings.json`:

```json
{
  "solidity.compiler.version": "v0.8.19+commit.7dd6d404",
  "solidity.packageDefaultDependenciesContractsDirectory": "contracts",
  "solidity.packageDefaultDependenciesDirectory": "node_modules",
  "files.associations": {
    "*.sol": "solidity"
  }
}
```

## Troubleshooting

### Common Issues

#### Foundry Installation Issues

If you encounter issues with Foundry installation:

```bash
# Update Foundry
foundryup

# Check version
forge --version
```

#### Node.js Version Issues

Ensure you're using Node.js v18 or higher:

```bash
node --version
# Should output v18.0.0 or higher

# If using nvm
nvm install 18
nvm use 18
```

#### Permission Issues

On macOS/Linux, if you encounter permission issues:

```bash
# Fix npm permissions
sudo chown -R $(whoami) ~/.npm
```

#### Network Connection Issues

If you're behind a corporate firewall:

```bash
# Configure npm proxy
npm config set proxy http://proxy.company.com:8080
npm config set https-proxy http://proxy.company.com:8080

# Or use yarn
yarn config set proxy http://proxy.company.com:8080
yarn config set https-proxy http://proxy.company.com:8080
```

### Getting Help

If you encounter issues not covered here:

1. Check the [GitHub Issues](https://github.com/reflex-mev/reflex/issues)
2. Join our [Discord](https://discord.gg/reflex) for community support
3. Review the [Security Overview](../security/overview)

## Next Steps

Now that you have Reflex installed, you can:

1. 🚀 **[Quick Start](quick-start)** - Deploy your first integration
2. 📚 **[Examples](../examples/basic-backrun)** - Explore sample implementations
3. 🏗️ **[Architecture](../architecture/overview)** - Understand the system design

---

**Need help?** Join our community on [Discord](https://discord.gg/reflex) or check out our [GitHub discussions](https://github.com/reflex-mev/reflex/discussions).
