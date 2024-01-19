// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import {SafeERC20} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableMap} from "@chainlink/contracts-ccip/src/v0.8/vendor/openzeppelin-solidity/v4.8.0/contracts/utils/structs/EnumerableMap.sol";
import "./gho/interfaces/IGhoToken.sol";
import "./interfaces/ICrossChainFacilitator.sol";
import "./PercentageMath.sol";

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

contract CrossChainFacilitator is ICrossChainFacilitator {
    using PercentageMath for uint256;

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

    uint256 private _ghoTreasuryFees;

    constructor(address ghoToken, address usdcToken, address ghoTreasury, address aaveGovernance, uint256 fee) {
        require(fee <= MAX_FEE, 'CrossChainFacilitator: Fee out of range');
        GHO_TOKEN = IGhoToken(ghoToken);
        USDC_TOKEN = IERC20(usdcToken);
        _updateGhoTreasury(ghoTreasury);
        _updateFee(fee);
        _updateAaveGovernance(aaveGovernance);
    }

    function mintGHOForUSDC(uint256 amount, address to) external {
        // transfer the USDC to this contract
        require(USDC_TOKEN.transferFrom(msg.sender, address(this), amount), "CrossChainFacilitator: Failed to transfer USDC to facilitator");

        // The fee due to the treasury
        uint256 ghoccFee = _ghoccFee(amount);

        // If the contract has enough GHO we transfer it out and not mint
        if (ghoBalance() >= amount + ghoccFee) {
            GHO_TOKEN.transfer(to, amount);
            _ghoTreasuryFees += ghoccFee;
            return;
        }

        // mint the GHO tokens
        GHO_TOKEN.mint(to, amount);
        // mint the fee for the treasury
        GHO_TOKEN.mint(address(this), ghoccFee);
        _ghoTreasuryFees += ghoccFee;
    }

    function redeemUSDCForGHO(uint256 amount, address to) external {
        // transfer GHO to this contract
        require(GHO_TOKEN.transferFrom(msg.sender, address(this), amount), "CrossChainFacilitator: Failed to transfer GHO to facilitator");

        // transfer USDC to the 
        require(USDC_TOKEN.transfer(to, amount), "CrossChainFacilitator: Failed to transfer USDC to address");
    }

    function sendGHOCrossChain(uint256 chainId, uint256 amount) external {

    }

    function _ghoccFee(uint256 amount) internal view returns (uint256) {
        return amount.percentMul(_fee);
    }


    function ghoBalance() internal view returns (uint256) {
        return GHO_TOKEN.balanceOf(address(this));
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

    function distributeFeesToTreasury() external override {
        GHO_TOKEN.transfer(_ghoTreasury, _ghoTreasuryFees);
        emit FeesDistributedToTreasury(_ghoTreasury, address(GHO_TOKEN), _ghoTreasuryFees);
    }
}
