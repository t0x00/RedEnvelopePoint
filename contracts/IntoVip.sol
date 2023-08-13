// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IIntoInterface.sol";
import "./AdminRoleUpgrade.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IIntoData {
    // function isAddStake(address _addr, string memory _type) external;
    // function getMemberCount(address _addr) external view returns(uint256);
    // function getChildMembers(address _addr) external view returns(address[] memory);
    // function getParent(address _addr) external view returns(address);
    function getPoint(address _addr) external view returns(uint256, uint256, uint256, uint256);
}



contract IntoVip is AdminRoleUpgrade, Initializable {
    IIntoData IntoData;
    // 自身拥有的Vip 级别 
    mapping(address => uint256) public ownerVipMap;

    // 子拥有的最大级别 0、1、2、 3、 4、 5、 6
    mapping(address => uint256) public childMaxVipMap;

    // 升级VIP是否得到过盲盒
    mapping(address => mapping(uint256 => bool)) public isOwnedNFT;
    // 每个级别的vip地址
    mapping(uint256 => address[]) public vipList;
    // 升级所需要的活跃点
    mapping(uint256 => uint256) public upActivePoint;

    IExchangeNFT exchangeNFT;
    IIntoAuth IntoAuth;

    bool public pause;
    IIntoRelation IntoRelation;
    // function setIntoData(address _addr) external onlyAdmin {
    //     IntoData = IIntoData(_addr);
    //     addAdmin(_addr);
    // }

    function setAboutAddress(address _IntoAddr, address _exchangeNFTAddr, address _IntoAuthAddr, address _IntoRelationAddr) external onlyAdmin{
        IntoData = IIntoData(_IntoAddr);
        exchangeNFT = IExchangeNFT(_exchangeNFTAddr);
        IntoAuth = IIntoAuth(_IntoAuthAddr);
        IntoRelation = IIntoRelation(_IntoRelationAddr);
    }
    
    function initialize() public initializer {
        
        _addAdmin(msg.sender);
        upActivePoint[6] = 100000;
        upActivePoint[5] = 50000;
        upActivePoint[4] = 30000;
        upActivePoint[3] = 10000;
        upActivePoint[2] = 3000;
        upActivePoint[1] = 300;
    } 

    modifier check(){
        require(!pause, "Do not operate");
        _;
    }

    function modifyUpdatePoint() external onlyAdmin{
        upActivePoint[6] = 100000;
        upActivePoint[5] = 50000;
        upActivePoint[4] = 30000;
        upActivePoint[3] = 10000;
        upActivePoint[2] = 3000;
        upActivePoint[1] = 300;
    }
    
    function setPause(bool _pause) external onlyAdmin{
        pause = _pause;
    }

    // 是否可以升级
    function isUpdateVip(address _addr) external view returns(bool ){
        address sender = _addr;
        uint256 ownerVip = ownerVipMap[sender];

        uint256 maxVip = _updateVip(sender);
        
        return (ownerVip == maxVip ? false: true);
    }

    // 更新VIP
    function updateVip(address _addr) external check {
        
        address sender = _addr;
        uint256 ownerVip = ownerVipMap[sender];
        uint256 maxVip = _updateVip(sender);  

        // 当本身的VIP级别 不等于 计算出的VIP级别，需要更改Vip级别
        if(ownerVip != maxVip){
            ownerVipMap[sender] = maxVip;
            if(maxVip >1){
                getNotTradableNFT(sender,maxVip);
            } 
            // 更新全局VIP列表
            updateVipList(sender,ownerVip, maxVip);
        }
        // 更新合约的最大级别
        updateVipMaxLevel(sender);
    }

    // 升级VIP获取不可交易的盲盒
    function getNotTradableNFT(address _addr,uint256 _maxVipLevel) internal {
        for(uint256 i=2; i <= _maxVipLevel; i++){
            if(!isOwnedNFT[_addr][i]){
                string memory _type;
                if(i==2){
                    _type = "D";
                }else if(i==3){
                    _type = "C";
                }else if(i==4){
                    _type = "B";
                }else if(i==5){
                    _type = "A";
                }else if(i==6){
                    _type = "S";
                }

                //  判断达到交易数量
                exchangeNFT.isAddStake(_addr, _type);
                isOwnedNFT[_addr][i] = true;
            }
        }
    }

    function _updateVip(address _addr) internal view returns(uint256 ){
        uint256 maxVip = 6;
        uint256 activePointLevel = getVipLevelWithActivePoint(_addr);
        uint256 childMaxLevel = checkChildMaxVip(_addr);
        uint256 shareLevel = getVipLevelWithShare(IntoAuth.getValidUserCount(_addr));

        // 获取可升级的最小级别
        maxVip = (maxVip < activePointLevel? maxVip: activePointLevel);
        maxVip = (maxVip < childMaxLevel? maxVip: childMaxLevel);
        maxVip = (maxVip < shareLevel? maxVip: shareLevel);

        return maxVip;
    }

    // 更新合约的最大级别
    function updateVipMaxLevel(address _addr) internal {
        address ownself = _addr;

        uint256 ownerMaxLevel =_getVipMaxLevel(ownself);
        uint256 childMaxVipLevel = childMaxVipMap[ownself];
        if(ownerMaxLevel != childMaxVipLevel){
            childMaxVipMap[ownself] = ownerMaxLevel;
        }
        // 当合约最大级别大于原来的最大级别，那么向上传递
        if(ownerMaxLevel > childMaxVipLevel){
            updateParentMaxVipWithAdd(ownself, ownerMaxLevel);
        }

        if(ownerMaxLevel < childMaxVipLevel){
            updateParentMaxVipWithReduce(ownself, childMaxVipLevel);
        }
        
    }

    function _getVipMaxLevel(address _addr) internal view returns(uint256){
        uint256 level =  ownerVipMap[_addr];
        uint256 maxLevel = updateOwnerChildVipMaxLevel(_addr);
        return maxLevel > level? maxLevel: level;
    }

    function updateOwnerChildVipMaxLevel(address _addr) public view returns(uint256) {
        address[] memory addrs = getChildMembers(_addr);
        uint256 maxLevel = 0;
        for(uint256 i=0; i< addrs.length; i++){
            uint256 level = childMaxVipMap[addrs[i]];
            if(level > maxLevel){
                maxLevel = level;
            }
        }

        return maxLevel;
    }



    // 检查合约的达到的可升级的VIP级别
    function checkChildMaxVip(address _addr) public view returns(uint256) {
        address[] memory childs = getChildMembers(_addr);
        uint256 maxLevel = 0;
        uint256 secLevel = 0;
        for(uint256 i=0; i < childs.length; i++){
            uint256 level = childMaxVipMap[childs[i]];
            if(level > maxLevel){
                secLevel = maxLevel;
                maxLevel = level;
            }else if(level > secLevel){
                secLevel = level;
            }
        }
        
        return secLevel +1;
        
        
    }

    function getVipLevelWithActivePoint(address _addr) public view returns(uint256){
        (, uint256 teamActivePoint,,) = IntoData.getPoint(_addr);
        if(teamActivePoint >= upActivePoint[6]){
            return 6;
        }else if(teamActivePoint >= upActivePoint[5]){
            return 5;
        }else if(teamActivePoint >= upActivePoint[4]){
            return 4;
        }else if(teamActivePoint >= upActivePoint[3]){
            return 3;
        }else if(teamActivePoint >= upActivePoint[2]){
            return 2;
        }else if(teamActivePoint >= upActivePoint[1]){
            return 1;
        }
        return 0;
    }


    function getVipLevelWithShare(uint256 count) public pure returns(uint256){
       
        
        if(count >= 100){
            return 6;
        }else if(count >= 50){
            return 5;
        }else if(count >= 30){
            return 4;
        }else if(count >= 20){
            return 3;
        }else if(count >= 10){
            return 2;
        }else if(count >= 5){
            return 1;
        }
        return 0;

        
    }


    // 获取合约的最大级别
    function getMaxVip(address _sender) internal view returns(uint256) {

        return childMaxVipMap[_sender];
    }

    // 当用户VIP更新时，更新级别列表
    function updateVipList(address _addr,uint256 oldLevel, uint256 newLevel) public check {
        _bind(_addr,newLevel);
        _unbind(_addr,oldLevel);
        
    }


    function _bind(address _addr,uint256 _level) internal {
        if(_level > 0){
            vipList[_level].push(_addr);
        }
        
    }


    function _unbind(address _addr, uint256 _level) internal {

        uint256 num = vipList[_level].length;
        bool isPop;
        for(uint256 i=0; i< vipList[_level].length; i++){
            if(vipList[_level][i] == _addr){
                vipList[_level][i] = vipList[_level][num-1];
                isPop = true;
            }
        }

        if(isPop && num > 0){
            vipList[_level].pop();
        }
    }
    
    //  mapping(uint256 => address[]) public vipList;
    function getVipList(uint256 _level) public view returns(address[] memory){
        return vipList[_level];
    }

    function getVipListCount(uint256 _level) public view returns(uint256){
        return vipList[_level].length;
    }

    function interUpdateParentMaxVipWithAdd(address _addr, uint256 _updateVipLevel) public onlyAdmin{
        updateParentMaxVipWithAdd(_addr, _updateVipLevel);
    }
    
    // 当VIP升级的时候，只需要向上传递
    function updateParentMaxVipWithAdd(address _addr, uint256 _updateVipLevel) internal {
        address sender = _addr;
        for(uint256 i=0; i< 60; i++){
            sender = getParent(sender);
            if(childMaxVipMap[sender] > _updateVipLevel){
                break;
            }
            childMaxVipMap[sender] = _updateVipLevel;
        }
    }

    
    function updateParentMaxVipWithReduce(address _addr, uint256 _vipLevel) internal{
        address sender = _addr;
        for(uint256 i=0; i< 60; i++){
            sender = getParent(sender);
            // 父级的最大级别大于传的值，退出循环
            if(childMaxVipMap[sender] > _vipLevel ){
                break;
            }
            
            // 本身的vip级别大于或者等于最大级别时候
            if(ownerVipMap[sender] >= _vipLevel){
                break;
            }
            uint256 childMaxVipLevel = getOwnerChildMaxVip(sender);
            // 比如从vip2直接降为vip0,那么对于他的上级来说，就需要重新计算他的最高代数
            // 当计算的最高级别和_vipLevel相等时候，还有另一个相等的级别。不用降级。
            if(childMaxVipLevel >= _vipLevel){
                break;
            }

            childMaxVipLevel = (childMaxVipLevel > ownerVipMap[sender]?childMaxVipLevel:ownerVipMap[sender] );
            childMaxVipMap[sender] = childMaxVipLevel;
        }
    }

    // 获取自身及子代能获取到的最大级别
    function getOwnerChildMaxVip(address _addr) public view returns(uint256){
        address[] memory childs = getChildMembers(_addr);
        uint256 len = childs.length;
        uint256 maxLevel = 0;
        for(uint256 i=0; i< len; i++){
            uint256 level = childMaxVipMap[childs[i]];
            maxLevel = (maxLevel > level? maxLevel:level);
        }
        
        return maxLevel;
    }

    
    function getParent(address _addr) public view returns (address) {
        return IntoRelation.Inviter(_addr);
    }

    function getMemberCount(address _addr) public view returns (uint256) {
        return IntoRelation.invListLength(_addr);
    }

    function getChildMembers(address _addr)
        public
        view
        returns (address[] memory)
    {
        return IntoRelation.getInvList(_addr);
    }
}