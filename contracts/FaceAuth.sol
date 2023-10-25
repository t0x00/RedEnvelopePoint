//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./AdminRoleUpgrade.sol";

interface IERC20Burnable is IERC20Upgradeable {
    function burn(uint256 amount) external;

    function burnFrom(address account, uint256 amount) external;
}

interface IIntoMedalToken {
    function inviteeConsume(address spender, uint256 amount) external;

    function deductBalance(address from, uint256 amount) external;
}

interface IPledgeWeight {
    function addParentWeightByNew(address addr) external;
}

interface IWithdrawLimit {
    function withdrawBlack(address sender) external view returns (bool);
}

contract Auth is AdminRoleUpgrade, Initializable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using AddressUpgradeable for address;
    event Transfer(address from, address to, uint256 amount);
    event DID(address from, string msg);

    bool private initialized;
    uint256 public contract_chain_id;

    // 每条链的价格
    mapping(uint256 => uint256) public authPrice;
    // 人脸认证信息
    mapping(address => bytes) public faceAuthMessage;
    // 身份映射账号
    mapping(string => address) public faceAuthAddress;
    // 支付信息
    mapping(address => chainPayment[]) public paymentMessage;
    // 链上 token 的地址
    // TokenAddress[] public chainTokenAddress;
    mapping(string => address) public chainTokenAddress;

    struct chainPayment {
        uint256 chain_id;
        bool isPayment;
    }

    address public intoMedalToken;
    address public pledgeWeight;

    receive() external payable {}

    function initialize(
        uint256 chain_id,
        uint256 _price,
        address token,
        string memory token_name
    ) public initializer {
        require(!initialized, "Contract instance has already been initialized");
        initialized = true;
        // 初始化本次部署的链id
        contract_chain_id = chain_id;
        // 初始化本链认证的价格
        authPrice[chain_id] = _price;
        // 设置链支付所使用UDT的信息(name, address)
        chainTokenAddress[token_name] = token;

        _addAdmin(msg.sender);
    }

    function setIntoMedalToken(address _address) external onlyAdmin {
        intoMedalToken = _address;
    }

    function setPledgeWeight(address _address) public onlyAdmin {
        pledgeWeight = _address;
    }

    // 设置 当前合约支持支付的token
    function setTokenAddress(
        uint256 _chain_id,
        string memory _token_name,
        address _token
    ) public onlyAdmin {
        require(_chain_id == contract_chain_id, "");
        // chainTokenAddress.push(TokenAddress(_token, _token_name));
        chainTokenAddress[_token_name] = _token;
    }

    // 设置价格
    function setPrice(uint256 _chain_id, uint256 _price) external onlyAdmin {
        authPrice[_chain_id] = _price;
    }

    function isNullAddress(address addr) public pure returns (bool) {
        address none_addr;
        if (addr == none_addr) {
            return true;
        } else {
            return false;
        }
    }

    // 检查是否有已经支付过的链 支付返回true 未支付 返回false
    function checkPayment(
        uint256[] memory chain_id
    ) public view returns (bool) {
        chainPayment[] memory payment_message = paymentMessage[msg.sender];
        for (uint256 i = 0; i < chain_id.length; i++) {
            for (uint256 m = 0; m < payment_message.length; m++) {
                if (payment_message[m].chain_id == chain_id[i]) {
                    return true;
                }
            }
        }
        return false;
    }

    // 检查每条链的价格 未设置 默认为0 返回true 已设置 返回false
    function checkChainPrice(
        uint256[] memory chain_id
    ) public view returns (bool) {
        for (uint256 i = 0; i < chain_id.length; i++) {
            if (authPrice[chain_id[i]] == 0) {
                return true;
            }
        }
        return false;
    }

    // 比较两个字符串是否相同
    function hashCompareWithLengthCheckInternal(string memory a, string memory b) internal pure returns (bool) {
        if (bytes(a).length != bytes(b).length) {
            return false;
        } else {
            return keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b));
        }
    }

    //刷脸付款
    function paymentFaceAuth(
        string memory token_name,
        uint256[] memory chain_id
    ) public {
        // 不能为零地址
        require(msg.sender != address(0), "It is a zero address");
        // 所有链不能已经支付过
        require(
            !checkPayment(chain_id),
            "Have already paid in the chain array"
        );
        // 所选链不能未设置价格，即不支持
        require(
            !checkChainPrice(chain_id),
            "In the array, there are unsupported chains"
        );
        // 转账支付金额限制
        uint256 auth_price = 0;
        for (uint256 i = 0; i < chain_id.length; i++) {
            auth_price += authPrice[chain_id[i]];
        }
        if (hashCompareWithLengthCheckInternal(token_name, 'TX')) {
            // 只能是match 链
            require(chain_id.length == 1 && chain_id[0] == 9001, "INTO token only support match chain");
            // 不转账 直接burn
            IERC20Burnable(chainTokenAddress[token_name]).burnFrom(msg.sender, 1);
        } else {
            IERC20Upgradeable(chainTokenAddress[token_name]).transferFrom(
                msg.sender,
                address(this),
                auth_price
            );
        }
        emit Transfer(msg.sender, address(this), auth_price);
        // 支付成功则写入支付mapping
        for (uint256 i = 0; i < chain_id.length; i++) {
            paymentMessage[msg.sender].push(chainPayment(chain_id[i], true));
        }
    }

    function paymentWithMedalToken(uint256[] memory chain_id) public {
        require(chain_id.length == 1 && chain_id[0] == 9001, "MedalToken only support match chain");
        // 不能为零地址
        require(msg.sender != address(0), "It is a zero address");
        // 所有链不能已经支付过
        require(!checkPayment(chain_id), "Have already paid in the chain array");
        // 所选链不能未设置价格，即不支持
        require(!checkChainPrice(chain_id), "In the array, there are unsupported chains");
        // 支付
        IIntoMedalToken(intoMedalToken).deductBalance(msg.sender, 1);
        // 支付成功则写入支付mapping
        for (uint256 i = 0; i < chain_id.length; i++) {
            paymentMessage[msg.sender].push(chainPayment(chain_id[i], true));
        }
    }

    function paymentWithInviter(uint256[] memory chain_id) public {
        require(chain_id.length == 1 && chain_id[0] == 9001, "MedalToken only support match chain");
        // 不能为零地址
        require(msg.sender != address(0), "It is a zero address");
        // 所有链不能已经支付过
        require(!checkPayment(chain_id), "Have already paid in the chain array");
        // 所选链不能未设置价格，即不支持
        require(!checkChainPrice(chain_id), "In the array, there are unsupported chains");
        // 支付
        IIntoMedalToken(intoMedalToken).inviteeConsume(msg.sender, 1);
        // 支付成功则写入支付mapping
        for (uint256 i = 0; i < chain_id.length; i++) {
            paymentMessage[msg.sender].push(chainPayment(chain_id[i], true));
        }
    }

    //获取刷脸支付信息
    function getPaymentMessage(
        address sender
    ) public view onlyAdmin returns (chainPayment[] memory) {
        return paymentMessage[sender];
    }

    // 写入刷脸认证数据 python 后端加密存入
    function setFaceAuthMessage(
        address sender,
        string memory message
    ) public onlyAdmin {
        bytes memory message_bytes = bytes(message);
        require(message_bytes.length < 500, "message overlength");
        // 每条链 每个用户(同一身份证)只能认证一次
        require(
            isNullAddress(faceAuthAddress[message]),
            "Auth Error: identity has certified this chain"
        );
        bytes memory message_byte = faceAuthMessage[sender];
        require(message_byte.length == 0, "sender has already auth");

        faceAuthMessage[sender] = message_bytes;
        faceAuthAddress[message] = sender;
        // 仅适用于match链
        //payable(sender).transfer(0.1 ether); // 取消DID奖励
        emit DID(sender, message);

        // if (!IWithdrawLimit(0xa3FF6A43b990A6AF220d1B376E9e97E2621bcaD3).withdrawBlack(sender)) {
        //     IPledgeWeight(pledgeWeight).addParentWeightByNew(sender);
        // }
    }

    function resetFaceAuthAdmin(address account) public onlyAdmin {
        address add;
        faceAuthAddress[string(faceAuthMessage[account])] = add;
        bytes memory none;
        faceAuthMessage[account] = none;
    }

    function removePaymentMessage(address account, uint256 chainId) public onlyAdmin {
        chainPayment[] storage array = paymentMessage[account];
        for (uint256 i = 0; i <= array.length; i++) {
            chainPayment memory pay = array[i];
            if (pay.chain_id == chainId) {
                array[i] = array[array.length - 1];
                array.pop();
            }
        }
    }

    function setAuthMessageWithAdmin(address[] memory sender, string[] memory message) external onlyAdmin {
        for (uint256 i; i < sender.length; i++) {
            bytes memory message_bytes = bytes(message[i]);
            require(
                isNullAddress(faceAuthAddress[message[i]]),
                "Auth Error: identity has certified this chain"
            );
            bytes memory message_byte = faceAuthMessage[sender[i]];
            require(message_byte.length == 0, "sender has already auth");

            faceAuthMessage[sender[i]] = message_bytes;
            faceAuthAddress[message[i]] = sender[i];
            emit DID(sender[i], message[i]);
        }
    }

    function addDIDEvent(address[] memory sender, string[] memory message) external onlyAdmin {
        for (uint256 i; i < sender.length; i++) {
            emit DID(sender[i], message[i]);
        }
    }

    // 查询刷脸认证数据
    function getFaceAuthMessage(
        address account
    ) public view onlyAdmin returns (string memory) {
        return string(faceAuthMessage[account]);
    }

    function getAuthStatus(
        address account
    ) public view returns (bool) {
        bytes memory messageAccount;
        messageAccount = faceAuthMessage[account];
        if (hashCompareWithLengthCheckInternal(string(messageAccount), '')) {
            return false;
        } else {
            return true;
        }
    }

    function getAuthStatusMany(address[] memory _address) public view returns (bool[] memory)  {
        bool[] memory auth = new bool[](_address.length);
        for (uint256 i = 0; i < _address.length; i++) {
            auth[i] = getAuthStatus(_address[i]);
        }
        return auth;
    }

    // 从合约中取款
    function Migrate(
        address token,
        address to,
        uint256 amount
    ) external onlyAdmin {
        IERC20Upgradeable(token).safeTransfer(to, amount);
    }
}
