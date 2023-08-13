// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./AdminRoleUpgrade.sol";
import "./librarys/IntoUintTool.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IIntoInterface.sol";



// 兑换NFT合约  
contract ExChangeNFT is AdminRoleUpgrade, Initializable {

    event MintNFT(address from, string name, uint256 token, uint256 favorite, uint256 count);
    event NFTStake(address from, string name, uint256 day, bool isTradable);

    using SafeMathUpgradeable for uint256;
    using IntoUintTool for uint256;

    address public _burnAddress;
    // 各类型盲盒质押的数量
    mapping(string => uint256) public  ownNFTCount;

    // 未出售、出售中、已出售
    struct NFTDetail{
        // 兑换需要的碎片
        uint256 exchangeToken;
        //兑换需要的收藏值
        uint256 exchangeFavoriteValue;

        // 预估奖励
        uint256 expectToken;
        // 挖矿时间
        uint256 day;

        // 得到的收藏值
        uint256 favoriteValue;
        // 得到的活跃点
        uint256 activePoint;

        // 盲盒类型 
        string name;
        
        // 是否挖矿
        bool isStake;

        // 是否开启盲盒
        bool isOpenNFT;
        // 是否可交易
        bool isTradable;
        // // 是否增加收藏值
        bool isAddPoint;
    }

    // 合成的盲盒 ==7
    NFTDetail[] public NFTList;

    // 拥有的盲盒数量 == 7
    mapping(address => uint256) public ownerNFTCount;
    // NFT盲盒的所有者 === 7
    mapping(uint256 => address) public NFTToOwner; 
    // 拥有盲盒的数目 == 7
    mapping(address =>uint256[]) public ownerNFTList;

    //NFT生成或产出所需要的条件,盲盒详情  ==
    mapping(string => NFTDetail) public NFTDetailMap;
    
    // 发行总量 ==
    mapping(string => uint256) public nftTotalCount;
    // 盲盒已兑换的数量 == 7
    mapping(string => uint256) public nftExchangeCount;

     // 得到盲盒的时间 ==7
    mapping(uint256 => uint256) public getNftTime;

     IActionPoint activePoint;
     IIntoData IntoData;
     IIntoPool IntoPool;

    // 是否赠送的NFT == 7
     mapping(uint256 => bool) public isSendNFT;


    IIntoRecord IntoRecord;
    bool public pause;

    struct NFTMigration{
        uint256[] ownerNFTLists;
    }
    
    IIntoAuth IntoAuth;
    modifier isCheckExchange(string memory _type){
        require(nftTotalCount[_type] > nftExchangeCount[_type], "Limit of quantity");
        _;
    }
    
     function initialize() public initializer {
        initNFTData();
        _addAdmin(msg.sender);
         _burnAddress = 0x000000000000000000000000000000000000dEaD;
    }

    modifier check(){
        require(!pause, "Do not operate");
        _;
    }


    function setPause(bool _pause) external onlyAdmin{
        pause = _pause;
    }

    // 初始化NFT盲盒
    function initNFTData() internal {

        for (uint i=0; i< 6; i++){
            (string memory _type, uint8 _num) = i.getownNFTCount();
            ownNFTCount[_type] = _num;
        }

        // 盲盒总数
        for(uint i=0; i < 13; i++){
            (uint256 exchangeToken, uint256 exchangeFavoriteValue, uint256 expectToken, uint256 day, uint256 favoriteValue, uint256 _activePoint, string memory name, bool _isStake, string memory stype, uint256 total) = i.retnNftDetail();
            NFTDetailMap[stype] = NFTDetail( exchangeToken,  exchangeFavoriteValue,  expectToken,  day,  favoriteValue,  _activePoint,  name,  false, false, _isStake, false);
            nftTotalCount[stype] = total;
        }
       
    }

    
    
    function setAboutAddress(address _activePointAddr, address _IntoDataAddr, address _poolAddr, address _IntoRecordAddr, address _IntoAuthAddr) external onlyAdmin{
        activePoint = IActionPoint(_activePointAddr);
        IntoData = IIntoData(_IntoDataAddr);
        IntoPool = IIntoPool(_poolAddr);
        IntoRecord = IIntoRecord(_IntoRecordAddr);
        IntoAuth = IIntoAuth(_IntoAuthAddr);
    }
    
    // 获取自身盲盒数组下标
    function getOwnerNFTList(address _addr) external view returns(uint256[] memory){
        return ownerNFTList[_addr];
    } 
    
    
    // MCP 兑换 盲盒
    function MCPExchangeNFT(string memory _type) external  isCheckExchange(_type) check {
        require(block.timestamp < 1670947200, "Do not operate");
        require(getStakeCount(msg.sender, _type) < ownNFTCount[_type], "Limit of quantity");
        NFTDetail memory nftDetail = NFTDetailMap[_type];
        require(!nftDetail.isTradable, "Only redeemable for non-tradable blind boxes");
        // 测试链
        // 0x767C1Ba10f0580211d1eC7D476F85CeeF886FeD0
        // bsc
        // 0x30aC82f35177A83d4e65A016c67163d485f925a1
        // polygon
        // 0x180BDb6075fa2E5DC6360e17245Bb66c4403D7e6
        IERC20(0x180BDb6075fa2E5DC6360e17245Bb66c4403D7e6).transferFrom(msg.sender,_burnAddress,nftDetail.exchangeToken);
        _createNFT(msg.sender, nftDetail, false);
        nftExchangeCount[_type]++; 
        activePoint.initSetWithFirst(msg.sender);
        activePoint.updateFavoriteAndPointWithMCPT(msg.sender,  nftDetail.exchangeFavoriteValue,nftDetail.favoriteValue, nftDetail.activePoint, true, 30);
    }


    
    function exchangeNFT(string memory _type, uint256 _level) external isCheckExchange(_type) check {
        
        address sender = msg.sender;
        
        NFTDetail memory nftDetail = NFTDetailMap[_type];
        // 用户碎片必须大于需要的碎片
        uint256 exchangeTotalToken = getExchangeTotalToken(msg.sender,nftDetail.exchangeToken, nftDetail.isTradable); 
        require(IntoData.balances(sender) >= exchangeTotalToken, "token limit");

        uint256 exchangeFavoriteValue = nftDetail.exchangeFavoriteValue;
        
        // 不可交易盲盒，需判断是否达到质押数量
        if(nftDetail.isTradable){
            // 收藏值判断 
            require(activePoint.favoriteValueMap(sender) >= exchangeFavoriteValue, "favorite value limit");
            // 可交易盲盒有交易手续费、扣除收藏值
            IntoData.IntoaddDividendToken(exchangeTotalToken - nftDetail.exchangeToken);
            activePoint.updateFavoriteValue(msg.sender, exchangeFavoriteValue, false);
            IntoRecord.setAboutRecord(msg.sender, "favorite", "nft", msg.sender, exchangeFavoriteValue, false, true, _type);
        }
        
        IntoData.updateBalances(msg.sender, exchangeTotalToken, false);
        // balances[msg.sender] -= exchangeTotalToken;
        // 生成盲盒
        nftDetail.isAddPoint = true;
        _createNFT(msg.sender, nftDetail, false);
        // 减少收藏值
        nftExchangeCount[_type]++; 

        if(_level >=2 ){
            IntoAuth.setNFTAuth(msg.sender);
        }

        IntoRecord.setAboutRecord(msg.sender, "token", "nft", msg.sender, exchangeTotalToken, false, true, _type);
        
        emit MintNFT(msg.sender, _type, exchangeTotalToken, exchangeFavoriteValue, nftExchangeCount[_type]);
    } 

    // 盲盒的质押数量，
    function getStakeCount(address _addr, string memory _type ) public view returns(uint256){
        uint256[] memory lists = ownerNFTList[_addr];
        uint256 count = 0;
        for(uint256 i=0; i< lists.length; i++){ 
            if(NFTToOwner[lists[i]] == _addr){
            
            
            NFTDetail memory nft = NFTList[lists[i]];
            if(keccak256(abi.encodePacked(_type)) == keccak256(abi.encodePacked(nft.name))) {
                if(!nft.isStake && !nft.isOpenNFT && !nft.isTradable){
                    count ++;
                }
                
            }
            }
        
        }
        return count + IntoPool.nftCountFromStake(_addr, _type);
    }

    // 是否添加收藏值、是否是赠送的
    function _createNFT(address _addr,NFTDetail memory _nft,  bool _isSend) internal {
        NFTList.push(_nft);
        uint256 nftID = NFTList.length - 1;
        NFTToOwner[nftID] = _addr;
        ownerNFTCount[_addr]++;
        ownerNFTList[_addr].push(nftID);
        getNftTime[nftID] = block.timestamp;
        
        if(_isSend){
            isSendNFT[nftID] = true;
        }
        
             
    }

    
    // 开启挖矿
    function nftOpenStake(uint256 _index) external check {
        require(msg.sender == NFTToOwner[_index], "you are not owner");
        NFTDetail storage nft = NFTList[_index];
        require(!nft.isStake, "already stake");
        require(!nft.isOpenNFT, "already open NFT");
        nft.isStake = true;

        // 同步之前的数据
        activePoint.initSetWithFirst(msg.sender);
        addStake(msg.sender, nft, isSendNFT[_index]);
        // 这里需要加收藏值和活跃度
        if(nft.isAddPoint){
            activePoint.updateFavoriteAndPoint(msg.sender, 0,nft.favoriteValue, nft.activePoint, true, 30);
        }
        emit NFTStake(msg.sender, nft.name, nft.day, nft.isTradable);
    }

     function isAddStake(address _addr, string memory _type) public onlyAdmin {
        require(nftExchangeCount[_type] < nftTotalCount[_type], "Limit of quantity");
        
        NFTDetail memory _nft = NFTDetailMap[_type]; 
        nftExchangeCount[_type]++; 
        _nft.isAddPoint = true;
        _createNFT(_addr, _nft,  true);
        
    }

    function addStake(address _addr, NFTDetail memory _nft, bool _isSend) internal{
        IntoPool.addStake(_addr, _isSend, _nft.isTradable, _nft.expectToken, _nft.day,  _nft.name, _nft.activePoint);
    }

 
    // // 兑换需要的碎片
    function getExchangeTotalToken(address _addr, uint256 _token, bool _isTradable) internal view returns(uint256){
        
        if(!_isTradable){
            return _token;
        }

        return _token.add(_token.getFeeLevelToken( IntoData.ownerFeeLevelMap(_addr)));
    }
    
     
    // 这个线上需要部署 已部署 
    // function initTrandeNFT() public onlyAdmin{
    //      for(uint i=6; i < 12; i++){
    //         (uint256 exchangeToken, uint256 exchangeFavoriteValue, uint256 expectToken, uint256 day, uint256 favoriteValue, uint256 _activePoint, string memory name, bool _isStake, string memory stype,) = i.retnNftDetail();
    //         NFTDetailMap[stype] = NFTDetail( exchangeToken,  exchangeFavoriteValue,  expectToken,  day,  favoriteValue,  _activePoint,  name,  false, false, _isStake, false);
            
    //     }
    // }

    // 前端接口，获取自身的交易等级,
    function getOwnFeeLevelFee(address _addr) public view returns(uint256){
        // return  IntoData.ownerFeeLevelMap(_addr).getFeeLevelFee();
        uint256 level = IntoData.ownerFeeLevelMap(_addr);
       
        if(level == 0){
            return 50;
        }
        
        return level.getFeeLevelFee();
    } 
    
    function getOneNFTDetail(uint256 _index) external view returns(uint256 exchangeToken, uint256 exchangeFavoriteValue, uint256 expectToken, uint256 day, uint256 favoriteValue, uint256 _activePoint, string memory name, bool isStake,  bool isOpenNFT){
        NFTDetail memory nftDetail = NFTList[_index];
        return (nftDetail.exchangeToken, nftDetail.exchangeFavoriteValue, nftDetail.expectToken, nftDetail.day, nftDetail.favoriteValue, nftDetail.activePoint, nftDetail.name, nftDetail.isStake, nftDetail.isOpenNFT);
    }

    function setOwnNFTCount(string memory _type, uint256 _count) external onlyAdmin{
        ownNFTCount[_type] = _count;
    }

    function setNFTDetail(string memory _name, uint256 _day, uint256 _favoriteValue, uint256 _activePoint) external onlyAdmin {
       NFTDetail storage nft = NFTDetailMap[_name];
       nft.day = _day;
       nft.favoriteValue = _favoriteValue;
       nft.activePoint = _activePoint;
    }

    function getNFTTotalCount(string memory _name, uint256 _count) external onlyAdmin{
        nftTotalCount[_name] = _count;
    }
    

    function transferNFTWithSell(address _from, address _to, uint256 _tokenID) external onlyAdmin{
        require(NFTToOwner[_tokenID] == _from, "Not the owner");
        NFTToOwner[_tokenID] = _to;
        ownerNFTList[_to].push(_tokenID);
        ownerNFTCount[_from]--;
        ownerNFTCount[_to]++;
        getNftTime[_tokenID] = block.timestamp;
        _unbind(_from, _tokenID);
    }

    function _unbind(address _addr, uint256 _tokenID) internal {

        uint256 num = ownerNFTList[_addr].length;
        bool isPop;
        for(uint256 i=0; i< ownerNFTList[_addr].length; i++){
            if(ownerNFTList[_addr][i] == _tokenID){
                ownerNFTList[_addr][i] = ownerNFTList[_addr][num -1] ;
                isPop = true;
            }
        }

        if(isPop && num > 0){
            ownerNFTList[_addr].pop();
        }
    }
    

    
    
    

}