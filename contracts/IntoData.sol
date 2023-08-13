// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./AdminRoleUpgrade.sol";
import "./librarys/IntoUintTool.sol";


interface IIntoFeeLevel {
    function setFeeLevel(address _addr) external view returns (uint256);
}

interface IIntoERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function burn(uint256 amount) external;

    function decimals() external view returns (uint8);

    function burnFrom(address account, uint256 amount) external;
}

interface IActionPoint {
    

    function favoriteValueMap(address _addr) external view returns (uint256);

    function getPoint(address _addr)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        );

    function setTradingFavorite(
        address _addr,
        uint256 _value,
        bool isInto
    ) external;

    function getRatioFavorite(uint256 _value, bool isInto)
        external
        view
        returns (uint256);

    function updateFavoriteValue(
        address _addr,
        uint256 _value,
        bool _isAdd
    ) external;
}

interface IIntoDividend {
    function addDividendToken(uint256 _token) external;

    // function dividendToken(uint256 todayTimestamp) external;
}



interface IIntoRelation {
    function getInvList(address addr_)
        external
        view
        returns (address[] memory _addrsList);

    function invListLength(address addr_) external view returns (uint256);

    function Inviter(address _addr) external view returns (address);
}

interface IIntoVip {
    function updateVip(address _addr) external;

    function isUpdateVip(address _addr) external view returns (bool);
}

interface IIntoRecord{
    function setAboutRecord(address _addr,string memory _stype, string memory _source, address _user, uint256 _token, bool _isAdd, bool _isValid, string memory _remark) external;
     function setBatchRecord(address[] memory _addrs,string memory _stype, string memory _source, uint256 _token) external;
}

interface IIntoAuth{
    function validUser(address _addr) external view returns(bool);
}

contract IntoData is AdminRoleUpgrade, Initializable {
    event Withdraw(address from, uint256 token);
    event Recharge(address from, uint256 token);

    using IntoUintTool for uint256;
    using SafeMathUpgradeable for uint256;
   
    // 拥有的余额
    mapping(address => uint256) public balances;

    // 手续费等级
    mapping(address => uint256) public ownerFeeLevelMap;

    IIntoERC20 IntoERC20;

    IActionPoint activePoint;

    IIntoDividend IntoDividend;
    IIntoFeeLevel IntoFeeLevel;
    
    IIntoRelation IntoRation;
    address IntoVipAddr;
    IIntoRecord IntoRecord;
    IIntoAuth IntoAuth;

    bool public pause;
    function initialize() public initializer {
        // initNFTData();
        _addAdmin(msg.sender);
    }

    modifier check(){
        require(!pause, "Do not operate");
        _;
    }

    function setPause(bool _pause) external onlyAdmin{
        pause = _pause;
    }

    function setAboutAddress(
        address _IntoERC20Addr,
        address _activePointAddr,
        address _IntoDividendAddr,
        address _IntoFeeLevelAddr,
        address _IntoRationAddr,
        
        address _IntoVipAddr,
        address _IntoRecordAddr,
        address _IntoAuthAddr
    ) external onlyAdmin {
        IntoERC20 = IIntoERC20(_IntoERC20Addr);
        activePoint = IActionPoint(_activePointAddr);
        IntoDividend = IIntoDividend(_IntoDividendAddr);
        IntoFeeLevel = IIntoFeeLevel(_IntoFeeLevelAddr);
        
        IntoRation = IIntoRelation(_IntoRationAddr);
        IntoVipAddr = _IntoVipAddr;
        IntoRecord = IIntoRecord(_IntoRecordAddr);
        IntoAuth = IIntoAuth(_IntoAuthAddr);
    }


    // 更新手续费等级
    function updateOwnerFeeLevel(address _addr) public {
        if (ownerFeeLevelMap[_addr] != IntoFeeLevel.setFeeLevel(_addr)) {
            ownerFeeLevelMap[_addr] = IntoFeeLevel.setFeeLevel(_addr);
        }
        // if (IIntoVip(IntoVipAddr).isUpdateVip(_addr)) {
        //     IIntoVip(IntoVipAddr).updateVip(_addr);
        // }
    }

    function updateBalances(
        address _addr,
        uint256 _amount,
        bool isAdd
    ) public onlyAdmin {
        if (isAdd) {
            balances[_addr] += _amount;
        } else {
            balances[_addr] -= _amount;
        }
    }

    function getPoint(address _addr)
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return activePoint.getPoint(_addr);
    }

    function getParent(address _addr) public view returns (address) {
        return IntoRation.Inviter(_addr);
    }

    function getMemberCount(address _addr) public view returns (uint256) {
        return IntoRation.invListLength(_addr);
    }

    function getChildMembers(address _addr)
        public
        view
        returns (address[] memory)
    {
        return IntoRation.getInvList(_addr);
    }

    // 往代币合约转账， 需要扣除手续费, 收藏值
    function transferWithERC20(uint256 _token) public check {
        // require(IntoAuth.validUser(msg.sender), "not required");
        require(msg.sender != address(0), "It cannot be a zero address");
        // 转出需要收一比一的收藏值，这里需要判断收藏值是否够用
        require(
            activePoint.getRatioFavorite(_token, false) >= _token,
            "Insufficient collection value"
        );

        // 更新用户的等级手续费
        // updateOwnerFeeLevel(msg.sender);
        uint256 transToken = getExchangeTotalToken(msg.sender,_token, true);
        require(balances[msg.sender] > transToken, "Not enough handling fees");
        balances[msg.sender] -= transToken;
        activePoint.setTradingFavorite(msg.sender, _token, false);
        
        IntoERC20.transfer(msg.sender, _token);
       
        IntoRecord.setAboutRecord(msg.sender, "token", "withdraw", msg.sender, transToken, false, true, "");
        IntoRecord.setAboutRecord(msg.sender, "favorite", "withdraw", msg.sender,  activePoint.getRatioFavorite(_token, false), false, true, "");
        IntoDividend.addDividendToken(transToken - _token);
        emit Withdraw(msg.sender, transToken);
    }


    // 充值
    function erc20TransferWithInto(uint256 _token) public check {
        require(msg.sender != address(0), "It cannot be a zero address");
        IntoERC20.transferFrom(msg.sender, address(this), _token);
        balances[msg.sender] += _token;
        activePoint.setTradingFavorite(msg.sender, _token, true);
        IntoRecord.setAboutRecord(msg.sender, "token", "recharge", msg.sender, _token, true, true, "");
        IntoRecord.setAboutRecord(msg.sender, "favorite", "recharge", msg.sender, activePoint.getRatioFavorite(_token, true), true, true, "");

        emit Recharge(msg.sender, _token);
    }

    // 手续费收益
    function IntoaddDividendToken(uint256 _token) public onlyAdmin {
        IntoDividend.addDividendToken(_token);
    }

    // isReturn 判断是转还是交易截止
    // true 退返
    // false 正常交易
    function transferTokenWithSell(
        address _from,
        address _to,
        uint256 _token, 
        uint256 _status
    ) external onlyAdmin {
        if(_status == 1){
            transferTokenWithAllDeposit(_from, _to, _token);
        }else if(_status == 2){
            transferTokenWithSellCreate(_from, _to, _token);
        }else if(_status == 3){
            transferTokenWithSellFail(_from, _to, _token);
        }else if(_status == 4){
            transferTokenWithSellSuccess(_from, _to, _token);
        }
        
    }

    function transferTokenWithAllDeposit(address _from, address _to, uint256 _token) internal {
        uint256 token = getExchangeTotalToken(_from,_token, true);
        uint256 fromBalance = balances[_from];
        require(fromBalance >= token, "transfer amount exceeds balance");
        
        require(
            activePoint.favoriteValueMap(_from) >=
                activePoint.getRatioFavorite(_token, false),
            "transfer favorite value exceeds balance"
        );
        // 转账
        _transfer(_from, _to, _token, token - _token);

        // 减少收藏值
        activePoint.setTradingFavorite(_from, _token, false);
        activePoint.setTradingFavorite(_to, _token, true);
        
        IntoDividend.addDividendToken(token - _token);

        IntoRecord.setAboutRecord(_from, "token", "sell", _from, token, false, true, "");
        IntoRecord.setAboutRecord(_from, "favorite", "sell", _from, _token, false, true, "");
        IntoRecord.setAboutRecord(_to, "token", "buy", _to, _token, true, true, "");
        IntoRecord.setAboutRecord(_to, "favorite", "buy", _to, activePoint.getRatioFavorite(_token, true), true, true, "");
    }

    function transferTokenWithSellCreate(address _from, address _to, uint256 _token) internal{
        uint256 token = getExchangeTotalToken(_from,_token, true);
        uint256 fromBalance = balances[_from];
        require(fromBalance >= token, "transfer amount exceeds balance");

        require(activePoint.favoriteValueMap(_from) >= activePoint.getRatioFavorite(_token, false), "transfer favorite value exceeds balance");
        // 转账
        _transfer(_from, _to, token, 0);
        activePoint.setTradingFavorite(_from, _token, false);
        IntoRecord.setAboutRecord(_from, "token", "sell", _from, token, false, true, "");
        IntoRecord.setAboutRecord(_from, "favorite", "sell", _from, _token, false, true, "");
    }


    function transferTokenWithSellFail(address _from, address _to, uint256 _token) internal {
        
        _transfer(_from, _to, balances[_from], 0);
        activePoint.updateFavoriteValue(_to, _token, true);
        IntoRecord.setAboutRecord(_to, "token", "sell", _from, _token, true, true, "");
        IntoRecord.setAboutRecord(_to, "favorite", "sell", _from, _token, true, true, "");
    }

    function transferTokenWithSellSuccess(address _from, address _to, uint256 _token) internal{
        
        uint256 dividentToken = balances[_from] - _token;
        _transfer(_from, _to, _token, dividentToken);

        
        IntoDividend.addDividendToken(dividentToken);
        activePoint.setTradingFavorite(_to, _token, true);
        IntoRecord.setAboutRecord(_to, "token", "buy", _to, _token, true, true, "");
        IntoRecord.setAboutRecord(_to, "favorite", "buy", _to, activePoint.getRatioFavorite(_token, true), true, true, "");
    }


    // 兑换需要的碎片
    function getExchangeTotalToken(address _addr,uint256 _token, bool _isTradable)
        internal
        view
        returns (uint256)
    {
        if (!_isTradable) {
            return _token;
        }

        return
            _token.add(_token.getFeeLevelToken(ownerFeeLevelMap[_addr]));
    }

    function _transfer(
        address from,
        address to,
        uint256 amount,
        uint256 _dividendToken
    ) internal  {
        require(from != address(0), "transfer from the zero address");
        require(to != address(0), "transfer to the zero address");

        uint256 fromBalance = balances[from];
        require(fromBalance >= amount, "transfer amount exceeds balance");
        balances[from] -= amount;
        balances[to] += amount;
        balances[from] -= _dividendToken;
    }

    // 批量更新余额， 目前用在利益分红
    function batchUpdateToken(address[] memory _addrs, uint256 _token)
        public
        onlyAdmin
    {
        for (uint256 i = 0; i < _addrs.length; i++) {
            balances[_addrs[i]] += _token;
        }
    }

    function batchGetBalances(address[] memory addrs) external view returns(uint256[] memory){
        uint256 addrLength = addrs.length;
        uint256[] memory ownerBalances = new uint256[](addrLength);
        
        for(uint256 i=0; i < addrLength; i++){
            address  addr = addrs[i];
            ownerBalances[i] = balances[addr];
        }

        return ownerBalances;
    } 

    
   
}
