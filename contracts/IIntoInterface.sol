// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


interface IExchangeNFT {

    function NFTToOwner(uint256 _index) external view returns (address);

    function getOneNFTDetail(uint256 _index)
        external
        view
        returns (
            uint256 exchangeToken,
            uint256 exchangeFavoriteValue,
            uint256 expectToken,
            uint256 day,
            uint256 favoriteValue,
            uint256 _activePoint,
            string memory name,
            bool isStake,
            bool isOpenNFT
        );

    function getOwnerNFTList(address _addr) external view returns(uint256[] memory);
    function transferNFTWithSell(address _from, address _to, uint256 _tokenID) external;
    function isAddStake(address _addr, string memory _type) external;
    function addAdmin(address account) external;
    function removeAdmin(address account) external;

}

interface IIntoRelation{

    // 获取直推下级地址
    function getInvList(address addr_)
        external view
        returns(address[] memory _addrsList);

    // 获取直推人数 
    function invListLength(address addr_) external view returns(uint256);
    
    // 获取父级
    function Inviter(address _addr) external view returns(address);
}

interface IIntoPool{
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
    function getBoxStake(address _addr) external view returns(StakeDetail[] memory);

    function addStake(address _addr, bool _isSend, bool _isTradable, uint256 _expectToken, uint256 _day,  string memory _name, uint256 _activePoint) external;
    function nftCountFromStake(address _addr, string memory _boxType) external view returns(uint256);
    function getLevelWithStake(address _addr) external view returns (uint256);
    function getValidBoxWithAuth(address _addr) external view returns(bool);
    function stakeStartTime(address _addr) external view returns(uint256);
    function isMining(address _addr) external view returns(bool);
    function getStakeReceive(address _addr) external;
}

interface IActionPoint {
     function updateFavoriteAndPoint(address _addr, uint256 subFavoritetValue, uint256 addFavoriteValue, uint256 actionPoint, bool isAddPoint, uint256 _count) external;
     function favoriteValueMap(address _addr) external view returns(uint256);

     function setTradingFavorite(address _addr, uint256 _value, bool isInto) external;
     function getRatioFavorite(uint256 _value, bool isInto) external view returns(uint256);
     function updateFavoriteValue(address _addr,uint256 _value, bool _isAdd) external;
    // function updateOwnActionPoint(address _sender) external;
    function updateParentFavoriteValueWithValid(address _addr) external;
    function updateFavoriteAndPointWithMCPT(address _addr, uint256 subFavoritetValue, uint256 addFavoriteValue, uint256 actionPoint,  bool isAddPoint, uint256 _count) external;
    function updateParentActivePointWithValid(address _addr) external;
     function initSetWithFirst(address _addr) external;

}

interface IIntoData{
    function balances(address _addr) external view returns(uint256);
    function ownerFeeLevelMap(address _addr) external view returns(uint256);
    function setBalances(address _addr, uint256 _amount) external;
    function updateBalances(address _addr, uint256 _amount, bool isAdd) external;
    function IntoaddDividendToken(uint256 _token) external;
    function addAdmin(address account) external;
    function removeAdmin(address account) external;
    function transferTokenWithSell(address _from, address _to,uint256 _token, uint256 _status) external;
   
    function getMemberCount(address _addr) external view returns(uint256);
    function getChildMembers(address _addr) external view returns(address[] memory);
    function getParent(address _addr) external view returns(address);
    function getPoint(address _addr) external view returns(uint256, uint256, uint256, uint256);
    function updateOwnerFeeLevel(address _addr) external;
    
    
}

interface IBABT {
    function tokenIdOf(address owner) external view returns(uint256);
    function balanceOf(address owner) external view returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address); 
}

interface IIntoAuth {
     function validUser(address _addr) external view returns(bool);
     function getValidUserCount(address _addr) external view returns(uint256);
    // function isTrande(address _addr) external view returns(bool);
    function setNFTAuth(address _addr) external;
}

interface IIntoRecord{
    function setAboutRecord(address _addr,string memory _stype, string memory _source, address _user, uint256 _token, bool _isAdd, bool _isValid, string memory _remark) external;
     function setBatchRecord(address[] memory _addrs,string memory _stype, string memory _source, uint256 _token) external;
}

interface IIntoDividend{
     function receiveDividends(address _addr) external;
}


