// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "../gho/interfaces/IGhoFacilitator.sol";
import "../gho/interfaces/IGhoToken.sol";

interface ICrossChainFacilitator is IGhoFacilitator {
    /**
     * @dev Emitted when the percentage fee is updated
     * @param oldFee The old fee (in bps)
     * @param newFee The new fee (in bps)
     */
    event MintFeeUpdated(uint256 oldFee, uint256 newFee);

    /**
     * @dev Emitted when the percentage fee is updated
     * @param oldFee The old fee (in bps)
     * @param newFee The new fee (in bps)
     */
    event TransferFeeUpdated(uint256 oldFee, uint256 newFee);

    event AaveGovernanceUpdated(address oldAaveGovernance, address newAaveGovernance);

    event MessageSent(
        bytes32 indexed messageId, 
        uint64 indexed destinationChainSelector,
        address receiver,
        uint256 amount,
        address feeToken,
        uint256 fees
    );

    // If we have GHO in the contract, we just gonna transfer that to the address, if not we gonna mint
    // Or we can transfer the GHO that's in the contract, and mint the rest of the amount
    function mintGHOForUSDC(uint256 amount, address to) external;

    function redeemUSDCForGHO(uint64 amount, address to) external;

    function sendGHOCrossChain(uint64 chainId, uint256 amount, address to) external returns (bytes32 messageId);

    /**
     * @notice Returns the address of the GHO token contract
     * @return The address of the GhoToken
     */
    function GHO_TOKEN() external view returns (IGhoToken);

    /**
     * @notice Returns the maximum value the fee can be set to
     * @return The maximum percentage fee of the minted amount that the fee can be set to (in bps).
     */
    function MAX_FEE() external view returns (uint256);

    /**
     * @notice Updates the percentage fee. It is the percentage of the minted amount that needs to be repaid.
     * @dev The fee is expressed in bps. A value of 100, results in 1.00%
     * @param newFee The new percentage fee (in bps)
     */
    function updateMintFee(uint256 newFee) external;

    /**
     * @notice Returns the percentage of each mint taken as a fee
     * @return The percentage fee of the minted amount that needs to be repaid, on top of the principal (in bps).
     */
    function getMintFee() external view returns (uint256);

    function updateTransferFee(uint256 newFee) external;

    function getTransferFee() external view returns (uint256);
}
