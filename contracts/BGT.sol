// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract BGT is ERC20("BG Trade", "BGT"), Ownable {

    mapping(address => bool) private _minters;
    mapping(address => bool) private _prohibitFrom;
    mapping(address => bool) private _prohibitTo;

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
    }
 
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function setMinter(address account, bool isMinter_) external onlyOwner {
        _minters[account] = isMinter_;
        if (isMinter_ == false)
        {
            delete _minters[account];
        }
    }

    function isMinter(address account) public view returns(bool) {
        return _minters[account];
    }

    modifier onlyMinter(){
        require(_minters[_msgSender()] == true, "Ownable: caller is not the minter");
        _;
    }

    function addProhibitFrom(address account) public onlyMinter
    {
        _prohibitFrom[account] = true;
    }

    function removeProhibitFrom(address account) public onlyMinter
    {
        delete _prohibitFrom[account];
    }

    function inProhibitFrom(address account) public view returns (bool)
    {
        return _prohibitFrom[account];
    }

    function addProhibitTo(address account) public onlyMinter
    {
        _prohibitTo[account] = true;
    }

    function removeProhibitTo(address account) public onlyMinter
    {
        delete _prohibitTo[account];
    }

    function inProhibitTo(address account) public view returns (bool)
    {
        return _prohibitTo[account];
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal view override {
        require(this.inProhibitFrom(from) == false, "ERC20: no transfer out");
        require(this.inProhibitTo(to) == false, "ERC20: no transfer in");
        amount;
    }
}