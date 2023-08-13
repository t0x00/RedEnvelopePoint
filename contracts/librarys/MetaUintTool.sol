// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./BokkyPooBahsDateTimeLibrary.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";

library IntoUintTool {
    
    using BokkyPooBahsDateTimeLibrary for uint256;
    using SafeMathUpgradeable for uint256;

    // 获取东8区下一天零点时间
    function getNextDayTimestamp(uint256 timestamp) public pure returns(uint256 nextTimestamp){
        timestamp += 8*3600;
        uint256 newTimestamp =  BokkyPooBahsDateTimeLibrary.addDays(timestamp, 1);
        // 因为在东8区，所以要减去8小时
        nextTimestamp = BokkyPooBahsDateTimeLibrary.timestampFromDate(newTimestamp.getYear(), newTimestamp.getMonth(), newTimestamp.getDay()) - 8*3600 ;
    }

    // 获取结束时间
    function getStakeEndTime(uint256 timestamp, uint256 _day) public pure returns(uint256 newTimestamp){
        newTimestamp = getNextDayTimestamp(timestamp) + _day*24*3600;
    }

    // 获取当天时间
    function getTodayTimestamp(uint256 timestamp) public pure returns (uint256) {
        // 
        uint256 newTimestamp = timestamp + 8*3600;
        return BokkyPooBahsDateTimeLibrary.timestampFromDate(newTimestamp.getYear(), newTimestamp.getMonth(), newTimestamp.getDay()) - 8*3600;
    }

    

    function getFeeLevelToken(uint256 _token, uint256 level) public pure returns(uint256) {
        if(level == 1){
            return getToken(_token, getFeeLevelFee(level), 100);
        }else if(level == 2){
            return getToken(_token, getFeeLevelFee(level), 100);
        }else if(level == 3){
            return getToken(_token, getFeeLevelFee(level), 100);
        }else if(level == 4){
            return getToken(_token, getFeeLevelFee(level), 100);
        }else if(level == 5){
            return getToken(_token, getFeeLevelFee(level), 100);
        }else if(level == 6){
            return getToken(_token, getFeeLevelFee(level), 100);
        }
        
        return getToken(_token, 50, 100);
    }

    function getFeeLevelFee(uint256 level) public pure returns(uint256){
        if(level == 1){
            return 50;
        }else if(level == 2){
            return 40;
        }else if(level == 3){
            return 35;
        }else if(level == 4){
            return 30;
        }else if(level == 5){
            return 25;
        }else if(level == 6){
            return 20;
        }
        
        return 50;
    }


    function getToken(uint256 _token, uint256 _molecular, uint256 _denominator) public pure returns(uint256){
        return _token.mul(_molecular).div(_denominator);
    }

    function retnNftDetail(uint256 _index) public pure returns(
        uint256 exchangeToken, uint256 exchangeFavoriteValue, uint256 expectToken, uint256 day, uint256 favoriteValue, uint256 activePoint, string memory name, bool isStake, string memory stype, uint256 total
    ){
        if(_index == 0){
            return (getDecimalToken(30), 0, getDecimalToken(36), 30, getFavoriteValue(9), 3, "E", false, "E", 500000);
        }
        else if(_index == 1){
            return (getDecimalToken(300), 0, getDecimalToken(360), 30, getFavoriteValue(90), 30, "D", false, "D", 200000);
        }else if(_index == 2){
            return (getDecimalToken(1000), 0, getDecimalToken(1220), 35, getFavoriteValue(300), 100, "C", false, "C", 30000);
        }else if(_index == 3){
            return (getDecimalToken(3000), 0, getDecimalToken(3720), 35, getFavoriteValue(900), 300, "B", false , "B", 5000);
        }else if(_index == 4){
            return (getDecimalToken(10000), 0, getDecimalToken(12700), 40, getFavoriteValue(3000), 1000, "A", false , "A", 2000);
        }else if(_index == 5){
            return (getDecimalToken(30000), 0, getDecimalToken(40000), 40, getFavoriteValue(10000), 3000, "S", false, "S" ,300);
        }else if(_index == 6){
            return (getDecimalToken(30), getFavoriteValue(30), getExtraToken(), 30, getFavoriteValue(45), 3, "E", true , "TE", 250000);
        }else if(_index == 7){
            return (getDecimalToken(300), getFavoriteValue(300), getDecimalToken(369), 30, getFavoriteValue(450), 30, "D", true , "TD", 100000);
        }else if(_index == 8){
            return (getDecimalToken(1000), getFavoriteValue(1000), getDecimalToken(1525), 35, getFavoriteValue(1500), 100, "C", true , "TC", 15000);
        }else if(_index == 9){
            return (getDecimalToken(3000), getFavoriteValue(3000), getDecimalToken(3810), 35, getFavoriteValue(4500), 300, "B", true , "TB", 2500);
        }else if(_index == 10){
            return (getDecimalToken(10000), getFavoriteValue(10000), getDecimalToken(13000), 40, getFavoriteValue(15000), 1000, "A", true , "TA", 1000);
        }else if(_index == 11){
            return (getDecimalToken(30000), getFavoriteValue(30000), getDecimalToken(40800), 40, getFavoriteValue(45000), 3000, "S", true , "TS", 150);
        }else if(_index == 12){
            return (getDecimalToken(30), 0, getDecimalToken(40), 30, getFavoriteValue(9), 3, "F", false, "F", 1000000);
        }

        return (getDecimalToken(0), 0, getDecimalToken(0), 30, getFavoriteValue(0), 0, "G", false,"G",0 );


    }

    function getDecimalToken(uint256 _token) public pure returns(uint256){
        return _token*10**18;
    }

    function getExtraToken() public pure returns(uint256){
        return 36.9*10**18;
        
    }

    // 收藏值 精度为18
    function getFavoriteValue(uint256 _value) public pure returns(uint256){
        return _value*10**18;
    }


   function getownNFTCount(uint256 _value) public pure returns(string memory,uint8)  {
        if(_value == 0){
            return ("E", 10);
        }else if(_value == 1){
            return ("D", 6);
        }else if(_value == 2){
            return ("C", 2);
        }else if(_value == 3){
            return ("B", 2);
        }else if(_value == 4){
            return ("A", 1);
        }else {
            return ("S", 1);
        }

    }

}


