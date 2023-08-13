// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IIntoInterface.sol";
import "./AdminRoleUpgrade.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IAuth {
    function faceAuthMessage(address _addr) external view returns(bytes memory);
}




contract IntoAuth is AdminRoleUpgrade, Initializable {
    event BindBABT(address addr, uint256 babtId);
    event MintNFT(address from, string name, uint256 token, uint256 favorite, uint256 count);
    event NFTStake(address from, string name, uint256 day, bool isTradable); 
    // 是否领取体验盲盒
    mapping(address => bool) public isReceive;

    // 体验盲盒是否被开启
    mapping(address => bool) public isOpen;

    uint256 public nftExchangeCount;

    address faceAuthAddress;
    address IntoPoolAddress;
    address activePointAddress;
    address IntoDataAddress;

    uint256 public  ownNFTCount;

    address BABTAddress;

    address IntoRelationAddress;
    bool public pause;

    mapping(address => uint256) public ownerTokenID;

    // 通过购买D级及以上盲盒实名
    mapping(address => bool) public nftAuth;
    // address
    function initialize() public initializer {
        _addAdmin(msg.sender);
        ownNFTCount = 1000000;
    }

    modifier check(){
        require(!pause, "Do not operate");
        _;
    }

    function setPause(bool _pause) external onlyAdmin{
        pause = _pause;
    }

    function setNftCount(uint256 _count) external onlyAdmin {
        ownNFTCount = _count;
    }

    // 批量初始化相关设置
    // faceAuthAddress  人脸认证还没有上线，暂时移除
    function setAboutAddress(address _IntoPoolAddress, address _activePointAddress, address _IntoRelationAddress, address _faceAuthAddress) external onlyAdmin{
        
        IntoPoolAddress = _IntoPoolAddress;
        activePointAddress = _activePointAddress;
        IntoRelationAddress = _IntoRelationAddress;
        faceAuthAddress = _faceAuthAddress;
    }

    function setBABTTokenID(uint256 _tokenID) external {
        IActionPoint(activePointAddress).initSetWithFirst(msg.sender);
        ownerTokenID[msg.sender] = _tokenID;
        emit BindBABT(msg.sender, _tokenID);
    }
    

    function receiveStake() external check {
        require(!isReceive[msg.sender], "already receive");
        require(ownNFTCount > nftExchangeCount, "Limit of quantity");
       
        nftExchangeCount ++;
        isReceive[msg.sender] = true;
        emit MintNFT(msg.sender, "F", 0, 0, nftExchangeCount);
    }

    // 开启挖矿
    function openStake() external check {
        require(isReceive[msg.sender], "Please pick it up");
        require(!isOpen[msg.sender], "already open");
        IActionPoint(activePointAddress).initSetWithFirst(msg.sender);
        IIntoPool(IntoPoolAddress).addStake(msg.sender, false, false, 40*10**18, 30, "F", 3);
        isOpen[msg.sender] = true;
        IActionPoint(activePointAddress).updateFavoriteAndPoint(msg.sender, 0, 9*10**18, 3, true, 10);
        emit NFTStake(msg.sender, "F", 30, false);
    }

    
    
    function validUser(address _addr) public view returns(bool){
        if(babtVerify(_addr)){
            return true;
        }else if(nftAuth[_addr]){
            return true;
        }else if(IAuth(faceAuthAddress).faceAuthMessage(_addr).length > 0){
            return true;
        }else if(hasStakeVerify(_addr)){
            return true;
        }

        return false;
    }

    function hasStakeVerify(address _addr) public view returns(bool){
        if(isOpen[_addr]){
            return false;
        }
        
        return IIntoPool(IntoPoolAddress).getValidBoxWithAuth(_addr);
              
    }

    
    // BABT认证
    function babtVerify( address _addr) public view returns(bool){
        if(ownerTokenID[_addr]>0){
            return true;
        }
        return false;
    }


    function getValidUserCount(address _addr) public view returns(uint256){
        address[] memory  invList =  IIntoRelation(IntoRelationAddress).getInvList(_addr);
        uint256 count = 0;
        for(uint256 i=0; i< invList.length; i++){
            address invAddr = invList[i];
            if(validUser(invAddr)){
                count++;
            }
        }
        return count;
    }


    function setNFTAuth(address _addr) external onlyAdmin{
        _setNFTAuth(_addr);
    }
    
    function _setNFTAuth(address _addr) internal {
        IActionPoint(activePointAddress).initSetWithFirst(_addr);
        if(!nftAuth[_addr]){
            nftAuth[_addr] = true;
        }
    }

    
}