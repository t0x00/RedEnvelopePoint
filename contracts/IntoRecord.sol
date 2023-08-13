// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
import "./IIntoInterface.sol";
import "./librarys/BokkyPooBahsDateTimeLibrary.sol";
import "./AdminRoleUpgrade.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
// 交易收益    日期 

// 类型
// 挖矿收益 

// 分红收益   
// 团队分红 
// 收藏家分红 

// 直推收益

// 二代收益 

// 需要给IntoData、IntoDividend权限，可以调合约
contract IntoRecord is AdminRoleUpgrade, Initializable {
    event ERecord(address to, string stype, string source, address from, uint256 token, bool isAdd, bool isValid, string remark);
    using BokkyPooBahsDateTimeLibrary for uint256;
    // 类型 -> 时间 -> 收益
    // mapping(address => mapping(string => mapping(uint256 => uint256))) public records;

    struct Record{
        string stype;
        string source;
        uint256 time;
        address user;
        uint256 token;
        bool isAdd;
        bool isValid;
        string remark;
       
    }

    

    mapping(address => Record[]) public myRecords;

    struct MigrationRecord{
        Record[] records;
    }

    struct MRecords{
        address addr;
        Record record; 
    }

    mapping(address => mapping(uint256=> Record[])) public myDateRecords;
    function initialize() public initializer {
        _addAdmin(msg.sender);
  
    } 
    

    function getRecords(address addr) public view returns(Record[] memory){
        return myRecords[addr];
    }

    function getNextDayTimestamp(uint256 _day) public view returns(uint256){
        return getTodayTimestamp() - _day*24*3600;
    } 

    function getRecordsWithDataTimestamp(address _addr, uint256 _timestamp) public view returns(Record[] memory){
        return myDateRecords[_addr][_timestamp];
    }

    // 获取东八区当天时间零点时间
    function getTodayTimestamp() public view returns (uint256) {
        uint256 timestamp = block.timestamp + 8*3600;
        return BokkyPooBahsDateTimeLibrary.timestampFromDate(timestamp.getYear(), timestamp.getMonth(), timestamp.getDay()) - 8*3600;
    }

    function setBatchRecord(address[] memory _addrs,string memory _stype, string memory _source, uint256 _token) public onlyAdmin{
        for(uint256 i=0; i< _addrs.length; i++){
            // setRecordWithString(_addrs[i], _name, _token, true);
            
             _setAboutRecord(_addrs[i], _stype, _source, address(0), _token, true, true, "");
        }
    }




    function setAboutRecord(address _addr,string memory _stype, string memory _source, address _user, uint256 _token, bool _isAdd, bool _isValid, string memory _remark) public onlyAdmin{
        _setAboutRecord(_addr, _stype, _source, _user, _token, _isAdd, _isValid, _remark);
        
    }
    
    function _setAboutRecord(address _addr,string memory _stype, string memory _source, address _user, uint256 _token, bool _isAdd, bool _isValid, string memory _remark) internal {
        // uint256 timestamp = getTodayTimestamp();
        // myRecords[_addr].push(Record(_stype, _source, block.timestamp, _user, _token, _isAdd, _isValid, _remark));
        // myDateRecords[_addr][timestamp].push(Record(_stype, _source, block.timestamp, _user, _token, _isAdd, _isValid, _remark));
        emit ERecord(_addr, _stype, _source, _user, _token, _isAdd, _isValid, _remark);
    }

     function checkStrBool (string memory _str1, string memory _str2) public pure returns(bool) {
        if(bytes(_str1).length == bytes(_str2).length){
            if(keccak256(abi.encodePacked(_str1)) == keccak256(abi.encodePacked(_str2))) {
                return true;
            }
        }
        return false;
    }
    

    // 获取无效token
    function getInvalidToken(address _addr) public view returns(uint256){
        uint256 timestamp = getTodayTimestamp();
        // Records[] memory records = myDateRecords[_addr][timestamp];
        uint256 count = myDateRecords[_addr][timestamp].length;
        if(count == 0){
            return 0;
        }
        // bool isContinue = true;
        uint256 invalidToken = 0;

        for(uint256 i=0; i< count; i++){
            Record memory record =myDateRecords[_addr][timestamp][i];
            if(checkStrBool(record.stype, "token")){
                if(checkStrBool(record.source, "first") || checkStrBool(record.source, "second")){
                    if(!record.isValid){
                       invalidToken+=record.token; 
                    }
                }
            }
        }


        // while(isContinue){
        //     Record memory record = myRecords[_addr][count-1];
        //     if(record.time < today){
        //         isContinue = false;
        //     }
        //     if(checkStrBool(record.stype, "token")){
        //         if(checkStrBool(record.source, "first") || checkStrBool(record.source, "second")){
        //             if(!record.isValid){
        //                invalidToken+=record.token; 
        //             }
        //         }
        //     }

        //     count--;
        //     if(count == 0){
        //         isContinue = false;
        //     }
           
        // }

        return invalidToken;
        
    }

    function batchSetRecord(address addr, Record[] memory records) external onlyAdmin{
       
        for(uint256 i=0; i< records.length; i++){
            myRecords[addr].push(records[i]);
        }
    }

    
    function batchGetRecord(address[] memory addrs) external view returns(MRecords[] memory){
        uint256 count = 0;
        uint256 index = 0;
        for(uint256 i=0; i< addrs.length; i++){
            count += myRecords[addrs[i]].length;
        }


        MRecords[] memory records = new MRecords[](count);
        for(uint256 i=0; i< addrs.length; i++){
            for(uint256 j=0; j< myRecords[addrs[i]].length; j++){
                records[index] = MRecords(addrs[i], myRecords[addrs[i]][j]);
                index += 1;
            }
        }

        return records;
    }

    function batchUpdateData(MRecords[] memory _records) external onlyAdmin{
        for(uint256 i=0; i< _records.length; i++){
            MRecords memory mrecord = _records[i];
            myRecords[mrecord.addr].push(mrecord.record);
        }
    }
    
}