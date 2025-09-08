<div align="center">
  <img src="logo.svg" alt="Reflex MEV Logo" />
</div>

![License](https://img.shields.io/badge/License-MIT-green.svg)
![MEV](https://img.shields.io/badge/MEV-Capture%20Engine-green.svg)
![DeFi](https://img.shields.io/badge/DeFi-Integration-purple.svg)
![Coverage](https://img.shields.io/badge/Coverage-94%25-brightgreen.svg)

**Reflex** is a sophisticated on-chain MEV (Maximum Extractable Value) capture engine designed for seamless integration into DEX protocols, specifically optimized for Algebra-based AMM systems. The system captures MEV opportunities while maintaining safety, decentralization, and ensuring zero interference with pool state or user experience.

## 📁 Monorepo Structure

This repository is structured as a monorepo containing multiple packages:

```
reflex/
├── core/                   # Core Solidity contracts and Forge project
│   ├── src/               # Smart contracts
│   ├── test/              # Comprehensive test suite (322+ tests)
│   ├── script/            # Deployment and maintenance scripts
│   ├── lib/               # External dependencies (git submodules)
│   └── README.md          # Core package documentation
├── sdk/                   # TypeScript SDK for client integration
│   ├── src/               # SDK source code
│   ├── tests/             # SDK test suite (49+ tests)
│   ├── examples/          # Usage examples
│   └── README.md          # SDK documentation
├── docs/                  # Protocol documentation
└── README.md             # This file (main documentation)
```

## 📦 Packages

### [Core Contracts](/core) (`/core`)

The foundational Solidity contracts that power the Reflex MEV system:

- **ReflexRouter**: Main router contract handling backrun execution and profit distribution
- **AlgebraBasePluginV3**: Algebra protocol integration with sliding fees and MEV hooks
- **ReflexAfterSwap**: Abstract base for MEV capture logic
- **FundsSplitter**: Multi-party profit distribution system
- **Comprehensive Test Suite**: 322+ tests ensuring system reliability and security

[→ See Core Documentation](/core/README.md)

### [TypeScript SDK](/sdk) (`/sdk`)

Client-side integration library for developers:

- **ReflexSDK**: Main SDK class providing easy contract interaction
- **Type Definitions**: Full TypeScript support for all contract interfaces
- **Utility Functions**: Address validation, token formatting, profit calculations
- **Event Monitoring**: Real-time event watching and filtering
- **Well Tested**: 49+ tests covering all SDK functionality

[→ See SDK Documentation](/sdk/README.md)

## 🚀 Getting Started

### Prerequisites

- [Foundry](https://getfoundry.sh/) - Ethereum development toolkit
- [Node.js](https://nodejs.org/) - JavaScript runtime (for SDK)

### Installation

1. Clone the repository with submodules:

```bash
git clone --recursive https://github.com/reflex-mev/reflex.git
cd reflex
```

2. If you already cloned without submodules, initialize them:

```bash
git submodule update --init --recursive
```

### Quick Start

**Core contracts:**

```bash
cd core
forge build
forge test
```

**SDK:**

```bash
cd sdk
npm install
npm run build
npm test
```

For detailed setup and usage instructions, see the individual package READMEs:

- [Core Documentation](/core/README.md) - Smart contracts, deployment, and testing
- [SDK Documentation](/sdk/README.md) - TypeScript integration and examples

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes and add tests
4. Ensure all tests pass
5. Commit your changes (`git commit -m 'Add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🔗 Related Projects

- [OpenZeppelin](https://github.com/OpenZeppelin/openzeppelin-contracts) - Security and utility contracts
- [Foundry](https://github.com/foundry-rs/foundry) - Development framework

## 📞 Support

For questions, issues, or contributions, please:

- Open an issue on GitHub
- Check the package-specific documentation for detailed usage
- Review the test suites for implementation examples

---

**⚠️ Disclaimer**: This software is provided as-is. Users should conduct their own testing and security reviews before deploying to production environments.
