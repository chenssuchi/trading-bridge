// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAnchor {
    function consumer() external view returns (address);

    function committee() external view returns (address);

    function messenger() external view returns (address);

    function totalRemotePaths() external view returns (uint256);

    function isPathEnabled(uint32 remoteChainId) external view returns (bool);

    function fetchRemoteAnchor(uint32 remoteChainId) external view returns (bytes32);

    function sendToMessenger(
        address payable refundAddress,
        bytes32 crossType,
        bytes memory extraFeed,
        uint32 dstChainId,
        bytes calldata payload
    ) external payable returns (bytes32 txUniqueIdentification);
}
