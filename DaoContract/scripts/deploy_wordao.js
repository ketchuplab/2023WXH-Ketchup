// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

var czW3Helper = require('../scriptUtils/czWeb3Helper');
var json = require('../package-lock.json');
const { utils } = require("mocha");
const { stringify } = require("querystring");
//console.log(json)
// 方法 - 延时
async function sleep(time) {
  return new Promise((resolve) => setTimeout(async () => {
    resolve()
  }, (time) * 1000));
}
async function OnDataEmit(len, sonTxt) {
  console.log('=====> OnDataEmit', len, sonTxt);
}
async function OnDataWriteback(len, sonTxt) {
  console.log('=====> OnDataWriteback', len, sonTxt);
}
 
// deploy oracle contract
async function deployOracle() {
  const contractFactory = await ethers.getContractFactory("WordaoOracle");
  const deployer = await contractFactory.deploy();
  console.log("Contract slave WordaoOracle deployed to address:", deployer.address);

  return deployer;
}
// deploy stake contract
async function deployStake() {
  const contractFactory = await ethers.getContractFactory("WordaoStake");
  const deployer = await contractFactory.deploy();
  console.log("Contract slave WordaoStake deployed to address:", deployer.address);

  return deployer;
}
// deploy user contract
async function deployUser() {
  const contractFactory = await ethers.getContractFactory("WordaoUsers");
  const deployer = await contractFactory.deploy();
  console.log("Contract slave WordaoUsers deployed to address:", deployer.address);

  return deployer;
}
// deploy config contract
async function deployCfg() {
  const contractFactory = await ethers.getContractFactory("WordaoConfig");
  const deployer = await contractFactory.deploy();
  console.log("Contract slave WordaoConfig deployed to address:", deployer.address);

  return deployer;
}

async function showWordaoBalance(deployer) {
  let masterBalance = await deployer.getMyBalance();
  console.log('WordaoBalance has: ', masterBalance);
}
// deploy wordao master contract
async function deployMaster() {

  // step1: deploy contract
  const oracleDeployer = await deployOracle();
  sleep(1)
  const stakeDeployer = await deployStake();
  sleep(1)
  const userDeployer = await deployUser();
  sleep(1)
  const cfgDeployer = await deployCfg();
  sleep(1)
  const contractFactory = await ethers.getContractFactory("WordaoMain");
  //const masterDeployer = await contractFactory.deploy("WorDAO", "WorDAO", 18);
  const masterDeployer = await contractFactory.deploy();
  console.log("Contract master deployed to address:", masterDeployer.address);

  // step2: set init param for each contract
  await masterDeployer.setOracleCT(oracleDeployer.address)
  await masterDeployer.setUserCT(userDeployer.address)
  await masterDeployer.setCfgCT(cfgDeployer.address)

  await oracleDeployer.setMasterCT(masterDeployer.address)
  await oracleDeployer.setUserCT(userDeployer.address)
  await stakeDeployer.setMasterCT(masterDeployer.address)
  await userDeployer.setOracleCT(oracleDeployer.address)

  console.log("Contract all init done...");
 
  await sleep(10);


  let privateKey1 = "0x59c6995exxxxx"
  let ownerPriKey = "0xac0974becxxxxx"
  //let wallet = new ethers.Wallet(privateKey)
  let wallet =new ethers.Wallet(privateKey1, masterDeployer.provider);
  let ownerWallet =new ethers.Wallet(ownerPriKey, masterDeployer.provider);

  let balance = await wallet.getBalance();
  let ownerBalance = await ownerWallet.getBalance();
   
  await showWordaoBalance(masterDeployer);

  console.log("begin createWorDAO :");

  let wordList = ['battle', 'trận đánh', '战争', 'боевой', 'معركة', '戦い', '전투', 'การต่อสู้', 'бій', 'savaş']
  
  for (let idx = 0; idx < 0; ++idx) {
    beginBalance = await wallet.getBalance();
    await masterDeployer.connect(wallet).createWorDAO(wordList[idx], 'this is description!!', 'http://a.io/101.png');
    //await masterDeployer.connect(wallet).createWorDAOTest();
    endBalance = await wallet.getBalance();
    let etherString = ethers.utils.formatEther(beginBalance-endBalance);
    console.log('cost =====>',ethers.utils.formatEther(beginBalance),ethers.utils.formatEther(endBalance),etherString);
  }
  //await masterDeployer.reqDataEmit(jsonTxt.length,jsonTxt);
  
  for (let idx = 0; idx < 2; ++idx) {
    console.log('createWorDAO ======>', wordList[idx])
    await masterDeployer.createWorDAO(wordList[idx], 'this is description!!', 'http://a.io/101.png', {
      value: ethers.utils.parseEther("0.01")
    });
    
    await sleep(10)
    await showWordaoBalance(masterDeployer);
  }

  console.log("createWorDAO done");

  await sleep(5)

}
async function main() {
  await deployMaster();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});