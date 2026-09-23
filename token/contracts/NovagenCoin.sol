// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/// @title Novagen Coin (NVG)
/// @notice Sabit arzlı ERC-20 token. Tüm arz deploy anında `recipient` adresine basılır;
///         sonradan yeni token basılamaz. Sahipler kendi tokenlarını yakabilir (burn).
contract NovagenCoin is ERC20, ERC20Burnable {
    constructor(address recipient, uint256 initialSupply)
        ERC20("Novagen Coin", "NVG")
    {
        _mint(recipient, initialSupply * 10 ** decimals());
    }
}
