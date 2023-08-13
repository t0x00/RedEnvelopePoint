//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./AdminRole.sol";

contract Auth is AdminRole {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;


    address public owner;
    uint256 public contract_chain_id;

    // 每条链的价格
    mapping(uint256 => uint256) public authPrice;
    // 人脸认证信息
    mapping(address => bytes) public faceAuthMessage;
    // 支付信息
    mapping(address => chainPayment[]) public paymentMessage;
    // 链上 token 的地址
    // TokenAddress[] public chainTokenAddress;
    mapping(string => address) public chainTokenAddress;


    // struct TokenAddress {
    //     address token;
    //     string name;
    // }

    struct chainPayment {
        uint256 chain_id;
        bool isPayment;
    }

    constructor (uint256 chain_id, uint256 _price, address token, string memory token_name){
        owner = msg.sender;
        // 初始化本次部署的链id
        contract_chain_id = chain_id;
        // 初始化本链认证的价格
        authPrice[chain_id] = _price;

        setTokenAddress(chain_id, token_name, token);
    }

    // 设置 当前合约支持支付的token
    function setTokenAddress(uint256 _chain_id, string memory _token_name, address _token) public onlyAdmin {
        require(_chain_id == contract_chain_id, "");
        // chainTokenAddress.push(TokenAddress(_token, _token_name));
        chainTokenAddress[_token_name] = _token;
    }

    // 设置价格
    function setPrice(uint256 _chain_id, uint256 _price) external onlyAdmin {
        require(msg.sender == owner, "Auth Error: is not owner");
        authPrice[_chain_id] = _price;
    }

    // 通过地址判定合约是否支持当前虚拟货币
    function requireToken(address _token,string memory _token_name) private view returns (bool){
        // for (uint256 i = 0; i < chainTokenAddress.length; i++) {
        //     if (chainTokenAddress[i].token == _token) {
        //         return true;
        //     }
        // }
        if (chainTokenAddress[_token_name]==_token){
            return true;
        }
        return false;
    }

    // 获取所有支持付款的虚拟货币
    // function getChainTokenAddress() public view returns (chainTokenAddress){
    //     return chainTokenAddress;

    // }

    //刷脸付款
    function paymentFaceAuth(address token,string memory token_name, uint amount, uint256[] memory chain_id) public {
        // 不能为零地址
        require(msg.sender != address(0), " it is a zero address");
        // 转账支付金额限制
        uint256 auth_price = 0;
        for (uint256 i = 0; i < chain_id.length; i++) {
            auth_price += authPrice[chain_id[i]];
        }
        require(amount == auth_price, "Pay Error: price is incorrect");
        require(requireToken(token, token_name), "");
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        // 支付成功则写入支付mapping

        for (uint i = 0; i < chain_id.length; i++) {
            paymentMessage[msg.sender].push(chainPayment(chain_id[i], true));
        }

    }

    //获取刷脸支付信息
    function getPaymentMessage(address sender) public view onlyAdmin returns (chainPayment[] memory) {
        return paymentMessage[sender];
    }

    // 写入刷脸认证数据 python 后端加密存入
    function setFaceAuthMessage(address sender, string memory message) public onlyAdmin {
        require(msg.sender == owner, "caller is not owner");
        bytes memory message_bytes = bytes(message);
        require(message_bytes.length < 500, "message overlength");
        faceAuthMessage[sender] = message_bytes;

    }

    // 查询刷脸认证数据
    function getFaceAuthMessage() public view onlyAdmin returns (string memory){
        return string(faceAuthMessage[msg.sender]);
    }

    // TODO 从合约中取款
}
