// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableMap} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/utils/structs/EnumerableMap.sol";

/* 
- take USDC as payment, mint GHO in return
- lock it up and mint wGHO on destination chain
- you can redeeem GHO by burning wGHO on destination chain
- you can redeem USDC with GHO
 */

 /* 
 steps:
 1. USDC, GHO, Aave governance hardcoded
 2. Have a capacitiy and a limit
 3. when received UDC mint equivalent of GHO
 4. have another function for sending cross chain
  */



contract CrossChainFacilitator {

}