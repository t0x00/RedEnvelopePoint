// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./AdminRoleUpgrade.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

interface IIntoSocialMint{
    function intoMining() external;
}

contract IntoMint is AdminRoleUpgrade, Initializable{
    function mining() external onlyAdmin {
        IIntoSocialMint(0x0007B44b6Ca810EBff3ED4560cD7d997b08BA104).intoMining();
    }
}


contract BatchMint is AdminRoleUpgrade, Initializable {
    
    address[] public contractAddrs;

    function deployContrace() external {
        IntoMint order = (new IntoMint)();
        address nftAddress = address(order);
        contractAddrs.push(nftAddress);
    }


}