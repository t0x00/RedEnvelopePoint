// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;


import "./AdminRoleUpgrade.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "./librarys/BokkyPooBahsDateTimeLibrary.sol";


interface IIntoCollector {
    function getCollectorWithAddr(address _addr) external view returns(bool, bool, bool);
    function getCollectorList(uint256 _level) external view returns(address[] memory);
    function getCollectorCountWithLevel(uint256 _level) external view returns(uint256);
}

interface IIntoVip {
    // function vipList(uint256 _level) external view returns(address[] memory); 
    function getVipList(uint256 _level) external view returns(address[] memory);
    function getVipListCount(uint256 _level) external view returns(uint256);
    function ownerVipMap(address _addr) external view returns(uint256);
}


interface IIntoData {
    function batchUpdateToken(address[] memory _addrs, uint256 _token) external ;
    function ownerFeeLevelMap(address _addr) external view returns(uint256);
     function updateBalances(
        address _addr,
        uint256 _amount,
        bool isAdd
    ) external;
}

interface IActivePoint {
    function batchFavoriteValue(address[] memory _addrs, uint256 _value) external;
    function updateFavoriteValue(address _addr,uint256 _value, bool _isAdd) external;
}

interface IIntoRecord{
    function setBatchRecord(address[] memory _addrs,string memory _stype, string memory _source, uint256 _token)  external;
     function setAboutRecord(address _addr,string memory _stype, string memory _source, address _user, uint256 _token, bool _isAdd, bool _isValid, string memory _remark) external;
}


// 利益分红
contract IntoDividend is AdminRoleUpgrade, Initializable {
    event DividendToken(address from,string name, uint256 level, uint256 token);

    using BokkyPooBahsDateTimeLibrary for uint256;
    using SafeMathUpgradeable for uint256;

    mapping(uint256 => uint256) public dividendRatio;

    // 分红的碎片
    uint256 public devidendToken;

    // 今天分红时间
    uint256 public devidendTimestamp;

    IIntoVip meteVip;
    IIntoCollector collector;
    IIntoData IntoData;
    IActivePoint activePoint;
    IIntoRecord IntoRecord;

    // 时间戳=>收益
    mapping( uint256 => uint256) public dividendMap;

    mapping(address => uint256) public receiceTime;
    function initialize() public initializer {
        _addAdmin(msg.sender);
        // meteVip = IIntoVip(_vipAddress);
        // collector = IIntoCollector(_collectorAddress);
        // IntoData = IIntoData(_IntoDataAddress);
        // vip1分红比例
        dividendRatio[0] = 5;
        // vip2分红比例
        dividendRatio[1] = 15;
        // vip3分红比例
        dividendRatio[2] = 20;
        // vip4分红比例
        dividendRatio[3] = 10;
        // vip5分红比例
        dividendRatio[4] = 7;
        // vip6分红比例
        dividendRatio[5] = 3;
        // 前期收藏家
        dividendRatio[6] = 10;
        // 中期收藏家
        dividendRatio[7] = 10;
        // 后期收藏家
        dividendRatio[8] = 10;
        
    }


    function setAboutAddress(address _IntoVipAddr, address _collectorAddr, address _IntoDataAddr, address _activePointAddr, address _IntoRecordAddr) external onlyAdmin{
        meteVip = IIntoVip(_IntoVipAddr);
        collector = IIntoCollector(_collectorAddr);
        IntoData = IIntoData(_IntoDataAddr);
        activePoint = IActivePoint(_activePointAddr);
        IntoRecord = IIntoRecord(_IntoRecordAddr);
    }

    function getPrevDayTimestamp(uint256 _day) public view returns(uint256){
        return getTodayTimestamp() - _day*24*3600;
    } 



    // 获取东八区当天时间零点时间
    function getTodayTimestamp() public view returns (uint256) {
        uint256 timestamp = block.timestamp + 8*3600;
        return BokkyPooBahsDateTimeLibrary.timestampFromDate(timestamp.getYear(), timestamp.getMonth(), timestamp.getDay()) - 8*3600;
    }

    // 增加手续费
    function addDividendToken(uint256 _token) external onlyAdmin  {
        dividendMap[getTodayTimestamp()] += _token;
        // devidendToken += _token;
    }

    // 
    function setIntoRecordAddress(address _addr) external onlyAdmin{
        IntoRecord = IIntoRecord(_addr);
    }

    function setActivePointAddress(address _addr) external onlyAdmin{
        activePoint = IActivePoint(_addr);
    }

    function setDividendRatio(uint256 _key, uint256 _value) external onlyAdmin{
        dividendRatio[_key] = _value;
    }

    function setIntoDataAddress(address _addr) external onlyAdmin {
        IntoData = IIntoData(_addr);
        addAdmin(_addr);
    }
    
    function setIntoVipAddress(address _addr) external onlyAdmin {
        meteVip = IIntoVip(_addr);
    }

    function setCollectorAddress(address _addr) external onlyAdmin {
        collector = IIntoCollector(_addr);
    }
    
    // 分发收益
    function dividendToken(uint256 todayTimestamp) external  {
        // 如果当天还没有分发收益，那么分发收益的时间，应该小于当天东8区零点时间
        if(devidendTimestamp < todayTimestamp){
            for(uint i=0; i<9; i++){
                (address[] memory addrs, uint256 _token) = _dividendToken(devidendToken, i);
                    if(_token > 0){
                        // 批量增加token
                        IntoData.batchUpdateToken(addrs, _token);
                        // 分发利益。获得70%的收藏值
                        activePoint.batchFavoriteValue(addrs, _token);
                        string memory record_type = "vip";
                        if(i>=6){
                            record_type = "collector";
                        }
                        // 收益记录
                        IntoRecord.setBatchRecord(addrs,"token", record_type, _token);
                        // 利益分成给70%的收藏值记录
                        uint256 value = _token.mul(70).div(100);
                        IntoRecord.setBatchRecord(addrs,"favorite", record_type, value);
                    }
                    
            }

            devidendTimestamp = block.timestamp;
        }
    }
    
    function isReceiveDividends(address _addr) public view returns(uint256){
        if(receiceTime[_addr] > getTodayTimestamp()){
            return 0;
        }
        (bool early, bool mid, bool late) = collector.getCollectorWithAddr(_addr);
        uint256 preTimestamp =  getPrevDayTimestamp(1);
        uint256 totalToken  = dividendMap[preTimestamp];
        uint256 balaceToken = 0;
        if(early){
            uint256 ratio = dividendRatio[6];
            // 获取自身可以获取到的收益
            uint256 ownDividendToken = _operation(totalToken, ratio, 100, collector.getCollectorCountWithLevel(0));
            balaceToken += ownDividendToken;
        }
        

        if(mid){
            uint256 ratio = dividendRatio[7];
            uint256 ownDividendToken = _operation(totalToken, ratio, 100, collector.getCollectorCountWithLevel(1));
            balaceToken += ownDividendToken;
            
        }

        if(late){
            uint256 ratio = dividendRatio[8];
            uint256 ownDividendToken = _operation(totalToken, ratio, 100, collector.getCollectorCountWithLevel(2));
            balaceToken += ownDividendToken;
        }

        // vip等级分成
        uint256 level = meteVip.ownerVipMap(_addr);
        if(level > 0){
            uint256 ratio = dividendRatio[level-1];
            uint256 ownDividendToken = _operation(totalToken, ratio, 100, meteVip.getVipListCount(level));
            balaceToken += ownDividendToken; 
        }

        return balaceToken;
    }

    function receiveDividends(address _addr) public {
        require(receiceTime[_addr] < getTodayTimestamp(), "received today");
        //  early, mid, late
        (bool early, bool mid, bool late) = collector.getCollectorWithAddr(_addr);
        uint256 preTimestamp =  getPrevDayTimestamp(1);
        uint256 totalToken  = dividendMap[preTimestamp];
        uint256 balaceToken = 0;
        uint256 favoriteValue = 0;
        if(early){
            uint256 ratio = dividendRatio[6];
            // 获取自身可以获取到的收益
            uint256 ownDividendToken = _operation(totalToken, ratio, 100, collector.getCollectorCountWithLevel(0));
            balaceToken += ownDividendToken;
            IntoRecord.setAboutRecord(_addr, "token", "collector", _addr, ownDividendToken, true, true, "0");
            // 利益分成给70%的收藏值记录
            uint256 value = ownDividendToken.mul(70).div(100);
            favoriteValue += value;
            
            IntoRecord.setAboutRecord(_addr, "favorite", "collector", _addr, value, true, true, "0");
            emit DividendToken(_addr,"collector",0,ownDividendToken);
        }
        

        if(mid){
            uint256 ratio = dividendRatio[7];
            uint256 ownDividendToken = _operation(totalToken, ratio, 100, collector.getCollectorCountWithLevel(1));
            balaceToken += ownDividendToken;
            IntoRecord.setAboutRecord(_addr, "token", "collector", _addr, ownDividendToken, true, true, "1");
            // 利益分成给70%的收藏值记录
            uint256 value = ownDividendToken.mul(70).div(100);
            favoriteValue += value;
            
            IntoRecord.setAboutRecord(_addr, "favorite", "collector", _addr, value, true, true, "1");
            emit DividendToken(_addr,"collector",1,ownDividendToken);
        }

        if(late){
            uint256 ratio = dividendRatio[8];
            uint256 ownDividendToken = _operation(totalToken, ratio, 100, collector.getCollectorCountWithLevel(2));
            balaceToken += ownDividendToken;
            IntoRecord.setAboutRecord(_addr, "token", "collector", _addr, ownDividendToken, true, true, "2");
            // 利益分成给70%的收藏值记录
            uint256 value = ownDividendToken.mul(70).div(100);
            favoriteValue += value;
            
            IntoRecord.setAboutRecord(_addr, "favorite", "collector", _addr, value, true, true, "2");
            emit DividendToken(_addr,"collector",2,ownDividendToken);
        }

        // vip等级分成
        uint256 level = meteVip.ownerVipMap(_addr);
        if(level > 0){
            uint256 ratio = dividendRatio[level-1];
            uint256 ownDividendToken = _operation(totalToken, ratio, 100, meteVip.getVipListCount(level));
            balaceToken += ownDividendToken;
            string memory levelStr = "";
            if(level == 1){
                levelStr = "1";
            }else if(level == 2){
                levelStr = "2";
            }else if(level == 3){
                levelStr = "3";
            }else if(level == 4){
                levelStr = "4";
            }else if(level == 5){
                levelStr = "5";
            }else if(level == 6){
                levelStr = "6";
            }
            IntoRecord.setAboutRecord(_addr, "token", "vip", _addr, ownDividendToken, true, true, levelStr);
            // 利益分成给70%的收藏值记录
            uint256 value = ownDividendToken.mul(70).div(100);
            favoriteValue += value;
            
            IntoRecord.setAboutRecord(_addr, "favorite", "vip", _addr, value, true, true, levelStr);
            emit DividendToken(_addr, "vip",level, ownDividendToken);
        }

        if(balaceToken >0){
             IntoData.updateBalances(_addr, balaceToken, true);
             activePoint.updateFavoriteValue(_addr, favoriteValue, true);
        }

        receiceTime[_addr] = block.timestamp;
       
    }

    function _dividendToken(uint256 _token, uint256 _level) public view  returns(address[] memory, uint256) {
        address[] memory addrs;
        if(_level < 6){
            addrs = meteVip.getVipList(_level+1);
        }else{
            addrs = collector.getCollectorList(_level-6);
        }

        return (addrs, _dividendTokenCount(_level, _token, addrs.length));
    }

    function _dividendTokenCount(uint256 _level,uint256 _totalToken , uint256 _count) public view returns(uint256) {
        if(_count == 0){
            return 0;
        }
        uint256 ratio = dividendRatio[_level];
        if(_level == 0){
            return _operation(_totalToken, ratio, 100, _count);
        }else if(_level == 1){
            return _operation(_totalToken, ratio, 100, _count);
        }else if(_level == 2){
            return _operation(_totalToken, ratio, 100, _count);
        }else if(_level == 3){
            return _operation(_totalToken, ratio, 100, _count);
        }else if(_level == 4){
            return _operation(_totalToken, ratio, 100, _count);
        }else if(_level == 5){
            return _operation(_totalToken, ratio, 100, _count);
        }else if(_level == 6){
            return _operation(_totalToken, ratio, 100, _count);
        }else if(_level == 7){
            return _operation(_totalToken, ratio, 100, _count);
        }else if(_level == 8){
            return _operation(_totalToken, ratio, 100, _count);
        }
        return 0;
    }

    function _operation(uint256 _token, uint256 _numerator, uint256 _denominator, uint256 _count) internal pure returns(uint256){
        return _token.mul(_numerator).div(_denominator).div(_count);
    }

    
}