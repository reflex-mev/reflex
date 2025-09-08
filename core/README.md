# Reflex Core Contracts

![Solidity](https://img.shields.io/badge/Solidity-0.8.20-blue.svg)
![Foundry](https://img.shields.io/badge/Built%20with-Foundry-red.svg)
![Tests](https://img.shields.io/badge/Tests-322%20Passing-brightgreen.svg)

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
- **Plugin-Level Integration**: Seamlessly integrates with various DEX plugin architectures
- **Fee Optimization**: Smart fee management to maximize profit extraction

### Safety & Security

- **Reentrancy Protection**: Built-in guards against reentrancy attacks
- **Dust Handling**: Proper handling of token remainders to prevent value loss
- **Comprehensive Testing**: 322+ tests covering all functionality and edge cases
- **MIT Licensed**: Open source with permissive licensing

## 🏗️ Architecture

### Core Components

#### `ReflexRouter`

Main router contract handling backrun execution:

- Executes arbitrary calldata and triggers multiple backruns
- Gas-optimized execution paths
- Built-in reentrancy protection
- Event emission for monitoring and analytics

#### `ReflexAfterSwap`

Abstract base contract for MEV capture logic:

- Implements the core profit extraction and distribution mechanism
- Configurable recipient share functionality (up to 50% of profits)
- Integration with `FundsSplitter` for multi-party profit distribution
- Reentrancy-protected with comprehensive validation

#### `FundsSplitter`

Handles distribution of captured profits:

- Supports multiple recipients with configurable shares
- Basis points system for precise percentage allocation
- Handles both ERC20 tokens and ETH distribution
- Dust handling ensures no value is lost

### Integration Flow

1. **Swap Execution**: User performs swap on supported DEX
2. **MEV Detection**: System identifies profitable arbitrage opportunities
3. **Hook Trigger**: Swap completion triggers MEV capture logic
4. **MEV Check**: System checks if MEV capture is enabled
5. **Profit Extraction**: If enabled, triggers backrun through ReflexRouter
6. **Profit Distribution**: Captured profits are split between recipient and fund distribution
7. **Failsafe**: Any errors are caught to prevent disruption

## 🛠️ Technical Features

### Enable/Disable Functionality

```solidity
// Enable or disable MEV capture at runtime
function setReflexEnabled(bool _enabled) external;

// Check current state
function reflexEnabled() external view returns (bool);
```

### Profit Sharing Configuration

```solidity
// Set percentage of profits to send directly to swap recipient
function setRecipientShare(uint256 _recipientShareBps) external;

// Maximum 50% (5000 basis points) allowed
// Remaining profits go to FundsSplitter distribution
```

### Authorization System

- Flexible role-based access control
- Secure, upgradeable authorization framework
- Administrative functions protected by access controls

## Testing

The repository includes comprehensive test suites for all components.

### Running Tests

```shell
# Run all tests
forge test

# Run specific test categories
forge test --match-contract AlgebraBasePluginV3Test
forge test --match-contract ReflexAfterSwapTest
forge test --match-contract FundsSplitterTest

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
├── ReflexRouter.sol                   # Main router with backrun functionality
├── integrations/
│   ├── algebra/
│   │   └── full/
│   │       └── AlgebraBasePluginV3.sol    # Main plugin contract
│   ├── ReflexAfterSwap.sol            # MEV capture logic
│   └── FundsSplitter/                 # Profit distribution system
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
// Deploy with MEV capture enabled by default
AlgebraBasePluginV3 plugin = new AlgebraBasePluginV3(
    poolAddress,
    factoryAddress,
    pluginFactoryAddress,
    baseFee,
    reflexRouterAddress
);
```

### Runtime Configuration

```solidity
// Disable MEV capture
plugin.setReflexEnabled(false);

// Set 25% of profits to go directly to swap recipient
plugin.setRecipientShare(2500); // 2500 basis points = 25%

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

### Profit Distribution Limits

Recipient share is capped at 50% to ensure reasonable profit distribution:

```solidity
require(_recipientShareBps <= MAX_RECIPIENT_SHARE_BPS, "Share too high");
```

## 🆘 Help

```shell
forge --help
anvil --help
cast --help
```

## 📚 Additional Resources

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

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

---

**⚠️ Disclaimer**: This software is provided as-is. Users should conduct their own testing and security reviews before deploying to production environments.
