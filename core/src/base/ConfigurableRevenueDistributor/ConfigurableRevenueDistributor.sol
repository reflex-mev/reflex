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

    /// @notice Default configuration ID used when no specific config is provided
    bytes32 public constant DEFAULT_CONFIG_ID = keccak256("DEFAULT_CONFIG");

    // ========== Storage ==========

    /// @notice Mapping of configuration ID to split configuration
    mapping(bytes32 => SplitConfig) public configs;

    // ========== Constructor ==========

    /// @notice Constructor sets up default configuration: 80% to deployer, 20% to varied recipient
    constructor() {
        address deployer = msg.sender;

        // Set up default configuration: 80% to deployer, 20% to varied recipient
        address[] memory recipients = new address[](1);
        recipients[0] = deployer;
        uint256[] memory sharesBps = new uint256[](1);
        sharesBps[0] = 8000; // 80%
        uint256 variedShareBps = 2000; // 20%

        // Store default config in the configs mapping
        SplitConfig storage defaultConfig = configs[DEFAULT_CONFIG_ID];
        defaultConfig.recipients = recipients;
        defaultConfig.sharesBps = sharesBps;
        defaultConfig.variedShareBps = variedShareBps;
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
        return (config.recipients, config.sharesBps, config.variedShareBps);
    }

    /// @notice Returns the default configuration
    /// @return The default split configuration
    function getDefaultConfig() external view returns (SplitConfig memory) {
        return configs[DEFAULT_CONFIG_ID];
    }

    /// @notice Returns the default configuration ID
    /// @return The default configuration ID
    function getDefaultConfigId() external pure returns (bytes32) {
        return DEFAULT_CONFIG_ID;
    }

    /// @inheritdoc IConfigurableRevenueDistributor
    function updateShares(
        bytes32 configId,
        address[] calldata _recipients,
        uint256[] calldata _sharesBps,
        uint256 _variedShareBps
    ) external override {
        _onlyFundsAdmin();
        _setShares(configId, _recipients, _sharesBps, _variedShareBps);
        emit SharesUpdated(configId, _recipients, _sharesBps, _variedShareBps);
    }

    /// @notice Updates the default configuration used when no specific config is found
    /// @param _recipients List of recipient addresses for the default config
    /// @param _sharesBps List of corresponding shares in basis points for the default config
    /// @param _variedShareBps Varied recipient's share in basis points for the default config
    function updateDefaultConfig(address[] calldata _recipients, uint256[] calldata _sharesBps, uint256 _variedShareBps)
        external
    {
        _onlyFundsAdmin();
        _setShares(DEFAULT_CONFIG_ID, _recipients, _sharesBps, _variedShareBps);
    }

    // ========== Internal Methods ==========

    /// @notice Internal function to split ERC20 tokens - can be called by inheriting contracts
    /// @param configId The configuration ID to use for splitting
    /// @param token The ERC20 token address
    /// @param amount The amount to split
    /// @param variedRecipient Address that receives dust and additional share (optional)
    function _splitERC20(bytes32 configId, address token, uint256 amount, address variedRecipient) internal {
        // Use requested config if it exists, otherwise fall back to default
        SplitConfig memory config;
        if (configs[configId].recipients.length == 0) {
            config = configs[DEFAULT_CONFIG_ID];
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

        // Distribute varied recipient share and any remaining dust
        uint256 variedAmount = 0;
        if (variedRecipient != address(0)) {
            // Calculate varied recipient's configured share
            if (config.variedShareBps > 0) {
                uint256 variedShare = (amount * config.variedShareBps) / TOTAL_BPS;
                totalDistributed += variedShare;
                variedAmount += variedShare;
            }

            // Add any remaining dust from rounding
            uint256 remainder = amount - totalDistributed;
            variedAmount += remainder;

            if (variedAmount > 0) {
                IERC20(token).safeTransfer(variedRecipient, variedAmount);
            }
        }

        emit SplitExecuted(configId, token, amount, config.recipients, amounts, variedRecipient, variedAmount);
    }

    /// @notice Internal function to split ETH - can be called by inheriting contracts
    /// @param configId The configuration ID to use for splitting
    /// @param variedRecipient Address that receives dust and additional share (optional)
    function _splitETH(bytes32 configId, address variedRecipient) internal {
        // Use requested config if it exists, otherwise fall back to default
        SplitConfig memory config;
        if (configs[configId].recipients.length == 0) {
            config = configs[DEFAULT_CONFIG_ID];
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

        // Distribute varied recipient share and any remaining dust
        uint256 variedAmount = 0;
        if (variedRecipient != address(0)) {
            // Calculate varied recipient's configured share
            if (config.variedShareBps > 0) {
                uint256 variedShare = (value * config.variedShareBps) / TOTAL_BPS;
                totalDistributed += variedShare;
                variedAmount += variedShare;
            }

            // Add any remaining dust from rounding
            uint256 remainder = value - totalDistributed;
            variedAmount += remainder;

            if (variedAmount > 0) {
                (bool success,) = variedRecipient.call{value: variedAmount}("");
                require(success, "ETH varied transfer failed");
            }
        }

        emit SplitExecuted(configId, address(0), value, config.recipients, amounts, variedRecipient, variedAmount);
    }

    /// @notice Internal function to update the split configuration
    /// @param configId The configuration ID to update
    /// @param _recipients List of recipient addresses
    /// @param _sharesBps List of corresponding shares in basis points
    /// @param _variedShareBps Varied recipient's share in basis points
    function _setShares(
        bytes32 configId,
        address[] memory _recipients,
        uint256[] memory _sharesBps,
        uint256 _variedShareBps
    ) internal {
        require(_recipients.length == _sharesBps.length, "Recipients and shares length mismatch");
        require(_recipients.length > 0, "No recipients provided");

        uint256 totalShares = _variedShareBps;

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
        config.variedShareBps = _variedShareBps;
    }
}
