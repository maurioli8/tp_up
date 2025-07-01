// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor(string memory name, string memory symbol, address to, uint256 amount) ERC20(name, symbol) {
        _mint(to, amount);
    }

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}