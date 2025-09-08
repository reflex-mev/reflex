# Test Utils

This directory contains shared testing utilities and mock contracts used across the Reflex project test suites.

## MockToken

A comprehensive ERC20 mock token designed for testing purposes with additional utility functions:

### Features

- **Standard ERC20**: Full ERC20 implementation using OpenZeppelin contracts
- **Flexible Creation**: Create tokens with custom name, symbol, and initial supply
- **Testing Utilities**: Additional functions for test convenience

### Functions

#### Creation Functions (via TestUtils library)

- `createMockToken(name, symbol, initialSupply)`: Create a custom token
- `createStandardMockToken()`: Create a standard "MockToken" with 1M tokens

#### Testing Utility Functions

- `mint(to, amount)`: Mint tokens to any address (for test setup)
- `burn(from, amount)`: Burn tokens from any address (for test cleanup)
- `setBalance(account, amount)`: Set an account's balance directly (for state manipulation)

### Usage Examples

```solidity
import "../utils/TestUtils.sol";

contract MyTest is Test {
    MockToken public token;

    function setUp() public {
        // Create standard token
        token = MockToken(TestUtils.createStandardMockToken());

        // Or create custom token
        address customToken = TestUtils.createMockToken("Custom", "CST", 500 * 10**18);
    }

    function testSomething() public {
        // Set up test state
        token.setBalance(alice, 1000 * 10**18);
        token.mint(bob, 500 * 10**18);

        // Run your tests...
    }
}
```
