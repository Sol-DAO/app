// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC20} from "../../src/tokens/ERC20token.sol";

contract MockERC20 is ERC20 {
    function mint(address to, uint256 value) public virtual {
        _mint(to, value);
    }

    function burn(address from, uint256 value) public virtual {
        _burn(from, value);
    }
}
