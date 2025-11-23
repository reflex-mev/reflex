---
sidebar_position: 2
---

# Security Audits

## 🔍 Professional Security Reviews

We take security seriously and work with leading audit firms to ensure the highest level of security for the Reflex protocol.

### Completed Audits

| Auditor                                             | Scope         | Date           | Status  | Report                                                                                                                   |
| --------------------------------------------------- | ------------- | -------------- | ------- | ------------------------------------------------------------------------------------------------------------------------ |
| **[Optimum Security](https://www.optimumsec.xyz/)** | Full Protocol | September 2025 | ✅ Done | [View Audit Report](https://github.com/reflex-mev/reflex/blob/main/audits/september-2025-reflex-security-assessment.pdf) |
| **[Optimum Security](https://www.optimumsec.xyz/)** | Full Protocol | November 2025  | ✅ Done | [View Audit Report](https://github.com/reflex-mev/reflex/blob/main/audits/november-2025-reflex-security-assessment.pdf)  |

### Audit Scope

Our security audits cover the entire Reflex protocol, including:

#### Core Contracts

- **ReflexRouter**: Main router contract handling MEV capture and profit distribution
- **ConfigurableRevenueDistributor**: Flexible profit distribution system
- **GracefulReentrancyGuard**: Custom reentrancy protection implementation

#### Integration Contracts

- **ReflexAfterSwap**: Algebra/Uniswap V3 plugin integration
- **BackrunEnabledSwapProxy**: Universal DEX integration pattern

### Audit Highlights

**September 2025 Audit (Optimum Security)**

- Full protocol security review
- Smart contract best practices validation
- Economic model verification
- Integration pattern analysis

**November 2025 Audit (Optimum Security)**

- Follow-up security review
- New features and improvements validation
- Universal integration pattern verification
- Additional integration testing

## 🛡️ Internal Security Measures

While external audits provide independent verification, we maintain rigorous internal security practices:

### Continuous Security Practices

- **Comprehensive Testing**: 98%+ code coverage across all contracts
- **Static Analysis**: Continuous monitoring with Slither, Mythril, and custom tools
- **Peer Review**: Minimum 3 reviewer approval for all changes
- **Formal Verification**: Critical functions verified with symbolic execution tools

## 🔐 Audit Transparency

### Public Disclosure

All audit reports are publicly available in our GitHub repository:

- [View All Audits](https://github.com/reflex-mev/reflex/tree/main/audits)
- [Security Documentation](https://github.com/reflex-mev/reflex/blob/main/website/docs/security/overview.md)
