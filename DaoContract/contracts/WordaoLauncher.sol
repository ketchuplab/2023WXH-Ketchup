//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
 
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "./WordaoMain.sol";
import "./WordaoUsers.sol";
import "./WordaoOracle.sol";
import "./WordaoHolder.sol";
import "./WordaoConfig.sol";
import "./proxy/ProxyConfig.sol";

import { IWordaoProxy } from "./proxy/ProxyUpgrade.sol";
/**
 * This is a oracle contract
 */
contract WordaoLauncher is IWordaoProxy {
     
     ProxyConfig proxyCfg;
     WordaoConfig wdCfg;
     WordaoMain mainCT;
     mapping(uint8 => address) ctDic;
     constructor(){
     }

     function setCfg(address inProxyCfg) public onlyOwner{
        proxyCfg = ProxyConfig(inProxyCfg);
     }
     // 配置文件
     function launchConfig(uint8 inType) public onlyOwner{
        bytes memory _initializationCalldata = abi.encodeWithSelector(
                WordaoConfig.initialize.selector,
                msg.sender
        );
        address holderProxy = address(
            new ProxyUpgrade(address(proxyCfg), _initializationCalldata,inType)
        );
        wdCfg = WordaoConfig(holderProxy);
        ctDic[inType] = holderProxy; 
        console.log('====> launchConfig done!',inType,holderProxy);
     }
     // 主合约
     function launchMain(uint8 inType) public onlyOwner{
        bytes memory _initializationCalldata = abi.encodeWithSelector(
                WordaoMain.initialize.selector,
                address(wdCfg),
                msg.sender
        );
        address holderProxy = address(
            new ProxyUpgrade(address(proxyCfg), _initializationCalldata,inType)
        );
        ctDic[inType] = holderProxy;
        
        mainCT = WordaoMain(payable(holderProxy));
        // mainCT.showDebugInfo();
        console.log('====> launchMain done!',inType,holderProxy);
     }
     // 预言机
     function launchOracle(uint8 inType) public onlyOwner{
        bytes memory _initializationCalldata = abi.encodeWithSelector(
                WordaoOracle.initialize.selector,
                address(wdCfg),
                msg.sender
        );
        address holderProxy = address(
            new ProxyUpgrade(address(proxyCfg), _initializationCalldata,inType)
        );
        ctDic[inType] = holderProxy;
        console.log('====> launchOracle done!',inType,holderProxy);
     }
     // 用户数据
     function launchUser(uint8 inType) public onlyOwner{
        bytes memory _initializationCalldata = abi.encodeWithSelector(
                WordaoUsers.initialize.selector,
                address(wdCfg),
                msg.sender
        );
        address holderProxy = address(
            new ProxyUpgrade(address(proxyCfg), _initializationCalldata,inType)
        );
        ctDic[inType] = holderProxy;
        console.log('====> launchUser done!',inType,holderProxy);
     }

     function showDebugInfo(uint8 inType) public {
        mainCT.showDebugInfo();
        //WordaoMain((ctDic[inType])).initParam();
     }
     // 获取数据
     function getCTAddr(uint8 inType) public view returns(address){
        return  ctDic[inType];
     }
}
