---
sidebar_position: 1
---

# Revenue Configuration

Revenue sharing configurations in Reflex are centrally managed by the Reflex team to ensure security, consistency, and proper validation of all profit distribution mechanisms.

## Overview

All MEV profits captured by Reflex are distributed according to predefined configurations that specify:
- **Recipients**: Addresses that will receive profit shares
- **Percentages**: How profits are split between recipients
- **Validation**: Ensuring all configurations are legitimate and secure

## Default Configuration

Reflex provides a default revenue sharing configuration that works for most integrations:

- **Protocol Fee**: 80% to Reflex for infrastructure and development
- **User Rewards**: 20% back to traders/users

## Custom Configuration Process

If you need a custom profit sharing structure different from the default, follow this process:

### 1. Contact Reflex

Reach out to the Reflex team with your requirements:

**Required Information:**
- Protocol name and description
- Desired revenue sharing structure
- Recipient addresses and their purposes
- Expected transaction volume
- Integration timeline

**Contact Methods:**
- **Email**: support@reflexmev.io
- **Twitter/X**: [@ReflexMEV](https://x.com/ReflexMEV)

### 2. Configuration Review

The Reflex team will review your request and validate:

- **Address Security**: All recipient addresses are properly verified
- **Share Allocation**: Percentages add up to 100% and are reasonable
- **Compliance**: Configuration meets protocol standards
- **Technical Feasibility**: Integration approach is sound

### 3. Receive Configuration ID

After approval, you'll receive:

```typescript
// Example configuration details
const customConfig = {
  configId: "0x1234567890abcdef...", // Your unique config ID
  recipients: [
    "0xProtocolTreasury...",  // 40%
    "0xUserRewardsPool...",   // 50%
    "0xValidatorTips..."      // 10%
  ],
  shares: [40, 50, 10],
  description: "Custom protocol revenue sharing"
};
```

### 4. Implementation

Use your provided `configId` in all Reflex integration calls:

```solidity
// Smart Contract Integration
reflexRouter.triggerBackrun(
    poolId,
    backrunAmount,
    zeroForOne,
    profitRecipient,
    customConfigId // Your provided config ID
);
```

```typescript
// SDK Integration
const executeParams = {
  target: "0xYourContract...",
  value: 0n,
  callData: "0x..."
};

const backrunParams = [{
  triggerPoolId: "0xPool...",
  swapAmountIn: "1000000000000000000",
  token0In: true,
  recipient: "0xUser...",
  configId: customConfigId // Your provided config ID
}];

const result = await reflexSDK.backrunedExecute(
  executeParams,
  backrunParams
);
```

## Configuration Examples

### DEX Protocol Example

```javascript
const dexConfig = {
  recipients: [
    "0xReflex...",    // Reflex
    "0xDEXTreasury...",       // Protocol treasury
    "0xLPRewardsPool...",     // Liquidity provider rewards
  ],
  shares: [70, 20, 10],       // Percentages
  description: "DEX protocol with LP rewards"
};
```

### Aggregator Protocol Example

```javascript
const aggregatorConfig = {
  recipients: [
    "0xReflex...",     // Reflex  
    "0xUserCashback...",       // Direct user cashback
    "0xAggregatorTreasury...", // Protocol development
  ],
  shares: [75, 15, 10],
  description: "Aggregator with user cashback focus"
};
```

### Wallet Integration Example

```javascript
const walletConfig = {
  recipients: [
    "0xReflex...",     // Reflex
    "0xUserRewards...",        // Direct user benefits
    "0xWalletTreasury...",     // Wallet development
  ],
  shares: [70, 20, 10],
  description: "Wallet integration with user focus"
};
```

## Best Practices

### Security Considerations

1. **Verify Addresses**: Ensure all recipient addresses are correct and controlled by appropriate parties
2. **Test Configuration**: Start with small amounts to verify profit distribution works correctly
3. **Monitor Distribution**: Set up monitoring for profit distribution to detect any issues
4. **Regular Reviews**: Periodically review your configuration to ensure it still meets your needs

### Optimization Tips

1. **Minimize Recipients**: Fewer recipients reduce gas costs for profit distribution
2. **Round Percentages**: Use round numbers when possible to simplify calculations
3. **Cache Config ID**: Store your config ID as an immutable variable to save gas
4. **Batch Operations**: If possible, batch multiple operations with the same config

### Compliance Guidelines

1. **Legal Review**: Ensure your revenue sharing structure complies with local regulations
2. **Transparency**: Be transparent with users about how MEV profits are shared
3. **Documentation**: Keep clear documentation of your revenue sharing model
4. **Updates**: Notify stakeholders of any changes to revenue distribution

## Configuration Management

### Updating Configurations

Configuration updates require:
1. **New Request**: Submit a new configuration request to Reflex team
2. **Review Process**: Updated configuration goes through the same review process
3. **New Config ID**: You'll receive a new config ID for the updated configuration
4. **Migration**: Update your contracts/SDK calls to use the new config ID

### Configuration Lifecycle

- **Active**: Configuration is live and processing transactions
- **Deprecated**: Old configuration still works but is no longer recommended
- **Sunset**: Configuration will be disabled after a grace period
- **Disabled**: Configuration no longer accepts new transactions

## Support

If you have questions about revenue configuration:

1. **Documentation**: Check this documentation first
2. **Email Support**: Contact support@reflexmev.io for assistance
3. **Twitter/X**: Follow [@ReflexMEV](https://x.com/ReflexMEV) for updates
4. **Partnership Team**: Contact partnerships team for enterprise needs

---

**Next Steps:**
- For smart contract integration, see [Smart Contract Integration](./smart-contract)
- For SDK integration, see [SDK Integration Guide](./sdk-integration)
- For implementation details, check out [Smart Contract Integration](./smart-contract) and [SDK Integration](./sdk-integration)
