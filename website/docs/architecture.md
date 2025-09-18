---
sidebar_position: 1
---

# Architecture

Understanding Reflex's architecture is key to building effective MEV capture strategies. This document provides a comprehensive overview of the system design, components, and data flow.

## 🏗️ High-Level Architecture

Reflex operates through a simple yet powerful architecture consisting of core smart contracts deployed per chain and multiple integration pathways for different entities. The system is designed to capture MEV opportunities and distribute profits fairly across the ecosystem.

### Core Components Per Chain

Each blockchain network has two core Reflex contracts:

```mermaid
graph LR
    subgraph "Users"
        UserGroup[👤 Users<br/>Traders & DeFi Users]
    end

    subgraph "Core Smart Contracts (Per Chain)"
        Router[⚡ Reflex Router<br/>Execution engine]
        Quoter[🧠 Reflex Quoter<br/>Profit detection & path optimization]
        Router <--> Quoter
    end

    subgraph "Onchain Clients"
        PluginDEX[🔌 Plugin-based DEX<br/>Automatic MEV capture via hooks]
        RegularDEX[🏪 Standard DEX<br/>Direct router integration]
    end

    subgraph "Offchain Clients"
        SDKApps[📱 SDK Applications<br/>DApps, MEV Bots]
    end

    %% User transactions trigger MEV opportunities
    UserGroup -->|Trade/Swap| PluginDEX
    UserGroup -->|Trade/Swap| RegularDEX
    UserGroup -->|Interact| SDKApps

    %% Client connections to core contracts
    PluginDEX -->|triggerBackrun| Router
    RegularDEX -->|triggerBackrun| Router
    SDKApps -->|backrunedExecute| Router
```

**Reflex Router** - The central execution engine that coordinates all MEV capture activities. Handles both automatic MEV capture through `triggerBackrun()` and protected transaction execution through `backrunedExecute()`.

**Reflex Quoter** - The analysis engine that detects MEV opportunities by analyzing price differences across DEX pools, calculating optimal arbitrage routes, and estimating profitability.

**Onchain Clients** - Smart contracts that integrate directly with Reflex:

- Plugin-based DEXes use hooks to automatically capture MEV after user swaps
- Standard DEXes integrate the router directly into their core contracts

**Offchain Clients** - Applications that use the Reflex SDK:

- DApps protect users from MEV while capturing profits
- MEV Bots implement custom strategies for professional MEV extraction

## 🧩 Core Components

### 1. Reflex Router

The central execution engine that coordinates all MEV capture activities. **One instance deployed per blockchain.**

**Key Responsibilities:**

- Executes MEV capture through two main entry points
- Coordinates with the quoter for profitability analysis
- Manages arbitrage execution for MEV capture
- Handles revenue distribution to configured recipients
- Maintains security through reentrancy protection

### 2. Reflex Quoter

The pricing and analysis engine that determines MEV opportunities. **One instance deployed per blockchain.**

**Key Responsibilities:**

- Analyzes price differences across DEX pools in real-time
- Calculates optimal arbitrage routes and execution paths
- Estimates gas costs and net profitability
- Provides execution parameters to the router
- Caches route data for efficiency

**Analysis Workflow:**

```mermaid
graph LR
    TriggerPool[🎯 Trigger] --> PriceCheck[📊 Analysis]
    PriceCheck --> RouteFind[🛣️ Route Discovery]
    RouteFind --> GasEst[⛽ Gas Estimation]
    GasEst --> ProfitCalc[💰 Profit Calculation]
    ProfitCalc --> ExecutionPlan[⚡ Execution Parameters]
```

### 3. Integration Types

Reflex supports three main integration patterns to accommodate different use cases:

**Plugin-based Integration** - Lightweight contracts that use DEX hooks or callbacks to automatically trigger MEV capture after user swaps. Ideal for existing DEX protocols that want to add MEV capture without modifying core contracts.

**Direct Integration** - DEX protocols integrate Reflex router calls directly into their core smart contracts. Provides maximum control and customization for revenue sharing and MEV strategies.

**SDK Integration** - Applications use the TypeScript SDK to interact with Reflex. Perfect for DApp frontends, MEV bots, trading tools, and any offchain application that wants to protect users or implement custom MEV strategies.

#### SDK Application Types:

- **DApp Frontends**: Protect users from MEV while capturing profits
- **MEV Bots**: Custom strategies for professional MEV extraction
- **Protocol UIs**: Integrated MEV capture in protocol interfaces
- **Trading Tools**: Enhanced trading with automatic MEV protection

#### SDK Capabilities:

- Event monitoring and opportunity detection
- Transaction simulation and profit estimation
- Automated MEV capture execution
- Multi-chain deployment management

## 🔄 Transaction Flow

### Standard Backrun Flow

```mermaid
sequenceDiagram
    participant User
    participant Integration as Reflex Integration<br/>(Plugin/SDK/Direct)
    participant Router as Reflex Router
    participant Quoter as Reflex Quoter

    User->>Integration: Execute Swap
    Integration->>Integration: Execute user swap
    Integration->>Router: triggerBackrun()
    Router->>Quoter: getQuote()
    Quoter-->>Router: profit estimate + route

    alt Profitable Opportunity
        Router->>Router: Execute arbitrage route
        Router->>Router: Distribute profits to user & protocol
    end
```

## 💡 Capabilities

### 1. Sandwich Attack Prevention

Transform harmful sandwich attacks into beneficial backruns:

```mermaid
graph LR
    BadMEV[😈 Sandwich Attack] --> Detection[🔍 Detection]
    Detection --> Mitigation[🛡️ Mitigation]
    Mitigation --> GoodMEV[😇 User Backrun]
    GoodMEV --> Reward[🎁 User Rewards]
```

### 2. Slippage Correction

Detect and correct price slippage by capturing arbitrage opportunities:

```mermaid
graph LR
    UserSwap[User Swap] --> PriceImpact[Price Impact Created]
    PriceImpact --> Detection[Slippage Detection]
    Detection --> Correction[Arbitrage Execution]
    Correction --> Profit[Captured Profit]
    Profit --> UserShare[Shared with User]
```

## 🛡️ Security Architecture

### Reflex Security

Reflex implements multiple security layers to ensure safe and reliable MEV operations:

**Failsafe Mechanisms** - Built-in safety checks that prevent execution if profitability thresholds aren't met or if gas costs exceed expected limits. All operations can be safely reverted without affecting user transactions.

**Independent Operation** - Reflex operates completely independently from protocol and user swaps. The system has no access to user funds or protocol treasuries, only capturing MEV through legitimate arbitrage opportunities.

**Reentrancy Protection** - All router functions implement strict reentrancy guards to prevent malicious contracts from exploiting callback mechanisms during MEV executions.

**Access Controls** - Granular permission system ensures only authorized contracts can trigger specific functions, with different access levels for plugins, direct integrations, and administrative operations.

### Risk Mitigation

1. **Reentrancy Protection**: Protected by reentrancy guards and callback validation
2. **Unauthorized Access**: Role-based permissions prevent malicious contract interactions
3. **Fund Safety**: No direct access to user or protocol funds - only captures public arbitrage opportunities
4. **Execution Failures**: Comprehensive failsafe mechanisms ensure failed MEV attempts don't impact user transactions

## 🔧 Gas Optimization

### Efficient Profit Detection

Reflex implements a multi-stage gas optimization strategy that minimizes costs while maximizing MEV capture efficiency:

**Stage 1: Profit Check (Minimal Gas)** - Initial profitability assessment adds virtually no gas overhead. This lightweight check determines if an MEV opportunity exists without committing to expensive calculations.

**Stage 2: Route Optimization (Moderate Gas)** - When profitable opportunities are detected, the system performs detailed route calculations and profit estimations. This includes optimal path discovery, gas cost analysis, and net profit calculations.

**Stage 3: Swap Execution (Variable Gas)** - Actual MEV capture execution with gas costs dependent on the selected arbitrage route. Multi-hop swaps require additional gas per DEX interaction.

### Gas Economics

**Profitability Guarantee** - All executed backruns are profitable by design, ensuring gas costs are always covered by captured MEV profits. Failed profitability checks prevent unprofitable executions.

**User Gas Rebates** - A portion of captured MEV profits is automatically shared with users to offset their original transaction gas costs, providing net positive value.

### Gas Limit Recommendations

**Recommended Gas Limit** - For optimal MEV capture, we recommend setting a gas limit of 1.5M gas for most transactions, this provides sufficient headroom for profitable MEV operations.

## 🌐 Multi-Chain Architecture

Reflex is designed to work across multiple blockchain networks and supported by over 180 EVM chains.

---

This architecture enables Reflex to provide efficient, secure, and fair MEV capture that benefits all participants in the DeFi ecosystem. The modular design allows for easy integration with existing protocols while maintaining the flexibility to adapt to future innovations.

For implementation details, see our [Integration Guide](./integration/overview) and [API Reference](./api/smart-contracts).
