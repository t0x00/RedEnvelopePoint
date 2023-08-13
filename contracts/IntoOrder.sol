// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./IIntoInterface.sol";
import "./AdminRole.sol";
import "./AdminRoleUpgrade.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IERC20 {
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);
}

interface IPurchase {
    function addAdmin(address account) external;

    function removeAdmin(address account) external;

    function saveSellOrder(address _addr, address _orderAddr) external;

}

interface IOrder {
    function Migrate(
        address token,
        address to,
        uint256 amount
    ) external;

    enum OrderType {
        NFT,
        BOX,
        TOKEN
    }
    function orderType() external view returns(OrderType);
    enum Status {
        Create,
        Closed,
        Cancel,
        Locked,
        Inactive
    }

    function status() external view returns(Status);
    // function isAll() external view returns(bool);
    // function tokenID() external view returns(uint256);
    // function buyer() external view returns(address);
    // function price() external view returns(uint256);
}

contract Purchase is AdminRoleUpgrade, Initializable {
    event NewOrder(
        address from,
        uint256 orderType,
        string boxType,
        uint256 tokenID,
        uint256 price
    );
    // 买家订单
    mapping(address => address[]) public buyOrder;

    address erc20Address;

    address IntoDataAddress;
    address IntoAuthAddress;

    // 上线浮动
    uint256 public depositRatio;
    // 过期时间， 默认时间是24小时
    uint256 public expireTime;
    // 所有订单的地址
    // address payable[]  public orders;
    address[] public orders;

    // 最新订单的地址
    address public lastOrder;

    address[] public nftOrders;
    address[] public boxOrders;
    address[] public tokenOrders;

    mapping(address => address[]) public sellOrders;

    address exchangeNFTAddr;

    bool public pause;

    uint256 public maxRatio;
    uint256 public minRatio;

    uint256 public basePrice;

    // function initialize() public initializer {
    //     _addAdmin(msg.sender);
    //     expireTime = 24 * 3600;
    //     depositRatio = 1;
    // }

    modifier check() {
        require(!pause, "Do not operate");
        _;
    }

    function setPause(bool _pause) external onlyAdmin {
        pause = _pause;
    }

    // 设置基础值
    function setBasePrice(uint256 _price) external onlyAdmin{
        basePrice = _price;
    }
    // 设置上下浮动值 整数比如10% 就是 10
    function setDepositRatio(uint256 _ratio) external onlyAdmin {
        depositRatio = _ratio;
    }
    // 设置交易时间，精确到秒比如 24*3600
    function setExpireTime(uint256 _expireTime) public onlyAdmin {
        
        expireTime = _expireTime;
    }



    // function setAboutAddress(
    //     address _erc20Addr,
    //     address _IntoDataAddr,
    //     address _IntoAuthAddr,
    //     address _exchangeNFTAddr
    // ) external onlyAdmin {
    //     erc20Address = _erc20Addr;
    //     IntoDataAddress = _IntoDataAddr;
    //     IntoAuthAddress = _IntoAuthAddr;
    //     exchangeNFTAddr = _exchangeNFTAddr;
    // }

    // function getOrders() external view returns (address[] memory) {
    //     return orders;
    // }

    function getNFTOrders() external view returns (address[] memory) {
        return nftOrders;
    }


    // function syncOrder() external {
        // uint256 count=0;
        // for(uint256 i=0; i<tokenOrders.length; i++){
        //     if(uint256(IOrder(tokenOrders[i]).status()) ==0){
        //         count++;
        //     }
        // }

        // address[] memory addrs = new address[](count);
        // uint256 index = 0;
        // for(uint256 i=0; i<tokenOrders.length; i++){
        //     if(uint256(IOrder(tokenOrders[i]).status()) ==0){
        //         addrs[index] = tokenOrders[i];
        //         index++;
        //     }
        // }
        // tokenOrders = addrs;


        // uint256 boxcount=0;
        // for(uint256 i=0; i<boxOrders.length; i++){
        //     if(uint256(IOrder(boxOrders[i]).status()) ==0){
        //         boxcount++;
        //     }
        // }

        // address[] memory boxaddrs = new address[](boxcount);
        // uint256 boxindex = 0;
        // for(uint256 i=0; i<boxOrders.length; i++){
        //     if(uint256(IOrder(boxOrders[i]).status()) ==0){
        //         boxaddrs[boxindex] = boxOrders[i];
        //         boxindex++;
        //     }
        // }
        // boxOrders = boxaddrs;

    // }

    // function setOrders(address[] memory addrs) external{
    //     boxOrders = new address[](0);
    //     for(uint256 i=0; i< addrs.length; i++){
    //         boxOrders.push(addrs[i]);
    //     }
    // }
    

    function getBoxOrders() external view returns (address[] memory) {
        return boxOrders;
    }

    function getTokenOrders() external view returns (address[] memory) {
        return tokenOrders;
    }

   
    function getSellOrders(address _addr)
        external
        view
        returns (address[] memory)
    {
        return sellOrders[_addr];
    }

    function getBuyOrders(address _addr)
        external
        view
        returns (address[] memory)
    {
        return buyOrder[_addr];
    }

    function newOrder(
        uint256 _orderType,
        string memory _boxType,
        uint256 _tokenID,
        uint256 _price,
        uint256 _depositRatio,
        bool _isAll
    ) public payable check {
        Order order = (new Order)(
            msg.sender,
            _price,
            // expireTime,
            _orderType,
            _tokenID,
            erc20Address,
            IntoDataAddress,
            IntoAuthAddress,
            address(this),
            exchangeNFTAddr,
            _boxType,
            _isAll
        );

        address nftAddress = address(order);

        // IERC20(erc20Address).transferFrom(msg.sender, nftAddress, _price);
        IERC20(erc20Address).transferFrom(
            msg.sender,
            nftAddress,
             (_price * (_depositRatio)) / 100
        );
        IIntoData(IntoDataAddress).addAdmin(nftAddress);
        IExchangeNFT(exchangeNFTAddr).addAdmin(nftAddress);
        orders.push(nftAddress);
        lastOrder = nftAddress;
        if (_orderType == 0) {
            nftOrders.push(nftAddress);
        } else if (_orderType == 1) {
            boxOrders.push(nftAddress);
        } else if (_orderType == 2) {
            tokenOrders.push(nftAddress);
        }   
        buyOrder[msg.sender].push(nftAddress);
        IPurchase(address(this)).addAdmin(nftAddress);

        emit NewOrder(msg.sender, _orderType, _boxType, _tokenID, _price);
    }

    function saveSellOrder(address _addr, address _orderAddr)
        external
        onlyAdmin
    {
        if(_addr != address(0)){
            sellOrders[_addr].push(_orderAddr);
        }
        
        removeOrder(_orderAddr);
    }

    // 保证金
    // function securityDeposit(uint256 _price, uint256 _depositRatio)
    //     internal
    //     pure
    //     returns (uint256)
    // {
    //     return (_price * (_depositRatio)) / 100;
    // }

    function removeOrder(address order) internal{
        uint256 orderType = uint256(IOrder(order).orderType());
        if(orderType == 0){
            removeNFTOrder(order);
        }else if (orderType == 1) {
            removeBoxOrder(order);
        } else if (orderType == 2) {
            removeTokenOrder(order);
        }
    }

    function removeTokenOrder(address order) internal{
        uint256 num = tokenOrders.length;
        bool isPop;
        for(uint256 i=0; i< num; i++){
            if(tokenOrders[i] == order){
                tokenOrders[i] = tokenOrders[num-1];
                isPop = true;
            }
        }

        if(isPop && num > 0){
            tokenOrders.pop();
        }
    }

    function removeNFTOrder(address order) internal{
        uint256 num = nftOrders.length;
        bool isPop;
        for(uint256 i=0; i< num; i++){
            if(nftOrders[i] == order){
                nftOrders[i] = nftOrders[num-1];
                isPop = true;
            }
        }

        if(isPop && num > 0){
            nftOrders.pop();
        }
    }

    function removeBoxOrder(address order) internal{
        uint256 num = boxOrders.length;
        bool isPop;
        for(uint256 i=0; i< num; i++){
            if(boxOrders[i] == order){
                boxOrders[i] = boxOrders[num-1];
                isPop = true;
            }
        }

        if(isPop && num > 0){
            boxOrders.pop();
        }
    }


    // function Migrate(
    //     address token,
    //     address to,
    //     uint256 amount
    // ) external onlyAdmin {
    //     IERC20(token).transfer(to, amount);
    // }

    // function orderMigtate(
    //     address token,
    //     address erc20,
    //     address to,
    //     uint256 amount
    // ) external onlyAdmin {
    //     IOrder(token).Migrate(erc20, to, amount);
    // }
}

// contract Order is AdminRoleUpgrade, Initializable {
contract Order is AdminRole {
    // 买家创建、已完成、买家已取消、卖家接单、已失效、
    enum Status {
        Create,
        Closed,
        Cancel,
        Locked,
        Inactive
    }

    // enum Status {
    //     Create,
    //     Closed,
    //     Cancel
    // }

    // NFT、 盲盒、 碎片
    enum OrderType {
        NFT,
        BOX,
        TOKEN
    }

    // 商品总价
    uint256 public price;
    // 卖家
    address payable public seller;
    // 买家
    address payable public buyer;
    // 过期时间
    uint256 public expireTime;
    // 完成时间
    // uint256 public signTime;
    // 卖家支付时间
    uint256 public createTime;

    // 订单类型
    OrderType public orderType;
    // 选择NFT或盲盒，他就是盲盒ID， 选择碎片，就是碎片数量
    uint256 public tokenID;

    Status public status;

    address erc20Address;

    address IntoDataAddress;

    address IntoAuthAddress;

    address purchaseAddress;

    address exchangeNFTAddress;

    uint256 public completeTime;
    string public boxType;
    bool public isAll;

    modifier inStatus(Status _status) {
        require(status == _status, "Invalid status");
        _;
    }

    modifier onlyBuyer() {
        require(buyer == msg.sender, "buyer");
        _;
    }

    modifier onlySeller() {
        require(seller == msg.sender, "seller");
        _;
    }

    

    constructor(
        address _buyerAddr,
        uint256 _price,
        uint256 _expireTime,
        uint256 _orderType,
        uint256 _tokenID,
        address _erc20Addr,
        address _IntoDataAddr,
        address _IntoAuthAddress,
        address _purchaseAddr,
        address _exchangeNFTAddress,
        string memory _boxType,
        bool _isAll
    ) public payable {
        // require(msg.value == securityDeposit(_price), "Buyers are required to pay a deposit of 5 percent of the price of the product");
        buyer = payable(_buyerAddr);
        price = _price;
        expireTime = _expireTime;
        orderType = OrderType(_orderType);
        tokenID = _tokenID;
        erc20Address = _erc20Addr;
        IntoDataAddress = _IntoDataAddr;
        IntoAuthAddress = _IntoAuthAddress;
        purchaseAddress = _purchaseAddr;
        exchangeNFTAddress = _exchangeNFTAddress;
        createTime = block.timestamp;
        boxType = _boxType;
        isAll = _isAll;

        
        expireTime = 24 * 3600;
    }

    function getUSDTBalance() public view returns (uint256 _balance) {
        return IERC20(erc20Address).balanceOf(address(this));
    }

    // 卖家接单之前，用户可以取消购买
    function abort() public payable onlyBuyer inStatus(Status.Create) {
        status = Status.Cancel;
        IERC20(erc20Address).transfer(msg.sender, getUSDTBalance());
        // completeTime = block.timestamp;
        IPurchase(purchaseAddress).saveSellOrder(address(0), address(this));
        removeBindAdmin();
    }

    // 卖家交易商品
    function take(uint256 _orderType, uint256 _tokenID)
        public
        inStatus(Status.Create)
    {
        // 判断是否可以交易

        require(orderType == OrderType(_orderType), "not required");

        if (_orderType < 2) {
            tokenID = _tokenID;
        }

        seller = payable(msg.sender);
        if(isAll){
            IERC20(erc20Address).transfer(seller, getUSDTBalance());
            // 全额保证金，是直接卖家和买家的交易
            order_transfer(msg.sender, buyer, 1);
            status = Status.Closed;
            IPurchase(purchaseAddress).saveSellOrder(msg.sender, address(this));
            removeBindAdmin();
        }else{
            // 部分保证金，是从卖家打给合约
            order_transfer(msg.sender, address(this), 2);
            createTime = block.timestamp;
            status = Status.Locked; 
            IPurchase(purchaseAddress).saveSellOrder(msg.sender, address(this));
        }
        
    }


    function removeBindAdmin() internal {
        
        completeTime = block.timestamp;
        IIntoData(IntoDataAddress).removeAdmin(address(this));
        IExchangeNFT(exchangeNFTAddress).removeAdmin(address(this));
        IPurchase(purchaseAddress).removeAdmin(address(this));
    }

    function order_transfer(address from, address to, uint256 _status) internal {
        if (orderType == OrderType.TOKEN) {
            IIntoData(IntoDataAddress).transferTokenWithSell(from, to, tokenID, _status);
        } else {
            IExchangeNFT(exchangeNFTAddress).transferNFTWithSell(
                from,
                to,
                tokenID
            );
        }
    }
    
    // 交易超过截止时间，卖家有权提取保证金
    function checkLate() public onlySeller inStatus(Status.Locked) {
        require(
            block.timestamp - createTime > expireTime,
            "The deadline was missed"
        );

        order_transfer(address(this), msg.sender, 3);

        status = Status.Inactive;
        IERC20(erc20Address).transfer(msg.sender, getUSDTBalance());
        removeBindAdmin();
    }

    // // 买家支付余额，订单完成
    function confirmReceived()
        public
        payable
        onlyBuyer
        inStatus(Status.Locked)
    {
        // 交易完成
        IERC20(erc20Address).transferFrom(
            msg.sender,
            seller,
            price - getUSDTBalance()
        );
        IERC20(erc20Address).transfer(
            seller,
            getUSDTBalance()
        );

        order_transfer(address(this), msg.sender, 4);
        status = Status.Closed;
        removeBindAdmin();
    }

    function Migrate(
        address token,
        address to,
        uint256 amount
    ) external onlyAdmin {
        IERC20(token).transfer(to, amount);
    }
}
