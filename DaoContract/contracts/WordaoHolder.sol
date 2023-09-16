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
import "./WordaoMain.sol";
import { IWordaoProxy } from "./proxy/ProxyUpgrade.sol";
/**
 * This is a wordao holder contract
 */
contract WordaoHolder is IWordaoProxy, ERC3525 {
    using Strings for uint256;

    // org platform
    address ownerPlatAddr;
    uint256 maxSharePerSlot = 1000 * 10000;
    uint256 minOrgOwnSharePerSlot = maxSharePerSlot / 10;
    uint256 minStakeSharePerSlot = maxSharePerSlot / 2;
    uint256 preReleasedShare = maxSharePerSlot/5; 
    uint256 maxCreatePriceOfSlot = 0.01 ether;
    
    uint256 tokenCounter = 1000;
    uint256 holderTokenID = 1000;
 
    userAccountInfo cachedUserAccInfo;
    // address => userAccountInfo []
    mapping(address => userAccountInfo) userBalanceDic; 
    mapping(address => uint256) userTokenIdDic; 
    // slot => users address list
    address[] usersList;

    wordInfo wordDaoInfo; 
    WordaoConfig cfgCT;

    address masterAddr;
    address userMgrAddr;
    address cfgAddr;
 
 
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    // constructor(
    //     string memory inName,
    //     string memory inSymbol,
    //     uint8 inDecimals
    // ) ERC3525(inName, inSymbol, inDecimals) {
    //     ownerPlatAddr = address(this);
    // }
    constructor() ERC3525("", "", 18) {
        ownerPlatAddr = address(this);
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }  
    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }
    function valueDecimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    modifier onlyMaster() {
        console.log('onlyMaster check: ',masterAddr , _msgSender());
        require(masterAddr == _msgSender(), "caller is not the master");
        _;
    }

    //////////////////////////////////////////////////初始化////////////////////////////////////////////
    function initialize(address inMasterAddr,address inCfgAddr,address inUserMgrAddr,address inOwnerAddr) external onlyAdmin{
        console.log('WordaoHolder initialize : ',msg.sender,address(this),inCfgAddr);
        masterAddr = inMasterAddr;
        cfgAddr = inCfgAddr;
        userMgrAddr = inUserMgrAddr;
        tokenCounter = 1000;
        _name = "DaoName";
        _symbol = "DaoSymbol";
        _decimals = 18;
        cfgCT = WordaoConfig(inCfgAddr);
        _transferOwnership(inOwnerAddr); 
         (maxSharePerSlot,minOrgOwnSharePerSlot,minStakeSharePerSlot,preReleasedShare,maxCreatePriceOfSlot) = cfgCT.getWordaoCfg();
    }

    // function setCfgCT(address  inCfgCTAddr) public onlyOwner { 
    //     cfgCT = WordaoConfig(inCfgCTAddr);
    // }
    /**
     * @dev Generate the value of slot by utilizing keccak256 algorithm to calculate the hash
     * value of multi properties.
     */
    // function getSlotID(string memory inWordName, address inOrgAddr)
    //     public
    //     view 
    //     returns (uint256 slotID)
    // {
    //     console.log('getSlotID',msg.sender,inWordName,inOrgAddr);
    //     slotID = uint256(keccak256(abi.encodePacked(inOrgAddr, inWordName)));
    //     console.log('getSlotID',slotID);
    //     return slotID;
    // }

    function slotURI(uint256 wordID)
        public
        view
        virtual
        override
        returns (string memory)
    {
        return
            string(
                abi.encodePacked(
                    /* solhint-disable */
                    "data:application/json;base64,",
                    Base64.encode(
                        abi.encodePacked(
                            '{"name":"',
                            wordDaoInfo.name,
                            '","description":"',
                            wordDaoInfo.description,
                            '","image":"',
                            wordDaoInfo.image,
                            "}"
                        )
                    )
                    /* solhint-enable */
                )
            );
    }
    
    //////////////////////////////////////////////////////////////pay支付////////////////////////////////////////////////////////////////

    function approve(
        uint256 tokenId_,
        address to_,
        uint256 value_
    ) external payable virtual override {
         console.log( "=============> approve receive msg.sender = ", msg.sender, address(this),to_ );
        //super.approve(tokenId_,to_,value_);
        address owner = ERC721.ownerOf(tokenId_);
        require(to_ != owner, "ERC3525: approval to current owner");
        require(
            ERC721._isApprovedOrOwner(_msgSender(), tokenId_),
            "ERC3525: approve caller is not owner nor approved for all"
        );
        _approveValue(tokenId_, to_, value_);
    }

    // Function to receive Ether
    receive() external payable {
        console.log(
            "=============> Contract receive msg.sender = ",
            msg.sender,
            address(this).balance
        );
    }
    // Send ETH worth `balances[msg.sender]` back to msg.sender
    function withdraw() public  {
        require(userBalanceDic[msg.sender].totalBalance > 0 ,'you are so poor. Go away!');
        require(address(this).balance >= userBalanceDic[msg.sender].totalBalance ,'i am so poor. Go away!');
        userBalanceDic[msg.sender].totalBalance = 0;
        
        console.log( "before withdraw =============> ", msg.sender, address(this).balance);
        //(bool sent, ) = msg.sender.call{value: 0.086 ether}("");
        (bool sent, ) = msg.sender.call{value: userBalanceDic[msg.sender].totalBalance}("");
        console.log(
            "after withdraw =============> ",
            msg.sender,
            address(this).balance
        );
    }

    function getMyBalance() public view returns (uint256) {
        return address(this).balance;
    }
    //////////////////////////////////////////////////////////////user join////////////////////////////////////////////////////////////////
    
    function joinWordao(address  userAddr) public onlyMaster { 
        if(wordDaoInfo.creatorAddr != userAddr){
            require(wordDaoInfo.bPayed,'unpayed word,can not join!');
        }
        if(!userBalanceDic[userAddr].bValidUser){
            userBalanceDic[userAddr] = cachedUserAccInfo;
            usersList.push(userAddr);
        }
    }
    function isUserJoinWordao(address  userAddr) public view returns(bool){
         return userBalanceDic[userAddr].bValidUser;
    }
    //////////////////////////////////////////////////////////////public////////////////////////////////////////////////////////////////
     
    function createWorDAO(
        uint256 inSlotID,
        address inCreatorAddr,
        string memory inWordName,
        string memory inSymbol,
        string memory inWordDes,
        string memory inWordImage
    ) public onlyMaster{  
        wordDaoInfo.wordID = inSlotID;
        wordDaoInfo.name = inWordName;
        wordDaoInfo.description = inWordDes;
        wordDaoInfo.image = inWordImage;
        wordDaoInfo.creatorAddr = inCreatorAddr;
        wordDaoInfo.bValidWord = true;
        wordDaoInfo.createTime = block.timestamp; 
        
        _name = inWordName;
        _symbol = inSymbol;

        _mintValue(address(this),tokenCounter,inSlotID,maxSharePerSlot);
        holderTokenID =  tokenCounter;

        tokenCounter++;
        //joinWordao(inCreatorAddr);
    }
 
    // callback from external oracle
    function createWordCallback(
        uint8 inWordLevel, 
        address inCreator, 
        uint256 inGrantRate
    )  public onlyMaster{
        console.log("=============> createWordCallback = ",msg.sender,address(this));
        require(inCreator == wordDaoInfo.creatorAddr,"invalid creator from master"); 
         
        wordDaoInfo.wordType = inWordLevel;
         
       uint256 createShareOfSlot = (maxSharePerSlot * inGrantRate) / 100; 
        // step1: mint an empty nft
        ERC3525._mintValue( inCreator, tokenCounter, wordDaoInfo.wordID, 0);

        // step2: transfer to new nft 
        this.approve(holderTokenID, inCreator, createShareOfSlot);
        this.transferFrom(holderTokenID, tokenCounter, createShareOfSlot);

        //console.log("=============> onCreateWordCallback createShareOfSlot = ",createShareOfSlot); 
        userTokenIdDic[inCreator] = tokenCounter;

        tokenCounter++;
        // wordDaoInfo.leftShare = maxSharePerSlot - minStakeSharePerSlot;
        // wordDaoInfo.totalReleasedShare += createShareOfSlot;
        // TODO TEST CASE
        {
            wordDaoInfo.leftShare = maxSharePerSlot - minStakeSharePerSlot + preReleasedShare;
            wordDaoInfo.totalReleasedShare += createShareOfSlot + preReleasedShare;
        }

        wordDaoInfo.bPayed = true;
        wordDaoInfo.createTime = block.timestamp;
    } 
    // release share
    function releaseShareForWord(address userAddr) public onlyMaster{ 
        console.log("=============> onReleaseShareForWords = ", userAddr);
        uint256 releasedShare = cfgCT.getReleasedShareByLevel(wordDaoInfo.wordType);
        if(wordDaoInfo.totalReleasedShare <(maxSharePerSlot-minStakeSharePerSlot) && wordDaoInfo.leftShare < maxSharePerSlot){
            wordDaoInfo.leftShare += releasedShare;
            wordDaoInfo.totalReleasedShare += releasedShare;
            console.log("=============> onReleaseShareForWords = ", wordDaoInfo.leftShare,releasedShare);
        }
    }

    function buyShareOfWord(address userAddr,uint256 wordID, uint256 buyShareRate) public {
        require(wordDaoInfo.bValidWord,'invalid wordID'); 
        require(wordDaoInfo.leftShare > minStakeSharePerSlot,'not enough released share');
        
        uint256 buyShareOfSlot = (maxSharePerSlot * buyShareRate) / 1000;
        require(wordDaoInfo.leftShare >= (buyShareOfSlot + minStakeSharePerSlot),'not enough share left');
 
        joinWordao(userAddr);  
        console.log("=============> buyShareOfWord  = ", buyShareOfSlot); 
        wordDaoInfo.leftShare -= buyShareOfSlot;
    }
    function changeCreateTime(uint256 timeStamp) public onlyMaster {
        console.log('changeCreateTime ===> ', wordDaoInfo.createTime,timeStamp);
        wordDaoInfo.createTime = timeStamp;
    }
    //////////////////////////////////////////////////////////////public////////////////////////////////////////////////////////////////

    function getCurrentBuyPrice(uint256 buyShareRate) public view returns(uint256){ 
        require(wordDaoInfo.bValidWord,'invalid wordID'); 
        require(wordDaoInfo.leftShare > minStakeSharePerSlot,'not enough released share');

        uint8 level = wordDaoInfo.wordType; 
        uint256 validFansCnt = WordaoUsers(payable(userMgrAddr)).getValidUserCount(usersList);
        uint256 buySharePrice = cfgCT.getInvestPrice(buyShareRate, validFansCnt, level); 
        return buySharePrice; 
    }
    function getHolderTokenID() public view returns(uint256){
        return holderTokenID;
    }
    function getUserTokenID(address userAddr) public view returns(uint256){
        return userTokenIdDic[userAddr];
    }
    function getUserBalance(address userAddr) public view returns(uint256){
        if(userTokenIdDic[userAddr] == 0){
            return 0;
        }
        return balanceOf(userTokenIdDic[userAddr]);
    }
    function getWordInfo() public view returns (wordInfo memory) {
        return wordDaoInfo;
    }
}
