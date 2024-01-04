//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "hardhat/console.sol";

import "./Exchange.sol";

contract Factory {
    // 페어의 주소를 저장하는 매핑 
    mapping ( address => address) tokenToExchange;
    event NewExchange(address indexed token, address indexed exchange);

    function createExchange(address _token) public returns (address) {
        require(address(_token) != address(0));
        require(tokenToExchange[_token] == address(0)); // 유효성 검증인데 2번째 라인 은 중요 이래야 중복해서 안되니까 페어생성이 
        Exchange exchange = new Exchange(_token); // 
        tokenToExchange[_token] = address(exchange);
        emit NewExchange(_token, address(exchange));

        return (address(exchange));
    }
    // 해당하는 주소의 pair의 주소를 리턴해준다.
    function getExchange(address _token) public returns (address) {
        return tokenToExchange[_token];
    }
}