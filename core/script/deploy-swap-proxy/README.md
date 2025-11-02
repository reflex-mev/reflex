# BackrunEnabledSwapProxy Deployment

This directory contains the deployment script for the `BackrunEnabledSwapProxy` contract.

## Overview

The `BackrunEnabledSwapProxy` is a proxy contract that enables executing swaps on a target router with integrated backrun functionality via the Reflex Router. It ensures:

- Secure token handling with no leftover balances
- Automatic approval management
- Graceful backrun failure handling
- ETH forwarding support
- Reentrancy protection

## Prerequisites

Before deploying, ensure you have:

1. **Forge** installed (part of Foundry)
2. **RPC URL** for the target network
3. **Private Key** or hardware wallet
4. **Target Router Address** - The swap router you want to proxy (e.g., Uniswap V2 Router, SushiSwap Router)
5. (Optional) **Etherscan API Key** for contract verification

## Deployment Steps

### 1. Set Environment Variables

```bash
export TARGET_ROUTER_ADDRESS=0x... # Required: Address of the target swap router
export VERIFY_CONTRACT=true        # Optional: Enable contract verification
export ETHERSCAN_API_KEY=...       # Optional: For verification
```

### 2. Simulate Deployment (Dry Run)

Test the deployment without broadcasting:

```bash
forge script script/deploy-swap-proxy/DeployBackrunEnabledSwapProxy.s.sol \
  --rpc-url $RPC_URL
```

### 3. Deploy to Network

Deploy and broadcast the transaction:

```bash
forge script script/deploy-swap-proxy/DeployBackrunEnabledSwapProxy.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### 4. Deploy with Verification

Deploy and automatically verify on Etherscan:

```bash
forge script script/deploy-swap-proxy/DeployBackrunEnabledSwapProxy.s.sol \
  --rpc-url $RPC_URL \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $ETHERSCAN_API_KEY
```

## Network-Specific Examples

### Ethereum Mainnet

```bash
TARGET_ROUTER_ADDRESS=0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D \
forge script script/deploy-swap-proxy/DeployBackrunEnabledSwapProxy.s.sol \
  --rpc-url https://eth-mainnet.g.alchemy.com/v2/YOUR-API-KEY \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

### Arbitrum

```bash
TARGET_ROUTER_ADDRESS=0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506 \
forge script script/deploy-swap-proxy/DeployBackrunEnabledSwapProxy.s.sol \
  --rpc-url https://arb-mainnet.g.alchemy.com/v2/YOUR-API-KEY \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

### Base

```bash
TARGET_ROUTER_ADDRESS=0x... \
forge script script/deploy-swap-proxy/DeployBackrunEnabledSwapProxy.s.sol \
  --rpc-url https://base-mainnet.g.alchemy.com/v2/YOUR-API-KEY \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify
```

### Local/Testnet

```bash
TARGET_ROUTER_ADDRESS=0x... \
forge script script/deploy-swap-proxy/DeployBackrunEnabledSwapProxy.s.sol \
  --rpc-url http://localhost:8545 \
  --private-key $PRIVATE_KEY \
  --broadcast
```

## Post-Deployment

After deployment, the script will:

1. ✅ Deploy the `BackrunEnabledSwapProxy` contract
2. ✅ Verify the target router is correctly set
3. ✅ Save deployment information to `deployments/deployment-swap-proxy-{chainId}-{timestamp}.json`
4. ✅ Output the contract address and next steps

### Deployment Output

The script creates a JSON file with deployment details:

```json
{
  "contract": "BackrunEnabledSwapProxy",
  "address": "0x...",
  "targetRouter": "0x...",
  "chainId": 1,
  "blockNumber": 12345678,
  "timestamp": 1234567890,
  "deployer": "0x..."
}
```

## Integration

Once deployed, integrate the proxy into your application:

```solidity
// 1. Approve tokens to the swap proxy
IERC20(tokenIn).approve(address(swapProxy), amountIn);

// 2. Prepare swap calldata for target router
bytes memory swapCallData = abi.encodeWithSelector(
    IRouter.swap.selector,
    tokenIn,
    amountIn,
    tokenOut,
    recipient
);

// 3. Prepare backrun parameters
IReflexRouter.BackrunParams[] memory backrunParams = new IReflexRouter.BackrunParams[](1);
backrunParams[0] = IReflexRouter.BackrunParams({
    triggerPoolId: poolId,
    swapAmountIn: backrunAmount,
    token0In: true,
    recipient: msg.sender,
    configId: configId
});

// 4. Execute swap with backruns
(bytes memory swapReturnData, uint256[] memory profits, address[] memory profitTokens) = 
    swapProxy.swapWithbackrun(
        swapCallData,
        tokenIn,
        amountIn,
        reflexRouterAddress,
        backrunParams
    );
```

## Manual Verification

If automatic verification fails, manually verify with:

```bash
forge verify-contract \
  --chain-id {chainId} \
  --constructor-args $(cast abi-encode "constructor(address)" {targetRouterAddress}) \
  src/integrations/BackrunEnabledSwapProxy.sol:BackrunEnabledSwapProxy \
  --etherscan-api-key $ETHERSCAN_API_KEY \
  {deployedProxyAddress}
```

## Common Target Routers

| Network | Router | Address |
|---------|--------|---------|
| Ethereum | Uniswap V2 | `0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D` |
| Ethereum | SushiSwap | `0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F` |
| Arbitrum | SushiSwap | `0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506` |
| Arbitrum | Uniswap V3 | `0xE592427A0AEce92De3Edee1F18E0157C05861564` |
| Base | Uniswap V2 | `0x4752ba5dbc23f44d87826276bf6fd6b1c372ad24` |

## Troubleshooting

### Error: "TARGET_ROUTER_ADDRESS environment variable not set"
**Solution**: Set the required environment variable:
```bash
export TARGET_ROUTER_ADDRESS=0x...
```

### Error: "Target router address must be a contract"
**Solution**: Ensure the target router address is a deployed contract on the target network.

### Gas Estimation Failed
**Solution**: 
- Check deployer has sufficient ETH balance
- Verify RPC URL is correct
- Try with explicit gas settings: `--gas-limit 2000000`

### Verification Failed
**Solution**:
- Verify Etherscan API key is correct
- Wait a few minutes and try manual verification
- Check the network is supported by Etherscan

## Security Considerations

Before deploying to mainnet:

1. ✅ Verify the target router contract is audited and trustworthy
2. ✅ Test thoroughly on testnet first
3. ✅ Ensure the target router interface matches your expectations
4. ✅ Review the deployment transaction before broadcasting
5. ✅ Monitor the contract after deployment

## Support

For issues or questions:
- Review the test suite: `test/integrations/BackrunEnabledSwapProxy.test.sol`
- Check contract documentation: `src/integrations/BackrunEnabledSwapProxy.sol`
- Review deployment logs in `deployments/` directory
