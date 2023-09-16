#!/usr/bin/env python
# -*- coding:utf-8 -*-  
import os,json,io,datetime 
import sys,traceback 
import random
from turtle import right
import common.czUtils as czUtils 
from common.czConsoleUtils import Color,Mode,LogPrint,LogGreen,LogWarning,LogError

import sys 

class czCfgHelper():

    bProduct = False
    cfgJson = ''
    cfgHelper = None
    discountCfg = {}
    releaseShare = {}

    def __init__(self):
        self.cfgJson = ''
        self.initCfg()
        self.genCfgDiscountTemplate()
        self.genCfgReleaseShareTemplate()
        self.cfgHelper = self

    def initCfg(self): 
        cfgFilePath = os.getcwd()+'/{}.json'.format('czWordaoCfg')
        self.cfgJson = self.loadJsonCfg(cfgFilePath) 
        LogGreen('initCfg:{}'.format(self.cfgJson))
         
        #cfgParam = {}
        # cfgParam ['secret_id'] = secret_id;
        # cfgParam ['secret_key'] = secret_key;
        # cfgParam ['region'] = region;
        # cfgParam ['bucket'] = self.bucket; 
        # self.saveJsonCfg(cfgFilePath,cfgParam)

    def writeTemplateCfg(self): 
        cfgFilePath = os.getcwd()+'/{}.json'.format('czWordaoCfg.tpl')
         
        LogGreen('writeTemplateCfg:{}'.format(self.cfgJson))
        cfgParam = {}
        cfgParam ['local'] = {
            'main':{
                'contract':'0x5FbDB2ddddddddddddddddd',
                'abiPath':'',
            },
            'oracle':{
                'contract':'0x5FbDB2ddddddddddddddddd',
                'abiPath':'',
            },
            'user':{
                'contract':'',
                'abiPath':'',
            },
            'stake':{
                'contract':'',
                'abiPath':'',
            },
            'provider_url':'',
        };
        self.saveJsonCfg(cfgFilePath,cfgParam)
 
    # load config
    def loadJsonCfg(self,cfgFilePath): 
        LogGreen('loadJsonCfg:{}'.format(cfgFilePath))
        cfgJson = ''
        with open(cfgFilePath,'r',encoding = 'utf-8') as cfgFile:
                cfgJson =  json.load(cfgFile) 
                cfgFile.close()
        return cfgJson

    # save config
    def saveJsonCfg(self,cfgFilePath,jsonData):  
        LogGreen('saveJsonCfg:{}'.format(cfgFilePath))
        with open(cfgFilePath,'w',encoding = 'utf-8') as jsonFile:
            if jsonData: 
                json.dump(jsonData,jsonFile,indent = 4,ensure_ascii=False)
                return True
        return False

    # make cfg init template
    def genCfgDiscountTemplate(self): 
        self.discountCfg = discountCfg = {}
        discountCfg['lv0'] = {'level':0,'score':[-1,0],'grantRate':25,'price':'0.01','rand':[[0,10,100],[10,20,50],[20,80,0]]}
        discountCfg['lv1'] = {'level':1,'score':[0,10],'grantRate':15,'price':'0.01','rand':[[0,5,100],[5,15,50],[15,25,20],[25,100,0]]}
        discountCfg['lv2'] = {'level':2,'score':[10,30],'grantRate':10,'price':'0.01','rand':[[0,5,100],[5,15,50],[15,25,20],[25,40,10],[40,100,0]]}
        discountCfg['lv3'] = {'level':3,'score':[30,50],'grantRate':5,'price':'0.01','rand':[[0,1,100],[1,6,50],[6,26,20],[26,51,10],[51,100,0]]}
        discountCfg['lv4'] = {'level':4,'score':[50,75],'grantRate':3,'price':'0.01','rand':[[0,0.5,100],[0.5,3,50],[3,13,20],[13,28,10],[28,53,5],[53,100,0]]}
        discountCfg['lv5'] = {'level':5,'score':[75,100],'grantRate':2,'price':'0.01','rand':[[0,0.5,100],[0.5,3,50],[3,13,20],[13,28,10],[28,53,5],[53,100,0]]}
        self.saveJsonCfg('discountCfg.json',discountCfg)
        
    # make cfg init template 这里比例是千分制
    def genCfgReleaseShareTemplate(self): 
        self.releaseShare = releaseShare = {}
        releaseShare['lv0'] = {'level':0,'score':[-1,0],'creatorShare':25,'maxReleaseShareRate':50,'addShareRatePerFan':25,'minBuyShareRate':20,'maxUnitOfEachBuy':10,'priceOfBuyBase':'0.001','addPricePerFan':'0.00001',}
        releaseShare['lv1'] = {'level':1,'score':[0,10],'creatorShare':15,'maxReleaseShareRate':50,'addShareRatePerFan':15,'minBuyShareRate':10,'maxUnitOfEachBuy':10,'priceOfBuyBase':'0.001','addPricePerFan':'0.00001',}
        releaseShare['lv2'] = {'level':2,'score':[10,30],'creatorShare':10,'maxReleaseShareRate':50,'addShareRatePerFan':10,'minBuyShareRate':5,'maxUnitOfEachBuy':10,'priceOfBuyBase':'0.001','addPricePerFan':'0.00001',}
        releaseShare['lv3'] = {'level':3,'score':[30,50],'creatorShare':5,'maxReleaseShareRate':50,'addShareRatePerFan':5,'minBuyShareRate':1,'maxUnitOfEachBuy':10,'priceOfBuyBase':'0.001','addPricePerFan':'0.00001',}
        releaseShare['lv4'] = {'level':4,'score':[50,75],'creatorShare':3,'maxReleaseShareRate':50,'addShareRatePerFan':2,'minBuyShareRate':1,'maxUnitOfEachBuy':10,'priceOfBuyBase':'0.001','addPricePerFan':'0.00001',}
        releaseShare['lv5'] = {'level':5,'score':[75,100],'creatorShare':2,'maxReleaseShareRate':50,'addShareRatePerFan':1,'minBuyShareRate':1,'maxUnitOfEachBuy':10,'priceOfBuyBase':'0.001','addPricePerFan':'0.00001',}
        self.saveJsonCfg('releaseShare.json',releaseShare)
        
    # make random discount rate
    def getDiscountInfo(self, wordScore,randSeed):
        discountCfg = self.discountCfg
        for key in discountCfg:
            wordLevel = discountCfg[key]['level']
            score = discountCfg[key]['score']
            grantRate = discountCfg[key]['grantRate']
            price = discountCfg[key]['price']
            randList = discountCfg[key]['rand']
            leftScore = score[0]
            rightScore = score[1]
            if wordScore >= leftScore and wordScore < rightScore:
                # print(key,discountCfg[key][])
                expScale = 10000 
                randValue = randSeed*expScale
                if randSeed < 0:
                    randValue = random.randrange(1,100*expScale)
                for idx in range(0,len(randList)):
                    leftRand = randList[idx][0]
                    rightRand = randList[idx][1]
                    exemptRate = randList[idx][2]
                    if randValue >= leftRand*expScale and randValue < rightRand*expScale:
                        return wordLevel,grantRate,exemptRate,price
        return 0,0,0,0
    
    # 更新合约配置--股权释放的配置参数
    def updateCTReleaseShareInfo(self,wDaoOracleInst):
        releaseShare = self.releaseShare
        try:
            for key in releaseShare:
                shareItem = releaseShare[key]
                level = shareItem['level']
                creatorShare = shareItem['creatorShare']
                maxReleaseShareRate = shareItem['maxReleaseShareRate']
                addShareRatePerFan = shareItem['addShareRatePerFan']
                minBuyShareRate = shareItem['minBuyShareRate']
                maxUnitOfEachBuy = shareItem['maxUnitOfEachBuy']
                priceOfBuyBase = wDaoOracleInst.w3.toWei(shareItem['priceOfBuyBase'], "ether")
                addPricePerFan = wDaoOracleInst.w3.toWei(shareItem['addPricePerFan'], "ether")

                tx_hash = wDaoOracleInst.cfgCT.functions.updateInvestConfig(
                                                                level,
                                                                creatorShare,
                                                                maxReleaseShareRate,
                                                                addShareRatePerFan,
                                                                minBuyShareRate,
                                                                maxUnitOfEachBuy,
                                                                priceOfBuyBase,
                                                                addPricePerFan
                ).transact({"from": '0xf39Fdxxxxxxxxxxxxxxxxxxxx'});

            LogGreen('updateCTReleaseShareInfo:{}'.format(shareItem))
        except:
            import sys,traceback
            traceback.print_exc()
            LogError('updateCTReleaseShareInfo: failed')

cfgHelper = None
if __name__ == "__main__": 
    if not cfgHelper :
        cfgHelper = czCfgHelper()
        #cfgHelper.writeTemplateCfg()