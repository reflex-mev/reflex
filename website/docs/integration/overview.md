---
sidebar_position: 1
---

# Integration Overview

Learn how to integrate Reflex into your DeFi protocol to capture and distribute MEV fairly among your users.

## 🎯 Choose Your Integration Method

Reflex offers three integration methods designed for different protocol architectures. Select the approach that best fits your needs:

---

### 1. 🔌 DEX Plugin-Based Integration

**Best for DEXes with native hook/plugin systems**

Integrate MEV capture seamlessly using your DEX's existing plugin architecture. Automatic MEV capture on every swap with zero modifications to core contracts.

**Ideal for:** Algebra Integral, PancakeSwap Infinity, Uniswap v4

[**→ Read Plugin-Based Guide**](./plugin-based)

---

### 2. 🌐 Universal DEX Integration  

**Best for any DEX or DApp - no protocol changes needed**

Add MEV capture to any DEX using the BackrunEnabledSwapProxy + TypeScript SDK. Works with any existing DEX router without modifications.

**Ideal for:** Existing DEXes, DApp frontends, multi-DEX aggregators

[**→ Read Universal DEX Guide**](./universal-dex)

---

### 3. ⚙️ Direct Contract Access

**Best for custom protocols requiring fine-grained control**

Call the ReflexRouter directly from your smart contracts. Maximum flexibility for unique integration requirements and conditional MEV logic.

**Ideal for:** Custom DeFi protocols, advanced integrations, conditional MEV capture

[**→ Read Direct Access Guide**](./direct-access)

---

## Quick Comparison

| Integration Type | DEX Changes Required | Complexity | Flexibility | Best Use Case |
|-----------------|---------------------|------------|-------------|---------------|
| **Plugin-Based** | None (uses hooks) | Low | Medium | DEXes with plugin support |
| **Universal DEX** | None (uses proxy) | Low | Low | Any existing DEX |
| **Direct Access** | Custom integration | Medium | High | Custom protocols |

---

## Next Steps

1. **Choose** the integration method that fits your architecture
2. **Follow** the detailed guide for your chosen method  
3. **Deploy** and test your integration
4. **Monitor** MEV capture and profit distribution

Need help deciding? Check our [Architecture Guide](../architecture) to understand how Reflex components work together.

For detailed API documentation, see our [Smart Contract API Reference](../api/smart-contracts).
