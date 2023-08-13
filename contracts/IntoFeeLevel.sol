// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./AdminRoleUpgrade.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "./IIntoInterface.sol";



// 等级手续费需要重新部署

contract IntoFeeLevel is AdminRoleUpgrade, Initializable {
    // 等级手续费

    // IExchangeNFT exchangeNFT;
    address poolAddr;


    address IntoAuthAddr;

    // 交易等级手续费
    mapping(address => uint256) public ownerFeeLevelMap;
    function setAboutAddress(address _poolAddr,  address _IntoAuthAddr) external onlyAdmin {
        // exchangeNFT = IExchangeNFT(_dataAddr);
        poolAddr = _poolAddr;
        
        IntoAuthAddr = _IntoAuthAddr;
    }

    function initialize() public initializer {
        _addAdmin(msg.sender);
    } 

    function updateOwnerFeeLevel(address _addr) public {
        ownerFeeLevelMap[_addr] = setFeeLevel(_addr);
    }
    

    function setFeeLevel(address _addr) public view returns (uint256) {
        uint256 level = 1;

        uint256 invLevel = getLevelWithInv(_addr);
        level = (
            invLevel > level ? invLevel : level
        );
        if (level == 6) {
            return level;
        }
       

        // level = (getLevelWithNft(_addr) > level? getLevelWithNft(_addr) : level);
        // if (level == 6) {
        //     return level;
        // }
        uint256 stakeLevel = IIntoPool(poolAddr).getLevelWithStake(_addr);
        level = (stakeLevel > level? stakeLevel : level);
        
        return level;
    }

    // function getLevelWithNft(address _addr) public view returns (uint256) {
    //     uint256[] memory uints = exchangeNFT.getOwnerNFTList(_addr);
    //     uint256 level = 1;
        
    //     for (uint256 i = 0; i < uints.length; i++) {
    //         if (exchangeNFT.NFTToOwner(uints[i]) == _addr) {
    //             (
    //                 ,
    //                 ,
    //                 ,
    //                 ,
    //                 ,
    //                 ,
    //                 string memory name,
    //                 bool isStake,
                    
                    
    //             ) = exchangeNFT.getOneNFTDetail(uints[i]);
    //             if (!isStake) {
    //                 if (checkBool(name, "D") && level < 2) {
    //                     level = 2;
    //                 } else if (checkBool(name, "C") && level < 3) {
    //                     level = 3;
    //                 } else if (checkBool(name, "B") && level < 4) {
    //                     level = 4;
    //                 } else if (checkBool(name, "A") && level < 5) {
    //                     level = 5;
    //                 } else if (checkBool(name, "S") && level < 6) {
    //                     level = 6;
    //                 }
    //             }
    //         }
    //     }
    //     return level;
    // }

    
    

    function getLevelWithStake(address _addr) public view returns (uint256) {
        // return level;
        return IIntoPool(poolAddr).getLevelWithStake(_addr);
    }

    

   

    // 这里是有效直推，所以逻辑需要更改
    function getLevelWithInv(address _addr) public view returns (uint256) {
        // uint256 count = IntoRelation.getMemberCount(_addr);
        uint256 count = IIntoAuth(IntoAuthAddr).getValidUserCount(_addr);

        if (count >= 50) {
            return 6;
        } else if (count >= 30) {
            return 5;
        } else if (count >= 20) {
            return 4;
        } else if (count >= 10) {
            return 3;
        } else if (count >= 5) {
            return 2;
        } else {
            return 1;
        }
        
    }
}
