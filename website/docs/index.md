---
sidebar_position: 0
slug: /
---

# Overview

## Introduction

Reflex is an on-chain MEV capture engine designed to reclaim backrun profits for protocols, users, and ecosystems. Instead of letting external actors extract value, Reflex routes that value back into the protocol environment.

### Key features:

- **100% on-chain**: no backend dependencies, no private servers.
- **Plug and play**: integration requires no changes to existing smart contracts.
- **Secure by design**: Reflex is fully non-custodial, operating independently of user funds and requiring no approval access.
- **Cross-ecosystem**: works across EVM protocols, and L1,L2 environments.

## Protocol Integrations

### Overview

Protocols can integrate Reflex at different levels of depth. From pool-level hooks to router-level integration, Reflex adapts to the architecture you already use.

### Reflex vs External Arbitrage

|                       | External Arbitrage (current state)                    | Reflex (integrated)                                     |
| --------------------- | ----------------------------------------------------- | ------------------------------------------------------- |
| **MEV profits**       | Captured by third-party searchers, exit the ecosystem | Redirected on-chain to users or the protocol treasury   |
| **Protocol revenue**  | None — profits leak to external actors                | Configurable share of profits accrue to the protocol    |
| **Execution control** | Uncoordinated, opaque, dependent on external bots     | Native, deterministic, fully on-chain                   |
| **Security**          | No alignment between arbitrageur and protocol         | Protocol retains control of how profits are distributed |

### Why this matters:

Arbitrage is inevitable, but today it benefits external actors who have no alignment with your protocol. Reflex ensures the same arbitrage happens within your ecosystem and its profits are redistributed according to your rules.

### Integration Types

Reflex offers three primary integration methods to suit different protocol architectures and use cases:

1. **[DEX Plugin-Based Integration](./integration/overview#1-dex-plugin-based-integration)** - For DEXes with hook/plugin support (Algebra, PancakeSwap Infinity, Uniswap v4)

2. **[Universal DEX Integration](./integration/overview#2-universal-dex-integration)** - For any DEX and client-side applications using SwapProxy + SDK

3. **[Direct Contract Access](./integration/overview#3-direct-contract-access)** - For custom smart contract integration with full control

### Supported Protocols

Reflex is protocol-agnostic and already runs with leading DEXs and aggregators across EVM ecosystem.

### Getting Started

1. Contact us to request an API key.

2. Configure payout addresses.

3. Plug and play integration (hook, router, sdk).

4. Start capturing MEV profits immediately.

## Technical Documentation

Ready to integrate Reflex into your protocol? Check out our comprehensive guides:

- � [**Integration Guide**](./integration/overview) - Step-by-step integration instructions
- � [**API Reference**](./api/smart-contracts) - Complete contract documentation
- 🏗️ [**Architecture**](./architecture) - Understand the system design
- � [**Security**](./security) - Security considerations and best practices

## What's Next?

1. **[Start with Integration](./integration/overview)** - Learn how to integrate Reflex
2. **[Read the Architecture](./architecture)** - Understand the system design
3. **[Plugin-Based Integration](./integration/plugin-based)** - For DEXes with hook support
4. **[Universal DEX Integration](./integration/universal-dex)** - For any DEX or DApp
5. **[Direct Contract Access](./integration/direct-access)** - For custom protocols

---

_Ready to revolutionize MEV capture? Let's get started! 🚀_
