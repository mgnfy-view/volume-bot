// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { Script } from "forge-std/Script.sol";

contract SendFunds is Script {
    address public constant TO = 0x78355EF65a76bA50cC0BBe9D9082D995d4EcF761;

    uint256 public constant SEED_AMOUNT = 3 ether;

    error SendFunds__TransferFailed();

    function run() public {
        vm.broadcast();
        (bool success,) = payable(TO).call{ value: SEED_AMOUNT }("");
        if (!success) revert SendFunds__TransferFailed();
        vm.broadcast();
    }
}
