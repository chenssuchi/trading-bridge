// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {BoolConsumerBase} from "./bool/BoolConsumerBase.sol";
import {IAnchor} from "./bool/interfaces/IAnchor.sol";
import {IMessengerFee} from "./bool/interfaces/IMessengerFee.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interface/IERC20.sol";
import "./BGT.sol";

contract BridgeArbitrumNativeCoin is BoolConsumerBase, Ownable {
    address public bgtToken;
    uint256 private _localNonce;
    address private _poolAddress;
    /** Events */
    event BridgeOut(uint32 dstChainId, uint256 amount);
    event BridgeIn(uint32 srcChainId, uint256 amount);
    event BridgeCall(
        address sender,
        address recipient,
        uint256 amount,
        uint256 nonce,
        uint256 sourceChainId,
        uint256 dstChainId
    );
    event BridgeExecute(
        address sender,
        address recipient,
        uint256 amount,
        uint256 nonce,
        uint256 sourceChainId,
        uint256 dstChainId
    );

    constructor(address anchor_) BoolConsumerBase(anchor_) {}

    function adminSetBgtToken(address bgtToken_) public onlyOwner {
        bgtToken = bgtToken_;
    }

    function adminSetPool(address poolAddress_) public onlyOwner {
        _poolAddress = poolAddress_;
    }

    /** Calculate Cross-chain Fee (Optional) */
    // As the source chain
    function bridgeOut(
        uint32 dstChainId,
        uint256 amount,
        address dstRecipient
    ) external payable {
        uint256 costCrossChain = 10000000000000000;
        uint256 callValue = msg.value;
        address sender = msg.sender;

        require(
            callValue >= amount + costCrossChain,
            "The cross chain cost is approximately 1000000 Gwei, value=cost+amount"
        );

        /** Construct payload to be consumed on the destination chain */
        bytes memory payload = _encodePayload(
            sender,
            dstRecipient,
            amount,
            _localNonce,
            block.chainid
        );

        /** Send to the binding Anchor */
        _sendAnchor(
            costCrossChain,
            payable(sender),
            PURE_MESSAGE,
            bytes(""),
            dstChainId,
            payload
        );
        /** Emit event */
        emit BridgeCall(
            sender,
            dstRecipient,
            amount,
            _localNonce,
            block.chainid,
            dstChainId
        );

        _localNonce++;
    }

    // As the destination chain
    function receiveFromAnchor(
        bytes32 txUniqueIdentification,
        bytes memory payload
    ) external override onlyAnchor {
        uint32 srcChainId;
        bytes memory crossId = abi.encode(txUniqueIdentification);

        (
            address sender,
            address recipient,
            uint256 amount,
            uint256 nonce,
            uint256 sourceChainId
        ) = _decodePayload(payload);

        // solhint-disable-next-line no-inline-assembly
        assembly {
            srcChainId := mload(add(crossId, 4))
        }

        /** Mint tokens on the destination chain */
        _bridgeIn(sender, recipient, amount, nonce, sourceChainId);

        /** Emit event */
        emit BridgeIn(srcChainId, amount);
    }

    /** Internal/Private Functions */
    function _bridgeOut(
        address sender,
        address dstRecipient,
        uint256 amount,
        uint256 dstChainId
    ) private {
        emit BridgeCall(
            sender,
            dstRecipient,
            amount,
            _localNonce,
            block.chainid,
            dstChainId
        );
    }

    function _bridgeIn(
        address sender,
        address recipient,
        uint256 amount,
        uint256 nonce,
        uint256 sourceChainId
    ) private {
        // Transfer ETH
        require(address(this).balance >= amount, "insufficient balance");
        require(recipient != address(0), "recipient can not be 0");
        Address.sendValue(payable(recipient), amount);
        emit BridgeExecute(
            sender,
            recipient,
            amount,
            nonce,
            sourceChainId,
            block.chainid
        );
    }

    function sendEther(address payable _to) public payable {
        // 检查合约余额是否充足，以及传入的 _to 地址是否有效
        require(address(this).balance >= msg.value && _to != address(0));
        // 将代币转账到指定地址
        _to.transfer(msg.value);
    }

    //  event BridgeExecute(address sender, address recipient, uint256 amount, uint256 nonce, uint256 sourceChainId, uint256 dstChainId);
    function _encodePayload(
        address sender,
        address recipient,
        uint256 amount,
        uint256 nonce,
        uint256 sourceChainId
    ) private pure returns (bytes memory payload) {
        payload = abi.encode(sender, recipient, amount, nonce, sourceChainId);
    }

    function _decodePayload(bytes memory payload)
        private
        pure
        returns (
            address sender,
            address recipient,
            uint256 amount,
            uint256 nonce,
            uint256 sourceChainId
        )
    {
        (sender, recipient, amount, nonce, sourceChainId) = abi.decode(
            payload,
            (address, address, uint256, uint256, uint256)
        );
    }

    /** View/Pure Functions */
    function calculateFee(
        address sender,
        address recipient,
        uint256 amount,
        uint256 nonce,
        uint32 dstChainId
    ) public view returns (uint256 fee) {
        address srcAnchor = _anchor;
        bytes memory payload = _encodePayload(
            sender,
            recipient,
            amount,
            nonce,
            block.chainid
        );
        fee = IMessengerFee(IAnchor(srcAnchor).messenger()).cptTotalFee(
            srcAnchor,
            dstChainId,
            uint32(payload.length),
            PURE_MESSAGE,
            bytes("")
        );
    }

    receive() external payable {}
}
