// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

// import {ERC20token} from "src/tokens/ERC20token.sol";
import {ERC20} from "src/tokens/ERC20.sol";

import {MockERC20} from "./mocks/MockERC20.sol";

contract ERC20Test is Test {
    using stdStorage for StdStorage;

    MockERC20 erc20;

    function setUp() external {
        erc20 = new MockERC20();
    }

    // VM Cheatcodes can be found in ./lib/forge-std/src/Vm.sol
    // Or at https://github.com/foundry-rs/forge-std
    function testERC20() external {}

    /*//////////////////////////////////////////////////////////////
                            APPROVE FUNCTION
    //////////////////////////////////////////////////////////////*/

    function testApproveFromTheZeroAddress() external {
        address from = address(0);
        address to = address(this);

        vm.prank(from);
        vm.expectRevert(ERC20.ERC20__ApproveFromTheZeroAddress.selector);
        erc20.approve(to, 1e18);
    }

    function testApproveToTheZeroAddress() external {
        address from = address(this);
        address to = address(0);

        vm.prank(from);
        vm.expectRevert(ERC20.ERC20__ApproveToTheZeroAddress.selector);
        erc20.approve(to, 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSFER FUNCTION
    //////////////////////////////////////////////////////////////*/

    function testTransferFromTheZeroAddress() public {
        address from = address(0);
        address to = address(this);

        vm.prank(from);
        vm.expectRevert(ERC20.ERC20__TransferFromTheZeroAddress.selector);
        erc20.transfer(to, 1e18);
    }

    function testTransferToTheZeroAddress() public {
        address from = address(this);
        address to = address(0);

        vm.expectRevert(ERC20.ERC20__TransferToTheZeroAddress.selector);
        erc20.transfer(to, 1e18);
    }

    function testTransferAmountExceedsBalance() public {
        address from = address(this);
        address to = address(0xBEEF);

        erc20.mint(from, 1e18);
        vm.expectRevert(ERC20.ERC20__TransferAmountExceedsBalance.selector);
        erc20.transfer(to, 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                         TRANSFER FROM FUNCTION
    //////////////////////////////////////////////////////////////*/

    function testFailTransferFromAllowedEqualToMax() public {
        erc20.transferFrom(msg.sender, address(0), type(uint256).max);
    }

    /*//////////////////////////////////////////////////////////////
                             PERMIT FUNCTION
    //////////////////////////////////////////////////////////////*/

    // Added permit function but don't know what values go in the v, r, s param slots.
    // So will need help with this test
}
