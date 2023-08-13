// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
// import "./ExchangeNFT.sol";
import "./librarys/IntoUintTool.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./AdminRoleUpgrade.sol";
import "./IIntoInterface.sol";




interface IIntoRelation {
    function getInvList(address addr_)
        external view
        returns(address[] memory _addrsList);
        
    function invListLength(address addr_) external view returns(uint256);

    function Inviter(address _addr) external view returns(address);
}



contract IntoPool1 is AdminRoleUpgrade, Initializable {
    event StackStake(address addr);
    using SafeMathUpgradeable for uint256;
    using IntoUintTool for uint256;

    
    // 3.5小时
    uint256 public stakeTime ;

    // 是否在挖矿
    mapping(address => bool) public isMining;
    // 挖矿的开始时间
    mapping(address => uint256) public stakeStartTime;

    struct StakeDetail{
        // 是否可交易
        bool isTradable;
        // 预估奖励
        uint256 expectToken;
        // 挖矿时间
        uint256 day;
        // 生效时间 
        uint256 startTime;
        // 结束时间
        uint256 endTime;
        // 盲盒名称
        string name;

        //已经奖励的token
        uint256 rewardToken;

        // 是否已经过期
        bool expire;
        // 活跃度
        uint256 activePoint;
        
        // 是否赠送的
        bool isSend;
    }

    // 挖矿映射
    mapping(address => StakeDetail[]) public boxStakeMap;

    IIntoData IntoData;
    IIntoRecord IntoRecord;
    IIntoRelation IntoRation;
    IActionPoint activePoint;
    IIntoAuth IntoAuth;
    IIntoDividend IntoDividend;
    // 是否是有效用户，内部使用，判断是否需要更新活跃点
    mapping(address => bool) public isValidUser;
    // 矿机主的地址集合
    address[] public mintOwner;
    // 是否是矿机主
    mapping(address => bool) public isMinter;
    // 是否更新过活跃点,目前的冗余字段
    mapping(address => mapping(uint256 => bool)) public isUpdateAP;

    struct MigrateStake{
        address addr;
        StakeDetail detail;
    }

    bool public pause;
    function initialize() public initializer {
        stakeTime = 3*3600 + 1800;
        _addAdmin(msg.sender);
    }



    modifier check(){
        require(!pause, "Do not operate");
        _;
    }

    function setPause(bool _pause) external onlyAdmin{
        pause = _pause;
    }


    function setAboutAddress(address _IntoDataAddr, address _IntoRecordAddr, address _IntoRationAddr, address _activePointAddr, address _IntoAuthAddr, address _IntoDividendAddr) external onlyAdmin{
        IntoData = IIntoData(_IntoDataAddr);
        IntoRecord = IIntoRecord(_IntoRecordAddr);
        IntoRation = IIntoRelation(_IntoRationAddr);
        activePoint = IActionPoint(_activePointAddr);
        IntoAuth = IIntoAuth(_IntoAuthAddr);
        IntoDividend = IIntoDividend(_IntoDividendAddr);
    }

    // 挖矿时间
    function updateStakeTime(uint256 _stakeTime) external onlyAdmin {
        stakeTime = _stakeTime;
    }  

    // 一键挖矿
    function stackStake() external check {
        
        require(!isMining[msg.sender], "is mining");
        // 不能为零地址
        require(msg.sender != address(0), "it is a zero address");
        // 判断今天是否已经挖过
        require(stakeStartTime[msg.sender] < block.timestamp.getTodayTimestamp(), "Mined today");
        require(getMiningBoxCount(msg.sender) > 0, "No mining machine");
        
        uint256 time = block.timestamp;

        stakeStartTime[msg.sender] = time;
        isMining[msg.sender] = true;

        // // 判断是否为有效用户，如果是则给上级收藏值
        // activePoint.updateParentFavoriteValueWithValid(msg.sender);
        // // 更新自身手续费等级和VIP
        // IntoData.updateOwnerFeeLevel(msg.sender);
        // // 利益分红
        // IntoDividend.receiveDividends(msg.sender);

        // // 当用户有效和无效之间有变动时更新
        // if(IntoAuth.validUser(msg.sender) != isValidUser[msg.sender]){
        //     isValidUser[msg.sender] = IntoAuth.validUser(msg.sender);
        //     activePoint.updateParentActivePointWithValid(msg.sender);
        // }

        emit StackStake(msg.sender);
    }
    // 获取开始挖矿时间和当天时间
     function timeJudge(address _addr) public view returns(uint256, uint256, bool){
        return (stakeStartTime[_addr], block.timestamp.getTodayTimestamp(), stakeStartTime[_addr] < block.timestamp.getTodayTimestamp());
    }


    // 领取收益
    function stakeReceive() external check {
        require(isMining[msg.sender], "already receive");
        
        StakeDetail[] storage records = boxStakeMap[msg.sender];
       
        // 当前时间加1天
        uint256 nextDayTimestamp = block.timestamp.getNextDayTimestamp();
        uint256 mystakeStartTime = stakeStartTime[msg.sender].getTodayTimestamp();
        uint256 expirePoint = 0;
        uint256 ownerbalances = 0;
        uint256 oldExpirePoint = 0;
        uint256 len = records.length;
        for(uint i=0; i< len; i++){
            StakeDetail storage record = records[i];
            
            // 盲盒未过期 && 当前的时间要大于盲盒生效时间
            if(!record.expire &&  mystakeStartTime >= record.startTime){
                
                // 思路：先求出正常应该获取的token，然后乘以(已经挖矿时间-开始时间)/应挖时间的百分比，获取应得到的token.
                uint256 rewardToken = getExpectToken(msg.sender,record.expectToken, record.day);
                
                
                // if(record.expectToken - 5*10**17 > record.rewardToken ){
                    // record.rewardToken += rewardToken;
                    // ownerbalances += rewardToken;
                // }
                
                if(record.rewardToken + rewardToken > record.expectToken){
                     (,uint256 rt) = record.expectToken.trySub(record.rewardToken);
                    record.rewardToken += rt;
                    ownerbalances += rt;
                }else{
                    record.rewardToken += rewardToken;
                    ownerbalances += rewardToken;
                }

                // 因为record的结束时间小于新的一天，所以判断他已经挖完，就将它设置过期
                if(record.endTime < nextDayTimestamp){
                    record.expire = true;
                    // 12月30号之前的减60代
                    if(record.startTime < 1672329600){
                        oldExpirePoint += record.activePoint;
                    }else{
                            
                        if(checkBool(record.name, "F")){
                            activePoint.updateFavoriteAndPoint(msg.sender, 0,0, record.activePoint, false, 10);
                        }else{
                            expirePoint += record.activePoint;
                        }
                    }
                    
                    
                }
            }
        }



        if(expirePoint > 0 || oldExpirePoint > 0){
            // 同步数据
            activePoint.initSetWithFirst(msg.sender);
            if(expirePoint > 0){
                activePoint.updateFavoriteAndPoint(msg.sender, 0,0, expirePoint, false, 30);
            }
            if(oldExpirePoint > 0){
                activePoint.updateFavoriteAndPoint(msg.sender, 0,0, oldExpirePoint, false, 60);
            }
            
            IntoData.updateOwnerFeeLevel(msg.sender);
        }

        if(ownerbalances > 0){
            updateOwnerBalances(msg.sender, ownerbalances, "");
            updateParentBalances(msg.sender, ownerbalances, "");
        }

        isMining[msg.sender] = false;
    }

    function updateParentBalances(address _addr, uint256 _token, string memory _boxType) internal {
        if(IntoAuth.validUser(_addr)){
            (uint256 value1, uint256 value2) = updateSuperFavorite(_token);
            address parent = getParent(msg.sender);
            address grandParent = getParent(getParent(msg.sender));
         
            IntoData.updateBalances(parent, value1, true);
            IntoData.updateBalances(grandParent, value2, true);
            IntoRecord.setAboutRecord(parent, "token", "first", _addr, value1, true, true, _boxType);
            IntoRecord.setAboutRecord(grandParent, "token", "second", _addr, value2, true, true, _boxType);
         }
        //  else{
        //     IntoRecord.setAboutRecord(parent, "token", "first", _addr, value1, true, false, _boxType);
        //     IntoRecord.setAboutRecord(grandParent, "token", "second", _addr, value2, true, false, _boxType);
        //  }
               
    }

    // 获取预计收益
    function getTodayExpectToken() external view returns(uint256) {
       return getAboutTodayExpectToken(msg.sender);
    }


    function getAboutTodayExpectToken(address _addr) public view returns(uint256){
        StakeDetail[] memory records = boxStakeMap[_addr];
        // bool isNormal = getStakeEndWithNormal();
        // uint256 nextDayTimestamp = block.timestamp.getNextDayTimestamp();
        uint256 startTime=block.timestamp;
        if(stakeStartTime[_addr] > 0 ){
            startTime = stakeStartTime[_addr];
        }
        uint256 mystakeStartTime = startTime.getTodayTimestamp();
        uint256 totalrewardToken = 0;
        for(uint i=0; i< records.length; i++){
            StakeDetail memory record = records[i];
            
            // 盲盒未过期 && 当前的时间要大于盲盒生效时间
            if(!record.expire &&  mystakeStartTime >= record.startTime){
                
                // 思路：先求出正常应该获取的token，然后乘以(已经挖矿时间-开始时间)/应挖时间的百分比，获取应得到的token.
                uint256 rewardToken = getExpectToken(_addr,record.expectToken, record.day);
                totalrewardToken += rewardToken;
            }
        }

        return totalrewardToken;
    }

    function updateOwnerBalances(address _addr, uint256 _token, string memory _boxType) internal {
        
        IntoData.updateBalances(_addr, _token, true);
        IntoRecord.setAboutRecord(_addr, "token", "stake", _addr, _token, true, true, _boxType);
       
    }
    

    function updateSuperFavorite(uint256 _value) internal pure returns(uint256, uint256){
        return (_value.mul(3).div(100), _value.mul(2).div(100));
    }

    // 获取预计收益
    function getExpectToken(address _addr,uint256 _token, uint256 _day) public view returns(uint256){
        uint256 rewardToken = _token.div(_day);

        uint256 startTime=block.timestamp;
        if(stakeStartTime[_addr] > 0 ){
            startTime = stakeStartTime[_addr];
        }
        // uint256 mystakeStartTime = startTime.getTodayTimestamp();
        // 判断新一天零点的时间是否大于当前时间，如果大于，说明领取的时候还是当天时间，那么返回当天时间，如果小于，则说明是第二天领取的，那么返回新一天零点时间
        uint256 endtime = startTime.getNextDayTimestamp() > block.timestamp? block.timestamp: startTime.getNextDayTimestamp();

        uint256 needtime = endtime - stakeStartTime[msg.sender];
        needtime = stakeTime > needtime? needtime:stakeTime;
        rewardToken = rewardToken.mul(needtime).div(stakeTime);
        return rewardToken;
    }


    // 是否正常挖矿结束，当天是否可以挖完
    function getStakeEndWithNormal() internal view returns(bool){
        return (stakeStartTime[msg.sender] + stakeTime) < stakeStartTime[msg.sender].getNextDayTimestamp();
    }

    function getBoxStake(address _addr) external view returns(StakeDetail[] memory){
        return boxStakeMap[_addr];
    }

    // 获取质押的盲盒数量
    function nftCountFromStake(address _addr,string memory _boxType) public view returns(uint256){
        StakeDetail[] memory records = boxStakeMap[_addr];
        uint count = 0;
        for(uint i=0; i< records.length; i++){
            StakeDetail memory record = records[i];
            if(!record.expire && record.endTime > block.timestamp.getNextDayTimestamp() && !record.isSend){
                 if(keccak256(abi.encodePacked(record.name)) == keccak256(abi.encodePacked(_boxType))){
                    count++;
                }
            }
            
        }

        return count;
    }


    function getParent(address _addr) public view returns(address){
        return IntoRation.Inviter(_addr);
    }

    function getMemberCount(address _addr) public view returns(uint256){
        return IntoRation.invListLength(_addr);
    }

    function getChildMembers(address _addr) public view returns(address[] memory){
        return IntoRation.getInvList(_addr);
    }

    
    

    function addStake(address _addr, bool _isSend, bool _isTradable, uint256 _expectToken, uint256 _day,  string memory _name, uint256 _activePoint) external onlyAdmin {
        boxStakeMap[_addr].push(StakeDetail({isTradable:_isTradable, expectToken:_expectToken, day:_day, startTime:block.timestamp.getNextDayTimestamp(), endTime:block.timestamp.getStakeEndTime(_day-1),name:_name,rewardToken:0,  expire:false, activePoint:_activePoint, isSend: _isSend }));
        
        // boxStakeMap[_addr].push(StakeDetail({isTradable:_isTradable, expectToken:_expectToken, day:_day, startTime:block.timestamp.getTodayTimestamp(), endTime:block.timestamp.getTodayTimestamp(),name:_name,rewardToken:0,  expire:false, activePoint:_activePoint, isSend: _isSend }));
        // 当盲盒挖矿时候，需要更新自身手续费等级
        IntoData.updateOwnerFeeLevel(_addr);
    }

    

    function getMiningBoxCount(address _addr) public view returns(uint256){
        StakeDetail[] memory records = boxStakeMap[_addr];
        uint count = 0;
        uint256 len = records.length;
        for(uint i=0; i< len; i++){
            StakeDetail memory record = records[len-1-i];
            
            if(record.endTime >= block.timestamp.getTodayTimestamp() && record.startTime <= block.timestamp.getTodayTimestamp()){
                count ++;
                // if(count > 0){
                break;
                // }
            }
            
        }

        return count;
    }

    function getValidBoxWithAuth(address _addr) public view returns(bool){
         StakeDetail[] memory records = boxStakeMap[_addr];
         bool isHas = false;
        uint256 len = records.length;
        if(len == 0){
            return false;
        }
        for(uint i=0; i< len; i++){
            if(records[i].endTime > block.timestamp ){
               isHas = true;
               break;
            }
        }

        return isHas;
    }
    
    
    
    
    function getLevelWithStake(address _addr) public view returns (uint256) {
        // IIntoPool.StakeDetail[] memory nfts = IIntoPool(poolAddr).getBoxStake(_addr);
        uint256 level = 1;

        uint256 len =  boxStakeMap[_addr].length;
        for (uint256 i = 0; i < len; i++) {
            StakeDetail memory detail = boxStakeMap[_addr][i];
            // if (detail.endTime > block.timestamp.getNextDayTimestamp()) {
            if (detail.endTime > block.timestamp) {
                string memory name = detail.name;
                if (checkBool(name, "D") && level < 2) {
                    level = 2;
                } else if (checkBool(name, "C") && level < 3) {
                    level = 3;
                } else if (checkBool(name, "B") && level < 4) {
                    level = 4;
                } else if (checkBool(name, "A") && level < 5) {
                    level = 5;
                } else if (checkBool(name, "S") && level < 6) {
                    level = 6;
                }
            }
        }

        return level;
    }

    function checkBool(string memory _str1, string memory _str2)
        public
        pure
        returns (bool)
    {
        if (bytes(_str1).length == bytes(_str2).length) {
            if (
                keccak256(abi.encodePacked(_str1)) ==
                keccak256(abi.encodePacked(_str2))
            ) {
                return true;
            }
        }
        return false;
    }
    
    
 
    
    
}