// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/CCNFT.sol";

contract DeployCCNFT is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        CCNFT ccnft = new CCNFT("MyNFT", "MNFT");
        console.log("CCNFT deployed at:", address(ccnft));
        // Aquí puedes llamar setters si lo deseas
        vm.stopBroadcast();
    }
}