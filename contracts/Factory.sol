//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "hardhat/console.sol";

import "./Exchange.sol";

contract Factory {
    // 페어의 주소를 저장하는 매핑 
    mapping ( address => address) tokenToExchange;
    event NewExchange(address indexed token, address indexed exchange);
    /* 
        파라메터 _token은 Token.sol을 처음에 발행하여 생긴 컨트랙트 주소 
    */
    function createExchange(address _token) public returns (address) {
        require(address(_token) != address(0));
        require(tokenToExchange[_token] == address(0)); // 유효성 검증인데 2번째 라인 은 중요 이래야 중복해서 안되니까 페어생성이 
        Exchange exchange = new Exchange(_token); //여기선 맨처음 Token.sol에서 배포를 시킨 것과의 페어 그것을 주소로 하는 Exchange 코인을 발행하는 것 
        tokenToExchange[_token] = address(exchange);// 그러니 Token.sol(발행코인) - Exchange.sol(Token.sol을 배포한 그 컨트랙트 주소) 이렇게 2개가 쌍으로 이루어지는 것
        emit NewExchange(_token, address(exchange));

        return (address(exchange));
    }
    // 해당하는 주소의 pair의 주소를 리턴해준다.
    function getExchange(address _token) public returns (address) {
        return tokenToExchange[_token];
    }
}