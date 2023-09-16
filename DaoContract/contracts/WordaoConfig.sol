//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC3525.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "./WordaoOracle.sol";
import "./CTBase.sol";
import { IWordaoProxy } from "./proxy/ProxyUpgrade.sol";

/**
 * This is a WordaoConfig contract
 */
 
struct investCfg{
    uint256 level;
    uint256 creatorShare;
    uint256 maxReleaseShareRate;
    uint256 addShareRatePerFan;
    uint256 minBuyShareRate;
    uint256 maxUnitOfEachBuy;
    uint256 priceOfBuyBase;
    uint256 addPricePerFan;
    uint256 updateTime;
    bool bValid;
}

contract WordaoConfig is CTBase{
    using Strings for uint256;
    mapping(uint256 => investCfg) investCfgDic;


    // 初始化配置
    uint256 maxSharePerSlot = 1000 * 10000; 
    uint256 minOrgOwnSharePerSlot = maxSharePerSlot / 10;
    uint256 minStakeSharePerSlot = maxSharePerSlot / 2;
    uint256 preReleasedShare = maxSharePerSlot/5; 
    uint256 maxCreatePriceOfSlot = 0.01 ether;

    // 用户节点加入oracle需要的费用
    uint256 nodeJoinOracleFee = 0.01 ether;
    uint256 minVerifyNodeCnt = 1;

    constructor()CTBase("Name","Symbol"){}
    ////////////////////////////////////////////////////////////////////////////////////////
    function initialize(address inOwnerAddr) external onlyAdmin(){
         console.log('WordaoConfig initialize : ',msg.sender,address(this),inOwnerAddr);
         _transferOwnership(inOwnerAddr);
         // 重新初始化
         maxSharePerSlot = 1000 * 10000; 
         minOrgOwnSharePerSlot = maxSharePerSlot / 10;
         minStakeSharePerSlot = maxSharePerSlot / 2;
         preReleasedShare = maxSharePerSlot/5; 
         maxCreatePriceOfSlot = 0.01 ether;
         // 用户节点加入oracle需要的费用
         nodeJoinOracleFee = 0.01 ether;
         minVerifyNodeCnt = 1;
    }
    
    function updateInvestConfig(uint256 level,
            uint256 creatorShare,
            uint256 maxReleaseShareRate,
            uint256 addShareRatePerFan,
            uint256 minBuyShareRate,
            uint256 maxUnitOfEachBuy,
            uint256 priceOfBuyBase,
            uint256 addPricePerFan
            ) public onlyOwner{

        investCfgDic[level] = investCfg(level,
                            creatorShare,
                            maxReleaseShareRate,
                            addShareRatePerFan,
                            minBuyShareRate,
                            maxUnitOfEachBuy,
                            priceOfBuyBase,
                            addPricePerFan,
                            block.timestamp,true);
    }
    function showDebugInfo() public view returns(uint256){
        console.log('WordaoConfig showDebugInfo ===> ',owner() ,msg.sender,address(this)); 
        return 0;
    }
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////////
    
    function getWordaoCfg() public view returns(uint256,uint256,uint256,uint256,uint256){ 
        return (maxSharePerSlot,minOrgOwnSharePerSlot,minStakeSharePerSlot,preReleasedShare,maxCreatePriceOfSlot);
    }
    function getOracleJoinFee() public view returns(uint256){
        return nodeJoinOracleFee;
    }
    function getMinVerifyNodeCount() public view returns(uint256){
        return minVerifyNodeCnt;
    }
    function setMinVerifyNodeCount(uint256 inMinNodeCnt) public onlyOwner{
        console.log('WordaoConfig setMinVerifyNodeCount: ', inMinNodeCnt);
        minVerifyNodeCnt = inMinNodeCnt;
    }
    function getWordaoCfg2() public view returns(uint256){ 
        return maxSharePerSlot;
    }
    function getInvestCfg(uint256 level) public view returns(investCfg memory){
        require(investCfgDic[level].bValid,'invalid invest level');
        return investCfgDic[level];
    }

    function getInvestPrice(uint256 buyShareRate,uint256 validFansCnt,uint256 level) public view returns(uint256){
        
        console.log('getInvestPrice: enter = ',buyShareRate,validFansCnt,level);

        require(investCfgDic[level].bValid,'invalid invest level');
        
        console.log('getInvestPrice: check = ',investCfgDic[level].minBuyShareRate,investCfgDic[level].maxUnitOfEachBuy,investCfgDic[level].minBuyShareRate);

        require(buyShareRate >= investCfgDic[level].minBuyShareRate,'too small to buy share');
        require(buyShareRate <= investCfgDic[level].maxUnitOfEachBuy*investCfgDic[level].minBuyShareRate,'too much to buy share');
 
        console.log('getInvestPrice:0 = ',buyShareRate,validFansCnt,level);
        // 2%     50%	0.1%	0.1%	0.003eth	每新增1粉丝增加0.001eth
        // 2%     500	10	10	0.003eth	每新增1粉丝增加 0.001eth
        investCfg memory oneCfg = investCfgDic[level];
        
        uint256 totalReleasedRate = oneCfg.creatorShare + maxSharePerSlot*oneCfg.addShareRatePerFan*validFansCnt/1000;
        uint256 totalAddPrice = oneCfg.addPricePerFan * validFansCnt;
        
        require(totalReleasedRate <= investCfgDic[level].maxReleaseShareRate,'not enough share to buy');

        // G:增长梯度    S:份数  P: 每份额单价起步价
        // 当前购买价格 = (P+当前新增有效粉丝数*G)*S
        uint256 buySharePrice = (oneCfg.priceOfBuyBase+totalAddPrice)*(buyShareRate/oneCfg.minBuyShareRate);
        
        console.log('getInvestPrice:1 = ',oneCfg.addPricePerFan,oneCfg.addShareRatePerFan,oneCfg.priceOfBuyBase);
        console.log('getInvestPrice:2 = ',totalReleasedRate,totalAddPrice,buySharePrice);
        return buySharePrice;
    }
    
    function getReleasedShareByLevel(uint256 level) public view returns(uint256){
        require(investCfgDic[level].bValid,'invalid invest level'); 
  
        investCfg memory oneCfg = investCfgDic[level];
        uint256 releasedShare = maxSharePerSlot*oneCfg.addShareRatePerFan/1000;
        return releasedShare;
    }

}
