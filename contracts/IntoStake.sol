// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./AdminRoleUpgrade.sol";
import "./IIntoInterface.sol";

contract IntoStake is AdminRoleUpgrade, Initializable {
    event StackStake(address addr);
    event Migration(address addr);
    using SafeMathUpgradeable for uint256;

    // 3.5小时
    uint256 public stakeTime;

    // 是否在挖矿
    mapping(address => bool) public isMining;
    // 挖矿的开始时间
    mapping(address => uint256) public stakeStartTime;

    struct StakeDetail {
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
    IIntoPool IntoPool;
    // 是否更新过活跃点,目前的冗余字段
    mapping(address => mapping(uint256 => bool)) public isUpdateAP;

    bool public pause;

    // 地址是否迁移
    mapping(address => bool) public migration;
    //正在挖矿的
    mapping(address => uint256[]) public myStakeIds;
    // 未挖矿次数
    mapping(address => mapping(uint256 => uint256)) public unusedTimes;
    // 每次矿机每天所得
    mapping(address => mapping(uint256 => uint256)) public baseToken;

    // 矿机过期时间
    mapping(address => mapping(uint256 => uint256)) public expireTime;
    
    mapping(address => uint256) public stakeEndTime;
    
    mapping(address => mapping(uint256 => uint256)) public rewardToken;


    function initialize() public initializer {
        stakeTime = 3 * 3600 + 1800;
        _addAdmin(msg.sender);
    }

    modifier check() {
        require(!pause, "Do not operate");
        _;
    }

    // function setPause(bool _pause) external onlyAdmin {
    //     pause = _pause;
    // }

    // function setAboutAddress(
    //     address _IntoDataAddr,
    //     address _IntoRecordAddr,
    //     address _IntoRationAddr,
    //     address _activePointAddr,
    //     address _IntoAuthAddr,
    //     address _IntoDividendAddr,
    //     address _IntoPoolAddr
    // ) external onlyAdmin {
    //     IntoData = IIntoData(_IntoDataAddr);
    //     IntoRecord = IIntoRecord(_IntoRecordAddr);
    //     IntoRation = IIntoRelation(_IntoRationAddr);
    //     activePoint = IActionPoint(_activePointAddr);
    //     IntoAuth = IIntoAuth(_IntoAuthAddr);
    //     IntoDividend = IIntoDividend(_IntoDividendAddr);
    //     IntoPool = IIntoPool(_IntoPoolAddr);
    // }

    // 挖矿时间
    function updateStakeTime(uint256 _stakeTime) external onlyAdmin {
        stakeTime = _stakeTime;
    }

    // 一键挖矿
    function stackStake() external {
        syncPoolData(msg.sender);

        require(!isMining[msg.sender], "is mining");

        // 判断今天是否已经挖过
        require(
            stakeEndTime[msg.sender] < getTodayTimestamp(),
            "Mined today"
        );
        // require(getValidBoxWithAuth(msg.sender), "No mining machine");

        isMining[msg.sender] = true;
        stakeStartTime[msg.sender] = block.timestamp;
        emit StackStake(msg.sender);
    }

    // 领取收益
    function stakeReceive() external {
        require(isMining[msg.sender], "already receive");
        address sender = msg.sender;
        uint256 currentTime = block.timestamp;

        uint256[] memory stakeIds = myStakeIds[sender];
        uint256 len = stakeIds.length;
        uint256 ownerbalances = 0;
        uint256 oldExpirePoint = 0;
        uint256 expirePoint = 0;
        bool isUpdateIds = false;
        for (uint256 i = 0; i < len; i++) {
            uint256 index = stakeIds[i];
            if (unusedTimes[sender][index] > 0) {
                ownerbalances += baseToken[sender][index];
                unusedTimes[sender][index]--;
                rewardToken[sender][index] += baseToken[sender][index];
            }

            if (unusedTimes[sender][index] == 0) {
                // 需要做移除工作
                isUpdateIds = true;
            }

            if (
                !isUpdateAP[sender][index] &&
                expireTime[sender][index] < currentTime 
            ) {
                isUpdateAP[sender][index] = true;
                // 活跃度减少
                StakeDetail memory record = boxStakeMap[sender][index];

                if (record.startTime < 1672329600) {
                    oldExpirePoint += record.activePoint;
                } else {
                    if (checkBool(record.name, "F")) {
                        activePoint.updateFavoriteAndPoint(
                            msg.sender,
                            0,
                            0,
                            record.activePoint,
                            false,
                            10
                        );
                    } else {
                        expirePoint += record.activePoint;
                    }
                }
            }
        }

        if (expirePoint > 0 || oldExpirePoint > 0) {
            // 同步数据
            activePoint.initSetWithFirst(msg.sender);
            if (expirePoint > 0) {
                activePoint.updateFavoriteAndPoint(
                    msg.sender,
                    0,
                    0,
                    expirePoint,
                    false,
                    30
                );
            }
            if (oldExpirePoint > 0) {
                activePoint.updateFavoriteAndPoint(
                    msg.sender,
                    0,
                    0,
                    oldExpirePoint,
                    false,
                    60
                );
            }

            IntoData.updateOwnerFeeLevel(msg.sender);
        }

        if (ownerbalances > 0) {
            updateOwnerBalances(msg.sender, ownerbalances, "");
            if (IntoAuth.validUser(sender)) {
                updateParentBalances(msg.sender, ownerbalances, "");
            }
        }

        if(isUpdateIds){
           updateStakeIds(msg.sender); 
        }
        stakeEndTime[msg.sender] = currentTime;
        isMining[msg.sender] = false;
    }

    function updateParentBalances(
        address _addr,
        uint256 _token,
        string memory _boxType
    ) internal {
        (uint256 value1, uint256 value2) = updateSuperFavorite(_token);
        address parent = getParent(_addr);
        address grandParent = getParent(getParent(_addr));

        IntoData.updateBalances(parent, value1, true);
        IntoData.updateBalances(grandParent, value2, true);
        IntoRecord.setAboutRecord(
            parent,
            "token",
            "first",
            _addr,
            value1,
            true,
            true,
            _boxType
        );
        IntoRecord.setAboutRecord(
            grandParent,
            "token",
            "second",
            _addr,
            value2,
            true,
            true,
            _boxType
        );
    }


    function getAboutTodayExpectToken(address _addr)
        public
        view
        returns (uint256)
    {
        uint256 totalrewardToken = 0;
        uint256[] memory ids = getValidBox(_addr);

        for (uint256 i = 0; i < ids.length; i++) {
            totalrewardToken += baseToken[_addr][ids[i]];
        }

        return totalrewardToken;
    }

    function updateOwnerBalances(
        address _addr,
        uint256 _token,
        string memory _boxType
    ) internal {
        IntoData.updateBalances(_addr, _token, true);
        IntoRecord.setAboutRecord(
            _addr,
            "token",
            "stake",
            _addr,
            _token,
            true,
            true,
            _boxType
        );
    }

    function updateSuperFavorite(uint256 _value)
        internal
        pure
        returns (uint256, uint256)
    {
        return (_value.mul(3).div(100), _value.mul(2).div(100));
    }

    function getBoxStake(address _addr)
        external
        view
        returns (StakeDetail[] memory)
    {
        return boxStakeMap[_addr];
    }

    // 获取质押的盲盒数量
    function nftCountFromStake(address _addr, string memory _boxType)
        public
        view
        returns (uint256)
    {
        uint256[] memory ids = getValidBox(_addr);
        uint256 count = 0;
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 index = ids[i];
            StakeDetail memory record = boxStakeMap[_addr][index];
            if (
                keccak256(abi.encodePacked(record.name)) ==
                keccak256(abi.encodePacked(_boxType))
            ) {
                count++;
            }
        }

        return count;
    }

    function getParent(address _addr) public view returns (address) {
        return IntoRation.Inviter(_addr);
    }

    function addStake(
        address _addr,
        bool _isSend,
        bool _isTradable,
        uint256 _expectToken,
        uint256 _day,
        string memory _name,
        uint256 _activePoint
    ) external onlyAdmin {
        syncPoolData(_addr);
        boxStakeMap[_addr].push(
            StakeDetail({
                isTradable: _isTradable,
                expectToken: _expectToken,
                day: _day,
                startTime: getTodayTimestamp(),
                endTime: gettimestampWithAdd(_day - 1),
                name: _name,
                rewardToken: 0,
                expire: false,
                activePoint: _activePoint,
                isSend: _isSend
            })
        );

        uint256 detailID = boxStakeMap[_addr].length - 1;
        myStakeIds[_addr].push(detailID);
        unusedTimes[_addr][detailID] = _day;
        baseToken[_addr][detailID] = _expectToken.div(_day);
        expireTime[_addr][detailID] = gettimestampWithAdd(_day - 1);

        // 当盲盒挖矿时候，需要更新自身手续费等级
        IntoData.updateOwnerFeeLevel(_addr);
    }

    function getValidBoxWithAuth(address _addr) public view returns (bool) {
        return (getValidBoxCount(_addr) > 0 ? true : false);
    }

    function getValidBoxCount(address _addr) internal view returns(uint256){
        uint256 len = myStakeIds[_addr].length;
        uint256 count = 0;

        for (uint256 i = 0; i < len; i++) {
            uint256 index = myStakeIds[_addr][i];
            if (unusedTimes[_addr][index] > 0) {
                count++;
            }
        }
        return count;
    }

    function getValidBox(address _addr)
        internal
        view
        returns (uint256[] memory)
    {
        uint256 len = myStakeIds[_addr].length;
        uint256 count = getValidBoxCount(_addr);
        uint256[] memory ids = new uint256[](count);
        uint256 needCount = 0;
        for (uint256 i = 0; i < len; i++) {
            uint256 index = myStakeIds[_addr][i];
            if (unusedTimes[_addr][index] > 0) {
                ids[needCount] = index;
                needCount++;
            }
        }

        return ids;
    }

    function getLevelWithStake(address _addr) public view returns (uint256) {
        uint256 level = 1;

        uint256[] memory ids = getValidBox(_addr);
        uint256 len = ids.length;
        for (uint256 i = 0; i < len; i++) {
            uint256 index = ids[i];
            StakeDetail memory detail = boxStakeMap[_addr][index];
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

    function getTodayTimestamp() public view returns (uint256) {
        uint256 dayID = (block.timestamp + 8*3600).div(86400);
        uint256 timestamp = dayID * 86400;
        return timestamp - 8 * 3600;
    }

    function gettimestampWithAdd(uint256 day) public view returns (uint256) {
        return getTodayTimestamp() + day * 86400;
    }

    // function gettimestampWithReduce(uint256 day) public view returns (uint256) {
    //     return getTodayTimestamp() - day * 86400;
    // }

    function syncBoxData(address _addr) internal {
        IIntoPool.StakeDetail[] memory nfts = IntoPool.getBoxStake(_addr);
        uint256 today = getTodayTimestamp();
        stakeStartTime[_addr] = IntoPool.stakeStartTime(_addr);
        isMining[_addr] = IntoPool.isMining(_addr);
        uint256 len = nfts.length;
        for (uint256 i = 0; i < len; i++) {
            IIntoPool.StakeDetail memory record = nfts[i];
            boxStakeMap[_addr].push(
                StakeDetail(
                    record.isTradable,
                    record.expectToken,
                    record.day,
                    record.startTime,
                    record.endTime,
                    record.name,
                    record.rewardToken,
                    record.expire,
                    record.activePoint,
                    record.isSend
                )
            );
            isUpdateAP[_addr][i] = record.expire;
            rewardToken[_addr][i] = record.rewardToken;
            uint256 getToken = record.expectToken.div(record.day);
            baseToken[_addr][i] = getToken;
            expireTime[_addr][i] = record.endTime;
            myStakeIds[_addr].push(i);
            if (record.startTime > today) {
                unusedTimes[_addr][i] = record.day;
            } else if (record.endTime < today) {
                unusedTimes[_addr][i] = 0;
            } else {
                uint256 dayID = (today - record.startTime).div(86400);
                // if (stakeStartTime[_addr] > today) {
                //     unusedTimes[_addr][i] = record.day - dayID - 1;
                // } else {
                    unusedTimes[_addr][i] = record.day - dayID;
                // }
            }
        }
    }

    function getStakeIds(address _addr) public view returns (uint256[] memory) {
        return myStakeIds[_addr];
    }

    

    function syncPoolData(address _addr) internal {
        if (!migration[_addr]) {
            bool poolIsMining = IntoPool.isMining(_addr);
            if (poolIsMining) {
                IntoPool.getStakeReceive(_addr);
            }
            syncBoxData(_addr);

            migration[_addr] = true;
            emit Migration(_addr);
        }
    }


    function updateStakeIds(address _addr) internal {
        for(uint256 i=0; i< myStakeIds[_addr].length; i++){
            uint256 index = myStakeIds[_addr][i];
            if(unusedTimes[_addr][index] == 0 && isUpdateAP[_addr][index]){
                myStakeIds[_addr][i] = myStakeIds[_addr][myStakeIds[_addr].length-1];
                myStakeIds[_addr].pop();
            }
        }
    }

    
    // function removeStakeIds(address _addr, uint256 count) public onlyAdmin {
    //     myStakeIds[_addr] = new uint256[](0);
    //     for(uint256 i=0; i< count; i++){
    //         myStakeIds[_addr].push(i);
    //     }
        
    // }
}
