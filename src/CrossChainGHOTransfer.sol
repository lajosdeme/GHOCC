// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

struct CrossChainGHOTransfer {
    uint256 amount;
    address receiver;
    address sender;
}

function encodeCCTransfer(CrossChainGHOTransfer memory _transfer) pure returns (bytes memory) {
    return abi.encode(_transfer);
}

function decodeCCTransfer(bytes memory _transferBytes) pure returns (CrossChainGHOTransfer memory) {
    return abi.decode(_transferBytes, (CrossChainGHOTransfer));
}
