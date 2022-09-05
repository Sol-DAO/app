// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.16;

import {Script} from 'forge-std/Script.sol';

import {ERC20token} from "src/tokens/ERC20token.sol";

/// @notice A very simple deployment script
contract Deploy is Script {
  /// @notice The main script entrypoint
  /// @return erc20 The deployed contract
  function run() external returns (ERC20token erc20) {
    vm.startBroadcast();
    erc20 = new ERC20token();
    vm.stopBroadcast();
  }
}