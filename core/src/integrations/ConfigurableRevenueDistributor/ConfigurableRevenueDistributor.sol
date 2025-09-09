// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IConfigurableRevenueDistributor.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title ConfigurableRevenueDistributor
/// @notice Abstract contract for stateless ETH/ERC20 revenue distribution without storing funds.
///         Supports multiple configurations with configurable recipient shares via basis points.
abstract contract ConfigurableRevenueDistributor is IConfigurableRevenueDistributor {
    using SafeERC20 for IERC20;

    // ========== Errors ==========

    // ========== Constants ==========

    /// @notice Total basis points used to express 100% (1% = 100 bps)
    uint256 public constant TOTAL_BPS = 10_000;

    // ========== Storage ==========

    /// @notice Mapping of configuration ID to split configuration
    mapping(bytes32 => SplitConfig) public configs;

    /// @notice Default configuration used when no specific config is found
    SplitConfig public defaultConfig;

    // ========== Constructor ==========

    /// @notice Constructor sets up default configuration: 80% to deployer, 20% to dust
    constructor() {
        address deployer = tx.origin;

        // Set up default configuration: 80% to deployer, 20% to dust
        defaultConfig.recipients = new address[](1);
        defaultConfig.recipients[0] = deployer;
        defaultConfig.sharesBps = new uint256[](1);
        defaultConfig.sharesBps[0] = 8000; // 80%
        defaultConfig.dustShareBps = 2000; // 20%
    }

    // ========== Access Control Hook ==========

    /// @notice Internal function that must be implemented by child contract to enforce admin access control
    function _onlyFundsAdmin() internal view virtual;

    // ========== Public Methods ==========

    /// @inheritdoc IConfigurableRevenueDistributor
    function getConfig(bytes32 configId) external view override returns (SplitConfig memory) {
        return configs[configId];
    }

    /// @inheritdoc IConfigurableRevenueDistributor
    function getRecipients(bytes32 configId)
        external
        view
        override
        returns (address[] memory, uint256[] memory, uint256)
    {
        SplitConfig storage config = configs[configId];
        return (config.recipients, config.sharesBps, config.dustShareBps);
    }

    /// @inheritdoc IConfigurableRevenueDistributor
    function updateShares(
        bytes32 configId,
        address[] calldata _recipients,
        uint256[] calldata _sharesBps,
        uint256 _dustShareBps
    ) external override {
        _onlyFundsAdmin();
        _setShares(configId, _recipients, _sharesBps, _dustShareBps);
        emit SharesUpdated(configId, _recipients, _sharesBps, _dustShareBps);
    }

    /// @notice Updates the default configuration used when no specific config is found
    /// @param _recipients List of recipient addresses for the default config
    /// @param _sharesBps List of corresponding shares in basis points for the default config
    /// @param _dustShareBps Dust recipient's share in basis points for the default config
    function updateDefaultConfig(address[] calldata _recipients, uint256[] calldata _sharesBps, uint256 _dustShareBps)
        external
    {
        _onlyFundsAdmin();
        _setDefaultShares(_recipients, _sharesBps, _dustShareBps);
    }

    // ========== Internal Methods ==========

    /// @notice Internal function to split ERC20 tokens - can be called by inheriting contracts
    /// @param configId The configuration ID to use for splitting
    /// @param token The ERC20 token address
    /// @param amount The amount to split
    /// @param dustRecipient Address that receives dust and additional share (optional)
    function _splitERC20(bytes32 configId, address token, uint256 amount, address dustRecipient) internal {
        // Use requested config if it exists, otherwise fall back to default
        SplitConfig memory config;
        if (configs[configId].recipients.length == 0) {
            config = defaultConfig;
        } else {
            config = configs[configId];
        }

        uint256[] memory amounts = new uint256[](config.recipients.length);
        uint256 totalDistributed = 0;

        // Distribute to main recipients
        for (uint256 i = 0; i < config.recipients.length; i++) {
            address recipient = config.recipients[i];
            uint256 share = (amount * config.sharesBps[i]) / TOTAL_BPS;
            amounts[i] = share;
            totalDistributed += share;
            IERC20(token).safeTransfer(recipient, share);
        }

        // Distribute dust recipient share and any remaining dust
        uint256 dustAmount = 0;
        if (dustRecipient != address(0) && config.dustShareBps > 0) {
            // Calculate dust recipient's configured share
            uint256 dustShare = (amount * config.dustShareBps) / TOTAL_BPS;
            totalDistributed += dustShare;
            dustAmount += dustShare;

            // Add any remaining dust from rounding
            uint256 remainder = amount - totalDistributed;
            dustAmount += remainder;

            if (dustAmount > 0) {
                IERC20(token).safeTransfer(dustRecipient, dustAmount);
            }
        }

        emit SplitExecuted(configId, token, amount, config.recipients, amounts, dustRecipient, dustAmount);
    }

    /// @notice Internal function to split ETH - can be called by inheriting contracts
    /// @param configId The configuration ID to use for splitting
    /// @param dustRecipient Address that receives dust and additional share (optional)
    function _splitETH(bytes32 configId, address dustRecipient) internal {
        // Use requested config if it exists, otherwise fall back to default
        SplitConfig memory config;
        if (configs[configId].recipients.length == 0) {
            config = defaultConfig;
        } else {
            config = configs[configId];
        }

        uint256 value = msg.value;
        uint256[] memory amounts = new uint256[](config.recipients.length);
        uint256 totalDistributed = 0;

        // Distribute to main recipients
        for (uint256 i = 0; i < config.recipients.length; i++) {
            address recipient = config.recipients[i];
            uint256 share = (value * config.sharesBps[i]) / TOTAL_BPS;
            amounts[i] = share;
            totalDistributed += share;
            (bool success,) = recipient.call{value: share}("");
            require(success, "ETH transfer failed");
        }

        // Distribute dust recipient share and any remaining dust
        uint256 dustAmount = 0;
        if (dustRecipient != address(0) && config.dustShareBps > 0) {
            // Calculate dust recipient's configured share
            uint256 dustShare = (value * config.dustShareBps) / TOTAL_BPS;
            totalDistributed += dustShare;
            dustAmount += dustShare;

            // Add any remaining dust from rounding
            uint256 remainder = value - totalDistributed;
            dustAmount += remainder;

            if (dustAmount > 0) {
                (bool success,) = dustRecipient.call{value: dustAmount}("");
                require(success, "ETH dust transfer failed");
            }
        }

        emit SplitExecuted(configId, address(0), value, config.recipients, amounts, dustRecipient, dustAmount);
    }

    /// @notice Internal function to update the split configuration
    /// @param configId The configuration ID to update
    /// @param _recipients List of recipient addresses
    /// @param _sharesBps List of corresponding shares in basis points
    /// @param _dustShareBps Dust recipient's share in basis points
    function _setShares(
        bytes32 configId,
        address[] memory _recipients,
        uint256[] memory _sharesBps,
        uint256 _dustShareBps
    ) internal {
        require(_recipients.length == _sharesBps.length, "Recipients and shares length mismatch");
        require(_recipients.length > 0, "No recipients provided");

        uint256 totalShares = _dustShareBps;

        // Validate recipients and calculate total shares
        for (uint256 i = 0; i < _recipients.length; i++) {
            address recipient = _recipients[i];
            uint256 share = _sharesBps[i];
            require(recipient != address(0), "Invalid recipient address");
            require(share > 0, "Invalid share amount");
            totalShares += share;
        }

        require(totalShares == TOTAL_BPS, "Total shares must equal 100%");

        // Update configuration
        SplitConfig storage config = configs[configId];
        config.recipients = _recipients;
        config.sharesBps = _sharesBps;
        config.dustShareBps = _dustShareBps;
    }

    /// @notice Internal function to update the default split configuration
    /// @param _recipients List of recipient addresses for the default config
    /// @param _sharesBps List of corresponding shares in basis points for the default config
    /// @param _dustShareBps Dust recipient's share in basis points for the default config
    function _setDefaultShares(address[] memory _recipients, uint256[] memory _sharesBps, uint256 _dustShareBps)
        internal
    {
        require(_recipients.length == _sharesBps.length, "Recipients and shares length mismatch");
        require(_recipients.length > 0, "No recipients provided");

        uint256 totalShares = _dustShareBps;

        // Validate recipients and calculate total shares
        for (uint256 i = 0; i < _recipients.length; i++) {
            address recipient = _recipients[i];
            uint256 share = _sharesBps[i];
            require(recipient != address(0), "Invalid recipient address");
            require(share > 0, "Invalid share amount");
            totalShares += share;
        }

        require(totalShares == TOTAL_BPS, "Total shares must equal 100%");

        // Update default configuration
        defaultConfig.recipients = _recipients;
        defaultConfig.sharesBps = _sharesBps;
        defaultConfig.dustShareBps = _dustShareBps;
    }
}
