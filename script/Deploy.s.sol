// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";

import { FlashLoaner } from "../src/FlashLoaner.sol";

contract Deploy is Script {
    address public constant POOL_ADDRESSES_PROVIDER_MAINNET =
        0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e;
    address public constant WETH_MAINNET = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant UNISWAP_ROUTER_02_MAINNET = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    FlashLoaner public flashLoaner;

    function run() public returns (address) {
        vm.startBroadcast();
        flashLoaner = new FlashLoaner(
            POOL_ADDRESSES_PROVIDER_MAINNET, WETH_MAINNET, UNISWAP_ROUTER_02_MAINNET
        );
        vm.stopBroadcast();

        return address(flashLoaner);
    }
}
