// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {IERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableMap} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/utils/structs/EnumerableMap.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./gho/interfaces/IGhoToken.sol";

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
    // GHO token address
    IGhoToken public immutable GHO_TOKEN;

    // USDC token address
    IERC20 public immutable USDC_TOKEN;

    uint256 public constant MAX_FEE = 1e4;

    // The GHO treasury, the recipient of fee distributions
    address private _ghoTreasury;

    // The facilitator fee, expressed in bps (a value of 10000 results in 100.00%)
    uint256 private _fee;

    address private _aaveGovernance;

    constructor(address ghoToken, address ghoTreasury, address aaveGovernance, uint256 fee) {
        require(fee <= MAX_FEE, 'CrossChainFacilitator: Fee out of range');
        GHO_TOKEN = IGhoToken(ghoToken);
        _updateGhoTreasury(ghoTreasury);
        _updateFee(fee);
        _updateAaveGovernance(newAaveGovernance);
    }

    function updateFee(uint256 newFee) external { // TODO
        _updateFee(newFee);
    }

    function updateGhoTreasury(address newGhoTreasury) external { // TODO
        _updateGhoTreasury(newGhoTreasury);
    }

    function getFee() external view override returns (uint256) {
        return _fee;
    }

    function getGhoTreasury() external view override returns (address) {
        return _ghoTreasury;
    }

    function _updateFee(uint256 newFee) internal {
        require(newFee <= MAX_FEE, 'CrossChainFacilitator: Fee out of range');
        uint256 oldFee = _fee;
        _fee = newFee;
        emit FeeUpdated(oldFee, newFee);
    }

    function _updateGhoTreasury(address newGhoTreasury) internal {
        address oldGhoTreasury = _ghoTreasury;
        _ghoTreasury = newGhoTreasury;
        emit GhoTreasuryUpdated(oldGhoTreasury, newGhoTreasury);
    }

    function _updateAaveGovernance(address newAaveGovernance) internal {
        address oldAaveGovernance = _aaveGovernance;
        _aaveGovernance = newAaveGovernance;
        emit AaveGovernanceUpdated(oldAaveGovernance, newAaveGovernance);
    }
}
