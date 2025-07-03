// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/BUSD.sol";

contract DeployBUSD is Script {
    function run() public {
        vm.startBroadcast();
        new BUSD();
        vm.stopBroadcast();
    }
}