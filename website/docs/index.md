---
sidebar_position: 0
slug: /
---

# Overview

## Introduction

Reflex is an on-chain MEV capture engine built for any product or protocol that controls trading flow.

If you operate a DEX, an aggregator, an RFQ system, or a smart order router — your flow creates arbitrage opportunities. Today, that arbitrage is captured by external bots and leaves your ecosystem.

**Reflex changes the economics:**

It captures the same arbitrage inside the user transaction itself and routes the profits back to the flow owner — or to LPs, users, or your treasury, based on your configuration.

Reflex also neutralizes toxic MEV such as sandwich attacks, converting harmful extraction into aligned, value-creating execution.

## Why Reflex is built for flow owners

- **Fully on-chain** — all computation and backrun execution happen directly on-chain, with no backend, no relayers, no off-chain solvers.

- **Plug-and-play integration** — works with leading DEXes and aggregators without requiring changes to your architecture.

- **Non-custodial** — Reflex never takes custody, never requires approvals, and cannot touch user funds.

- **Universal compatibility** — supports any trading flow that creates price impact and arbitrage.

- **Deterministic execution** — MEV capture occurs atomically inside the same transaction.

- **MEV protection** — Reflex absorbs sandwich attempts by converting the attacker's opportunity into internal arbitrage that benefits your ecosystem.

## Who can integrate Reflex?

Reflex is built for any execution layer that creates or routes swaps, including:

- **DEX protocols** — supporting all major AMM models and their routing layers

- **Aggregators and Smart Order Routers**

- **RFQ engines** that settle on-chain

- **Cross-chain routers** and bridge-based swap flows

- **L1/L2 native AMM modules**

If your system creates token price movement, Reflex allows you to reclaim the value that movement generates.

## Reflex vs External Arbitrage

|                      | External Arbitrage (today)                | Reflex (integrated)                                       |
| -------------------- | ----------------------------------------- | --------------------------------------------------------- |
| **MEV profits**      | Taken by searchers, leaving the ecosystem | Captured and redistributed to the flow owner              |
| **Ecosystem value**  | Lost                                      | Routed to LPs, users, or the treasury                     |
| **Execution path**   | Off-chain, opaque, unpredictable          | Native, deterministic, within the same transaction        |
| **Control**          | None                                      | Full control over profit routing                          |
| **Alignment**        | Zero alignment                            | 100% aligned with protocol incentives                     |
| **Sandwich attacks** | Harmful, extractive, user-hostile         | Neutralized — Reflex converts toxic MEV into positive MEV |

## Why this matters — for DEXes, aggregators, RFQ engines, and execution layers

Every swap you route creates price shifts.  
Price shifts create arbitrage.  
Arbitrage creates profit.

**If you do nothing, that profit is taken by outsiders.**

With Reflex, you internalize that value and turn it into a native revenue engine that strengthens your product, your users, and your ecosystem — while eliminating toxic MEV.

Reflex ensures you keep the value your flow creates.

## Integration Types

Reflex offers three primary integration methods to suit different protocol architectures and use cases:

1. **[DEX Plugin-Based Integration](./integration/plugin-based)** - For DEXes with hook/plugin support (Algebra, PancakeSwap Infinity, Uniswap v4)

2. **[Universal DEX Integration](./integration/universal-dex)** - For any DEX and client-side applications using SwapProxy + SDK

3. **[Direct Contract Access](./integration/direct-access)** - For custom smart contract integration with full control

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
- � [**API Reference**](./api/reflex-router) - Complete contract documentation
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
