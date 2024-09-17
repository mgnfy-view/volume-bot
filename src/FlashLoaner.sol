// Layout:
//     - pragma
//     - imports
//     - interfaces, libraries, contracts
//     - type declarations
//     - state variables
//     - events
//     - errors
//     - modifiers
//     - functions
//         - constructor
//         - receive function (if exists)
//         - fallback function (if exists)
//         - external
//         - public
//         - internal
//         - private
//         - view and pure functions

// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IWETH } from "./interfaces/IWETH.sol";
import { IPoolAddressesProvider } from "@aave/contracts/interfaces/IPoolAddressesProvider.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IUniswapV2Router02 } from "@uniswap-v2/contracts/interfaces/IUniswapV2Router02.sol";

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { FlashLoanSimpleReceiverBase } from
    "aave-v3-core/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";

/**
 * @title FlashLoaner.
 * @author mgnfy-view.
 * @notice This contract can be used by any volume booster bot to increase the trading volume
 * of a token pair on Uniswap. It flash borrows WETH from Aave, uses it to buy tokens on Uniswap,
 * and sells those tokens in the same transaction to get back WETH and pay back the loan.
 */
contract FlashLoaner is FlashLoanSimpleReceiverBase {
    using SafeERC20 for IERC20;

    uint256 public constant HOLD_PERCENTAGE = 1; // 0.01%
    uint256 private constant BPS = 10_000;

    address private immutable i_weth;
    address private immutable i_uniswapRouter02;

    error FlashLoaner__TransferFailed();
    error FlashLoaner__UnsupportedToken(address token);
    error FlashLoaner__InvalidInitiator(address initiator);

    constructor(
        address _addressProvider,
        address _weth,
        address _uniswapRouter02
    )
        FlashLoanSimpleReceiverBase(IPoolAddressesProvider(_addressProvider))
    {
        i_weth = _weth;
        i_uniswapRouter02 = _uniswapRouter02;
    }

    receive() external payable { }

    /**
     * @notice Allows anyone to initiate a flash loan on Aave V3 using raw ETH.
     * @dev Any surplus raw ETH passed will be returned at the end of the function.
     * @param _amount The WETH amount to flash loan.
     * @param _tokenToIncreaseVolumeOf The token to buy and sell with the flash loaned amount.
     */
    function initiateFlashLoan(
        uint256 _amount,
        address _tokenToIncreaseVolumeOf,
        uint256 _minimumTokenAmountOut,
        uint256 _deadline
    )
        public
        payable
    {
        // Convert raw ETH to WETH
        // msg.value is used here so that a surplus amount of ETH can be converted to WETH
        // This will allow us to pay the fee for the flash loan and the swaps
        IWETH(i_weth).deposit{ value: msg.value }();

        address thisAddress = address(this);
        bytes memory encodedData =
            abi.encode(_tokenToIncreaseVolumeOf, _minimumTokenAmountOut, msg.sender, _deadline);
        uint16 referralCode = 0; // No referral

        POOL.flashLoanSimple(thisAddress, i_weth, _amount, encodedData, referralCode);

        uint256 wethBalance = IERC20(i_weth).balanceOf(thisAddress);

        // Convert WETH to raw ETH and send back any remaining raw ETH to the msg.sender
        IWETH(i_weth).withdraw(wethBalance);
        (bool success,) = payable(msg.sender).call{ value: address(this).balance }("");
        if (!success) revert FlashLoaner__TransferFailed();
    }

    /**
     * @notice This is the callback function called by Aave after it has transferred the flashloan
     * amount to our contract. The logic to increase the volume of a token pair is handled here.
     * @param _asset The flash loaned asset. In our case, it's always WETH.
     * @param _amount The flash loan amount.
     * @param _premium The total fee to be paid for the flash loan.
     * @param _initiator The address that initiated the flash loan. In our case, it should be this
     * contract itself.
     * @param _params Any encoded params passed by the initiator of the flash loan.
     * @return A boolean indicating if the flash loan was successful or not.
     */
    function executeOperation(
        address _asset,
        uint256 _amount,
        uint256 _premium,
        address _initiator,
        bytes calldata _params
    )
        external
        override
        returns (bool)
    {
        if (_asset != i_weth) revert FlashLoaner__UnsupportedToken(_asset);
        if (_initiator != address(this)) revert FlashLoaner__InvalidInitiator(_initiator);
        (
            address tokenToIncreaseVolumeOf,
            uint256 minimumTokenAmountOut,
            address receiver,
            uint256 deadline
        ) = abi.decode(_params, (address, uint256, address, uint256));

        // Buy the token
        (uint256[] memory amounts) =
            _swap(i_weth, tokenToIncreaseVolumeOf, _amount, minimumTokenAmountOut, deadline);

        // Send a small percentage of the tokens bought to the receiver's wallet
        uint256 amountToSendToReceiver = _calculateTokenAmountToSendToReceiver(amounts[1]);
        IERC20(tokenToIncreaseVolumeOf).safeTransfer(receiver, amountToSendToReceiver);

        // Sell the tokens to get WETH back
        uint256 tokenAmountLeft = amounts[1] - amountToSendToReceiver;
        // The 0 amount out cannot be exploited here since this swap occurs in a single transaction
        // where the previous swap had safety checks
        _swap(tokenToIncreaseVolumeOf, i_weth, tokenAmountLeft, 0, deadline);

        // Approve the flash loaned amount plus the fee so that Aave can pull it back when
        // control returns to it
        uint256 paybackAmount = _amount + _premium;
        IERC20(_asset).approve(address(POOL), paybackAmount);

        return true;
    }

    function _swap(
        address _inputToken,
        address _outputToken,
        uint256 _amountIn,
        uint256 _minimumAmountOut,
        uint256 _deadline
    )
        internal
        returns (uint256[] memory)
    {
        uint256 numCheckPoints = 2;
        address[] memory path = new address[](numCheckPoints);
        path[0] = _inputToken;
        path[1] = _outputToken;

        IERC20(_inputToken).approve(i_uniswapRouter02, _amountIn);

        return IUniswapV2Router02(i_uniswapRouter02).swapExactTokensForTokens(
            _amountIn, _minimumAmountOut, path, address(this), _deadline
        );
    }

    /**
     * @notice Calculates the amount of received tokens to send to the receiver. Set to a constant 1% of the token
     * amount received.
     * @param _amount The token amount received after the swap.
     * @return The token amount to send to the receiving wallet.
     */
    function _calculateTokenAmountToSendToReceiver(
        uint256 _amount
    )
        internal
        pure
        returns (uint256)
    {
        return (_amount * HOLD_PERCENTAGE) / BPS;
    }

    /**
     * @notice Get the WETH address.
     * @return The WETH token address.
     */
    function getWETH() external view returns (address) {
        return i_weth;
    }

    /**
     * @notice Get the Uniswap V2 router 02 address.
     * @return The Uniswap V2 router 02 address.
     */
    function getUniswapV2Router02() external view returns (address) {
        return i_uniswapRouter02;
    }
}
