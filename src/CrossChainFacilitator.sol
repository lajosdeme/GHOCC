// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {OwnerIsCreator} from "@chainlink/contracts-ccip/src/v0.8/shared/access/OwnerIsCreator.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
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

contract CrossChainFacilitator is CCIPReceiver, ICrossChainFacilitator {
    struct CrossChainGHOTransfer {
        uint256 amount;
        address receiver;
        address sender;
    }

    using PercentageMath for uint256;

    // GHO token address
    IGhoToken public immutable GHO_TOKEN;

    // USDC token address
    IERC20 public immutable USDC_TOKEN;

    uint256 public constant MAX_FEE = 1e4;

    // The GHO treasury, the recipient of fee distributions
    address private _ghoTreasury;

    // The facilitator fee for minting GHO, expressed in bps (a value of 10000 results in 100.00%)
    uint256 private _mintFee;

    // The facilitator fee for transferring GHO cross-chain, expressed in bps (a value of 10000 results in 100.00%)
    uint256 private _transferFee;

    address private _aaveGovernance;

    uint256 private _ghoTreasuryFees;

    mapping(uint64 => address) approvedCrossChainReceivers; // TODO

    modifier onlyAaveGovernance() {
        require(msg.sender == _aaveGovernance, "CrossChainFacilitator: Only Aave Governance can call.");
        _;
    }

    constructor(
        address ghoToken,
        address usdcToken,
        address ghoTreasury,
        address aaveGovernance,
        uint256 mintFee,
        uint256 transferFee,
        address _router
    ) CCIPReceiver(_router) {
        require(mintFee <= MAX_FEE && transferFee <= MAX_FEE, "CrossChainFacilitator: Fees out of range");
        GHO_TOKEN = IGhoToken(ghoToken);
        USDC_TOKEN = IERC20(usdcToken);
        _updateGhoTreasury(ghoTreasury);
        _updateMintFee(mintFee);
        _updateTransferFee(transferFee);
        _updateAaveGovernance(aaveGovernance);
    }

    function mintGHOForUSDC(uint256 amount, address to) external {
        // transfer the USDC to this contract
        require(
            USDC_TOKEN.transferFrom(msg.sender, address(this), amount),
            "CrossChainFacilitator: Failed to transfer USDC to facilitator"
        );

        // The fee due to the treasury
        uint256 mintFee = _calcMintFee(amount);

        // If the contract has enough GHO we transfer it out and not mint
        if (ghoBalance() >= amount + mintFee) {
            GHO_TOKEN.transfer(to, amount);
            _ghoTreasuryFees += mintFee;
            return;
        }

        // mint the GHO tokens
        GHO_TOKEN.mint(to, amount);
        // mint the fee for the treasury
        GHO_TOKEN.mint(address(this), mintFee);
        _ghoTreasuryFees += mintFee;
    }

    function redeemUSDCForGHO(uint64 amount, address to) external {
        // transfer GHO to this contract
        require(
            GHO_TOKEN.transferFrom(msg.sender, address(this), amount),
            "CrossChainFacilitator: Failed to transfer GHO to facilitator"
        );

        // transfer USDC to the
        require(USDC_TOKEN.transfer(to, amount), "CrossChainFacilitator: Failed to transfer USDC to address");
    }

    function sendGHOCrossChain(uint64 chainId, uint256 amount, address to) external returns (bytes32 messageId) {
        // calculate the fee to the treasury
        uint256 transferFee = _calcTransferFee(amount);

        // transfer amount + fee of GHO to contract
        require(
            GHO_TOKEN.transferFrom(msg.sender, address(this), amount + transferFee),
            "CrossChainFacilitator: Failed to transfer GHO to facilitator"
        );

        _ghoTreasuryFees != transferFee;

        // get target chain receiver
        address _receiver = approvedCrossChainReceivers[chainId];
        require(_receiver != address(0), "CrossChainFacilitator: Target chain is not supported.");

        // create cross chain transfer
        CrossChainGHOTransfer memory _transfer = CrossChainGHOTransfer(amount, to, msg.sender);

        // build CCIP message
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(_receiver, _transfer, address(0));

        // send CCIP message
        IRouterClient router = IRouterClient(this.getRouter());

        uint256 fees = router.getFee(chainId, evm2AnyMessage);
        require(fees < address(this).balance, "CrossChainFacilitator: Not enough balance to cover fees.");

        messageId = router.ccipSend{value: fees}(chainId, evm2AnyMessage);

        emit MessageSent(messageId, chainId, to, amount, address(0), fees);

    }

    // MINT FEE
    function _calcMintFee(uint256 amount) internal view returns (uint256) {
        return amount.percentMul(_mintFee);
    }

    function getMintFee() external view override returns (uint256) {
        return _mintFee;
    }

    function updateMintFee(uint256 newFee) external onlyAaveGovernance {
        _updateMintFee(newFee);
    }

    function _updateMintFee(uint256 newFee) internal {
        require(newFee <= MAX_FEE, "CrossChainFacilitator: Fee out of range");
        uint256 oldFee = _mintFee;
        _mintFee = newFee;
        emit MintFeeUpdated(oldFee, newFee);
    }

    // TRANSFER FEE
    function _calcTransferFee(uint256 amount) internal view returns (uint256) {
        return amount.percentMul(_transferFee);
    }

    function getTransferFee() external view override returns (uint256) {
        return _transferFee;
    }

    function updateTransferFee(uint256 newFee) external onlyAaveGovernance {
        _updateTransferFee(newFee);
    }

    function _updateTransferFee(uint256 newFee) internal {
        require(newFee <= MAX_FEE, "CrossChainFacilitator: Fee out of range");
        uint256 oldFee = _transferFee;
        _transferFee = newFee;
        emit TransferFeeUpdated(oldFee, newFee);
    }

    function ghoBalance() internal view returns (uint256) {
        return GHO_TOKEN.balanceOf(address(this));
    }

    function updateGhoTreasury(address newGhoTreasury) external onlyAaveGovernance {
        _updateGhoTreasury(newGhoTreasury);
    }

    function getGhoTreasury() external view override returns (address) {
        return _ghoTreasury;
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

    function distributeFeesToTreasury() external override onlyAaveGovernance {
        GHO_TOKEN.transfer(_ghoTreasury, _ghoTreasuryFees);
        _ghoTreasuryFees = 0;
        emit FeesDistributedToTreasury(_ghoTreasury, address(GHO_TOKEN), _ghoTreasuryFees);
    }

    function approveCrossChainReceiver(uint64 chainId, address ccReceiver) external onlyAaveGovernance {
        approvedCrossChainReceivers[chainId] = ccReceiver;
    }

    function encodeCCTransfer(CrossChainGHOTransfer memory _transfer) internal pure returns (bytes memory) {
        return abi.encode(_transfer);
    }

    function decodeCCTransfer(bytes memory _transferBytes) internal pure returns (CrossChainGHOTransfer memory) {
        return abi.decode(_transferBytes, (CrossChainGHOTransfer));
    }

    /// @notice Construct a CCIP message.
    /// @dev This function will create an EVM2AnyMessage struct with all the necessary information for sending a text.
    /// @param _receiver The address of the receiver.
    /// @param _transfer The CrossChainGhoTransfer.
    /// @param _feeTokenAddress The address of the token used for fees. Set address(0) for native gas.
    /// @return Client.EVM2AnyMessage Returns an EVM2AnyMessage struct which contains information for sending a CCIP message.
    function _buildCCIPMessage(address _receiver, CrossChainGHOTransfer memory _transfer, address _feeTokenAddress)
        internal
        pure
        returns (Client.EVM2AnyMessage memory)
    {
        // encode the transfer into bytes
        bytes memory encodedTransfer = encodeCCTransfer(_transfer);
        // Create an EVM2AnyMessage struct in memory with necessary information for sending a cross-chain message
        return Client.EVM2AnyMessage({
            receiver: abi.encode(_receiver), // ABI-encoded receiver address
            data: encodedTransfer, // Encoded CrossChainGhoTransfer
            tokenAmounts: new Client.EVMTokenAmount[](0), // Empty array aas no tokens are transferred
            extraArgs: Client._argsToBytes(
                // Additional arguments, setting gas limit
                Client.EVMExtraArgsV1({gasLimit: 200_000})
                ),
            // Set the feeToken to a feeTokenAddress, indicating specific asset will be used for fees
            feeToken: _feeTokenAddress
        });
    }

    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage) internal override {
        // TODO
    }
}
