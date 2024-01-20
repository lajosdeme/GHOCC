// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ICrossChainReceiver {
    event MessageReceived(
        bytes32 indexed messageId, 
        uint64 indexed sourceChainSelector, 
        address receiver, 
        address sender, 
        uint256 amount
    );

    event MessageSent(
        bytes32 indexed messageId,
        uint64 indexed destinationChainSelector,
        address recevier,
        uint256 amount,
        address feeToken,
        uint256 fees
    );

    function sendGHOToSourceChain(uint256 amount, address to) external payable returns (bytes32 messageId);

    function setSourceChainSender(address _sender) external;
}
