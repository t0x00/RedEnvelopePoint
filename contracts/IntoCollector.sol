// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./AdminRoleUpgrade.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// 收藏家
contract IntoCollector is AdminRoleUpgrade, Initializable {

    enum Level {
        early, mid, late
    }

    // 是否为收藏家
    mapping(address => bool) public isCollector;
    // 收藏家数量
    mapping(Level => uint256) public collectorCount;
    
    mapping(Level => address[]) public collectorList;

    mapping(address => mapping(Level => bool)) public isLevelCollector;

    function initialize() public initializer {
         _addAdmin(msg.sender);
         collectorCount[Level.early] = 36;
         collectorCount[Level.mid] = 36;
         collectorCount[Level.late] = 36;
    } 

    function getCollectorList(uint256 _level) public view returns(address[] memory){
        return collectorList[Level(_level)];
    }


    // 设置收藏家数量
    function setCollectorCount(uint256 _level, uint256 _count) external onlyAdmin  {
        
        collectorCount[Level(_level)] = _count;
    }

    // 设置收藏家
    function setCollector(uint256 _level, address _addr) external onlyAdmin  {
        require(collectorCount[Level(_level)] > collectorList[Level(_level)].length, "Limit of quantity");
        require(!isLevelCollector[_addr][Level(_level)], "Already a collector");
        collectorList[Level(_level)].push(_addr);
        isCollector[_addr] = true;
        isLevelCollector[_addr][Level(_level)] = true;
    }

    function setBatchCollector(uint256 _level, address[] memory _addrs) external onlyAdmin {
        require(collectorCount[Level(_level)] > collectorList[Level(_level)].length + _addrs.length, "Limit of quantity");

        for(uint i=0; i< _addrs.length; i++){
            require(!isLevelCollector[_addrs[i]][Level(_level)], "Already a collector");
            collectorList[Level(_level)].push(_addrs[i]);
            isCollector[_addrs[i]] = true;
            isLevelCollector[_addrs[i]][Level(_level)] = true;
        }
    }

    // 获取自身是否是收藏家
    function getCollectorWithAddr(address _addr) public view returns(bool, bool, bool){
        return (isLevelCollector[_addr][Level.early], isLevelCollector[_addr][Level.mid],isLevelCollector[_addr][Level.late]);
    }

    function getCollectorCountWithLevel(uint256 _level) public view returns(uint256){
        return collectorList[Level(_level)].length;
    }


    function unbindCollector(address _addr) external onlyAdmin  {
        require(isCollector[_addr], "Not a collector");
        if(isLevelCollector[_addr][Level.early]){
            _unbind(0, _addr);
            
        }
        if(isLevelCollector[_addr][Level.mid]){
            _unbind(1, _addr);
        }
        
        if(isLevelCollector[_addr][Level.late]){
            _unbind(2, _addr);
        }
        
        isCollector[_addr] = false;
        
    }

    function _unbind(uint256 _level, address _addr) internal{
        uint256 num = collectorList[Level(_level)].length;
        bool isPop;

        for(uint256 i=0; i < num; i++){
            if(collectorList[Level(_level)][i] == _addr){
                collectorList[Level(_level)][i] = collectorList[Level(_level)][num - 1];
                isPop = true;
            }
        }

        if(isPop){
            collectorList[Level(_level)].pop();
        }
        isLevelCollector[_addr][Level(_level)] = false;

    }


}