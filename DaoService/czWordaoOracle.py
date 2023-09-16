#!/usr/bin/env python
# -*- coding:utf-8 -*-
# web3 使用的python例子参考： https://www.dappuniversity.com/articles/web3-py-intro

import os,sys
from web3 import Web3, HTTPProvider
import json
# import contract_abi
import threading
from eth_account import Account
from web3 import Web3

import time,datetime
import asyncio

import common.czUtils as czUtils
from czCfgHelper import czCfgHelper 
from czOracleHelper import czOracleHelper 
from czLocalWebService import czLocalWebService 
from common.czConsoleUtils import Color,Mode,LogPrint,LogGreen,LogWarning,LogError
from common.czLogUtils import czLogUtils

class czWordaoOracle(czLogUtils): 
    bProduct = False
    canRunTick = True
    providerIdx = 0
    def __init__(self,nodeIdx = 0,providerIdx = 0):

        czLogUtils.__init__(self)
        self.czWriteLog(os.path.split(__file__)[-1].split(".")[0] + '__init__ done','log')

        self.cfgHelper = czCfgHelper()
        self.oracleHelper = czOracleHelper(self)

        czLocalWebService.czMasterInst = self.oracleHelper;
        czLocalWebService.startServer()

        self.cfgParam = self.cfgHelper.cfgJson
        self.nodeIdx = nodeIdx
        self.providerIdx = providerIdx
        self.oracleNodeID = ''
        # 初始化所有合约地址
        self.initWeb3New() 
        # 初始化合约配置
        self.initContractCfg();
        # 加入预言机
        self.joinOracle();

        self.failedQueue = []
        
    
    def initWeb3(self):
        contract_addresses = [
            self.cfgParam['local_contract_address'],
            self.cfgParam['goerli_contract_address'],
            self.cfgParam['mainNet_contract_address'],
        ]
        self.contract_address     = contract_addresses[self.providerIdx]
        self.abiPath     = self.cfgParam['abiPath']   
        proxies = {"http": None,"https": None,}         # 解决代理发不出去消息的问题 
        providerUrl = [
            self.cfgParam['localProvideUrl'],
            self.cfgParam['goerliProvideUrl'],
            self.cfgParam['mainNetProvideUrl'],
        ]
        self.w3 = Web3(HTTPProvider(providerUrl[self.providerIdx],request_kwargs={
                            #"timeout": 1000,
                            "proxies": proxies
                        }))

        #w3 = Web3(Web3.EthereumTesterProvider())
        print('w3.isConnected : ',self.w3.isConnected())
        # w3.eth.enable_unaudited_features()
        #abiPath = './czSharkBeeNFT.json' 

        contract_abi = ''
        with open(self.abiPath, 'r') as f:
            contract_abi = json.loads(f.read())
            #print(contract_abi['abi']) 

        self.contract = self.w3.eth.contract(address = Web3.toChecksumAddress(self.contract_address), abi = contract_abi['abi'])
        print('contract == > ',self.contract)
     
    # 获取合约通用接口
    def getContract(self,ctCfg):
        if len(ctCfg['contract']) <= 0 or len(ctCfg['abiPath']) <= 0:
            LogError('getContract error {}'.format(ctCfg))
            return ''

        contract_abi = ''
        with open(ctCfg['abiPath'], 'r') as f:
            contract_abi = json.loads(f.read())
            #print(contract_abi['abi'])
        return self.w3.eth.contract(address = Web3.toChecksumAddress(ctCfg['contract']), abi = contract_abi['abi'])

    def initWeb3New(self):

        userContract = ['local','goerli','mainNet',]
        ctKey  = userContract[self.providerIdx]
        print('initWeb3New ==> ',self.cfgParam[ctKey])
        self.mainCTCfg = self.cfgParam[ctKey]['main']
        self.oracleCTCfg = self.cfgParam[ctKey]['oracle']
        self.userCTCfg = self.cfgParam[ctKey]['user']
        self.stakeCTCfg = self.cfgParam[ctKey]['stake']
        self.cfgCTCfg = self.cfgParam[ctKey]['config']

        providerUrl = self.cfgParam[ctKey]['provider_url']

        proxies = {"http": None,"https": None,}         # 解决代理发不出去消息的问题 
        self.w3 = Web3(HTTPProvider(providerUrl,request_kwargs={
                            #"timeout": 1000,
                            "proxies": proxies
                        }))

        #w3 = Web3(Web3.EthereumTesterProvider())
        print('w3.isConnected : ',self.w3.isConnected())
        # w3.eth.enable_unaudited_features()
 
        self.mainCT = self.getContract(self.mainCTCfg)
        self.oracleCT = self.getContract(self.oracleCTCfg)
        self.userCT = self.getContract(self.userCTCfg)
        self.stakeCT = self.getContract(self.stakeCTCfg)
        self.cfgCT = self.getContract(self.cfgCTCfg)

    # 初始化合约配置
    def initContractCfg(self):
 
        self.cfgHelper.updateCTReleaseShareInfo(self)
    
    def joinOracle(self):
        ret = 0
        msg = ''
        try:
            walletAddr = '0xf3cccccccccccccccccc'
            print('joinOracle======>',self.oracleCT.functions)
            userNodesList = self.oracleCT.functions.getUserOracleNodes(walletAddr).call()
            print('userNodesList = ',userNodesList)

            if len(userNodesList) <= 0:
                tx_hash = self.oracleCT.functions.joinOracle().transact({"from": walletAddr,"value": self.w3.toWei("0.01", "ether")})
            # and whatever
            userNodesList = self.oracleCT.functions.getUserOracleNodes(walletAddr).call()
            self.oracleNodeID = userNodesList[self.nodeIdx]
            LogGreen('joinOracle success ===========> wallet =  {}, oracleNodeID = {}'.format(walletAddr,self.oracleNodeID))
            msg = 'oracle joinOracle success'
        except:
            LogError('joinOracle error : {}'.format(walletAddr))
            ret = 1
            msg = 'oracle joinOracle error'
            import sys,traceback
            traceback.print_exc()
        return ret,msg
        
    def checkBalanceInfo(self,wallet_address):
        wallet_address       = '0x942Bbcccccccccccc'
        balance = self.w3.eth.getBalance(wallet_address)
        print('wallet_address balance: ',self.w3.fromWei(balance, "ether"))

    # 获取指定用户信息
    def getUserDetail(self,address): 
        address = self.w3.toChecksumAddress(address)
        userDetail = self.contract.functions.getUserDetail(address).call()
        print("getUserDetail == > ",userDetail)
        try:
            return True,userDetail
        except:
            print('getUserDetail error')
        return False,''

    def checkContractInfo(self):
                
        totalSupply = self.contract.functions.totalSupply().call()
        print("totalSupply == > ",self.w3.fromWei(totalSupply, 'ether'))

        czConfig = self.contract.functions.getContractConfig().call()
        print("czConfig == > ",czConfig)

        tokenUri = self.contract.functions.tokenURI(5).call()
        print("tokenUri == > ",tokenUri)

        ownerOfToken = self.contract.functions.ownerOf(5).call()
        print("ownerOfToken == > ",ownerOfToken)

        the_lower_case_ganache_address = 'xxxxxxxxxxxxxxxx'

        balanceOfOwner = self.contract.functions.balanceOf(Web3.toChecksumAddress(the_lower_case_ganache_address)).call()
        print("balanceOfOwner == > ",balanceOfOwner)

    ########################################################### 处理其他合约服务 #####################################################
    def getWordaoID(self,sWord): 
        try: 
            slotID = self.mainCT.functions.getSlotID(sWord,self.w3.toChecksumAddress(self.mainCTCfg['contract'])).call()
            bValid = self.mainCT.functions.isWordValid(slotID).call()
            #wordList = self.mainCT.functions.getWordList(0).call()
            print('getWordaoID ========> ',slotID,bValid)
            #print('getWordaoID toText ========> ',self.w3.toText(str=slotID))
            return True,'{}'.format(slotID)
        except ValueError:
            LogError( "getWordaoID Error")
        return False,''

    # 判定词是否有效存在
    def isWordValid(self,wordID): 
        try: 
            bValid = self.mainCT.functions.isWordValid(self.w3.toInt(text = wordID)).call()
            return True,bValid
        except ValueError:
            LogError( "isWordValid Error {}".format(wordID))
        return False,''
    
    # 获取word词的信息
    def getWordInfo(self,wordID): 
        try: 
            wordInfo = self.mainCT.functions.getWordInfo(self.w3.toInt(text = wordID)).call()
            print('=====> wordInfo : ', wordInfo)
            LogWarning('wordInfo bValid: {}'.format(wordInfo[8]))
            return wordInfo[8],wordInfo
        except ValueError:
            LogError( "getWordInfo Error {}".format(wordID))
        return False,''

    # twitter 验证
    def doVerifyUser(self,walletAddr):
        ret = 0
        msg = ''
        try:
            tx_hash = self.oracleCT.functions.onVerifyUserCallback(Web3.toChecksumAddress(walletAddr),True).transact({"from": '0xf39Fcccccccccc266'});
            # and whatever
            LogGreen('doVerifyUser success ===========> {}'.format(walletAddr))
            msg = 'oracle doVerifyUser success'
        except:
            LogError('doVerifyUser error : {}'.format(walletAddr))
            ret = 1
            msg = 'oracle doVerifyUser error'
            import sys,traceback
            traceback.print_exc()
        return ret,msg

    # 获取创建价格相关信息
    def getWordCreateInfo(self, word,randSeed):
        ret,avgScore = self.oracleHelper.getWordScore(word)
        if not ret:
            LogError('getWordCreateInfo error 1: {},{}'.format(word,ret))
            return False,0,0,0,0,0;
        averageScore = int(avgScore)
        wordLevel,grantRate,exemptRate,price = self.cfgHelper.getDiscountInfo(averageScore,randSeed) 
        LogGreen('getWordCreateInfo : {},{},{},{},{}'.format(word,wordLevel,grantRate,exemptRate,price))
        return True,averageScore,wordLevel,grantRate,exemptRate,price

    ########################################################### 接收合约事件 #####################################################
    def handle_event(self,event):
        #print(Web3.toJSON(event))
        creatorAddr = event['args']['creatorAddr'] 
        wordID = event['args']['wordID']
        nodeIDList = event['args']['nodeIDs']
        word = event['args']['wordTxt']
        randSeed = event['args']['randSeed']
        nodeID = 0
        print('handle_event args ==> ',word,randSeed,nodeIDList)
        for nID in nodeIDList:
            if nID == self.oracleNodeID:
                nodeID = nID;
                break;
        if nodeID != self.oracleNodeID:
            LogWarning('{}-{} is not my job'.format(word,nodeID))
            return True,wordID

        ret,avgScore,wordLevel,grantRate,exemptRate,price = self.getWordCreateInfo(word,randSeed)
        if not ret: 
            LogError('handle_event error 1: {},{},{},{}'.format(wordID,creatorAddr,wordID,ret))
            return ret,wordID
        try:
            #address inCreator,uint256 inWordID,uin8 wordLevel, uint256 hotScore,uint256 grantRatio,uint256 exemptionRate,string memory inWordTxt
            tx_hash = self.oracleCT.functions.onCreateWordCallback(nodeID,creatorAddr,wordID,wordLevel,avgScore,grantRate,exemptRate,word).transact({"from": '0xfccccccccccccc2266'})
            # and whatever
            print('handle_event ===========> done ')
            ret = True
        except:
            ret = False
            import sys,traceback
            traceback.print_exc()
            LogError('handle_event error 2: {},{},{},{},{}'.format(nodeID,wordID,creatorAddr,wordID,ret))
        
        return ret,wordID

    async def log_loop(self,event_filter, poll_interval):
        while True:
            for event in event_filter.get_new_entries():
                ret,wordID = self.handle_event(event)
                if not ret :
                    from functools import reduce
                    ret = reduce(lambda pre,cur:cur if cur['args']['wordID'] == wordID else pre,self.failedQueue,None)
                    if not(ret and 'args' not in ret):
                        LogWarning('log_loop: handle_event add {}-{}'.format(len(self.failedQueue),wordID))
                        self.failedQueue.append(event)
                        
            await asyncio.sleep(poll_interval)
            if len(self.failedQueue) > 0:
                ret,wordID = self.handle_event(self.failedQueue[0])
                LogWarning('log_loop: handle_event try: {}-{}-{}'.format(len(self.failedQueue),ret,wordID))
                if ret: 
                    self.failedQueue.pop(0)

    def mainEventLoop(self):
        if not self.w3.isConnected():
            LogError('mainEventLoop disconnect!!')
            return;
        event_filter = self.oracleCT.events.OnOracleCreateWord.createFilter(fromBlock='latest')
        # block_filter = web3.eth.filter('latest')
        # tx_filter = web3.eth.filter('pending')
        loop = asyncio.get_event_loop()
        try:
            loop.run_until_complete(
                asyncio.gather(self.log_loop(event_filter, 2)))
                    # log_loop(block_filter, 2),
                    # log_loop(tx_filter, 2)))
        finally:
            loop.close()
             
 
if __name__ == "__main__":
    
    print(sys.argv)
    nodeIdx = int(sys.argv[1])
    start = time.time()
    oracleServiceInst = czWordaoOracle(nodeIdx,0)
    oracleServiceInst.mainEventLoop()
 
    end = time.time()

    print('======> total Running time: %s Seconds'%(end-start)) 
 
print('Child process end.')