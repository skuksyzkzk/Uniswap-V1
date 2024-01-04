//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// 토큰
contract Token is ERC20 {
    /*
        생성자 : 이름 ,심볼 ,생성량을 파라메타로 받아서 토큰을 생성하고 발행함 msg.sender에게 

     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }
}