
#!/usr/bin/env python
# -*- coding:utf-8 -*-
  
import sys,os 
import requests
import json
import urllib
import time
import datetime
import random
import string 
from urllib.parse import urlparse
import math
import base64
import hmac

import sys,traceback  
from traceback import format_exception

import urllib3
import threading

urllib3.disable_warnings()

from http.server import BaseHTTPRequestHandler 
from common.czConsoleUtils import LogError,LogGreen
from common.czLogUtils import czLogUtils 
import common.czUtils as czUtils
#from czCfgHelper import czCfgHelper 

class czLocalWebService(czLogUtils,BaseHTTPRequestHandler):
    
    bProduct = False
    cfgJson = ''
    cfgHelper = None
    czMasterInst = None

    def __init__(self, request, client_address, server):
        czLogUtils.__init__(self)
        # 先初始化父类的构造，再初始化子类的值
        BaseHTTPRequestHandler.__init__(self, request, client_address, server)
        self.cfgHelper = None
    
    #处理 get来的数据
    def do_GET(self):  
        try:    
            #print(data)
            # 回调给相应的接口处理
            response = self.onGetRequestCallback()
 
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Access-Control-Allow-Methods', '*')
            self.send_header('Access-Control-Allow-Headers', '*')
            self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate')
            self.end_headers()  
            self.wfile.write(bytes(json.dumps(response, ensure_ascii=False), 'utf-8'))
            LogGreen('do_Get over')
        except:
            import sys,traceback
            traceback.print_exc()
            LogError('do_Get json body error')

    #处理 post来的数据
    def do_POST(self):  
        self.send_response(200)
        self.end_headers()

        length = int(self.headers['Content-Length'])
        #for item in self.headers.items: 
        #print(length)
        data = ''
        try:  
            jsonData = json.loads(self.rfile.read(length)) 
            data = jsonData
            #print(data)
            # 回调给相应的接口处理
            response = self.onPostRequestCallback(data)

            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.end_headers()  
            self.wfile.write(bytes(json.dumps(response, ensure_ascii=False), 'utf-8'))
            LogGreen('do_POST over')
        except:
            LogError('do_POST json body error')
   
    def onGetRequestCallback(self):
        #print('base request call back')
        #global czMasterInst
        if self.czMasterInst:
            return self.czMasterInst.onGetRequestCallback(self.path)
        
        data = {} 
        data['code'] = 0
        import urllib
        parsedPath = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsedPath.query)
        print(self.path,parsedPath,params)
        
        if parsedPath.path.startswith("/request_token"): 
            #tabID = params['tabid'][0]
            data['data'] = {'oauth_token':self.getTwitterAuthToken()}
            #print(tabID) 
        elif parsedPath.path.startswith("/access_token"):
            tabID = params['tabid'][0]
            print(tabID) 
        else: 
            LogError('onGetRequestCallback unknown request!!!')

        return data

    def onPostRequestCallback(self,body):
        print('base request call back')
        #global czMasterInst
        if self.czMasterInst:
            return self.czMasterInst.onPostRequestCallback(body)
        
        data = {}
        data['code'] = 0
        data['xPosList'] = []
        return data 
        
    @staticmethod
    def getTwitterAuthToken():
        from requests_oauthlib import OAuth1Session
        consumer_key = 'O0wkpbxxxxxi'
        consumer_secret = 'O0wkpbxxxxxi'
        # Get request token
        request_token_url = "https://api.twitter.com/oauth/request_token"
        oauth = OAuth1Session(consumer_key, client_secret=consumer_secret)
        fetch_response = None
        try:
            proxies = {"http": 'http://127.0.0.1:1080',"https": 'http://127.0.0.1:1080',} 
            fetch_response = oauth.fetch_request_token(request_token_url,verify=False,proxies=proxies)
            oauth_token = fetch_response.get("oauth_token")
            oauth_token_secret = fetch_response.get("oauth_token_secret")
            print("Got oauth_token: %s" % oauth_token,"oauth_token_secret: %s" % oauth_token_secret)
            return oauth_token
        except ValueError:
            print( "There may have been an issue with the consumer_key or consumer_secret you entered.")
            
    # 启动服务
    @staticmethod
    def serviceThread(threadName,threadID):
        LogGreen('+++++++++++++++startServer+++++++++++++')
        from http.server import HTTPServer 
        try:  
            #listenPort = 8099
            listenPort = czUtils.getAvailablePort(8099)
            LogGreen('start local http server with port : {}'.format(listenPort))
            web_server = HTTPServer(("",listenPort),czLocalWebService)
            web_server.serve_forever()

        except:
            traceback.print_exc(file=open('crash-{0}.log'.format(czLogUtils.getDateYMD()), 'a'))
    
    @staticmethod
    def startServer():
        hThread = threading.Thread(target=czLocalWebService.serviceThread, args=("serviceThread",1))
        hThread.start()
        #time.sleep(5)
            
if __name__=='__main__x':
  
    start = time.time()
    czLocalWebService.startServer()
    end = time.time()

    LogGreen('service online :{}s'.format(end-start))