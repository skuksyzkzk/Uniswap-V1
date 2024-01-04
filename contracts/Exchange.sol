//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.9;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import '../interfaces/IExchange.sol';
import '../interfaces/IFactory.sol';
contract Exchange is ERC20 { // ERC 20을 상속받음으로서 ERC20토큰으로서 기능 수행 
    IERC20 token;
    IFactory factory;
    // fair가 될 토큰 
    constructor (address _token) ERC20("Kim LP token","KSY-LP"){
        token = IERC20(_token);// 여기서 ERC 20의 함수 사용 이런거 위해서 IERC20을 인터페이스로 해서 초기화한것 
        factory = IFactory(msg.sender);
    }
    // transfer 대신 transferFrom 쓰는 이유가 내 토큰이 주체로 옮겨가는게 아니라 이걸 교환하고 싶은 exchanger가 호출하는거니까 payable이여야되고
    function addLiquidity(uint256 _maxToken) public payable {
        uint256 totalLiquidity = totalSupply();
        if(totalLiquidity >0){
            //기존의 유동성이 있을경우
            uint256 ethReserve = address(this).balance - msg.value;
            uint256 tokenReserve = token.balanceOf(address(this));
            uint256 _tokenAmount = msg.value * tokenReserve /ethReserve ;// 기존 비율 기존 비율만큼 그림에서처럼 2대1 이였으니 gray토큰 추가되는양 
            require(_maxToken >= _tokenAmount);
            token.transferFrom(msg.sender, address(this), _tokenAmount);//msg.sender(공급한사람 : 나),this(교환 요청한사람)
            uint256 liquidityMinted = totalLiquidity * msg.value/ethReserve ; 
            _mint(msg.sender,liquidityMinted); 
        }
        else {
            uint256 _tokenAmount = _maxToken;// 이동성이 0 이기때문에 계산할 필요없이 가면된다.
            uint256 initialLiquidity = address(this).balance;// uniswap v1에서는 LP토큰은 eth로 계산되어 진다 
            _mint(msg.sender,initialLiquidity); // 유동성 풀 제공자한테 lp토큰 부여 
            token.transferFrom(msg.sender, address(this), _tokenAmount);//msg.sender(공급한사람 : 나),this(교환 요청한사람)
        }
        
    }
    // 이함수로 유동성 제거 내가 만약에 200개 만큼 lp토큰 반납하면 그 비율에 따른 eth와 token을 반납받아야 되는 것이다.a
    function removeLiquidity(uint256 _lpTokenAmount) public {
        uint256 totalLiquidity = totalSupply();
        uint256 ethAmount = _lpTokenAmount * address(this).balance / totalLiquidity;
        uint256 tokenAmount  = _lpTokenAmount * token.balanceOf(address(this)) / totalLiquidity;

        _burn(msg.sender,_lpTokenAmount);// burn 을 먼저하는게 재진입을 막는 등 보안상 훨씬 좋다

        payable(msg.sender).transfer(ethAmount);
        token.transfer(msg.sender,tokenAmount);
    }
    // ETH -> ERC20 /// mintoken은 적어도 보장을 받아야 한다는 것 보장을 못받으면 에러 나야된다 
    function ethToTokenSwap(uint256 _minToken) public payable {
        ethToToken(_minToken, msg.sender);
    } 
    function ethToTokenTransfer(uint256 _minToken,address _recipient)public payable{
        ethToToken(_minToken, _recipient);
    }
    function ethToToken(uint256 _minToken,address _recipient) public payable{
        uint256 inputAmount = msg.value;
        // calculate amount out (zero fee) 
        // 여기서 outputAmount 구할때 토큰으로 교환하는 거니까 msg.value =이더량 /함수가 payable이기에 inputReserve는 value값이 이미 지불된 상태라 빼줘야된다.
        uint256 outputAmount =  getOutputAmountWithFee(msg.value,address(this).balance - msg.value,token.balanceOf(address(this)));
        //transfer token out

        require(outputAmount >= _minToken ,"Insufficient outputAmount");
        IERC20(token).transfer(_recipient, outputAmount);//스왑을 하는 나에게 아웃풋만큼 전송 
    }
    function tokenToEthSwap(uint256 _tokenSold,uint256 _minEth) public payable {
        uint256 outputAmount = getOutputAmountWithFee(_tokenSold, token.balanceOf(address(this)), address(this).balance);

        require(outputAmount >= _minEth,'not acecss');
        IERC20(token).transferFrom(msg.sender,address(this),_tokenSold); // 토큰이기때문에 msg.value로 안되고 이렇게 유동성 풀 공급할때 처럼 해야된다
        payable(msg.sender).transfer(outputAmount);// 센더는 받아야됨 이더만큼 
    }
    //mintokenbought 내가 최종적으로 스왑했을때 얻게되는 erc20의 값 
    //minethbought는 내가 스왑하게될 계산한 이더에서 에러 낼때 
    function tokenToTokenSwap(uint256 _tokenSold,uint256 _minTokenBought,uint256 _minEthBought,address _tokenAddress) public payable {
        address toTokenExchangeAddr = factory.getExchange(_tokenAddress);
        uint256 ethoutputAmount = getOutputAmountWithFee(_tokenSold, token.balanceOf(address(this)), address(this).balance);

        require(ethoutputAmount >= _minEthBought,'not acecss');
        IERC20(token).transferFrom(msg.sender,address(this),_tokenSold); // 토큰이기때문에 msg.value로 안되고 이렇게 유동성 풀 공급할때 처럼 해야된다
        // 새로운 인터페이스를 정의하고 호출해서 거기서 스왑함수를 호출해야된다 
        IExchange(toTokenExchangeAddr).ethToTokenTransfer{value: ethoutputAmount}(_minTokenBought,msg.sender);//즉 이게 eth/fast 이거 호출해서 바꾸는거지 
        //payable(msg.sender).transfer(outputAmount);// 센더는 받아야됨 이더만큼//이거는 팩토리 하기전단계 
    }

    function getPrice(uint256 inputReserve, uint256 outputReserve) public pure returns (uint256) {
        uint256 numerator = inputReserve;
        uint256 denominator = outputReserve;
        return numerator / denominator;
    }
    function getOutputAmount(uint256 inputAmount,uint256 inputReserve,uint256 outputReserve) public pure returns (uint256){
        uint256 numerator = outputReserve * inputAmount; // 분자 y * 델타 x
        uint256 denominator = inputReserve + inputAmount;//분모 x+ 델타 x
        return numerator / denominator;
    }
    function getOutputAmountWithFee(uint256 inputAmount,uint256 inputReserve,uint256 outputReserve) public pure returns (uint256){
        uint256 inputAmountWithFee = inputAmount * 99 ;//이게 1프로 수수료 땐다는 그런의미 왜냐면 uint256 이기도 하고 솔리디티에는 소수가 없다 
        uint256 numerator = outputReserve * inputAmountWithFee; // 분자 y * 델타 x
        uint256 denominator = inputReserve* 100 + inputAmountWithFee;//분모 x+ 델타 x
        return numerator / denominator;
    }

}

