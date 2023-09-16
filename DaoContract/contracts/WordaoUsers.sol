//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC3525.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "./WordaoOracle.sol";
import { IWordaoProxy } from "./proxy/ProxyUpgrade.sol";
/**
 * This is a wordao contract
 */

//Properties of the wordInfo
struct userInfo {
    string name;
    string email;
    string avatar;
    bool bValidUser;
    bool bValidTwitter;
    bool bValidWithQian;
    uint256 createTime;
}
struct dAppAuthInfo {
    bool bValid;
    uint256 authTime;
}

contract WordaoUsers is IWordaoProxy {
    using Strings for uint256;

    // org platform
    //address ownerPlatAddr;
    // address => wordInfo
    mapping(address => userInfo) private usersDic;
    uint256 userCount = 0;
    address cfgAddr;
 
    address oracleAddr;
    WordaoOracle oracleContract;
    uint256 regForUserQian = 0.01 ether;

    // constructor() {
    //     ownerPlatAddr = address(this);
    // } 
    ////////////////////////////////////////////////////////////////////////////////////////
    function initialize(address inCfgAddr,address inOwnerAddr) external onlyAdmin(){
         console.log('WordaoUsers initialize : ',msg.sender,address(this),inCfgAddr);
         cfgAddr = inCfgAddr;
         _transferOwnership(inOwnerAddr);
         regForUserQian = 0.01 ether;
    }

    // Function to receive Ether
    receive() external payable {
        console.log( "=============> WordaoUsers receive msg.sender = ", msg.sender, address(this).balance);
    }
    // Send ETH worth `balances[msg.sender]` back to msg.sender
    function withdraw() public onlyOwner {
        // console.log( "before withdraw =============> ", msg.sender, address(this).balance );
        // (bool sent, ) = msg.sender.call{value: 0.086 ether}("");
        // console.log( "after withdraw =============> ", msg.sender, address(this).balance );
    } 

    function getMyBalance() public view returns (uint256) {
        return address(this).balance;
    }

    /***************************************************用户中心************************************************/
    // 供第三方调用注册用户
    function registerUser(address userAddr) public {
        if (!usersDic[userAddr].bValidUser){
            userCount++;
            usersDic[userAddr] = userInfo('nickname','email','avatar',true,false,false,block.timestamp);
        }
    }
    // 供第三方调用注册用户
    function editUserInfo(address userAddr,string memory userName,string memory userEmail, string memory userAvatar) public {
        require(usersDic[userAddr].bValidUser,'user not valid');
        usersDic[userAddr].name = userName;
        usersDic[userAddr].email = userEmail;
        usersDic[userAddr].avatar = userAvatar;
    }
    /***********************************************************************************************************/
    function setRegQian(uint256 inRegQian) public onlyOwner {
        regForUserQian = inRegQian;
    }
    function registerUserWithQian() public payable {
        require(msg.value > regForUserQian,'not enough money');
        if (!usersDic[msg.sender].bValidUser){
            usersDic[msg.sender] = userInfo('nickname','email','avatar',true,false,true,block.timestamp);
        }
        usersDic[msg.sender].bValidWithQian = true;
    }

    modifier onlyOracle() { 
        console.log('onlyOracle check:',_msgSender(),msg.sender,address(this));
        require(oracleAddr == _msgSender(), "caller is not the oracle");
        _;
    }

    function setOracleCT(address payable inOracleAddr) public {
        oracleAddr = inOracleAddr;
        oracleContract = WordaoOracle(inOracleAddr);
    }

    ////////////////////////////////////////////////////////////////////////////////////////////////////
    // only call from oracle contract
    function verifyUser(address userAddr,bool bValid) external onlyOracle{
        registerUser(userAddr);
        usersDic[userAddr].bValidTwitter = bValid;
        console.log('=============>  verifyUser:',userAddr,bValid);
    }
    function isVerified(address userAddr) public view returns (bool){
        console.log("=============> isVerified = ",msg.sender,userAddr,usersDic[userAddr].bValidUser);
        return usersDic[userAddr].bValidTwitter;
    }
    function isValidUser(address userAddr) public view returns (bool){
        console.log("=============> isValidUser = ",msg.sender,userAddr,usersDic[userAddr].bValidUser);
        return usersDic[userAddr].bValidUser;
    }
    function getUserInfo(address userAddr) public view returns (userInfo memory){
        require(usersDic[userAddr].bValidUser,'user not valid');
        return usersDic[userAddr];
    }
    function getUserCount() public view returns (uint256){
        return userCount;
    }
    function getValidUserCount(address[] memory userList) public view returns (uint256){
        uint256 validCnt = 0;
        for(uint256 idx  =  0; idx < userList.length; ++idx){
            if (usersDic[userList[idx]].bValidTwitter){
                validCnt++;
            }
        }
        return validCnt;
    }
}
