// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./AdminRoleUpgrade.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";

interface IIntoRelation {
    function Inviter(address _addr) external view returns(address);
    function bindLv(address _addr) external view returns(uint256);
    function memberAmount(address _addr) external view returns(uint256);

    function userAddr(uint256 _user) external view returns(address);
    function userID(address _addr) external view returns(uint256);

    function invStats(address _addr) external view returns(bool);
    function getInvList(address addr_)
        external view
        returns(address[] memory);
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

interface IIntoERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}


interface IIntoActivePoint{
    struct Point {
        // 自身产生的活跃点
        uint256 ownerActivePoint;
        // 小区活跃点
        uint256 teamActivePoint;
        // 团队活跃度
        uint256 totalChildActivePoint;
    }

    function ownerPointMap(address addr) external view returns(Point memory);
    function favoriteValueMap(address addr) external view returns(uint256);
    function onwerInvalidActivePoint(address addr) external view returns(uint256);
    function ownerParentInvalidFV(address addr) external view returns(uint256);
    function ownerGrandparentsInvalidFV(address addr) external view returns(uint256);
    function ownerInvalidFV(address addr) external view returns(uint256);
    

}

interface IExchangeNFT{
    function ownerNFTCount(address) external view returns(uint256);
    function NFTToOwner(uint256) external view returns(address);
    function nftExchangeCount(string memory) external view returns(uint256);
    function getNftTime(uint256)  external view returns(uint256);
    function isSendNFT(uint256) external view returns(bool);
}

interface IOrder {
    function Migrate(
        address token,
        address to,
        uint256 amount
    ) external;

    enum OrderType {
        NFT,
        BOX,
        TOKEN
    }
    function orderType() external view returns(OrderType);
    enum Status {
        Create,
        Closed,
        Cancel,
        Locked,
        Inactive
    }

    function status() external view returns(Status);
    function isAll() external view returns(bool);
    function tokenID() external view returns(uint256);
    function buyer() external view returns(address);
    function price() external view returns(uint256);
    function boxType() external view returns(string memory);
}



contract Migration is AdminRoleUpgrade, Initializable{
    using AddressUpgradeable for address payable;
    struct RelationInvList{
        address[] invLists;
    }
    
    
    IIntoRelation IntoRelation;
    IIntoActivePoint activePoint;
    IExchangeNFT exchangeNFT;
    IIntoERC20 IntoERC20;
    address public WMatic;
    function initialize() public initializer {
        // initNFTData();
        _addAdmin(msg.sender);
    }

    function setAboutAddress(address _IntoRelationAddr, address _IntoActionPointAddr, address _exchangeNFTAddr, address _IntoERC20Addr, address _WMaticAddr) external {
        IntoRelation = IIntoRelation(_IntoRelationAddr);
        activePoint = IIntoActivePoint(_IntoActionPointAddr);
        exchangeNFT = IExchangeNFT(_exchangeNFTAddr);
        IntoERC20 = IIntoERC20(_IntoERC20Addr);
        WMatic = _WMaticAddr;
    }


    // function batchIntoRelationData(address[] memory addrs) external view returns(address[] memory, uint256[] memory, uint256[] memory,  uint256[] memory, bool[] memory){
    //     uint256 len = addrs.length;
    //     address[] memory Inviter = new address[](len);
    //     uint256[] memory bindLv = new uint256[](len);
    //     uint256[] memory memberAmount = new uint256[](len);
    //     // address[] memory userAddr = new address[](len);
    //     uint256[] memory userID = new uint256[](len);
    //     bool[] memory invStats = new bool[](len);

    //     for(uint256 i=0; i< len; i++){
    //         address addr = addrs[i];
    //         Inviter[i] = IntoRelation.Inviter(addr);
    //         bindLv[i] = IntoRelation.bindLv(addr);
    //         memberAmount[i] = IntoRelation.memberAmount(addr);
    //         userID[i] = IntoRelation.userID(addr);
    //         invStats[i] = IntoRelation.invStats(addr);
    //     }

    //     return (Inviter, bindLv, memberAmount, userID, invStats);
        
    // }



    // function batchIntolationInvList(address[] memory addrs) external view returns(RelationInvList[] memory){
    //     RelationInvList[] memory invLists = new RelationInvList[](addrs.length);
    //     for(uint256 i=0; i< addrs.length; i++){
    //         invLists[i].invLists = IntoRelation.getInvList(addrs[i]);
    //     }

    //     return invLists;
    // }


    // // *********************ActivePoint***********************
    // function batchIntoActivePointData(address[] memory addrs) external view returns(uint256[] memory,uint256[] memory,uint256[] memory,uint256[] memory,uint256[] memory){
    //     uint256 len = addrs.length;
    //     uint256[] memory favoriteValueMaps = new uint256[](len);
    //     uint256[] memory onwerInvalidActivePoints = new uint256[](len);
    //     uint256[] memory ownerParentInvalidFVs = new uint256[](len);
    //     uint256[] memory ownerGrandparentsInvalidFVs = new uint256[](len);
    //     uint256[] memory ownerInvalidFVs = new uint256[](len);

    //     for(uint256 i=0; i< len; i++){
    //         address addr = addrs[i];
    //         favoriteValueMaps[i] = activePoint.favoriteValueMap(addr);
    //         onwerInvalidActivePoints[i] = activePoint.onwerInvalidActivePoint(addr);
    //         ownerParentInvalidFVs[i] = activePoint.ownerParentInvalidFV(addr);
    //         ownerGrandparentsInvalidFVs[i] = activePoint.ownerGrandparentsInvalidFV(addr);
    //         ownerInvalidFVs[i] = activePoint.ownerInvalidFV(addr);
    //     }


    //     return (favoriteValueMaps, onwerInvalidActivePoints, ownerParentInvalidFVs, ownerGrandparentsInvalidFVs, ownerInvalidFVs);


    // }

    // function batchActionPoint(address[] memory addrs) external view returns(IIntoActivePoint.Point[] memory){
    //     IIntoActivePoint.Point[] memory points = new IIntoActivePoint.Point[](addrs.length);

    //     for(uint256 i=0; i<addrs.length; i++){
    //         address addr = addrs[i];
    //         points[i] = activePoint.ownerPointMap(addr);

    //     }

    //     return points;
    // }

    // // **************************exchangeNFT****************************
    // function batchGetOwnerNFTCount(address[] memory addrs) external view returns(uint256[] memory){
    //     uint256 len = addrs.length;
    //     uint256[] memory ownerNFTCounts = new uint256[](len);
    //     for(uint256 i=0; i< len; i++){
    //         address addr = addrs[i];
    //         ownerNFTCounts[i] = exchangeNFT.ownerNFTCount(addr);
    //     }
    //     return ownerNFTCounts;

    // }
    

    // function batchGetIntData(uint256 needcount) external view returns(address[] memory, uint256[] memory, bool[] memory){
    //     address[] memory NFTToOwners = new address[](needcount);
    //     uint256[] memory  getNftTimes = new uint256[](needcount);
    //     bool[] memory isSendNFTs = new bool[](needcount);
    //     for(uint256 i=0; i< needcount; i++){
    //         NFTToOwners[i] = exchangeNFT.NFTToOwner(i);
    //         getNftTimes[i] = exchangeNFT.getNftTime(i);
    //         isSendNFTs[i] = exchangeNFT.isSendNFT(i);
    //     }

    //     return (NFTToOwners, getNftTimes, isSendNFTs);
    // }

    // function batchGetnftExchangeCount(string memory _type) external view returns(uint256){
    //     return exchangeNFT.nftExchangeCount(_type);
    // }


    // // *********************************ERC20 MCPT**************************************
    // function batchERC20Balances(address[] memory addrs) external view returns(uint256[] memory){
    //     uint256[] memory balances = new uint256[](addrs.length);

    //     for(uint256 i=0; i< addrs.length; i++){
    //         balances[i] = IntoERC20.balanceOf(addrs[i]);
    //     }

    //     return balances;

    // }


    // function batchUpdateBalances(address[] memory addrs, uint256[] memory _balances) external onlyAdmin{
    //     for(uint256 i=0; i< addrs.length; i++){
    //         if(_balances[i] > 0 && addrs[i] != msg.sender){
    //             IIntoERC20(0x180BDb6075fa2E5DC6360e17245Bb66c4403D7e6).transferFrom(msg.sender, addrs[i], _balances[i]);
    //         }
            
    //     }
    // }

    // receive() external payable {
    //     require(msg.sender == WMatic, "OrderBook: invalid sender");
    // }

    // function batchTransferBalances(address[] memory addrs) external payable onlyAdmin{
    //     for(uint256 i=0; i< addrs.length; i++){
    //         // if(_balances[i] > 0 && addrs[i] != msg.sender){
    //         //     // IIntoERC20(0x0000000000000000000000000000000000001010).transferFrom(msg.sender, addrs[i], _balances[i]);
    //         // }
    //         address payable addr = payable(addrs[i]);
    //         uint256 _amountOut = 1*10**17;
    //         IWETH(WMatic).withdraw(_amountOut);
    //         addr.sendValue(_amountOut);

    //     }
    // }


    // function batchAllBalances(address  _addr, uint256 _amountOut) external payable onlyAdmin{
    //     IWETH(WMatic).withdraw(_amountOut);
    //     address payable addr = payable(_addr);
    //     addr.sendValue(_amountOut);
    // }
    
     function getDataWithOrders(address[] memory addrs) external view returns(uint256[] memory, uint256[] memory,uint256[] memory,bool[] memory,address[] memory, string[] memory ){
        uint256 len = addrs.length;
        uint256[] memory prices = new uint256[](len);
        uint256[] memory status = new uint256[](len);
        // uint256[] memory orderTypes = new uint256[](len);
        uint256[] memory tokenIDS = new uint256[](len);
        bool[] memory isAlls = new bool[](len);
        
        address[] memory buyers = new address[](len);
        string[] memory boxTypes = new string[](len);


        for(uint256 i=0; i< len; i++){
            address addr = addrs[i];
            prices[i] = IOrder(addr).price();
            status[i] = uint256(IOrder(addr).status());
            try IOrder(addr).isAll() {
                isAlls[i] = IOrder(addr).isAll();
            } catch {
                isAlls[i] = true;
            }

            // orderTypes[i] = uint256(IOrder(addr).orderType());
            tokenIDS[i] = IOrder(addr).tokenID();
            buyers[i] = IOrder(addr).buyer();

            try IOrder(addr).boxType() {
                 boxTypes[i] = IOrder(addr).boxType();
            } catch {
                boxTypes[i] = "";
            }
            

            // boxTypes[i] = IOrder(addr).boxType();
        }

        return (prices,status, tokenIDS, isAlls, buyers, boxTypes);

    }


}