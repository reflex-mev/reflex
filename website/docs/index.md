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
- **Cross-ecosystem**: works across EVM protocols, Solana, and L2 environments.

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

#### 1. Protocol Hooks

Reflex integrates natively with modern hook/plugin architectures:

- PancakeSwap Infinity hooks
- Algebra Integral plugins
- Uniswap v4 hooks

**_How it works:_**

When a user executes a swap, Reflex's integrated `afterSwap` is triggered to capture arbitrage opportunities across pools and protocols, with profits routed back to the protocol treasury or designated addresses.

#### 2. Router Integration

For DEXs that don't use a hook system, Reflex can integrate directly into the router contract. This method enables the router to trigger Reflex opportunities whenever trades pass through it.

#### 3. EIP-7702 (Account Abstraction Bundles)

Reflex supports account abstraction environments where trades can be wrapped into bundles. This allows traders and protocols to:

- Embed Reflex backruns into user-submitted bundles.
- Ensure arbitrage profits are redirected back on-chain.

#### 4. SDK Integration

Use the TypeScript SDK for custom MEV strategies and manual triggers. This approach gives you full control over when and how backruns are executed, perfect for building sophisticated MEV bots, custom trading strategies, or integrating Reflex into existing applications with specific requirements.

### Supported Protocols

Reflex is protocol-agnostic and already runs with leading DEXs and aggregators across EVM ecosystem.

### Getting Started

1. Contact us to request an API key.

2. Configure payout addresses.

3. Plug and play integration (hook, router, sdk).

4. Start capturing MEV profits immediately.

## Technical Documentation

Ready to integrate Reflex into your protocol? Check out our comprehensive guides:

- 📚 [**Installation Guide**](./technical/getting-started/installation) - Set up your development environment
- 🚀 [**Quick Start**](./technical/getting-started/quick-start) - Get up and running in minutes
- 🔗 [**Integration Guide**](./technical/integration/overview) - Step-by-step integration instructions
- 📖 [**API Reference**](./technical/api/smart-contracts) - Complete contract documentation

## What's Next?

1. **[Install Reflex](./technical/getting-started/installation)** - Set up your development environment
2. **[Try the Examples](./technical/examples/basic-backrun)** - See Reflex in action
3. **[Read the Architecture](./technical/architecture/overview)** - Understand the system design
4. **[Deploy Your First Plugin](./technical/integration/overview)** - Start capturing MEV

---

_Ready to revolutionize MEV capture? Let's get started! 🚀_
