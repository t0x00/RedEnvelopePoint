// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

library IntoString {
    
    
    function checkBool (string memory _str1, string memory _str2) public pure returns(bool) {
        if(bytes(_str1).length == bytes(_str2).length){
            if(keccak256(abi.encodePacked(_str1)) == keccak256(abi.encodePacked(_str2))) {
                return true;
            }
        }
        return false;
    }
    
} 
