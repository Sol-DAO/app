// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC20token} from "../tokens/ERC20token.sol";

import {ClonesWithImmutableArgs} from "../utils/ClonesWithImmutableArgs.sol";

/// @notice Factory to create ERC20 token.
contract ERC20tokenFactory {
    using ClonesWithImmutableArgs for address;

    ERC20token internal immutable erc20tokenTemplate;

    constructor(ERC20token _ERC20tokenTemplate) payable {
        erc20tokenTemplate = _ERC20tokenTemplate;
    }
 
    function createERC20token(
        bytes32 _name,
        bytes32 _symbol,
        uint8 _decimals,
        bytes32 _salt
    ) public payable {
        ERC20token erc20 = ERC20token(
            address(erc20tokenTemplate).cloneDeterministic(
                _salt,
                abi.encodePacked(
                    _name, 
                    _symbol, 
                    _decimals,
                    block.chainid
                )
            )
        );
        
        erc20.initialize();
    }
}
