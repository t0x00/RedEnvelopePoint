// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./AdminRoleUpgrade.sol";


contract IntoRedEnvelopePoint is AdminRoleUpgrade, Initializable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;


    uint256 public time;
    uint256 public redEnvelopeNum;
    mapping(uint256 => address) public token;
    mapping(string => uint256) public tokenId;

    mapping(uint256 => RedEnvelope) redEnvelopeMapping;
    uint256[] public unreceivedRedEnvelopeIndex;

    struct RedEnvelope {
        uint256 redEnvelopeIndex;
        uint256 tokenId;
        uint256 amount;
        uint256 time;
        address sender;
        address reception;
        uint256 status;
    }


    event SendRedEnvelope(
        address _sender,
        uint256 _amount,
        uint256 _redEnvelopeIndex
    );
    event GrabRedEnvelope(
        address _mine,
        address _sender,
        uint256 _whichRE,
        uint256 _amount
    );
    event GetRelease(address _sender, uint256 _leftRed, uint256 _nowTime);

    function initialize(address tokenAddress) public initializer {
        tokenId["TOXTEST"] = 2;
        token[2] = tokenAddress;
        time = 86400;
        _addAdmin(msg.sender);
    }

    function setToken(
        string memory _tokenName,
        address _tokenAddress,
        uint256 _tokenId
    ) public onlyAdmin {
        tokenId[_tokenName] = _tokenId;
        token[_tokenId] = _tokenAddress;
    }

    function _countNum() internal returns (uint256) {
        redEnvelopeNum += 1;
        return redEnvelopeNum;
    }

    function _getReleaseByIndex(uint256 _redEnvelopeIndex) internal returns (bool) {
        RedEnvelope storage _redEnvelope = redEnvelopeMapping[
        _redEnvelopeIndex
        ];

        require(_redEnvelope.status == 0, "red envelope balance is 0");
        require(_redEnvelope.time < block.timestamp, "time isn't out");

        _redEnvelope.status = 2;
        uint256 _amount = _redEnvelope.amount;
        bool success;

        if (_redEnvelope.tokenId == 0) {
            (success,) = payable(_redEnvelope.sender).call{value : _amount}("");
        } else {
            success = IERC20Upgradeable(token[_redEnvelope.tokenId]).transfer(
                _redEnvelope.sender,
                _amount
            );
        }

        emit GetRelease(_redEnvelope.sender, _amount, block.timestamp);
        return success;
    }

    function getRelease() public {
        uint256 for_num = 0;
        for (uint256 i = 0; i < unreceivedRedEnvelopeIndex.length; i++) {
            if (for_num >= 5) {
                break;
            }
            uint256 releaseIndex = unreceivedRedEnvelopeIndex[i];
            RedEnvelope memory _redEnvelopeMemory = redEnvelopeMapping[
            releaseIndex
            ];
            if (_redEnvelopeMemory.time < block.timestamp && _redEnvelopeMemory.status == 0) {
                unreceivedRedEnvelopeIndex[i] = unreceivedRedEnvelopeIndex[
                unreceivedRedEnvelopeIndex.length - 1
                ];
                unreceivedRedEnvelopeIndex.pop();
                for_num += 1;
                _getReleaseByIndex(releaseIndex);
            }
        }
    }

    // 发红包
    function sendRedEnvelope(
        uint256 _tokenId,
        address _reception,
        uint256 _amount
    ) public payable returns (uint256) {

        getRelease();

        uint256 redEnvelopeCountNum;
        redEnvelopeCountNum = _countNum();
        unreceivedRedEnvelopeIndex.push(redEnvelopeCountNum);

        RedEnvelope storage _newSender = redEnvelopeMapping[
        redEnvelopeCountNum
        ];
        if (_tokenId == 0) {
            require(
                _amount == msg.value,
                "The amount is not equal to the amount actually paid"
            );
            _newSender.amount = msg.value;
        } else {
            IERC20Upgradeable(token[_tokenId]).transferFrom(
                msg.sender,
                address(this),
                _amount
            );

            _newSender.amount = _amount;
        }

        uint256 _nowTime = block.timestamp;
        _newSender.tokenId = _tokenId;
        _newSender.time = time + _nowTime;
        _newSender.redEnvelopeIndex = redEnvelopeCountNum;
        _newSender.sender = msg.sender;
        _newSender.reception = _reception;
        _newSender.status = 0;

        emit SendRedEnvelope(
            _newSender.sender,
            _newSender.amount,
            _newSender.redEnvelopeIndex
        );
        return redEnvelopeCountNum;
    }

    function grabRedEnvelope(uint256 _redEnvelopeIndex) public returns (bool) {
        RedEnvelope storage _newSender = redEnvelopeMapping[_redEnvelopeIndex];

        require(_newSender.status == 0, "red envelope balance is 0");
        require(_newSender.reception == msg.sender, "not a recipient");
        _newSender.status = 1;
        for (uint256 i = 0; i < unreceivedRedEnvelopeIndex.length; i++) {
            if (unreceivedRedEnvelopeIndex[i] == _redEnvelopeIndex) {
                unreceivedRedEnvelopeIndex[i] = unreceivedRedEnvelopeIndex[
                unreceivedRedEnvelopeIndex.length - 1
                ];
                unreceivedRedEnvelopeIndex.pop();
                break;
            }
        }
        bool success;

        if (_newSender.tokenId == 0) {
            (success,) = payable(msg.sender).call{value : _newSender.amount}(
                ""
            );
        } else {
            success = IERC20Upgradeable(token[_newSender.tokenId]).transfer(
                msg.sender,
                _newSender.amount
            );
        }
        emit GrabRedEnvelope(
            msg.sender,
            _newSender.sender,
            _redEnvelopeIndex,
            _newSender.amount
        );
        return success;
    }

    function getRedEnvelope(uint256 _redEnvelopeIndex)
    public
    view
    returns (uint256 status)
    {
        RedEnvelope memory _newSender = redEnvelopeMapping[_redEnvelopeIndex];
        return _newSender.status;
    }

    function setTime(uint256 _time) public onlyAdmin {
        time = _time;
    }
}
