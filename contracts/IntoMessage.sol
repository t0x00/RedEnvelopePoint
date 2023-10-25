// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./IIntoInterface.sol";
import "./AdminRoleUpgrade.sol";

interface IIntoSocialWeight {
    function setSocialStatusData(address from, address to) external;

    function addSocialWeight(address from, address to) external;

    function intoSocialWeightInterface(address from, address[] memory to) external;
}

contract IntoMessage is AdminRoleUpgrade, Initializable {
    event Message(address addr, string uid, string from, string to, string text);
    event MessageMany(address addr, string uid, string from, string[] to, string text);

    struct Msg {
        string uind;
        string from;
        string to;
        string text;
        uint256 timestamp;
        address source;
        string stype;
    }

    mapping(string => Msg[]) public ownerMsg;

    IIntoBind intoBind;
    IIntoSocialWeight intoSocialWeight;

    function initialize() public initializer {
        _addAdmin(msg.sender);
    }

    function setIntoSocialWeightInterface(address _intoSocialAddress) public onlyAdmin {
        intoSocialWeight = IIntoSocialWeight(_intoSocialAddress);
    }

    function setAboutAddress(address _intoBindAddr) external onlyAdmin {
        intoBind = IIntoBind(_intoBindAddr);
    }

    function upploadMsg(string calldata from, string calldata to, string calldata text) external {
        require(intoBind.isBind(msg.sender), "from address is not bound");
        require(intoBind.isBind(intoBind.mainAddr(to)), "to address is not bound");
        string memory uid = intoBind.bindUid(msg.sender);
        ownerMsg[uid].push(Msg(uid, from, to, text, block.timestamp, msg.sender, "text"));
        intoSocialWeight.setSocialStatusData(intoBind.mainAddr(from), intoBind.mainAddr(to));
        intoSocialWeight.addSocialWeight(intoBind.mainAddr(from), intoBind.mainAddr(to));
        emit Message(msg.sender, uid, from, to, text);
    }

    function upploadMsgMany(string calldata from, string[] calldata to, string calldata text) external {
        require(intoBind.isBind(msg.sender), "from address is not bound");
        string memory uid = intoBind.bindUid(msg.sender);
        address[] memory uidAddress=intoBind.getMainBindAddressManyReturnAddress(to);
        intoSocialWeight.intoSocialWeightInterface(msg.sender, uidAddress);
        emit MessageMany(msg.sender, uid, from, to, text);
    }

    function getMsg(string memory uid) external view returns (Msg[] memory){
        return ownerMsg[uid];
    }


    function getMsgLength(string memory uid) external view returns (uint256){
        return ownerMsg[uid].length;
    }
}