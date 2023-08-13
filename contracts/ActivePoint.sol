// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./AdminRoleUpgrade.sol";

interface IIntoRelation {
    function getInvList(address addr_)
        external
        view
        returns (address[] memory _addrsList);

    function invListLength(address addr_) external view returns (uint256);

    function Inviter(address _addr) external view returns (address);
}

interface IIntoAuth {
    function validUser(address _addr) external view returns (bool);

    function getValidUserCount(address _addr) external view returns (uint256);

    function isTrande(address _addr) external view returns (bool);
}

interface IIntoRecord {
    function setAboutRecord(
        address _addr,
        string memory _stype,
        string memory _source,
        address _user,
        uint256 _token,
        bool _isAdd,
        bool _isValid,
        string memory _remark
    ) external;
}

// 活跃点收藏值
contract ActivePoint is AdminRoleUpgrade, Initializable {
    using SafeMathUpgradeable for uint256;

    IIntoRelation IntoRation;
    bytes32 public constant ADMIN = keccak256(abi.encodePacked("ADMIN"));
    // 活跃点
    struct Point {
        // 自身产生的活跃点
        uint256 ownerActivePoint;
        // 小区活跃点
        uint256 teamActivePoint;
        // 团队活跃度
        uint256 totalChildActivePoint;
    }

    // 转入转出比例，默认分母是100，如果是转入1:1， 那么intoRatio 就是100
    uint256 public intoRatio;
    uint256 public outRatio;
    uint256 public dividendRatio;

    // 自身拥有的活跃点
    mapping(address => Point) public ownerPointMap;

    // 收藏值
    mapping(address => uint256) public favoriteValueMap;

    IIntoAuth IntoAuth;
    // 无效的活跃点
    mapping(address => uint256) public onwerInvalidActivePoint;
    // 给一代的无效收藏值
    mapping(address => uint256) public ownerParentInvalidFV;
    // 给二代的无效收藏值
    mapping(address => uint256) public ownerGrandparentsInvalidFV;
    // 下级给自己的无效收藏值
    mapping(address => uint256) public ownerInvalidFV;

    IIntoRecord IntoRecord;

    // 初始化
    mapping(address => bool) public isSet;
    mapping(address => bool) public userStatus;

    function initialize() public initializer {
        // IntoRation = IIntoRelation(_relationAddr);
        _addAdmin(msg.sender);

        // 转入碎片是1.5倍, 转出是1倍
        intoRatio = 150;
        outRatio = 100;
        dividendRatio = 70;
    }

    function initSetWithFirst(address _addr) external onlyAdmin {
        if (!isSet[_addr]) {
            isSet[_addr] = true;
            userStatus[_addr] = IntoAuth.validUser(_addr);
        }
    }

    function setAboutAddress(address _IntoAuthAddr, address _IntoRecordAddr)
        external
        onlyAdmin
    {
        IntoAuth = IIntoAuth(_IntoAuthAddr);
        IntoRecord = IIntoRecord(_IntoRecordAddr);
    }

    function setIntoRatio(uint256 ratio) external onlyAdmin {
        intoRatio = ratio;
    }

    function setOutRatio(uint256 ratio) external onlyAdmin {
        outRatio = ratio;
    }

    function updateFavoriteAndPointWithMCPT(
        address _addr,
        uint256 subFavoritetValue,
        uint256 addFavoriteValue,
        uint256 actionPoint,
        bool isAddPoint,
        uint256 _count
    ) external onlyAdmin {
        updateFavoriteValue(_addr, subFavoritetValue, false);
        updateFavoriteValue(_addr, addFavoriteValue, true);
        updateParentFavoriteValue(_addr, addFavoriteValue);
        updateParentActivePoint(_addr, actionPoint, isAddPoint, _count);
        if (addFavoriteValue > 0) {
            IntoRecord.setAboutRecord(
                _addr,
                "favorite",
                "mcpt",
                _addr,
                addFavoriteValue,
                true,
                true,
                ""
            );
        }
    }

    // 地址，减少的收藏值， 增加的收藏值，
    function updateFavoriteAndPoint(
        address _addr,
        uint256 subFavoritetValue,
        uint256 addFavoriteValue,
        uint256 actionPoint,
        bool isAddPoint,
        uint256 _count
    ) external onlyAdmin {
        updateFavoriteValue(_addr, subFavoritetValue, false);
        updateFavoriteValue(_addr, addFavoriteValue, true);
        updateParentFavoriteValue(_addr, addFavoriteValue);
        updateParentActivePoint(_addr, actionPoint, isAddPoint, _count);
        if (addFavoriteValue > 0) {
            IntoRecord.setAboutRecord(
                _addr,
                "favorite",
                "openStake",
                _addr,
                addFavoriteValue,
                true,
                true,
                ""
            );
        }
    }

    // 判断交易是转出还是转入得到收藏值
    function setTradingFavorite(
        address _addr,
        uint256 _value,
        bool isInto
    ) external onlyAdmin {
        uint256 value = getRatioFavorite(_value, isInto);
        updateFavoriteValue(_addr, value, isInto);
    }

    // 利益分红，增加收藏值
    function batchFavoriteValue(address[] memory _addrs, uint256 _value)
        external
        onlyAdmin
    {
        uint256 value = _value.mul(dividendRatio).div(100);
        for (uint256 i = 0; i < _addrs.length; i++) {
            updateFavoriteValue(_addrs[i], value, true);
        }
    }

    function getRatioFavorite(uint256 _value, bool isInto)
        public
        view
        returns (uint256)
    {
        uint256 ratio = isInto ? intoRatio : outRatio;
        return _value.mul(ratio).div(100);
    }

    // 获取自身的活跃点 小区活跃点  团队活跃点  无效活跃点
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
        (, uint256 teamPoint, ) = updateTeamPoint(_addr);
        return (
            ownerPointMap[_addr].ownerActivePoint,
            teamPoint,
            ownerPointMap[_addr].totalChildActivePoint,
            onwerInvalidActivePoint[_addr]
        );
    }

    // 自身活跃点的增加或者减少，影响的是上级的小区活跃点，所以需要更新
    function updateParentActivePoint(
        address addr,
        uint256 _point,
        bool isAdd,
        uint256 _count
    ) public onlyAdmin {
        // 默认值是调用者
        address sender = addr;
        if (_point > 0) {
            Point storage point = ownerPointMap[sender];
            uint256 ownerActivePoint = point.ownerActivePoint;
            if (isAdd) {
                point.ownerActivePoint += _point;
            } else {
                if(point.ownerActivePoint > _point){
                    point.ownerActivePoint -= _point;
                }else{
                    point.ownerActivePoint = 0;
                }
                
            }
            

            bool _validStatus = IntoAuth.validUser(sender);
            // 如果两者相等，说明状态没有变更，那就直接向上传递
            if (_validStatus == userStatus[sender]) {
                // 用户有效，则向上传递有效团队活跃度， 无效则传递无效团队活跃度
                if (userStatus[sender]) {
                    updateParentActivePointWithValid(
                        sender,
                        isAdd,
                        _point,
                        isAdd,
                        0,
                        _count
                    );
                } else {
                    updateParentActivePointWithValid(
                        sender,
                        isAdd,
                        0,
                        isAdd,
                        _point,
                        _count
                    );
                }
            } else {
                // 两者不相等，那么需要变更状态，需要先去除之前增加给上级的活跃度
                if (userStatus[sender]) {
                    updateParentActivePointWithValid(
                        sender,
                        false,
                        ownerActivePoint,
                        true,
                        point.ownerActivePoint,
                        _count
                    );

                    
                } else {
                    updateParentActivePointWithValid(
                        sender,
                        true,
                        point.ownerActivePoint,
                        false,
                        ownerActivePoint,
                        _count
                    );
                }

                userStatus[sender] = _validStatus;
            }
        }
    }

    // event Log(uint256 count);
    // 更新自身及以上50代数据
    function updateParentActivePointWithValid(
        address _addr,
        bool _isValidAdd,
        uint256 _validPoint,
        bool _isInvalidAdd,
        uint256 _invalidPoint,
        uint256 _count
    ) internal {

        
        // emit Log(_count);
        address sender = _addr;
        if(_validPoint > 0){
            for (uint256 i = 0; i < _count; i++) {
            sender = getParent(sender);
            if (sender == address(0)) {
                break;
            }
            
            updateValidPoint(sender, _isValidAdd, _validPoint);
            
            //  去除无效活跃度
            // updateInvalidPoint(sender, _isInvalidAdd, _invalidPoint);
            
        }
        }
        
    }


    function addActionPoint(address _sender) internal {
        Point storage point = ownerPointMap[_sender];
        // 小区活跃点
        // point.teamActivePoint = updateTeamPoint(_sender);
        (uint256 totalPoint, , uint256 invalidPoint) = updateTeamPoint(_sender);

        if (point.totalChildActivePoint != totalPoint) {
            point.totalChildActivePoint = totalPoint;
        }

        if (onwerInvalidActivePoint[_sender] != invalidPoint) {
            onwerInvalidActivePoint[_sender] = invalidPoint;
        }
    }

    // 更新自身的小区活跃点
    function updateTeamPoint(address _sender)
        public
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        address[] memory childs = getChildMembers(_sender);
        uint256 maxActivePoint = 0;
        uint256 totalActivePoint = 0;
        uint256 childinvalidActivePoint = 0;
        uint256 len = childs.length;
        for (uint256 i = 0; i < len; i++) {
            address child = childs[i];
            Point memory point = ownerPointMap[child];

            // 有效活跃度往上级传递
            uint256 childTotalPoint = point.totalChildActivePoint;
            // 判断自身是否是有效用户，如果是，则有效团队活跃度就是 下级的团队活跃度+自身活跃度，否则则放入到无效活跃度里面
            if (IntoAuth.validUser(child)) {
                childTotalPoint += point.ownerActivePoint;
            } else {
                childinvalidActivePoint += point.ownerActivePoint;
            }
            maxActivePoint = (
                childTotalPoint > maxActivePoint
                    ? childTotalPoint
                    : maxActivePoint
            );
            totalActivePoint += childTotalPoint;
            childinvalidActivePoint += onwerInvalidActivePoint[child];
        }

        return (
            totalActivePoint,
            totalActivePoint - maxActivePoint,
            childinvalidActivePoint
        );
    }

    // 收藏值
    function updateFavoriteValue(
        address _addr,
        uint256 _value,
        bool _isAdd
    ) public onlyAdmin {
        if (_value > 0) {
            if (_isAdd) {
                favoriteValueMap[_addr] += _value;
            } else {
                if(favoriteValueMap[_addr] > _value){
                    favoriteValueMap[_addr] -= _value;
                }else{
                    favoriteValueMap[_addr] = 0;
                }
                
            }
        }
    }

    // 判断自身是否是有效用户，如果是有效用户，那么需要把收藏值给上级
    function updateParentFavoriteValueWithValid(address _addr) public {
        if (IntoAuth.validUser(_addr) && ownerParentInvalidFV[_addr] > 0) {
            // 把收藏值给一代二代
            favoriteValueMap[getParent(_addr)] += ownerParentInvalidFV[_addr];
            favoriteValueMap[
                getParent(getParent(_addr))
            ] += ownerGrandparentsInvalidFV[_addr];

            // 处理异常
            // if (
            //     ownerInvalidFV[getParent(_addr)] > ownerParentInvalidFV[_addr] ) {
            //     ownerInvalidFV[getParent(_addr)] -= ownerParentInvalidFV[_addr];
            // } else {
            //     ownerInvalidFV[getParent(_addr)] = 0;
            // }

            // if (ownerInvalidFV[getParent(getParent(_addr))] > ownerGrandparentsInvalidFV[_addr] ) {
            //     ownerInvalidFV[
            //         getParent(getParent(_addr))
            //     ] -= ownerGrandparentsInvalidFV[_addr];
            // } else {
            //     ownerInvalidFV[getParent(getParent(_addr))] = 0;
            // }

            ownerGrandparentsInvalidFV[_addr] = 0;
            ownerParentInvalidFV[_addr] = 0;
        }
    }

    // 给父级加收藏值
    function updateParentFavoriteValue(address _addr, uint256 _value)
        public
        onlyAdmin
    {
        if (_value > 0) {
            (uint256 value1, uint256 value2) = updateSuperFavorite(_value);
            if (IntoAuth.validUser(_addr)) {
                favoriteValueMap[getParent(_addr)] += value1;
                favoriteValueMap[getParent(getParent(_addr))] += value2;
                IntoRecord.setAboutRecord(
                    getParent(_addr),
                    "favorite",
                    "first",
                    _addr,
                    value1,
                    true,
                    true,
                    ""
                );
                IntoRecord.setAboutRecord(
                    getParent(getParent(_addr)),
                    "favorite",
                    "second",
                    _addr,
                    value2,
                    true,
                    true,
                    ""
                );
                updateParentFavoriteValueWithValid(_addr);
            } else {
                // 无效用户时，先保存需要给一代、二代的收藏值
                ownerParentInvalidFV[_addr] += value1;
                ownerGrandparentsInvalidFV[_addr] += value2;

                // 下级给自己的无效收藏值
                // ownerInvalidFV[getParent(_addr)] += value1;
                // ownerInvalidFV[getParent(getParent(_addr))] += value2;

                // IntoRecord.setAboutRecord(
                //     getParent(_addr),
                //     "favorite",
                //     "first",
                //     _addr,
                //     value1,
                //     true,
                //     false,
                //     ""
                // );
                // IntoRecord.setAboutRecord(
                //     getParent(getParent(_addr)),
                //     "favorite",
                //     "second",
                //     _addr,
                //     value2,
                //     true,
                //     false,
                //     ""
                // );
            }
        }
    }

    function updateSuperFavorite(uint256 _value)
        internal
        pure
        returns (uint256, uint256)
    {
        return (_value.mul(3).div(100), _value.mul(2).div(100));
    }

    // 设置
    function setIntoRation(address _addr) external onlyAdmin {
        IntoRation = IIntoRelation(_addr);
    }

    function getParent(address _addr) public view returns (address) {
        return IntoRation.Inviter(_addr);
    }

    // function getMemberCount() public view returns (uint256) {
    //     return IntoRation.invListLength(msg.sender);
    // }

    function getChildMembers(address _addr)
        public
        view
        returns (address[] memory)
    {
        return IntoRation.getInvList(_addr);
    }

    // 更新有效团队活跃度
    function updateValidPoint(
        address _addr,
        bool _isAdd,
        uint256 _point
    ) internal {
        if (_point > 0) {
            Point storage point = ownerPointMap[_addr];
            if (_isAdd) {
                point.totalChildActivePoint += _point;
            } else {
                if (point.totalChildActivePoint > _point) {
                    point.totalChildActivePoint -= _point;
                } else {
                    point.totalChildActivePoint = 0;
                }
            }
        }
    }

    // 更新无效的团队活跃度
    function updateInvalidPoint(
        address _addr,
        bool _isAdd,
        uint256 _point
    ) internal {
        if (_point > 0) {
            if (_isAdd) {
                onwerInvalidActivePoint[_addr] += _point;
            } else {
                if (onwerInvalidActivePoint[_addr] > _point) {
                    onwerInvalidActivePoint[_addr] -= _point;
                } else {
                    onwerInvalidActivePoint[_addr] = 0;
                }
            }
        }
    }


    function batchGetFavorite(address[] memory addrs) external view returns(uint256[] memory){
        uint256 addrLength = addrs.length;
        uint256[] memory ownerFavorites = new uint256[](addrLength);
        
        for(uint256 i=0; i < addrLength; i++){
            address  addr = addrs[i];
            ownerFavorites[i] = favoriteValueMap[addr];
        }

        return ownerFavorites;
    } 
}
