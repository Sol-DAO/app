// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

import {ERC20token} from "src/tokens/ERC20token.sol";

contract ERC20Test is Test {
    using stdStorage for StdStorage;

    ERC20token erc20;

    function setUp() external {
        erc20 = new ERC20token();
    }

    // VM Cheatcodes can be found in ./lib/forge-std/src/Vm.sol
    // Or at https://github.com/foundry-rs/forge-std
    function testERC20() external {
    }
}
