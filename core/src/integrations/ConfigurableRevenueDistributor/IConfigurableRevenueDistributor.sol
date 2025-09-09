// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IConfigurableRevenueDistributor
/// @notice Interface for a stateless ETH/ERC20 revenue distributor contract with multiple configurations
interface IConfigurableRevenueDistributor {
    // ========== Structs ==========

    /// @notice Configuration for fund splitting
    struct SplitConfig {
        address[] recipients;
        uint256[] sharesBps;
        uint256 dustShareBps;
    }

    // ========== Events ==========

    /// @notice Emitted when shares are updated by the admin
    event SharesUpdated(bytes32 indexed configId, address[] recipients, uint256[] sharesBps, uint256 dustShareBps);

    /// @notice Emitted when the default configuration is updated
    event DefaultConfigUpdated(address[] recipients, uint256[] sharesBps, uint256 dustShareBps);

    /// @notice Emitted after a successful split operation (ETH or ERC20)
    event SplitExecuted(
        bytes32 indexed configId,
        address indexed token,
        uint256 totalAmount,
        address[] recipients,
        uint256[] amounts,
        address dustRecipient,
        uint256 dustAmount
    );

    // ========== Functions ==========

    /// @notice Returns the configuration for a given config ID
    /// @param configId The 32-byte identifier for the configuration
    /// @return config The split configuration
    function getConfig(bytes32 configId) external view returns (SplitConfig memory config);

    /// @notice Returns the recipient list and their share percentages for a given config ID
    /// @param configId The 32-byte identifier for the configuration
    /// @return recipients List of recipient addresses
    /// @return sharesBps Corresponding list of share amounts in basis points (1% = 100 bps)
    /// @return dustShareBps Dust recipient's share in basis points
    function getRecipients(bytes32 configId)
        external
        view
        returns (address[] memory recipients, uint256[] memory sharesBps, uint256 dustShareBps);

    /// @notice Updates the recipients and their shares for a specific configuration (admin only)
    /// @param configId The 32-byte identifier for the configuration
    /// @param recipients List of recipient addresses
    /// @param sharesBps List of corresponding shares in basis points (1% = 100 bps)
    /// @param dustShareBps Dust recipient's share in basis points
    function updateShares(
        bytes32 configId,
        address[] calldata recipients,
        uint256[] calldata sharesBps,
        uint256 dustShareBps
    ) external;
}
