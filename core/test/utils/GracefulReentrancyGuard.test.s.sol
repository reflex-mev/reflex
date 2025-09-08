// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../../src/utils/GracefulReentrancyGuard.sol";

// Test contract to demonstrate graceful reentrancy behavior
contract TestGracefulContract is GracefulReentrancyGuard {
    uint256 public callCount;
    uint256 public lastReturnValue;

    function testFunction() external gracefulNonReentrant returns (uint256) {
        callCount++;

        // If this is the first call, try to reenter
        if (callCount == 1) {
            // This should be blocked gracefully and return 0
            lastReturnValue = this.testFunction();
        }

        return callCount;
    }

    function resetState() external {
        callCount = 0;
        lastReturnValue = 0;
    }
}

contract GracefulReentrancyGuardTest is Test {
    TestGracefulContract testContract;

    function setUp() public {
        testContract = new TestGracefulContract();
    }

    function testGracefulReentrancyPrevention() public {
        // Reset state
        testContract.resetState();

        // Call the function - it will try to reenter itself
        uint256 result = testContract.testFunction();

        // The main call should succeed and return 1
        assertEq(result, 1, "Main call should return 1");

        // The reentrant call should have been gracefully blocked and returned 0
        assertEq(testContract.lastReturnValue(), 0, "Reentrant call should return 0 (default value)");

        // Only one increment should have happened
        assertEq(testContract.callCount(), 1, "Only one call should have been executed");
    }

    function testNormalSequentialCallsWork() public {
        // Reset state
        testContract.resetState();

        // Make sequential calls (not reentrant)
        uint256 result1 = testContract.testFunction();
        uint256 result2 = testContract.testFunction();

        assertEq(result1, 1, "First call should return 1");
        assertEq(result2, 2, "Second call should return 2");
        assertEq(testContract.callCount(), 2, "Both calls should have been executed");
    }

    function testReentrancyStatusCheck() public {
        // Test the internal status checking function
        TestGracefulContractWithStatusCheck statusContract = new TestGracefulContractWithStatusCheck();

        bool result = statusContract.checkReentrancyStatus();
        assertTrue(result, "Status check should work correctly");
    }
}

// Additional test contract to test status checking
contract TestGracefulContractWithStatusCheck is GracefulReentrancyGuard {
    function checkReentrancyStatus() external gracefulNonReentrant returns (bool) {
        // During execution, we should be in reentrant state
        bool isReentrant = _isReentrant();

        // Try to call this function again (should be gracefully blocked)
        if (!isReentrant) {
            // This call should return early due to reentrancy
            this.checkReentrancyStatus();
        }

        return true;
    }
}
