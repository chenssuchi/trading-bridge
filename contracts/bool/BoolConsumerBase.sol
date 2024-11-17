// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import {ERC165, IERC165} from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import {IBoolConsumerBase} from "./interfaces/IBoolConsumerBase.sol";
import {IAnchor} from "./interfaces/IAnchor.sol";

abstract contract BoolConsumerBase is ERC165, IBoolConsumerBase {
    error NOT_ANCHOR(address wrongAnchor);

    bytes32 public constant PURE_MESSAGE = keccak256("PURE_MESSAGE");
    bytes32 public constant VALUE_MESSAGE = keccak256("VALUE_MESSAGE");

    address internal _anchor;

    constructor(address anchor_) {
        _anchor = anchor_;
    }

    modifier onlyAnchor() {
        _checkAnchor(msg.sender);
        _;
    }

    function receiveFromAnchor(
        bytes32 txUniqueIdentification,
        bytes memory payload
    ) external virtual override onlyAnchor {}

    function _checkAnchor(address targetAnchor) internal view {
        if (targetAnchor != _anchor) revert NOT_ANCHOR(targetAnchor);
    }

    function _sendAnchor(
        uint256 callValue,
        address payable refundAddress,
        bytes32 crossType,
        bytes memory extraFeed,
        uint32 dstChainId,
        bytes memory payload
    ) internal virtual returns (bytes32 txUniqueIdentification) {
        txUniqueIdentification = IAnchor(_anchor).sendToMessenger{value: callValue}(
            refundAddress,
            crossType,
            extraFeed,
            dstChainId,
            payload
        );
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(ERC165, IERC165) returns (bool) {
        return
            interfaceId == type(IBoolConsumerBase).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function anchor() external view override returns (address) {
        return _anchor;
    }
}
