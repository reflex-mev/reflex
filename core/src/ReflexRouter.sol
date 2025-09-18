// SPDX-License-Identifier: MIT
pragma solidity >=0.7.6;
pragma abicoder v2;

import "./interfaces/IReflexQuoter.sol";
import "@reflex/interfaces/IReflexRouter.sol";
import "./utils/GracefulReentrancyGuard.sol";
import "./libraries/DexTypes.sol";
import "./integrations/ConfigurableRevenueDistributor/ConfigurableRevenueDistributor.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IUniswapV3Pool {
    function swap(
        address recipient,
        bool zeroForOne,
        int256 amountSpecified,
        uint160 sqrtPriceLimitX96,
        bytes calldata data
    ) external returns (int256 amount0, int256 amount1);
}

interface IUniswapV2Pair {
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external;
}

// --- Fallback Loan behavior controls ---
uint8 constant LOAN_CALLBACK_TYPE_EMPTY = 0; // No ongoing swap, if fallback called, do nothing
uint8 constant LOAN_CALLBACK_TYPE_ONGOING = 1; // Ongoing swap, if callback called, check data format and payback loan
uint8 constant LOAN_CALLBACK_TYPE_UNI2 = 2; // Initial loan from uniswap v2 or solidly fork
uint8 constant LOAN_CALLBACK_TYPE_UNI3 = 3; // Initial loan from uniswap v3

/**
 * @title ReflexRouter
 * @notice A smart contract router for executing arbitrage trades across multiple DEX protocols
 * @dev Implements flash loan arbitrage strategies using UniswapV2, UniswapV3, and other DEX protocols
 * The contract uses flash loans to execute profitable arbitrage opportunities without requiring upfront capital
 * Supports multiple DEX types and handles callback-based flash loan mechanisms
 * Inherits from ConfigurableRevenueDistributor to support profit splitting across multiple configurations
 */
contract ReflexRouter is IReflexRouter, GracefulReentrancyGuard, ConfigurableRevenueDistributor {
    using SafeERC20 for IERC20;

    // ========== Events ==========

    /// @notice Emitted when the ReflexQuoter address is updated
    /// @param oldQuoter The address of the previous quoter contract
    /// @param newQuoter The address of the new quoter contract
    event ReflexQuoterUpdated(address indexed oldQuoter, address indexed newQuoter);

    // ========== State Variables ==========

    /// @notice The address of the contract owner/admin
    address public owner;

    /// @notice The address of the ReflexQuoter contract used for price quotes and route calculations
    address public reflexQuoter;

    /// @dev Internal state variable to track the type of ongoing flash loan callback
    /// Used to route different callback types appropriately during flash loan execution
    uint8 private loanCallbackType;

    /**
     * @notice Constructor sets the contract deployer as the owner
     * @dev Uses msg.sender to set the owner, which is the direct caller of the constructor
     */
    constructor() {
        owner = msg.sender;
    }

    /**
     * @notice Modifier to restrict access to owner functions
     * @dev Requires that the caller is the contract owner
     */
    modifier isOwner() {
        require(msg.sender == owner);
        _;
    }

    /**
     * @notice Internal function to enforce admin access control for ConfigurableRevenueDistributor
     * @dev Implementation of the abstract _onlyFundsAdmin function from ConfigurableRevenueDistributor
     */
    function _onlyFundsAdmin() internal view override {
        require(msg.sender == owner, "Only admin can manage revenue configurations");
    }

    /**
     * @notice Sets the address of the ReflexQuoter contract
     * @dev Only callable by admin. Used to update the quoter contract address
     * @param _reflexQuoter The address of the new ReflexQuoter contract
     */
    function setReflexQuoter(address _reflexQuoter) public isOwner {
        address oldQuoter = reflexQuoter;
        reflexQuoter = _reflexQuoter;
        emit ReflexQuoterUpdated(oldQuoter, _reflexQuoter);
    }

    /**
     * @notice Returns the address of the contract admin/owner
     * @dev Public view function to get the current owner address
     * @return The address of the contract owner
     */
    function getReflexAdmin() public view returns (address) {
        return owner;
    }

    /**
     * @notice Executes a backrun arbitrage opportunity on a DEX pool
     * @dev Gets a quote from ReflexQuoter, executes the swap route if profitable, and distributes profit using revenue distributor
     * @param triggerPoolId The unique identifier of the pool that triggered the backrun opportunity
     * @param swapAmountIn The amount of tokens to use as input for the arbitrage swap
     * @param token0In Whether to use token0 (true) or token1 (false) as the input token
     * @param recipient The address that will receive the arbitrage profit (used as dust recipient)
     * @param configId The configuration ID for profit splitting (uses default if bytes32(0))
     * @return profit The amount of profit generated from the arbitrage
     * @return profitToken The address of the token in which profit was generated
     */
    function triggerBackrun(
        bytes32 triggerPoolId,
        uint112 swapAmountIn,
        bool token0In,
        address recipient,
        bytes32 configId
    ) external override gracefulNonReentrant returns (uint256 profit, address profitToken) {
        return _triggerBackrun(triggerPoolId, swapAmountIn, token0In, recipient, configId);
    }

    /**
     * @notice Internal version of triggerBackrun without reentrancy guard for use with try-catch
     * @dev Used internally by backrunedExecute to enable failsafe mechanism
     * @param triggerPoolId The unique identifier of the pool that triggered the backrun opportunity
     * @param swapAmountIn The amount of tokens to use as input for the arbitrage swap
     * @param token0In Whether to use token0 (true) or token1 (false) as the input token
     * @param recipient The address that will receive the arbitrage profit (used as dust recipient)
     * @param configId The configuration ID for profit splitting (uses default if bytes32(0))
     * @return profit The amount of profit generated from the arbitrage
     * @return profitToken The address of the token in which profit was generated
     */
    function triggerBackrunSafe(
        bytes32 triggerPoolId,
        uint112 swapAmountIn,
        bool token0In,
        address recipient,
        bytes32 configId
    ) external returns (uint256 profit, address profitToken) {
        require(msg.sender == address(this), "Only self-call allowed");
        return _triggerBackrun(triggerPoolId, swapAmountIn, token0In, recipient, configId);
    }

    /**
     * @notice Internal function to execute a backrun arbitrage opportunity on a DEX pool
     * @dev Gets a quote from ReflexQuoter, executes the swap route if profitable, and distributes profit using revenue distributor
     * @param triggerPoolId The unique identifier of the pool that triggered the backrun opportunity
     * @param swapAmountIn The amount of tokens to use as input for the arbitrage swap
     * @param token0In Whether to use token0 (true) or token1 (false) as the input token
     * @param recipient The address that will receive the arbitrage profit (used as dust recipient)
     * @param configId The configuration ID for profit splitting (uses default if bytes32(0))
     * @return profit The amount of profit generated from the arbitrage
     * @return profitToken The address of the token in which profit was generated
     */
    function _triggerBackrun(
        bytes32 triggerPoolId,
        uint112 swapAmountIn,
        bool token0In,
        address recipient,
        bytes32 configId
    ) internal returns (uint256 profit, address profitToken) {
        (
            uint256 quoteProfit,
            IReflexQuoter.SwapDecodedData memory decoded,
            uint256[] memory amountsOut,
            uint256 initialHopIndex
        ) = IReflexQuoter(reflexQuoter).getQuote(
            address(uint160(uint256(triggerPoolId))), token0In ? 0 : 1, swapAmountIn
        );

        if (quoteProfit == 0) {
            return (0, address(0)); // No profit found
        }

        profitToken = decoded.tokens[0];
        uint256 balanceBefore = IERC20(profitToken).balanceOf(address(this));
        _triggerSwapRoute(decoded, amountsOut, initialHopIndex);
        profit = IERC20(profitToken).balanceOf(address(this)) - balanceBefore;

        // Split the profit using the revenue distributor (handles default config fallback internally)
        _splitERC20(configId, profitToken, profit, recipient);

        loanCallbackType = LOAN_CALLBACK_TYPE_EMPTY;
        emit BackrunExecuted(triggerPoolId, swapAmountIn, token0In, quoteProfit, profit, profitToken, recipient);
    }

    /**
     * @notice Executes arbitrary calldata on a target contract and then triggers multiple backruns
     * @dev First executes the provided calldata on the target, then performs multiple backrun arbitrages if profitable
     * @param executeParams The parameters for the execute call (target, value, callData)
     * @param backrunParams Array of parameters for each backrun trigger
     * @return success Whether the initial call was successful
     * @return returnData The return data from the initial call
     * @return profits Array of profits generated from each arbitrage
     * @return profitTokens Array of tokens in which profits were generated
     */
    function backrunedExecute(
        IReflexRouter.ExecuteParams calldata executeParams,
        IReflexRouter.BackrunParams[] calldata backrunParams
    )
        external
        payable
        override
        gracefulNonReentrant
        returns (bool success, bytes memory returnData, uint256[] memory profits, address[] memory profitTokens)
    {
        // Execute the arbitrary call first with ETH value
        (success, returnData) = executeParams.target.call{value: executeParams.value}(executeParams.callData);

        require(success, "Initial call failed");

        // Initialize result arrays
        profits = new uint256[](backrunParams.length);
        profitTokens = new address[](backrunParams.length);

        // Execute each backrun with failsafe mechanism
        for (uint256 i = 0; i < backrunParams.length; i++) {
            try this.triggerBackrunSafe(
                backrunParams[i].triggerPoolId,
                backrunParams[i].swapAmountIn,
                backrunParams[i].token0In,
                backrunParams[i].recipient,
                backrunParams[i].configId
            ) returns (uint256 profit, address profitToken) {
                profits[i] = profit;
                profitTokens[i] = profitToken;
            } catch {
                // If backrun fails, set profit to 0 and token to zero address
                // This allows other backruns to continue executing
                profits[i] = 0;
                profitTokens[i] = address(0);
            }
        }
    }

    /**
     * @notice Initiates the swap route execution for arbitrage
     * @dev Determines the swap direction and initiates either UniswapV2 or UniswapV3 style swap
     * @param decoded The decoded swap data containing pools, types, metadata, and tokens
     * @param valid Array of valid amounts for each hop in the swap route
     * @param index The index of the initial hop to start the swap route
     */
    function _triggerSwapRoute(IReflexQuoter.SwapDecodedData memory decoded, uint256[] memory valid, uint256 index)
        internal
    {
        bool isZeroForOne = _decodeIsZeroForOne(decoded.dexMeta[index]);

        // Encode data for callback
        bytes memory data = abi.encode(decoded.pools, decoded.dexType, decoded.dexMeta, valid, index, decoded.tokens);

        // uniswap v2 or solidly forks
        if (DexTypes.isUniswapV2WithCallback(decoded.dexType[index])) {
            loanCallbackType = LOAN_CALLBACK_TYPE_UNI2;
            (uint256 amount0Out, uint256 amount1Out) =
                isZeroForOne ? (uint256(0), valid[index + 1]) : (valid[index + 1], uint256(0));
            IUniswapV2Pair(decoded.pools[index]).swap(amount0Out, amount1Out, address(this), bytes(data));
        } else if (DexTypes.isUniswapV3Like(decoded.dexType[index])) {
            //Uniswap v3, algebra
            loanCallbackType = LOAN_CALLBACK_TYPE_UNI3;
            _swapUniswapV3Pool(decoded.pools[index], address(this), valid[index], isZeroForOne, bytes(data));
        }
    }

    /**
     * @notice Handles the flash loan callback and continues the swap execution
     * @dev Called by DEX pools during flash loans to continue the arbitrage swap route
     * @param data Encoded data containing swap route information (pools, types, metadata, amounts, etc.)
     */
    function _handleLoanCallback(bytes memory data) internal {
        (
            address[] memory _pairs,
            uint8[] memory _types,
            uint8[] memory _meta,
            uint256[] memory valid,
            uint8 initialHopIndex,
            address[] memory tokens
        ) = abi.decode(data, (address[], uint8[], uint8[], uint256[], uint8, address[]));
        uint256 nextHopIndex = (initialHopIndex + 1) % _pairs.length;

        // For uniswap v2 like pools we need to send the input amount before calling swap on the pool
        if (DexTypes.isUniswapV2Like(_types[nextHopIndex])) {
            IERC20(tokens[nextHopIndex]).safeTransfer(address(_pairs[nextHopIndex]), valid[nextHopIndex]);
        }
        _swapFlow(_pairs, valid, _types, _meta, initialHopIndex, tokens);

        IERC20(tokens[initialHopIndex]).safeTransfer(address(_pairs[initialHopIndex]), valid[initialHopIndex]);
    }

    /**
     * @notice Executes the main swap flow through multiple DEX pools
     * @dev Iterates through all pools in the route, executing swaps and managing token transfers
     * @param pairs Array of pool addresses to swap through
     * @param amounts Array of token amounts for each hop in the route
     * @param _dexType Array of DEX types (UniswapV2, UniswapV3, etc.) for each pool
     * @param _meta Array of metadata for each pool (swap direction, etc.)
     * @param initialHopIndex The starting index for the swap route
     * @param tokens Array of token addresses involved in the swap route
     */
    function _swapFlow(
        address[] memory pairs,
        uint256[] memory amounts,
        uint8[] memory _dexType,
        uint8[] memory _meta,
        uint8 initialHopIndex,
        address[] memory tokens
    ) internal {
        uint8 dexType;
        uint256 curHopIndex;

        address to;
        uint256 size = pairs.length;

        bool zeroForOne;

        for (uint8 pairIndex = 1; pairIndex < size; pairIndex++) {
            curHopIndex = (initialHopIndex + pairIndex) % size;
            dexType = (_dexType[curHopIndex]);
            zeroForOne = _decodeIsZeroForOne(_meta[curHopIndex]);
            {
                uint256 nextHopIndex = (curHopIndex + 1) % size;

                // Determine whether to send swap output to next pool or to the contract
                // In case of UniswapV3 we pay after the swap so we always want to get the funds to the contract
                // Loan is payed back at the end of the flow
                to = (
                    curHopIndex < size - 1 // if not last
                        && (DexTypes.isUniswapV2Like(_dexType[nextHopIndex])) // next hop is uni type
                        && (curHopIndex + 1 != initialHopIndex)
                ) // loan scope
                    ? pairs[nextHopIndex]
                    : address(this);
            }

            if (DexTypes.isUniswapV2Like(dexType)) {
                {
                    (uint256 amount0Out, uint256 amount1Out) =
                        zeroForOne ? (uint256(0), amounts[curHopIndex + 1]) : (amounts[curHopIndex + 1], uint256(0));

                    if (DexTypes.isUniswapV2WithCallback(dexType)) {
                        IUniswapV2Pair(pairs[curHopIndex]).swap(amount0Out, amount1Out, to, new bytes(0x0));
                    } else if (DexTypes.isUniswapV2WithoutCallback(dexType)) {
                        IUniswapV2Pair(pairs[curHopIndex]).swap(amount0Out, amount1Out, to);
                    }
                }
            } else if (DexTypes.isUniswapV3Like(dexType)) {
                _swapUniswapV3Pool(
                    pairs[curHopIndex], to, amounts[curHopIndex], zeroForOne, abi.encodePacked(tokens[curHopIndex])
                );
            }

            // if the loan was taken from the middle hop.
            if (
                initialHopIndex != 0 && initialHopIndex != size - 1 && curHopIndex == size - 1
                    && DexTypes.isUniswapV2Like(_dexType[0])
            ) {
                to = pairs[0];
                IERC20(tokens[0]).safeTransfer(to, amounts[0]);
            }
        }
    }

    /**
     * @notice Executes a swap on a UniswapV3-like pool
     * @dev Calls the swap function on UniswapV3 pools with appropriate parameters and price limits
     * @param pair The address of the UniswapV3 pool
     * @param recipient The address that will receive the swap output
     * @param amountIn The amount of input tokens for the swap
     * @param zeroForOne Whether swapping token0 for token1 (true) or token1 for token0 (false)
     * @param data Additional data to pass to the swap callback
     * @return amountOut The amount of tokens received from the swap
     */
    function _swapUniswapV3Pool(address pair, address recipient, uint256 amountIn, bool zeroForOne, bytes memory data)
        internal
        returns (uint256 amountOut)
    {
        (int256 amount0, int256 amount1) = IUniswapV3Pool(pair).swap(
            recipient,
            zeroForOne,
            int256(amountIn),
            (
                zeroForOne /*MIN_SQRT_RATIO+1*/
                    ? 4295128740 /*MAX_SQRT_RATIO-1*/
                    : 1461446703485210103287273052203988822378723970341
            ),
            data
        );

        return uint256(-(zeroForOne ? amount1 : amount0));
    }

    /**
     * @notice Withdraws ERC20 tokens from the contract (admin only)
     * @dev Allows the admin to withdraw any ERC20 tokens that may be stuck in the contract
     * @param token The address of the ERC20 token to withdraw
     * @param amount The amount of tokens to withdraw
     * @param _to The address to send the withdrawn tokens to
     */
    function withdrawToken(address token, uint256 amount, address _to) public isOwner {
        IERC20(token).safeTransfer(_to, amount);
    }

    /**
     * @notice Withdraws Ether from the contract (admin only)
     * @dev Allows the admin to withdraw any ETH that may be stuck in the contract
     * @param amount The amount of ETH to withdraw (in wei)
     * @param _to The address to send the withdrawn ETH to
     */
    function withdrawEth(uint256 amount, address payable _to) public isOwner {
        _to.transfer(amount);
    }

    /**
     * @notice Fallback function that handles DEX pool callbacks during flash loans
     * @dev Routes different types of callbacks (UniswapV2, UniswapV3) based on loan callback type
     * Handles the callback flow for flash loans from different DEX protocols
     */
    fallback() external payable {
        // UniswapV3 Flashloan callback from the middle hop, used to pass input of the tokens to the pool
        // for uni2 we pass it before the swap
        if (loanCallbackType == LOAN_CALLBACK_TYPE_ONGOING) {
            (int256 t0, int256 t1, bytes memory data) = _decodeUniswapV3LikeCallbackParams();
            if (data.length == 20) {
                IERC20(_bytesToAddress(data)).safeTransfer(msg.sender, uint256(t0 > 0 ? t0 : t1));
            }
        } else if (loanCallbackType == LOAN_CALLBACK_TYPE_UNI3) {
            (,, bytes memory data) = _decodeUniswapV3LikeCallbackParams();
            loanCallbackType = LOAN_CALLBACK_TYPE_ONGOING; // Reset the callback type

            // Convert the uniswapv3 callback amounts to the external flash call format which relys on the uniswapv2 callback
            // We pass the amounts out for token0 and token1, if amount is negative it means amount out is 0
            _handleLoanCallback(data);
        } else if (loanCallbackType == LOAN_CALLBACK_TYPE_UNI2) {
            loanCallbackType = LOAN_CALLBACK_TYPE_ONGOING; // Reset the callback type
            (,, bytes memory data) = _decodeUniswapV2LikeCallbackParams();
            _handleLoanCallback(data);
        }
    }

    /**
     * @notice Decodes UniswapV3-like callback parameters from calldata
     * @dev Extracts amount0, amount1, and data from the callback function call
     * @return tt0 The amount of token0 (can be positive or negative)
     * @return tt1 The amount of token1 (can be positive or negative)
     * @return data Additional data passed in the callback
     */
    function _decodeUniswapV3LikeCallbackParams() internal pure returns (int256 tt0, int256 tt1, bytes memory data) {
        (tt0, tt1, data) = abi.decode(msg.data[4:], (int256, int256, bytes));
    }

    /**
     * @notice Decodes UniswapV2-like callback parameters from calldata
     * @dev Extracts amount0, amount1, and data from the callback function call
     * @return tt0 The amount of token0
     * @return tt1 The amount of token1
     * @return data Additional data passed in the callback
     */
    function _decodeUniswapV2LikeCallbackParams() internal pure returns (uint256 tt0, uint256 tt1, bytes memory data) {
        (tt0, tt1, data) = abi.decode(msg.data[4:], (uint256, uint256, bytes));
    }

    /**
     * @notice Converts bytes data to an address
     * @dev Extracts an address from bytes data using assembly for efficiency
     * @param d The bytes data containing the address
     * @return addr The extracted address
     */
    function _bytesToAddress(bytes memory d) internal pure returns (address addr) {
        assembly {
            addr := mload(add(add(d, 20), 0))
        }
    }

    /**
     * @notice Fallback function to receive Ether
     * @dev Allows the contract to receive ETH transfers
     */
    receive() external payable {}

    /**
     * @notice Decodes the swap direction from metadata byte
     * @dev Extracts the zeroForOne flag from the most significant bit of a byte
     * Uses bitwise AND with 0x80 to check if the MSB is set
     * @param b The byte containing the encoded swap direction
     * @return zeroForOne True if swapping token0 for token1, false otherwise
     */
    // 1 byte - <1 bit zeroForOne><7 bits- other data>
    function _decodeIsZeroForOne(uint8 b) internal pure returns (bool zeroForOne) {
        assembly {
            zeroForOne := and(b, 0x80)
        }
    }
}
