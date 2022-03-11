//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DEXToken is ERC20("DEX Token", "DEX") {
    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }
}
