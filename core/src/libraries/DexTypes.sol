// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.7.6;

/**
 * @title DexTypes
 * @notice Library containing DEX type constants and utility functions for identifying different DEX protocols
 * @dev Provides a centralized way to manage DEX type identification across the Reflex system
 */
library DexTypes {
    // DEX Type Constants
    /// @notice UniswapV2 with callback support (flash loan capable)
    uint8 public constant UNISWAP_V2_WITH_CALLBACK = 0;

    /// @notice UniswapV2 without callback support (standard swap only)
    uint8 public constant UNISWAP_V2_WITHOUT_CALLBACK = 1;

    /// @notice UniswapV3 protocol
    uint8 public constant UNISWAP_V3 = 3;

    /// @notice Solidly fork protocol with callback support
    uint8 public constant SOLIDLY = 5;

    /// @notice Algebra protocol (UniswapV3 fork)
    uint8 public constant ALGEBRA = 6;

    /**
     * @notice Checks if a DEX type is UniswapV2-like
     * @dev Returns true for DEX types that follow UniswapV2 interface patterns
     * @param dexType The DEX type identifier
     * @return True if the DEX type is UniswapV2-like (types 0, 1, or 5)
     */
    function isUniswapV2Like(uint8 dexType) internal pure returns (bool) {
        return dexType < 2 || dexType == SOLIDLY;
    }

    /**
     * @notice Checks if a DEX type is UniswapV3-like
     * @dev Returns true for DEX types that follow UniswapV3 interface patterns
     * @param dexType The DEX type identifier
     * @return True if the DEX type is UniswapV3-like (types 3 or 6)
     */
    function isUniswapV3Like(uint8 dexType) internal pure returns (bool) {
        return dexType == UNISWAP_V3 || dexType == ALGEBRA;
    }

    /**
     * @notice Checks if a DEX type is UniswapV2-like with callback support
     * @dev Returns true for DEX types that support callback functions during swaps
     * @param dexType The DEX type identifier
     * @return True if the DEX type supports callbacks (types 0 or 5)
     */
    function isUniswapV2WithCallback(uint8 dexType) internal pure returns (bool) {
        return dexType == UNISWAP_V2_WITH_CALLBACK || dexType == SOLIDLY;
    }

    /**
     * @notice Checks if a DEX type is UniswapV2-like without callback support
     * @dev Returns true for DEX types that don't support callback functions during swaps
     * @param dexType The DEX type identifier
     * @return True if the DEX type doesn't support callbacks (type 1)
     */
    function isUniswapV2WithoutCallback(uint8 dexType) internal pure returns (bool) {
        return dexType == UNISWAP_V2_WITHOUT_CALLBACK;
    }

    /**
     * @notice Gets a human-readable name for a DEX type
     * @dev Useful for debugging and logging purposes
     * @param dexType The DEX type identifier
     * @return name The human-readable name of the DEX type
     */
    function getDexTypeName(uint8 dexType) internal pure returns (string memory name) {
        if (dexType == UNISWAP_V2_WITH_CALLBACK) {
            return "UniswapV2 (with callback)";
        } else if (dexType == UNISWAP_V2_WITHOUT_CALLBACK) {
            return "UniswapV2 (without callback)";
        } else if (dexType == UNISWAP_V3) {
            return "UniswapV3";
        } else if (dexType == SOLIDLY) {
            return "Solidly";
        } else if (dexType == ALGEBRA) {
            return "Algebra";
        } else {
            return "Unknown";
        }
    }
}
