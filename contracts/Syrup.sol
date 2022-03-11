//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./DEXToken.sol";

contract Syrup is ERC20("SyrupBar", "SYRUP") {
    using SafeMath for uint256;

    function mint(address _to, uint256 _amount) public {
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) public {
        _burn(_from, _amount);
    }

    DEXToken public DEX;

    constructor(address _DEX) {
        DEX = DEXToken(_DEX);
    }

    // Safe DEX transfer function, just in case if rounding error causes pool to not have enough DEXs.
    function safeDEXTransfer(address _to, uint256 _amount) public {
        uint256 DEXBal = DEX.balanceOf(address(this));
        if (_amount > DEXBal) {
            DEX.transfer(_to, DEXBal);
        } else {
            DEX.transfer(_to, _amount);
        }
    }
}
