// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Test } from "forge-std/Test.sol";
import { console } from "forge-std/console.sol";

import { FlashLoaner } from "../src/FlashLoaner.sol";

contract FlashLoanerTest is Test {
    address public constant USER = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    address public constant POOL_ADDRESSES_PROVIDER_MAINNET =
        0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address public constant WETH_MAINNET = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant UNISWAP_ROUTER_02_MAINNET = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    FlashLoaner public flashLoaner;

    function setUp() public {
        vm.startPrank(USER);
        flashLoaner = new FlashLoaner(
            POOL_ADDRESSES_PROVIDER_MAINNET, WETH_MAINNET, UNISWAP_ROUTER_02_MAINNET
        );
        vm.stopPrank();
    }

    function test_healthCheck() public pure {
        assertEq(uint256(1), uint256(1));
    }

    function test_checkInitialization() public view {
        uint256 expectedHoldPercentage = 1; // In bips

        assertEq(flashLoaner.getWETH(), WETH_MAINNET);
        assertEq(flashLoaner.getUniswapV2Router02(), UNISWAP_ROUTER_02_MAINNET);
        assertEq(flashLoaner.HOLD_PERCENTAGE(), expectedHoldPercentage);
    }

    function test_flashLoan() public {
        uint256 amount = 1 ether;
        uint256 buffer = 0.5 ether;
        vm.deal(USER, buffer);

        uint256 userEthBalanceBefore = USER.balance;

        vm.startPrank(USER);
        flashLoaner.initiateFlashLoan{ value: buffer }(amount, USDC, 0, block.timestamp + 1 minutes);
        vm.stopPrank();

        uint256 userEthBalanceAfter = USER.balance;
        uint256 userUSDCBalanceAfter = IERC20(USDC).balanceOf(USER);
        uint256 contractEthBalanceAfter = address(flashLoaner).balance;
        uint256 contractWethBalanceAfter = IERC20(flashLoaner.getWETH()).balanceOf(USER);

        assertGt(userEthBalanceBefore - userEthBalanceAfter, 0);
        assertGt(userUSDCBalanceAfter, 0);
        assertEq(contractEthBalanceAfter, 0);
        assertEq(contractWethBalanceAfter, 0);
    }
}
