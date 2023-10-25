// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "./AdminRoleUpgrade.sol";


interface IRelation {
    function Inviter(address _address) external returns (address);
}

contract IntoMedalToken is AdminRoleUpgrade, Initializable, ERC20BurnableUpgradeable {

    mapping(string => uint256) goodsPrice;
    address public TXAddress;
    address public relationAddress;

    event IntoMedalTokenLog(address from, address to, address spender, uint256 amount, uint256 types); // type 1 购买、2 兑换、 3 DID 4 转让 5 团队消耗


    function initialize(string memory name_, string memory symbol_) public initializer {
        __ERC20_init(name_, symbol_);
        _addAdmin(msg.sender);
    }

    function setTXAddress(address _address) external onlyAdmin {
        TXAddress = _address;
    }

    function setRelationAddress(address _address) external onlyAdmin {
        relationAddress = _address;
    }

    function decimals() public view virtual override returns (uint8) {
        return 0;
    }

    function inviteeConsume(address spender, uint256 amount) external onlyAdmin {
        address owner = IRelation(relationAddress).Inviter(spender);
        require(owner != address(0), "no relation");
        _burn(owner, amount);
        emit IntoMedalTokenLog(owner, address(0), spender, amount, 5);
    }


    function transfer(address to, uint256 amount) public virtual override returns (bool){
        _transfer(msg.sender, to, amount);
        emit IntoMedalTokenLog(msg.sender, to, address(0), amount, 4);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public virtual override onlyAdmin returns (bool) {
        _transfer(from, to, amount);
        emit IntoMedalTokenLog(from, to, address(0), amount, 4);
        return true;
    }

    function deductBalance(address from, uint256 amount) external onlyAdmin {
        _burn(from, amount);
        emit IntoMedalTokenLog(from, address(0), address(0), amount, 3);
    }

    function exchangeTX(uint256 amount) external {
        ERC20BurnableUpgradeable(TXAddress).burnFrom(msg.sender, amount);
        _mint(msg.sender, amount);
        emit IntoMedalTokenLog(address(0), msg.sender, address(0), amount, 2);
    }

    function mint(address recipient_, uint256 amount_) public onlyAdmin returns (bool){
        uint256 balanceBefore = balanceOf(recipient_);
        _mint(recipient_, amount_);
        uint256 balanceAfter = balanceOf(recipient_);
        emit IntoMedalTokenLog(address(0), recipient_, address(0), amount_, 1);
        return balanceAfter > balanceBefore;
    }
}
