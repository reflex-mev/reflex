# Reflex Core Contracts

![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue.svg)
![Foundry](https://img.shields.io/badge/Built%20with-Foundry-red.svg)
![Tests](https://img.shields.io/badge/Tests-373%20Passing-brightgreen.svg)

The core Solidity contracts that power the Reflex MEV capture engine, designed for seamless integration into DEX protocols and AMM systems.

## 🚀 Key Features

### Core MEV Functionality

- **Non-Intrusive Design**: Operates without affecting pool state or user transactions
- **Real-time MEV Capture**: Automatically detects and captures profitable opportunities after each swap
- **Failsafe Mechanisms**: Robust error handling prevents any disruption to normal DEX operations
- **Gas Optimized**: Minimal overhead with efficient execution paths

### Advanced Control Systems

- **Runtime Enable/Disable**: Toggle MEV capture functionality without contract redeployment
- **Authorization Framework**: Flexible access control system for secure administration
- **Configurable Profit Sharing**: Split captured profits between swap recipients and fund distribution
- **Multi-Configuration Support**: Support for different profit distribution configurations per config ID
- **Plugin-Level Integration**: Seamlessly integrates with various DEX plugin architectures
- **Fee Optimization**: Smart fee management to maximize profit extraction

### Safety & Security

- **Reentrancy Protection**: Built-in guards against reentrancy attacks
- **Dust Handling**: Proper handling of token remainders to prevent value loss
- **Comprehensive Testing**: 373+ tests covering all functionality and edge cases
- **MIT Licensed**: Open source with permissive licensing

## 🏗️ Architecture

### Core Components

#### `ReflexRouter`

Main router contract handling MEV capture execution:

- Executes arbitrary calldata and triggers multiple MEV capture operations
- Gas-optimized execution paths
- Built-in graceful reentrancy protection
- Event emission for monitoring and analytics
- Integrated revenue distribution with ConfigurableRevenueDistributor

#### `ReflexAfterSwap`

Abstract base contract for MEV capture logic:

- Implements the core profit extraction and distribution mechanism
- Configurable recipient share functionality (up to 50% of profits)
- **Configuration ID support** for different profit distribution setups
- Integration with `ConfigurableRevenueDistributor` for multi-party profit distribution
- Reentrancy-protected with comprehensive validation

#### `ConfigurableRevenueDistributor`

Advanced profit distribution system supporting multiple configurations:

- **Multiple Distribution Configurations**: Support for different profit splits per config ID
- **Basis Points System**: Precise percentage allocation using basis points (1% = 100 bps)
- **Stateless Design**: No fund storage, immediate distribution on receipt
- **Default Configuration**: Fallback distribution when specific config not found
- **Admin-Controlled**: Secure configuration management with access controls

### Integration Flow

1. **Swap Execution**: User performs swap on supported DEX
2. **MEV Detection**: System identifies profitable arbitrage opportunities
3. **Hook Trigger**: Swap completion triggers MEV capture logic
4. **MEV Check**: System checks if MEV capture is enabled
5. **Profit Extraction**: If enabled, triggers backrun through ReflexRouter with config ID
6. **Config Resolution**: Router uses config ID to determine profit distribution rules
7. **Profit Distribution**: Captured profits are split according to the configuration
8. **Failsafe**: Any errors are caught to prevent disruption

## 🔐 Authorization System

- **Flexible role-based access control**: Secure permission management for administrative functions
- **Upgradeable authorization framework**: Extensible system that can adapt to different protocol requirements
- **Administrative functions protection**: All sensitive operations are protected by access controls

## ⚙️ Configuration System

### Configuration IDs

The system supports multiple profit distribution configurations through configuration IDs:

- **Config ID**: 32-byte identifier (`bytes32`) used to select profit distribution configuration
- **Default Configuration**: Fallback used when no specific configuration is found
- **Per-Plugin Configuration**: Each plugin can be deployed with its own config ID
- **Runtime Flexibility**: Configurations can be updated by authorized administrators

### Profit Distribution Flow

1. **Plugin Deployment**: Plugin is deployed with a specific config ID
2. **Swap Execution**: User performs swap, triggering MEV capture
3. **Config Lookup**: System uses the plugin's config ID to find distribution rules
4. **Profit Split**: Captured profits are distributed according to the configuration
5. **Fallback Handling**: If config not found, default configuration is used

### Configuration Management

```solidity
// Example configuration setup
bytes32 configId = keccak256("protocol-v1");

// Recipients and their shares
address[] memory recipients = [treasury, lpRewards, devFund];
uint256[] memory shares = [5000, 3000, 1500]; // 50%, 30%, 15%
uint256 dustShare = 500; // 5% for dust/remainder

// Update configuration (admin only)
router.updateShares(configId, recipients, shares, dustShare);
```

## Testing

The repository includes comprehensive test suites for all components.

### Running Tests

```shell
# Run all tests
forge test

# Run specific test categories
forge test --match-contract AlgebraBasePluginV3Test
forge test --match-contract ReflexAfterSwapTest
forge test --match-contract ConfigurableRevenueDistributorTest

# Run configId functionality tests
forge test --match-test "test.*ConfigId"

# Run fee exemption tests specifically
forge test --match-test "test_BeforeSwap_.*"

# Run with gas reporting
forge test --gas-report

# Run with coverage
forge coverage
```

## 📋 Development Setup

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

### Installation

```shell
# Clone the repository
git clone --recursive https://github.com/reflex-mev/reflex.git
cd reflex/core

# Install dependencies
forge install

# Build the project
forge build

# Run tests
forge test
```

### Project Structure

```
src/
├── ReflexRouter.sol                   # Main router with MEV capture functionality
├── integrations/
│   ├── algebra/
│   │   └── full/
│   │       └── AlgebraBasePluginV3.sol    # Main plugin contract
│   ├── ReflexAfterSwap.sol            # MEV capture logic
│   ├── ConfigurableRevenueDistributor/ # Advanced profit distribution system
│   │   ├── ConfigurableRevenueDistributor.sol
│   │   └── IConfigurableRevenueDistributor.sol
│   └── FundsSplitter/                 # Basic profit distribution system
├── interfaces/                       # Contract interfaces
├── libraries/                        # Shared libraries
└── utils/                           # Utility contracts

test/
├── integrations/                     # Integration tests
├── ReflexRouter/                     # Router-specific tests
├── utils/                           # Test utilities
└── mocks/                          # Mock contracts

script/
├── deploy-reflex-router/            # Router deployment scripts
├── deploy-v1-factory/               # Factory deployment scripts
├── deploy-v3-plugin/                # Plugin deployment scripts
└── production/                      # Production deployment scripts
```

## 🔧 Configuration Examples

### Basic Plugin Deployment

```solidity
// Deploy with MEV capture enabled by default and specific config ID
bytes32 configId = keccak256("my-protocol-config");
AlgebraBasePluginV3 plugin = new AlgebraBasePluginV3(
    poolAddress,
    factoryAddress,
    pluginFactoryAddress,
    baseFee,
    reflexRouterAddress,
    configId
);
```

### Configuration Management

```solidity
// Set up a custom profit distribution configuration
bytes32 configId = keccak256("custom-config");
address[] memory recipients = new address[](2);
recipients[0] = protocolTreasury;
recipients[1] = lpIncentivePool;

uint256[] memory sharesBps = new uint256[](2);
sharesBps[0] = 6000; // 60% to treasury
sharesBps[1] = 3000; // 30% to LP incentives

uint256 dustShareBps = 1000; // 10% remainder

// Update the configuration (admin only)
reflexRouter.updateShares(configId, recipients, sharesBps, dustShareBps);
```

### Runtime Configuration

```solidity
// Disable MEV capture
plugin.setReflexEnabled(false);

// Re-enable MEV capture
plugin.setReflexEnabled(true);
```

### Fee Exemption in Action

```solidity
// When a normal user swaps - they pay the calculated fee
user.swap() -> beforeSwap(normalUser, ...) -> fee = 500 (0.05%)

// When reflexRouter performs MEV capture - zero fee automatically applied
reflexRouter.triggerBackrun() -> beforeSwap(reflexRouter, ...) -> fee = 0 (0%)

// Verification
assert(plugin.getRouter() == address(reflexRouter));
```

## 🛠️ Development Commands

### Build

```shell
forge build
```

### Test

```shell
# Run all tests
forge test

# Run with verbosity
forge test -v

# Run specific tests
forge test --match-test "testReflexAfterSwap"
forge test --match-contract "AlgebraBasePluginV3Test"

# Run with gas reporting
forge test --gas-report
```

### Code Quality

```shell
# Format code
forge fmt

# Generate gas snapshots
forge snapshot

# Generate coverage report
forge coverage
```

### Deployment

```shell
# Deploy to local network
forge script script/deploy-reflex-router/DeployReflexRouter.s.sol --rpc-url http://localhost:8545 --private-key <key> --broadcast

# Deploy to testnet
forge script script/deploy-reflex-router/DeployReflexRouter.s.sol --rpc-url <testnet_rpc> --private-key <key> --broadcast --verify

# Deploy plugin
forge script script/deploy-v3-plugin/DeployAlgebraBasePluginV3.s.sol --rpc-url <rpc_url> --private-key <key> --broadcast
```

### Local Development

```shell
# Start local blockchain
anvil

# Deploy contracts (example)
forge script script/deploy-reflex-router/DeployReflexRouter.s.sol --rpc-url http://localhost:8545 --private-key <key> --broadcast

# Interact with contracts
cast call <contract_address> "reflexEnabled()" --rpc-url http://localhost:8545
```

## 🔒 Security Considerations

### Reentrancy Protection

The system uses a graceful reentrancy guard that allows one entry per function call and gracefully exits on reentrancy attempts instead of reverting:

```solidity
modifier gracefulNonReentrant() {
    if (_status == _ENTERED) {
        return; // Graceful exit instead of revert
    }
    _status = _ENTERED;
    _;
    _status = _NOT_ENTERED;
}
```

### Authorization

All sensitive functions are protected by Algebra's authorization system:

```solidity
modifier onlyAdministrator() {
    require(IAlgebraFactory(factory).hasRoleOrOwner(ALGEBRA_BASE_PLUGIN_MANAGER, msg.sender));
    _;
}
```

## 🆘 Help

```shell
forge --help
anvil --help
cast --help
```

## 📚 Additional Resources

- [Reflex Documentation](https://reflex-mev.github.io/reflex) - Complete protocol documentation
- [Integration Guide](https://reflex-mev.github.io/reflex/integration/overview) - How to integrate Reflex
- [API Reference](https://reflex-mev.github.io/reflex/api/smart-contracts) - Smart contract API documentation
- [Security Guide](https://reflex-mev.github.io/reflex/security) - Security considerations and best practices
- [Foundry Book](https://book.getfoundry.sh/) - Comprehensive Foundry documentation
- [Algebra Documentation](https://docs.algebra.finance/) - Algebra protocol documentation
- [Solidity Documentation](https://docs.soliditylang.org/) - Solidity language reference

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and add tests
4. Ensure all tests pass (`forge test`)
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

For detailed contribution guidelines, see our [documentation](https://reflex-mev.github.io/reflex).

## 📞 Support

For questions, issues, or contributions:

- **📋 Issues**: [Open an issue](https://github.com/reflex-mev/reflex/issues/new/choose) for bugs or feature requests
- **📖 Documentation**: Check our [comprehensive docs](https://reflex-mev.github.io/reflex) for detailed guides
- **🛡️ Security**: Follow our [Security Policy](https://reflex-mev.github.io/reflex/security) for vulnerability reports
- **🐦 Twitter**: Follow [@ReflexMEV](https://x.com/ReflexMEV) for updates
- **📧 Email**: Contact us at team@reflexmev.io

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

---

**⚠️ Disclaimer**: This software is provided as-is. Users should conduct their own testing and security reviews before deploying to production environments.
