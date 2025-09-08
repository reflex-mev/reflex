// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "./TestUtils.sol";

contract TestUtilsTest is Test {
    function testCreateMockToken() public {
        address tokenAddr = TestUtils.createMockToken("TestToken", "TEST", 500 * 10 ** 18);
        MockToken token = MockToken(tokenAddr);

        assertEq(token.name(), "TestToken");
        assertEq(token.symbol(), "TEST");
        assertEq(token.totalSupply(), 500 * 10 ** 18);
        assertEq(token.balanceOf(address(this)), 500 * 10 ** 18);
    }

    function testCreateStandardMockToken() public {
        address tokenAddr = TestUtils.createStandardMockToken();
        MockToken token = MockToken(tokenAddr);

        assertEq(token.name(), "MockToken");
        assertEq(token.symbol(), "MOCK");
        assertEq(token.totalSupply(), 1000000 * 10 ** 18);
        assertEq(token.balanceOf(address(this)), 1000000 * 10 ** 18);
    }

    function testMockTokenMint() public {
        address tokenAddr = TestUtils.createStandardMockToken();
        MockToken token = MockToken(tokenAddr);

        address recipient = address(0x123);
        uint256 mintAmount = 1000 * 10 ** 18;

        token.mint(recipient, mintAmount);
        assertEq(token.balanceOf(recipient), mintAmount);
    }

    function testMockTokenBurn() public {
        address tokenAddr = TestUtils.createStandardMockToken();
        MockToken token = MockToken(tokenAddr);

        uint256 burnAmount = 1000 * 10 ** 18;
        uint256 initialBalance = token.balanceOf(address(this));

        token.burn(address(this), burnAmount);
        assertEq(token.balanceOf(address(this)), initialBalance - burnAmount);
    }

    function testMockTokenSetBalance() public {
        address tokenAddr = TestUtils.createStandardMockToken();
        MockToken token = MockToken(tokenAddr);

        address account = address(0x123);
        uint256 newBalance = 5000 * 10 ** 18;

        // Set balance higher than current (0)
        token.setBalance(account, newBalance);
        assertEq(token.balanceOf(account), newBalance);

        // Set balance lower
        uint256 lowerBalance = 2000 * 10 ** 18;
        token.setBalance(account, lowerBalance);
        assertEq(token.balanceOf(account), lowerBalance);

        // Set same balance (no change)
        token.setBalance(account, lowerBalance);
        assertEq(token.balanceOf(account), lowerBalance);
    }
}
