export const REFLEX_ROUTER_ABI = [
  {
    type: 'constructor',
    inputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'backrunedExecute',
    inputs: [
      {
        name: 'executeParams',
        type: 'tuple',
        components: [
          { name: 'target', type: 'address' },
          { name: 'value', type: 'uint256' },
          { name: 'callData', type: 'bytes' },
        ],
      },
      {
        name: 'backrunParams',
        type: 'tuple[]',
        components: [
          { name: 'triggerPoolId', type: 'bytes32' },
          { name: 'swapAmountIn', type: 'uint112' },
          { name: 'token0In', type: 'bool' },
          { name: 'recipient', type: 'address' },
        ],
      },
    ],
    outputs: [
      { name: 'success', type: 'bool' },
      { name: 'returnData', type: 'bytes' },
      { name: 'profits', type: 'uint256[]' },
      { name: 'profitTokens', type: 'address[]' },
    ],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    name: 'triggerBackrun',
    inputs: [
      { name: 'triggerPoolId', type: 'bytes32' },
      { name: 'swapAmountIn', type: 'uint112' },
      { name: 'token0In', type: 'bool' },
      { name: 'recipient', type: 'address' },
      { name: 'configId', type: 'bytes32' },
    ],
    outputs: [
      { name: 'profit', type: 'uint256' },
      { name: 'profitToken', type: 'address' },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'getReflexAdmin',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'reflexQuoter',
    inputs: [],
    outputs: [{ name: '', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    name: 'setReflexQuoter',
    inputs: [{ name: '_reflexQuoter', type: 'address' }],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'withdrawToken',
    inputs: [
      { name: 'token', type: 'address' },
      { name: 'amount', type: 'uint256' },
      { name: '_to', type: 'address' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    name: 'withdrawEth',
    inputs: [
      { name: 'amount', type: 'uint256' },
      { name: '_to', type: 'address' },
    ],
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'event',
    name: 'BackrunExecuted',
    inputs: [
      { name: 'triggerPoolId', type: 'bytes32', indexed: true },
      { name: 'swapAmountIn', type: 'uint112', indexed: false },
      { name: 'token0In', type: 'bool', indexed: false },
      { name: 'profit', type: 'uint256', indexed: false },
      { name: 'profitToken', type: 'address', indexed: true },
      { name: 'recipient', type: 'address', indexed: true },
    ],
    anonymous: false,
  },
  {
    type: 'fallback',
    stateMutability: 'payable',
  },
  {
    type: 'receive',
    stateMutability: 'payable',
  },
] as const;
