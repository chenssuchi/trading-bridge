// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {BoolConsumerBase} from "./bool/BoolConsumerBase.sol";
import {IAnchor} from "./bool/interfaces/IAnchor.sol";
import {IMessengerFee} from "./bool/interfaces/IMessengerFee.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interface/IERC20.sol";
import "./BGT.sol";

contract BridgePolygon is BoolConsumerBase, Ownable {
    address public ethToken;
    uint256 private _localNonce;
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

    function adminSetEthToken(address ethToken_) public onlyOwner {
        ethToken = ethToken_;
    }

    /** Calculate Cross-chain Fee (Optional) */
    // As the source chain
    function bridgeOut(
        uint32 dstChainId,
        uint256 amount,
        address dstRecipient
    ) external payable {
        uint256 callValue = msg.value;
        address sender = msg.sender;

        /** Burn tokens on the source chain*/
        _bridgeOut(sender, dstRecipient, amount, dstChainId);

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
            callValue,
            payable(sender),
            PURE_MESSAGE,
            bytes(""),
            dstChainId,
            payload
        );

        _localNonce++;
        /** Emit event */
        emit BridgeOut(dstChainId, amount);
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
        // lock
        IERC20 bgt = IERC20(ethToken);
        bgt.transferFrom(sender, address(this), amount);
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
        // transfer
        IERC20 bgt = IERC20(ethToken);
        bgt.transfer(recipient, amount);

        emit BridgeExecute(
            sender,
            recipient,
            amount,
            nonce,
            sourceChainId,
            block.chainid
        );
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
