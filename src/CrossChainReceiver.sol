// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import {IRouterClient} from "@chainlink/contracts-ccip/src/v0.8/ccip/interfaces/IRouterClient.sol";
import {Client} from "@chainlink/contracts-ccip/src/v0.8/ccip/libraries/Client.sol";
import {CCIPReceiver} from "@chainlink/contracts-ccip/src/v0.8/ccip/applications/CCIPReceiver.sol";
import "./interfaces/ICrossChainReceiver.sol";
import "./CrossChainGHOTransfer.sol";
import "./gho/GhoToken.sol";

contract CrossChainReceiver is ICrossChainReceiver, CCIPReceiver, Ownable {
    IGhoToken public immutable GHO_TOKEN;

    uint64 public immutable sourceChainId;

    address public sourceChainSender;

    address public lastSender;

    mapping(bytes32 => CrossChainGHOTransfer) public processedTransfers;

    modifier onlySourceChain(uint64 _chainId) {
        require(sourceChainId == _chainId, "CrossChainReceiver: Source chain is not supported.");
        _;
    }

    modifier onlyAllowListedSender(address _sender) {
        require(sourceChainSender == _sender, "CrossChainReceiver: Sender is not allowed.");
        _;
    }

    // Sepolia chain selector: 16015286601757825753
    constructor(uint64 _sourceChainId, address _router, address _sourceChainSender)
        CCIPReceiver(_router)
        Ownable(msg.sender)
    {
        GHO_TOKEN = new GhoToken(address(this));
        GHO_TOKEN.grantRole(GHO_TOKEN.FACILITATOR_MANAGER_ROLE(), address(this));
        GHO_TOKEN.grantRole(GHO_TOKEN.BUCKET_MANAGER_ROLE(), address(this));
        GHO_TOKEN.addFacilitator(address(this), "CrossChainFacilitator", 0);
    
        sourceChainId = _sourceChainId;
        sourceChainSender = _sourceChainSender;
    }

    function sendGHOToSourceChain(uint256 amount, address to) external payable returns (bytes32 messageId) {
        // burn the amount of GHO token from the sender's address
        GHO_TOKEN.burn(amount);

        // create cross chain transfer
        CrossChainGHOTransfer memory _transfer = CrossChainGHOTransfer(amount, to, msg.sender);

        // build CCIP message
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(sourceChainSender, _transfer, address(0));

        // get the fee for the transfer
        IRouterClient router = IRouterClient(this.getRouter());
        uint256 fees = router.getFee(sourceChainId, evm2AnyMessage);
        require(fees <= msg.value, "CrossChainFacilitator: Not enough balance to cover fees.");

        // send CCIP message
        messageId = router.ccipSend{value: fees}(sourceChainId, evm2AnyMessage);

        // emit event
        emit MessageSent(messageId, sourceChainId, to, amount, address(0), fees);
    }

    function setSourceChainSender(address _sender) external onlyOwner {
        sourceChainSender = _sender;
    }

    function getRouterFee(uint256 amount, address to) public view returns (uint256) {
        CrossChainGHOTransfer memory _transfer = CrossChainGHOTransfer(amount, to, msg.sender);
        Client.EVM2AnyMessage memory evm2AnyMessage = _buildCCIPMessage(sourceChainSender, _transfer, address(0));
        IRouterClient router = IRouterClient(this.getRouter());
        uint256 fees = router.getFee(sourceChainId, evm2AnyMessage);
        return fees;
    }

    function _ccipReceive(Client.Any2EVMMessage memory any2EvmMessage)
        internal
        override
        onlySourceChain(any2EvmMessage.sourceChainSelector)
        onlyAllowListedSender(bytesToAddress(any2EvmMessage.sender))
    {
        lastSender = bytesToAddress(any2EvmMessage.sender);
        // decode the bytes message into CrossChainGHOTransfer
        CrossChainGHOTransfer memory _transfer = decodeCCTransfer(any2EvmMessage.data);

        // set max bucket cap to amount
        (uint256 currentBucketCapacity, ) = GHO_TOKEN.getFacilitatorBucket(address(this));
        GHO_TOKEN.setFacilitatorBucketCapacity(address(this), uint128(currentBucketCapacity + _transfer.amount));

        // mint amount of GHO to the to address
        GHO_TOKEN.mint(_transfer.receiver, _transfer.amount);

        // emit event
        emit MessageReceived(
            any2EvmMessage.messageId,
            any2EvmMessage.sourceChainSelector,
            _transfer.receiver,
            _transfer.sender,
            _transfer.amount
        );
        // record processed transfer
       processedTransfers[any2EvmMessage.messageId] = _transfer; 
    }

    function bytesToAddress(bytes memory data) public pure returns (address) {
        require(data.length >= 20, "Data length must be at least 20 bytes");

        address result;
        assembly {
            result := mload(add(data, 20)) // Load the first 20 bytes of data into the result
        }
        return result;
    }

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

    receive() external payable {}
}
