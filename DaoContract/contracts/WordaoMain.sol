//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC3525.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/Base64.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";
import "./WordaoOracle.sol";
import "./WordaoUsers.sol";
import "./WordaoConfig.sol";
import "./WordaoHolder.sol";
import "./CTBase.sol";
import { IWordaoProxy ,ProxyUpgrade} from "./proxy/ProxyUpgrade.sol";
/**
 * This is a wordao contract
 */

//Properties of the wordInfo
struct wordInfo {
    string name;
    string description;
    string image;
    address creatorAddr;
    uint256 wordID;
    uint8 wordType;
    uint256 leftShare;
    uint256 totalReleasedShare;
    bool bValidWord;
    uint256 createTime;
    uint256 searchCnt;
    bool bPayed;
}
struct wordSimpleInfo { 
    bool bValidWord;
    address wordHolder;
}
struct userSlotInfo {  
    uint256 wordID;
    string wordName;
    address creatorAddr;// 创建者
    uint256 totalShare;
    uint256 searchCnt;
    uint8 wordType;
} 
struct  balanceData {
    uint256 blance;
    uint16 blanceType;
    uint256 balanceTime;
}
struct userAccountInfo {  
    bool bValidUser; 
    uint256 totalBalance;
    balanceData [] balanceHistory;
}
// wordao factory
contract WordaoMain is CTBase {
    using Strings for uint256;

    //  基础配置数据
    address ownerPlatAddr;
    uint256 maxSharePerSlot = 1000 * 10000;
    uint256 minOrgOwnSharePerSlot = maxSharePerSlot / 10;
    uint256 minStakeSharePerSlot = maxSharePerSlot / 2;
    uint256 preReleasedShare = maxSharePerSlot/5;
    uint256 maxCreatePriceOfSlot = 0.01 ether;
  
    // slot => wordInfo
    mapping(uint256 => wordInfo) private wordDic;
    
    // slot => word simple info
    mapping(uint256 => wordSimpleInfo) private wordHolderDic;
    
    uint256[] private wordList;

    // a user may has many slots
    // user => slots
    mapping(address => uint256[]) userSlotsDic;
 
    userAccountInfo cachedUserAccInfo;
    // address => userAccountInfo []
    mapping(address => userAccountInfo) userBalanceDic;

    // address -> slot -> token list
    mapping(address => mapping(uint256 => uint256[])) userSlotTokenDic;
    // slot => users(addr => valid )
    mapping(uint256 => mapping(address => bool)) slotUsersDic; 

    address oracleCTAddr;
    WordaoOracle oracleContract;

    address userCTAddr;
    address proxyCfgCTAddr;
    WordaoUsers userCT;
    WordaoConfig cfgCT;
    address cfgAddr;

    // string private _name;
    // string private _symbol;
    // uint8 private _decimals;

    // Event to emit when a word is created.
    event onCreateWordSuccessEvent(
        address indexed from,
        uint256 rebate,
        wordInfo wordData
    );

    wordInfo afterUpgradeWordInfo; 
    wordInfo emptyWordInfo;
    // constructor(
    //     string memory inName,
    //     string memory inSymbol,
    //     uint8 inDecimals
    // ) ERC3525(inName, inSymbol, inDecimals) {
    //     ownerPlatAddr = address(this);
    //      _name = inName;
    //      _symbol = inSymbol;
    //      _decimals = inDecimals;
    // }
 
    // function name() public view virtual override returns (string memory) {
    //     return _name;
    // }  
    // function symbol() public view virtual override returns (string memory) {
    //     return _symbol;
    // }
    // function valueDecimals() public view virtual override returns (uint8) {
    //     return _decimals;
    // }
    constructor()CTBase("Name","Symbol"){}
    ////////////////////////////////////////////////////////////////////////////////////////
    function initialize(address inCfgAddr,address inOwnerAddr) external onlyAdmin{
         console.log('WordaoMain initialize : ',msg.sender,address(this),inCfgAddr);
         cfgAddr = inCfgAddr;
         _transferOwnership(inOwnerAddr);
         ownerPlatAddr = address(this);
         //(maxSharePerSlot,minOrgOwnSharePerSlot,minStakeSharePerSlot,preReleasedShare,maxCreatePriceOfSlot) = WordaoConfig(cfgAddr).getWordaoCfg();
    }
    function showDebugInfo() public view returns(uint256){
        // console.log('wordaoMain showDebugInfo ===> ',owner() ,msg.sender,address(this)); 
        // console.log('wordaoMain showDebugInfo =======> ',maxSharePerSlot,minOrgOwnSharePerSlot,minStakeSharePerSlot);
        return 0;
    }
    function initParam() public onlyOwner{
         //showDebugInfo();
         //maxSharePerSlot = WordaoConfig(cfgAddr).getWordaoCfg2();
         //console.log('wordaoMain initParam =======> ',maxSharePerSlot,minOrgOwnSharePerSlot,minStakeSharePerSlot);
    }
    // function initTitle(
    //     string memory inName,
    //     string memory inSymbol,
    //     uint8 inDecimals
    // )  public {
    //     ownerPlatAddr = address(this);
    //      _name = inName;
    //      _symbol = inSymbol;
    //      _decimals = inDecimals;
    //     //console.log('========> initTitle : ',inName, inSymbol, inDecimals);
    // }
    /**
     * @dev Generate the value of slot by utilizing keccak256 algorithm to calculate the hash
     * value of multi properties.
     */
    function getSlotID(string memory inWordName, address inOrgAddr)
        public
        view 
        returns (uint256 slotID)
    {
        //console.log('getSlotID',msg.sender,inWordName,inOrgAddr);
        slotID = uint256(keccak256(abi.encodePacked(inOrgAddr, inWordName)));
        //console.log('getSlotID',slotID);
        return slotID;
    }

    // function slotURI(uint256 wordID)
    //     public
    //     view
    //     virtual
    //     override
    //     returns (string memory)
    // {
    //     require(wordHolderDic[wordID].bValidWord,'invalid wordID');
    //     WordaoHolder holder = WordaoHolder(payable(wordHolderDic[wordID].wordHolder));
    //     return holder.slotURI();
    // }

    modifier onlyOracle() {
        require(oracleCTAddr == _msgSender(), "caller is not the master");
        _;
    }

    function setOracleCT(address payable inOracleAddr) public {
        oracleCTAddr = inOracleAddr;
        oracleContract = WordaoOracle(inOracleAddr);
    }
    
    modifier onlyUserCT() {
        require(oracleCTAddr == _msgSender(), "caller is not the master");
        _;
    }

    function setUserCT(address payable inUserCTAddr) public {
        userCTAddr = inUserCTAddr;
        userCT = WordaoUsers(inUserCTAddr);
    }

    function setCfgCT(address payable inCfgCTAddr) public { 
        cfgCT = WordaoConfig(inCfgCTAddr);
    }
    function setProxyCfgCTAddr(address inProxyCfgCTAddr) public { 
        proxyCfgCTAddr = inProxyCfgCTAddr;
    }
  
    //////////////////////////////////////////////////////////////pay支付////////////////////////////////////////////////////////////////
    // Function to receive Ether
    receive() external payable {
        //console.log( "=============> BadContract receive msg.sender = ", msg.sender, address(this).balance );
    }
    // Send ETH worth `balances[msg.sender]` back to msg.sender
    function withdraw() public  {
        require(userBalanceDic[msg.sender].totalBalance > 0 ,'you are so poor. Go away!');
        require(address(this).balance >= userBalanceDic[msg.sender].totalBalance ,'i am so poor. Go away!');
        userBalanceDic[msg.sender].totalBalance = 0;
        
        //console.log( "before withdraw =============> ", msg.sender, address(this).balance );
        //(bool sent, ) = msg.sender.call{value: 0.086 ether}("");
        (bool sent, ) = msg.sender.call{value: userBalanceDic[msg.sender].totalBalance}("");
        //console.log(  "after withdraw =============> ", msg.sender,  address(this).balance );
    }

    // function approve(
    //     uint256 tokenId_,
    //     address to_,
    //     uint256 value_
    // ) external payable virtual override {
    //     //super.approve(tokenId_,to_,value_);
    //     address owner = ERC721.ownerOf(tokenId_);
    //     require(to_ != owner, "ERC3525: approval to current owner");
    //     require(
    //         ERC721._isApprovedOrOwner(_msgSender(), tokenId_),
    //         "ERC3525: approve caller is not owner nor approved for all"
    //     );
    //     _approveValue(tokenId_, to_, value_);
    // }

    function getMyBalance() public view returns (uint256) {
        return address(this).balance;
    }
    //////////////////////////////////////////////////////////////user join////////////////////////////////////////////////////////////////
    function joinWordao(uint256 wordID) public {
        require(wordHolderDic[wordID].bValidWord,'invalid word,can not join!'); 
        // step1: register
        userCT.registerUser(msg.sender);

        // step2: join holder dao
        WordaoHolder(payable(wordHolderDic[wordID].wordHolder)).joinWordao(msg.sender); 
        
        // step3: record user's slot
        if (!slotUsersDic[wordID][msg.sender]){
            slotUsersDic[wordID][msg.sender] = true;
            userSlotsDic[msg.sender].push(wordID);
        }
    }
    function isUserJoinWordao(uint256 wordID) public view returns(bool){
        //return slotUsersDic[wordID][msg.sender];
        //require(wordHolderDic[wordID].bValidWord,'invalid word'); 
        return !wordHolderDic[wordID].bValidWord || WordaoHolder(payable(wordHolderDic[wordID].wordHolder)).isUserJoinWordao(msg.sender);
    }
    //////////////////////////////////////////////////////////////public////////////////////////////////////////////////////////////////
    // function getUserWordList_v1(uint256 startIdx,address userAddr) public view returns (uint256,uint256,wordInfo[] memory) { 
    //     uint256 endIdx = startIdx + 3;
    //     endIdx = endIdx > userSlotsDic[userAddr].length ?  userSlotsDic[userAddr].length : endIdx;
    //     uint256 pageCnt = endIdx-startIdx;
    //     wordInfo[] memory tempList = new wordInfo[](pageCnt);
    //     for(uint256 idx = startIdx;idx < endIdx; ++idx){
    //         tempList[idx - startIdx] = wordDic[userSlotsDic[userAddr][idx]]; 
    //     }
    //     return (3,userSlotsDic[userAddr].length,tempList);
    // }
    function getUserAccountInfo() public view returns (userAccountInfo memory,userInfo memory) {  
        return (userBalanceDic[msg.sender],userCT.getUserInfo(msg.sender));
    }
    function getUserWordList(uint256 startIdx,address userAddr) public view returns (uint256,uint256,userSlotInfo[] memory) { 
        uint256 endIdx = startIdx + 3;
        endIdx = endIdx > userSlotsDic[userAddr].length ?  userSlotsDic[userAddr].length : endIdx;
        uint256 pageCnt = endIdx-startIdx;
        userSlotInfo[] memory tempList = new userSlotInfo[](pageCnt);
        for(uint256 idx = startIdx;idx < endIdx; ++idx){
            WordaoHolder holder = WordaoHolder(payable(wordHolderDic[userSlotsDic[userAddr][idx]].wordHolder));
             wordInfo memory wordData = holder.getWordInfo();
            tempList[idx - startIdx] = userSlotInfo(
                userSlotsDic[userAddr][idx],
            wordData.name,
            wordData.creatorAddr,
            0,
            wordData.searchCnt,
            wordData.wordType
            );
            tempList[idx - startIdx].totalShare += holder.getUserBalance(userAddr);
        }
        return (3,userSlotsDic[userAddr].length,tempList);
    }
    
    function getWordInfo(uint256 wordID) public view returns (wordInfo memory) {
        //require(wordHolderDic[wordID].bValidWord,'invalid wordID'); 
        if (!wordHolderDic[wordID].bValidWord){
            return emptyWordInfo;
        }
        WordaoHolder holder = WordaoHolder(payable(wordHolderDic[wordID].wordHolder)); 
        return holder.getWordInfo();
    }
    function isWordValid(uint256 wordID) public view returns (bool) { 
        return wordHolderDic[wordID].bValidWord;
    }
    // each can get 10 items
    function getWordList(uint256 startIdx) public view returns (wordInfo[]  memory) {
        //require(startIdx < wordList.length,'invalid index');
         
        uint256 endIdx = startIdx+10; 
        endIdx = endIdx > wordList.length ?  wordList.length : endIdx;

        require(startIdx <= endIdx,'invalid index');
        wordInfo[] memory tempList = new wordInfo[](endIdx-startIdx);

        for(uint256 idx = startIdx;idx < endIdx; ++idx){
            WordaoHolder holder = WordaoHolder(payable(wordHolderDic[wordList[idx]].wordHolder)); 
            tempList[idx-startIdx] = holder.getWordInfo();
        } 
        return tempList;
    }
    
    function createWorDAO(
        string memory inWordName, //  Tom and Jerry 
        string memory inSymbol, // 新增字段 Tom and Jerry ==> tomandjerry
        string memory inWordDes,
        string memory inWordImage
    ) public payable {
        require(msg.value >= maxCreatePriceOfSlot, "WorDAO: not enough money!");

        console.log(" main contract=============> createWorDAO 11 = ",inWordName,inSymbol,inWordDes);
        console.log(" main contract=============> createWorDAO 22 = ",inWordImage);

        uint256 slotID = getSlotID(inSymbol, ownerPlatAddr);
        require(!wordHolderDic[slotID].bValidWord, "WorDAO: word exist!");

        if (!wordHolderDic[slotID].bValidWord) {
            // step1: init wordao holder
            bytes memory _initializationCalldata = abi.encodeWithSelector(
                WordaoHolder.initialize.selector,
                address(this),
                cfgAddr,
                userCTAddr,
                owner()
            );

            address holderProxy = address(
                new ProxyUpgrade(proxyCfgCTAddr, _initializationCalldata,5)
            );

            // step2: create wordao
            wordHolderDic[slotID] = wordSimpleInfo({ 
                bValidWord: true, 
                wordHolder: holderProxy
            });
            // step3: mint total share to holder
            WordaoHolder(payable(holderProxy)).createWorDAO(slotID,msg.sender,inWordName,inSymbol,inWordDes,inWordImage); 
            
            // step4: join dao
            joinWordao(slotID);

            wordList.push(slotID); 
            if(userSlotsDic[msg.sender].length <= 1){ 
                userBalanceDic[msg.sender] = cachedUserAccInfo;
            }
            userBalanceDic[msg.sender].totalBalance += msg.value;
            // tell oracle to get buy config
            oracleContract.requestCreateWord(msg.sender, slotID, inWordName);
            
        }
    }
    
    // callback from external oracle
    function onCreateWordCallback(
        uint256 slotID,
        uint8 wordLevel,
        address inCreator,
        uint256 grantRate,
        uint256 exemptionRate
    ) external /*onlyOracle*/ {
        console.log("=============> onCreateWordCallback = ",msg.sender,address(this));
        if (wordHolderDic[slotID].bValidWord) {

            WordaoHolder holder = WordaoHolder(payable(wordHolderDic[slotID].wordHolder));
            uint256 startGas = gasleft();
            {
                 holder.createWordCallback(wordLevel,inCreator,grantRate); 
            }
            uint256 endGas = gasleft();

            // mint fee used from user, alse rebate similar to mint-fee
            uint256 gasCost = startGas - endGas;
            uint256 needPayback = (maxCreatePriceOfSlot / 100) * exemptionRate;
            uint256 allGasCost = gasCost * 2;
            uint256 rebate = 0;
            if (needPayback > allGasCost) {
                rebate = needPayback - gasCost * 2;
            }
            //console.log("onCreateWordCallback", gasCost, needPayback, rebate);
            if (rebate > 0) {
                // 不直接退款，由用户自己去提款，避免不必要的gas费用
                // startGas = gasleft();
                // (bool success1, ) = payable(inCreator).call{value: rebate}(
                //     ""
                // );
                // require(success1);
                // endGas = gasleft();
                // console.log(
                //     "onBuyWordCallback rebate gas cost: ",
                //     success1,
                //     startGas - endGas
                // );                 
                userBalanceDic[inCreator].balanceHistory.push(balanceData(rebate,0,block.timestamp));
            }
            emit onCreateWordSuccessEvent(inCreator,rebate,holder.getWordInfo());
            uint256 allCost = maxCreatePriceOfSlot-rebate;
            console.log("onBuyWordCallback need sub : ", userBalanceDic[inCreator].totalBalance,allCost);
            if( userBalanceDic[inCreator].totalBalance >= allCost){
                userBalanceDic[inCreator].totalBalance -= allCost;
            }
            else{
                userBalanceDic[inCreator].totalBalance = 0;
            } 
        }
    }
    // release share 
    function onReleaseShareForWords(address userAddr) external onlyOracle { 
        console.log("=============> onReleaseShareForWords = ", userAddr);
        for(uint256 idx = 0; idx < userSlotsDic[userAddr].length; ++idx){
            uint256 slotID = userSlotsDic[userAddr][idx];
            if (wordHolderDic[slotID].bValidWord) {
                WordaoHolder(payable(wordHolderDic[slotID].wordHolder)).releaseShareForWord(userAddr);
            }
        }
    }
    function getBuyPrice(uint256 wordID,uint256 buyShareRate) public view returns(uint256){
        require(wordHolderDic[wordID].bValidWord,'invalid wordID'); 
        WordaoHolder holder = WordaoHolder(payable(wordHolderDic[wordID].wordHolder)); 
        return holder.getCurrentBuyPrice(buyShareRate);
    } 
    // buy share
    function buyShareOfWord( uint256 wordID, uint256 buyShareRate) public payable {
        // require(wordHolderDic[wordID].bValidWord,'invalid wordID');

        // WordaoHolder holder = WordaoHolder(payable(wordHolderDic[wordID].wordHolder));
  
        // uint256 buySharePrice = holder.getCurrentBuyPrice(buyShareRate); 

        // require(msg.value >= buySharePrice,'not enough share left');

        // uint256 buyShareOfSlot = (maxSharePerSlot * buyShareRate) / 1000;
        // require(wordDic[wordID].leftShare >= (buyShareOfSlot + minStakeSharePerSlot),'not enough share left');
 
        // uint256 holderTokenID = holder.getHolderTokenID();

        // uint256 startGas = gasleft();
        // {  
        //     this.approve(holderTokenID, msg.sender, buyShareOfSlot);
        //     if(userSlotTokenDic[msg.sender][wordID].length > 0){ 
        //         transferFrom(holderTokenID, userSlotTokenDic[msg.sender][wordID][0], buyShareOfSlot);
        //     }
        //     else {  
        //         ERC3525._mintValue(msg.sender,tokenCounter,wordID,buyShareOfSlot);
                
        //         console.log("=============> buyShareOfWord  = ", buyShareOfSlot);
        //         userSlotTokenDic[msg.sender][wordID].push(tokenCounter);
               
        //         wordDic[wordID].leftShare -= buyShareOfSlot;
        //         tokenCounter++;
        //     }
        // }
        // uint256 endGas = gasleft();
        // console.log("=============> buyShareOfWord  gasCost= ", startGas-endGas);
    }
    function afterUpGradeTest(string memory inWDName) public {
        uint256 startGas = gasleft();
        afterUpgradeWordInfo.bPayed = true;
        afterUpgradeWordInfo.name = inWDName;
        afterUpgradeWordInfo.description= inWDName;
        afterUpgradeWordInfo.image = inWDName;
        afterUpgradeWordInfo.creatorAddr = address(this);
        afterUpgradeWordInfo.wordID = 1111;
        afterUpgradeWordInfo.wordType = 2;
        afterUpgradeWordInfo.leftShare = 10086;
        afterUpgradeWordInfo.totalReleasedShare = 3000000;
        afterUpgradeWordInfo.bValidWord = true;
        afterUpgradeWordInfo.createTime = block.timestamp;
        afterUpgradeWordInfo.searchCnt = 2000;
        afterUpgradeWordInfo.bPayed= true;
        emit onCreateWordSuccessEvent(msg.sender,11,afterUpgradeWordInfo);
        uint256 endGas = gasleft();
        console.log("=============> afterUpGradeTest  gasCost = ", startGas-endGas);
    }
    function editUserInfo(string memory userName,string memory userEmail, string memory userAvatar) public {
        userCT.editUserInfo(msg.sender,userName,userEmail,userAvatar);
    } 
    function changeCreateTime( uint256 wordID, uint256 timeStamp) public onlyOwner {
        require(wordHolderDic[wordID].bValidWord,'invalid wordID'); 
        WordaoHolder holder = WordaoHolder(payable(wordHolderDic[wordID].wordHolder)); 
        return holder.changeCreateTime(timeStamp);
    }
}
