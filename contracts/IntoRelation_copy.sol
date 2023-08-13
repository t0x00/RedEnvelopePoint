//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// import '@openzeppelin/contracts/access/Ownable.sol';
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./AdminRole.sol";

contract IntoRelation_copy is AdminRole {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;
    using Address for address;

    uint256 public UID = 10000001;
    address public USDT = 0x55d398326f99059fF775485246999027B3197955;
    address public _burnAddress = 0x000000000000000000000000000000000000dEaD;
    mapping(address => address) public Inviter;
    mapping(address => uint256) public bindLv;
    mapping(address => uint256) public memberAmount;
    mapping(uint256 => address) public userAddr;
    mapping(address => uint256) public userID;    
    mapping(address => bool) public invStats;
    mapping(address => address[]) public invList;


    constructor(){
        invStats[0x3DeEF4EA4086EAFDa8a2c193A3693DC60DeC07D6] = true;
        invStats[0x481A5a49A18cE850924143b714BA7889BD0D1ff3] = true;
        userAddr[10000000] = 0x481A5a49A18cE850924143b714BA7889BD0D1ff3;
        userAddr[9999999] = 0x3DeEF4EA4086EAFDa8a2c193A3693DC60DeC07D6;
    }

    function bind(address addr) 
    public
    {
        require(!invStats[msg.sender],"BIND ERROR: ONCE BIND");
        require(invStats[addr],"BIND ERROR: INVITER NOT BIND");
        _bind(addr,msg.sender);
        _recordMemberAmount(addr);
    }


    function _bind(address addr,address newaddr) 
    internal 
    {
        Inviter[newaddr] = addr;
        invList[addr].push(newaddr);
        invStats[newaddr]= true;
        bindLv[newaddr] = bindLv[addr] +1 ;
        userAddr[UID] = newaddr;
        userID[newaddr] = UID;
        UID++;
    }

    function _recordMemberAmount(address addr) 
    internal 
    {
        memberAmount[addr] += 1;
        uint256 Lv = bindLv[addr];
        address invAddr = Inviter[addr];
        for(uint256 i = 0;i< Lv;i++){
        memberAmount[invAddr] += 1;
        invAddr = Inviter[invAddr];
        }
    }


    function _unbind(address addr) internal{
        if(Inviter[addr] != address(0)){
        address account = Inviter[addr];
        uint256 num = invList[account].length - 1;
        for(uint256 i=0;i< invList[account].length;i++){
            if(invList[account][i] == addr){
                invList[account][i] = invList[account][num]; 
            }
        }
            invList[account].pop();
        }
    }


    function BatchBind(address[] memory addrs, address[] memory invs)  external onlyAdmin{
        for(uint256 i = 0; i < addrs.length; i++ ){
            _unbind(addrs[i]);
            _bind(invs[i],addrs[i]);
            _recordMemberAmount(addrs[i]);
        }
    }

    function setBindLv(address addr_, uint256 lv_) external onlyAdmin{
        bindLv[addr_] = lv_;
    }

    function BatchSetBindLv(address[] memory addrs, uint256[] memory lvls) external onlyAdmin{
        for(uint256 i=0;i< addrs.length;i++){
        bindLv[addrs[i]] = lvls[i];
        }
    }

    function invListLength(address addr_) public view returns(uint256)
    {
        return invList[addr_].length;
    }

    function getInvList(address addr_)
        public view
        returns(address[] memory _addrsList)
    {
        _addrsList = new address[](invList[addr_].length);
        for(uint256 i=0;i<invList[addr_].length;i++){
            _addrsList[i] = invList[addr_][i];
        }
    }

    function Migrate(address token, address to, uint256 amount) external onlyAdmin {
        IERC20(token).safeTransfer(to, amount);
    }

    function setStates(address addr) external onlyAdmin{
        invStats[addr]= true;
    }


    }

