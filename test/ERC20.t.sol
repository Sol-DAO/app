// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.15;

import "forge-std/Test.sol";

// import {ERC20token} from "src/tokens/ERC20token.sol";
import {ERC20} from "src/tokens/ERC20.sol";

import {MockERC20} from "./mocks/MockERC20.sol";

contract ERC20Test is Test {
    using stdStorage for StdStorage;

    bytes32 constant PERMIT_TYPEHASH =
        keccak256(
            "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
        );

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
        vm.expectRevert(ERC20.ApproveFromTheZeroAddress.selector);
        erc20.approve(to, 1e18);
    }

    function testApproveToTheZeroAddress() external {
        address from = address(this);
        address to = address(0);

        vm.prank(from);
        vm.expectRevert(ERC20.ApproveToTheZeroAddress.selector);
        erc20.approve(to, 1e18);
    }

    /*//////////////////////////////////////////////////////////////
                            TRANSFER FUNCTION
    //////////////////////////////////////////////////////////////*/

    function testTransferFromTheZeroAddress() public {
        address from = address(0);
        address to = address(this);

        vm.prank(from);
        vm.expectRevert(ERC20.TransferFromTheZeroAddress.selector);
        erc20.transfer(to, 1e18);
    }

    function testTransferToTheZeroAddress() public {
        address from = address(this);
        address to = address(0);

        vm.expectRevert(ERC20.TransferToTheZeroAddress.selector);
        erc20.transfer(to, 1e18);
    }

    function testTransferAmountExceedsBalance() public {
        address from = address(this);
        address to = address(0xBEEF);

        erc20.mint(from, 1e18);
        vm.expectRevert(ERC20.TransferAmountExceedsBalance.selector);
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

    function testDeadlintBelowBlockTimestamp() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    erc20.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            address(0xCAFE),
                            1e18,
                            0,
                            block.timestamp
                        )
                    )
                )
            )
        );

        vm.expectRevert(ERC20.DeadlineBelowBlockTimestamp.selector);
        erc20.permit(
            owner,
            address(0xCAFE),
            1e18,
            (block.timestamp - 1),
            v,
            r,
            s
        );
    }

    function testInvalidSignerRecoveredAddress() public {
        uint256 privateKey = 0xBEEF;
        address owner = vm.addr(privateKey);

        address notOwner = vm.addr(0xCAFE);

        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privateKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    erc20.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            owner,
                            address(0xCAFE),
                            1e18,
                            0,
                            block.timestamp
                        )
                    )
                )
            )
        );

        vm.expectRevert(ERC20.InvalidSignerRecoveredAddress.selector);
        erc20.permit(notOwner, address(0xCAFE), 1e18, block.timestamp, v, r, s);
    }
}
