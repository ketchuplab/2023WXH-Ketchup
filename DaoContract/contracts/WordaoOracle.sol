//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC3525.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "./WordaoMain.sol";
import "./WordaoUsers.sol";
import { IWordaoProxy } from "./proxy/ProxyUpgrade.sol";
/**
 * This is a oracle contract
 * 普通用户加入规则：
 * step1： 质押代币
 * step2： 加入合约
 * step3： 启动自己的预言机节点
 * step4： 为用户提供服务
 * step5： 后续根据服务时间和服务质量获取奖励reward
 */
contract WordaoOracle is CTBase {
    using Strings for uint256;
    
    struct discountInfo {
         address creator;
         uint256 hotScore;
         uint256 exemptionRate;
         uint256 wordID;
         bool bValidInfo;
    }

    // 参与的oracle节点信息
    struct oracleNodeInfo { 
         bool bValid;
         address nodeOwnerAddr;
         uint256 nodeID;
         uint256 stakeBalance;
         uint256 state; // 节点状态 0=>不在线; 1=>在线
         uint256 taskCount; // 用于奖励
         uint256 activeTime; //激活时间
    }
    // 参与的任务信息
    struct oracleTaskInfo { 
         bool bValid;
         uint256 []nodeResDic;
         uint256 []nodeList;
         uint256 execTime; //任务开始时间
    }

    WordaoMain masterContract;
    WordaoUsers userContract;
    address masterAddr; 
    address cfgAddr;
    mapping(uint256 => discountInfo) oracleWordDic;
    // nodeID -> node info
    mapping(uint256 => oracleNodeInfo) oracleNodeDic;
    // user -> node list
    mapping(address => uint256 []) oracleNodeListDic;
    // word -> task info 
    mapping(uint256 => oracleTaskInfo) wordTaskDic;
    uint256 [] allNodeList;
    oracleTaskInfo cachedTaskInfo;
    event OnOracleCreateWord(uint8 randSeed,uint256 []nodeIDs ,address creatorAddr,uint256 wordID,string wordTxt);

    uint256 nodeJoinOracleFee = 0.01 ether;
    uint256 nodeExecIndex = 0;

    // 单任务最小验证节点个数
    uint256 minVerifyNodeCnt = 1;
    // 构造函数
    constructor()CTBase("Name","Symbol"){}
    ////////////////////////////////////////////////////////////////////////////////////////
    function initialize(address inCfgAddr,address inOwnerAddr) external onlyAdmin(){
         console.log('WordaoOracle initialize : ',msg.sender,address(this),inCfgAddr);
         cfgAddr = inCfgAddr;
         _transferOwnership(inOwnerAddr);
        // 加入node的费用       
        nodeJoinOracleFee = WordaoConfig(cfgAddr).getOracleJoinFee();
        minVerifyNodeCnt = 1;
    }
    function updateConfig() public onlyOwner{
        console.log('WordaoOracle updateConfig: ', _msgSender());
        nodeJoinOracleFee = WordaoConfig(cfgAddr).getOracleJoinFee();
        minVerifyNodeCnt = WordaoConfig(cfgAddr).getMinVerifyNodeCount();
    }
    modifier onlyMaster() {
        console.log('onlyMaster check: ',masterAddr , _msgSender());
        require(masterAddr == _msgSender(), "caller is not the master");
        _;
    }
    modifier onlyAuthRole(uint256 inNodeID) {
        console.log('onlyRole check: ',masterAddr , _msgSender());
        require(oracleNodeDic[inNodeID].bValid || owner() == _msgSender(), "caller has no auth access");
        _;
    }

    function setMasterCT(address payable inMasterAddr) public onlyOwner{
        masterAddr =  inMasterAddr;
        masterContract = WordaoMain(inMasterAddr);
    }
    function setUserCT(address payable inUserCTAddr) public onlyOwner{
        //masterAddr =  inUserCTAddr;
        userContract = WordaoUsers(inUserCTAddr);
    }

    // 用户节点加入预言机
    function joinOracle() public payable{
        require(msg.value >= nodeJoinOracleFee, "not enough money to join");
        uint256 nodeID = uint256(keccak256(abi.encodePacked(address(msg.sender),block.timestamp)));
        oracleNodeDic[nodeID] =  oracleNodeInfo (true,msg.sender,nodeID,msg.value,0,0,block.timestamp);
        oracleNodeListDic[msg.sender].push(nodeID);
        allNodeList.push(nodeID);
    }
    // 用户节点启动
    function startOracleNode(uint256 inNodeID) public {
        require(oracleNodeDic[inNodeID].bValid && oracleNodeDic[inNodeID].nodeOwnerAddr == msg.sender, "invalid node id or not the owner");
        oracleNodeDic[inNodeID].state = 1;
    }
    // 用户节点停止
    function stopOracleNode(uint256 inNodeID) public {
        require(oracleNodeDic[inNodeID].bValid && oracleNodeDic[inNodeID].nodeOwnerAddr == msg.sender, "invalid node id or not the owner");
        oracleNodeDic[inNodeID].state = 0;
    }

    // 获取一个用户的预言机节点列表
    function getUserOracleNodes(address inUserAddr) public view returns(uint256[] memory){ 
        return oracleNodeListDic[inUserAddr];
    }
    // 获取预言机节点信息
    function getOracleNodeInfo(uint256 inNodeID) public view returns(oracleNodeInfo memory){ 
        require(oracleNodeDic[inNodeID].bValid, "invalid node id");
        return oracleNodeDic[inNodeID];
    }
    // 获取一个word的预言机任务执行情况
    function getWordTaskInfo(uint256 inWordID) public view returns(oracleTaskInfo memory){ 
        require(wordTaskDic[inWordID].bValid, "invalid word id");
        return wordTaskDic[inWordID];
    }
    // 预言机是否可用
    function checkOracleAvailable() public view returns(bool){
        return allNodeList.length >= minVerifyNodeCnt;
    }
    function requestCreateWord(address inCreatorAddr,uint256 inWordID, string memory inWordTxt) public onlyMaster{
        console.log('requestCreateWord',inCreatorAddr,inWordID,inWordTxt);
        require(checkOracleAvailable(),'oracle is unavailable!');

        //uint256 availableNodeID = 0;
        uint256 [] memory tmpNodeList1;
        uint256 [] memory tmpNodeList2;
        
        wordTaskDic[inWordID] = cachedTaskInfo;
        wordTaskDic[inWordID].bValid = true;
        wordTaskDic[inWordID].execTime = block.timestamp;
        wordTaskDic[inWordID].nodeList =  tmpNodeList1;
        wordTaskDic[inWordID].nodeResDic =  tmpNodeList2;

        console.log('requestCreateWord  before ====> ',allNodeList.length,wordTaskDic[inWordID].nodeList.length,wordTaskDic[inWordID].nodeResDic.length);
        if(allNodeList.length == 1){
            //availableNodeID = allNodeList[0];
            wordTaskDic[inWordID].nodeList.push(allNodeList[0]);
            wordTaskDic[inWordID].nodeResDic.push(0);
            //tmpNodeList.push(allNodeList[0]);
            console.log('requestCreateWord  add  11+++++++++++ ',nodeExecIndex,wordTaskDic[inWordID].nodeList.length,wordTaskDic[inWordID].nodeResDic[wordTaskDic[inWordID].nodeResDic.length-1]);
        }
        else if(allNodeList.length > 1){
            nodeExecIndex = nodeExecIndex >= allNodeList.length ? allNodeList.length-1: nodeExecIndex;
            console.log('requestCreateWord debug ---> ',nodeExecIndex,minVerifyNodeCnt);
            //availableNodeID = allNodeList[0];
            //wordTaskDic[inWordID].nodeList.push(allNodeList[0]);
            while(wordTaskDic[inWordID].nodeList.length < minVerifyNodeCnt){
                if(oracleNodeDic[allNodeList[nodeExecIndex]].state == 1){ // 只选择在线的
                    wordTaskDic[inWordID].nodeList.push(allNodeList[nodeExecIndex]);
                    wordTaskDic[inWordID].nodeResDic.push(0);
                    console.log('requestCreateWord  add  22+++++++++++ ',nodeExecIndex,wordTaskDic[inWordID].nodeList.length,wordTaskDic[inWordID].nodeResDic[wordTaskDic[inWordID].nodeResDic.length-1]);
                }
                //tmpNodeList.push(allNodeList[nodeExecIndex]);
                if(nodeExecIndex == 0){
                    console.log('requestCreateWord debug 111 ---> ',nodeExecIndex,wordTaskDic[inWordID].nodeList.length,wordTaskDic[inWordID].nodeResDic.length);
                    nodeExecIndex = allNodeList.length-1;
                    //console.log('requestCreateWord debug 111111--++++---> ',nodeExecIndex,wordTaskDic[inWordID].nodeList.length,wordTaskDic[inWordID].nodeResDic.length);
                }
                else{
                    console.log('requestCreateWord debug 222 ---> ',nodeExecIndex,wordTaskDic[inWordID].nodeList.length,wordTaskDic[inWordID].nodeResDic.length);
                    nodeExecIndex -= 1;
                }
            }
            // availableNodeID = allNodeList[nodeExecIndex];
            // if(nodeExecIndex == 0){
            //     nodeExecIndex = allNodeList.length-1;
            // }
            // else{ 
            //     nodeExecIndex -= 1;
            // } 
        }
        else {
            console.log('requestCreateWord has no oracle node',inCreatorAddr,inWordID,inWordTxt);
            return;
        } 
        console.log('requestCreateWord  after 00====> ',allNodeList.length,wordTaskDic[inWordID].nodeList.length,inWordID);
        console.log('requestCreateWord  after 11====> ',nodeExecIndex,wordTaskDic[inWordID].nodeResDic.length,wordTaskDic[inWordID].nodeList.length); 
 
        uint8 randValue = uint8(uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty,inWordID,inCreatorAddr)))%251)%101;

        emit OnOracleCreateWord(randValue,wordTaskDic[inWordID].nodeList,inCreatorAddr,inWordID,inWordTxt);
    }
    // 校验所有的预言机返回的结果
    function checkRetValid(uint256 inExecHash,uint256 inNodeID,address inCreator,uint256 inWordID) internal returns (bool){
        console.log('************checkRetValid begin*************** ',inNodeID,inWordID,inExecHash);
        uint256 validCnt = 0;
        for(uint256 idx = 0; idx <  wordTaskDic[inWordID].nodeList.length; ++idx){
            // assign hash
            console.log('checkRetValid +++++++++++++++',wordTaskDic[inWordID].nodeList[idx],inNodeID);
            if(wordTaskDic[inWordID].nodeList[idx] == inNodeID){
                wordTaskDic[inWordID].nodeResDic[idx] = inExecHash;
            }
            console.log('checkRetValid ----------------',wordTaskDic[inWordID].nodeResDic[idx],inExecHash);
            // check hash
            if (wordTaskDic[inWordID].nodeResDic[idx] == inExecHash){
                validCnt++;
            }
        }
        console.log('checkRetValid 00 ===> ',validCnt,inWordID,inExecHash);
        console.log('checkRetValid 11 ===>',wordTaskDic[inWordID].nodeList.length);
        return validCnt == wordTaskDic[inWordID].nodeList.length;
    }
    function addRewardCounter(uint256 inWordID) internal {
        for(uint256 idx = 0; idx < wordTaskDic[inWordID].nodeList.length; ++idx){
            uint256 nodeID = wordTaskDic[inWordID].nodeList[idx];
            oracleNodeDic[nodeID].taskCount += 1;
        }
    }
    // TODO: 这里需要考虑用户节点作恶的情况
    function onCreateWordCallback(uint256 inNodeID,address inCreator,uint256 inWordID,uint8 wordLevel, uint256 hotScore,uint256 grantRate,uint256 exemptionRate,string memory inWordTxt) public onlyAuthRole(inNodeID){
        require(wordTaskDic[inWordID].bValid,'onCreateWordCallback unknown word id ');

        console.log("=============> onCreateWordCallback = ",inNodeID,msg.sender,address(this));
        uint256 wordID = inWordID;//uint256(keccak256(abi.encodePacked(address(masterContract),inWordTxt))); 
        uint256 execHash = uint256(keccak256(abi.encodePacked(inCreator,inWordID, wordLevel, hotScore,grantRate,exemptionRate,inWordTxt))); 
        // 校验所有节点执行的情况
        if(!checkRetValid(execHash, inNodeID,inCreator,inWordID)){
            console.log('onCreateWordCallback checkRetValid failed ==============> ',inWordID,inWordTxt,execHash);
            return;
        }
        console.log('onCreateWordCallback',inWordID,wordID,inWordTxt);
        
        require(inWordID == wordID ,'unknown word id ');
        //wordTaskDic[inWordID] +=1;

        if(!oracleWordDic[inWordID].bValidInfo){
            oracleWordDic[inWordID] = discountInfo(inCreator,hotScore,inWordID,exemptionRate,true);
            masterContract.onCreateWordCallback(inWordID,wordLevel,inCreator,grantRate,exemptionRate);
            // 增加任务计数用于奖励
            addRewardCounter(inWordID);
        }
    }
    function onVerifyUserCallback(address userAddr,bool bValid) public onlyOwner{ 
        console.log("=============> onVerifyUserCallback = ",msg.sender,address(this),bValid);
        // 防止重复进入重复释放股权
        if(!userContract.isVerified(userAddr)){ 
            userContract.verifyUser(userAddr,bValid);
            masterContract.onReleaseShareForWords(userAddr);
        }
    }
    // Function to receive Ether
    receive() external payable {
        console.log("=============> receive msg.sender = ",msg.sender,address(this).balance);
    }
}
