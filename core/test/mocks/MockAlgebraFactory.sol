// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title MockAlgebraFactory
/// @notice Mock implementation of Algebra factory for testing
contract MockAlgebraFactory {
    mapping(address => bool) public isPool;
    mapping(bytes32 => mapping(address => bool)) public roleAssignments;
    mapping(address => mapping(address => address)) public poolsByPair;
    mapping(address => bool) public validPools;
    address public owner;

    bytes32 public constant POOLS_ADMINISTRATOR_ROLE = keccak256("POOLS_ADMINISTRATOR_ROLE");
    bytes32 public constant ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR =
        keccak256("ALGEBRA_BASE_PLUGIN_FACTORY_ADMINISTRATOR");

    constructor() {
        owner = msg.sender;
    }

    function setPool(address pool, bool status) external {
        isPool[pool] = status;
    }

    function setOwner(address _owner) external {
        owner = _owner;
    }

    function hasRoleOrOwner(bytes32 role, address account) external view returns (bool) {
        return account == owner || roleAssignments[role][account];
    }

    function grantRole(bytes32 role, address account) external {
        roleAssignments[role][account] = true;
    }

    function revokeRole(bytes32 role, address account) external {
        roleAssignments[role][account] = false;
    }

    function setPoolByPair(address token0, address token1, address pool) external {
        poolsByPair[token0][token1] = pool;
        poolsByPair[token1][token0] = pool;
        validPools[pool] = true;
    }

    function poolByPair(address token0, address token1) external view returns (address) {
        return poolsByPair[token0][token1];
    }
}
