// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./AdminRoleUpgrade.sol";

interface IIntoSocialWeight {
    function setSocialStatusData(address from, address to) external;

    function addSocialWeight(address from, address to) external;
}

contract IntoRedEnvelopeToMany is AdminRoleUpgrade, Initializable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;

    uint256 public time;
    bool private initialized;

    struct RedEnvelopeToMany {
        uint256 redEnvelopeIndex;
        uint256 tokenId;
        uint256 amount;
        uint256 balance;
        uint256 time;
        address sender;
        address[] reception;
        address [] alreadyReceive;
        uint256 status;
    }

    mapping(uint256 => address) public token;
    mapping(string => uint256) public tokenId;

    uint256 public redEnvelopeNum;
    mapping(uint256 => RedEnvelopeToMany) redEnvelopeToManyMapping;
    uint256[] public unreceivedRedEnvelopeIndex;

    IIntoSocialWeight intoSocialWeight;

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
        require(!initialized, "Contract instance has already been initialized");
        initialized = true;
        time = 60 * 60 * 24;
        tokenId["MATCH"] = 0;
        tokenId["USDT"] = 1;
        token[1] = tokenAddress;

        _addAdmin(msg.sender);
    }

    function setIntoSocialWeightInterface(address _intoSocialAddress) public onlyAdmin {
        intoSocialWeight = IIntoSocialWeight(_intoSocialAddress);
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
        RedEnvelopeToMany storage _redEnvelope = redEnvelopeToManyMapping[
                    _redEnvelopeIndex
            ];
        require(_redEnvelope.status == 0, "red envelope balance is 0");
        require(_redEnvelope.time < block.timestamp, "time isn't out");
        _redEnvelope.status = 2;
        uint256 _balance = _redEnvelope.balance;
        bool success;
        if (_redEnvelope.tokenId == 0) {
            (success,) = payable(_redEnvelope.sender).call{value: _balance}("");
        } else {
            success = IERC20Upgradeable(token[_redEnvelope.tokenId]).transfer(
                _redEnvelope.sender,
                _balance
            );
        }
        emit GetRelease(_redEnvelope.sender, _balance, block.timestamp);
        return success;
    }

    function getRelease() public {
        uint256 for_num = 0;
        for (uint256 i = 0; i < unreceivedRedEnvelopeIndex.length; i++) {
            if (for_num >= 5) {
                break;
            }
            uint256 releaseIndex = unreceivedRedEnvelopeIndex[i];
            RedEnvelopeToMany memory _redEnvelopeMemory = redEnvelopeToManyMapping[
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

    function sendRedEnvelopeToMany(
        uint256 _tokenId,
        address[] memory _reception,
        uint256 _amount
    ) public payable returns (uint256) {
        getRelease();

        uint256 redEnvelopeCountNum;
        redEnvelopeCountNum = _countNum();
        unreceivedRedEnvelopeIndex.push(redEnvelopeCountNum);

        RedEnvelopeToMany storage _newSender = redEnvelopeToManyMapping[
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
        _newSender.balance = _amount;

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
        for (uint256 i; i < _reception.length; i++) {
            intoSocialWeight.setSocialStatusData(msg.sender, _reception[i]);
            intoSocialWeight.addSocialWeight(msg.sender, _reception[i]);
        }

        return redEnvelopeCountNum;
    }

    function isReception(address _sender, uint256 _redEnvelopeIndex) public view returns (bool) {
        RedEnvelopeToMany memory _newSender = redEnvelopeToManyMapping[_redEnvelopeIndex];
        for (uint256 i; i < _newSender.reception.length; i++) {
            if (_newSender.reception[i] == _sender) {
                return true;
            }
        }
        return false;
    }

    function grabRedEnvelope(uint256 _redEnvelopeIndex) public returns (bool) {
        RedEnvelopeToMany storage _newSender = redEnvelopeToManyMapping[_redEnvelopeIndex];
        uint256 _amount = _newSender.amount / _newSender.reception.length;
        require(_newSender.status == 0, "red envelope balance is 0");
        require(isReception(msg.sender, _redEnvelopeIndex), "not a recipient");
        require(!isGrabbed(msg.sender, _redEnvelopeIndex), "already receive");
        _newSender.alreadyReceive.push(msg.sender);
        if (_newSender.reception.length == _newSender.alreadyReceive.length) {
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
        }

        bool success;
        _newSender.balance -= _amount;

        if (_newSender.tokenId == 0) {
            (success,) = payable(msg.sender).call{value: _amount}(
                ""
            );
        } else {
            success = IERC20Upgradeable(token[_newSender.tokenId]).transfer(
                msg.sender,
                _amount
            );
        }
        emit GrabRedEnvelope(
            msg.sender,
            _newSender.sender,
            _redEnvelopeIndex,
            _amount
        );
        return success;
    }

    function getRedEnvelopeToMany(uint256 _redEnvelopeIndex)
    public
    view
    returns (uint256 status)
    {
        RedEnvelopeToMany memory _newSender = redEnvelopeToManyMapping[_redEnvelopeIndex];
        return _newSender.status;
    }

    function setTime(uint256 _time) public onlyAdmin {
        time = _time;
    }

    function isGrabbed(address _sender, uint256 _redEnvelopeIndex) public view returns (bool)  {
        RedEnvelopeToMany memory _newSender = redEnvelopeToManyMapping[_redEnvelopeIndex];
        for (uint256 i; i < _newSender.alreadyReceive.length; i++) {
            if (_newSender.alreadyReceive[i] == _sender) {
                return true;
            }
        }
        return false;
    }
}
