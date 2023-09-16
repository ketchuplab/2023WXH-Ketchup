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
// deploy holder contract
async function deployHolder() {
  const contractFactory = await ethers.getContractFactory("WordaoHolder");
  const deployer = await contractFactory.deploy();
  console.log("Contract slave deployHolder deployed to address:", deployer.address);

  return deployer;
}

async function showWordaoBalance(deployer) {
  let masterBalance = await deployer.getMyBalance();
  console.log('WordaoBalance has: ', masterBalance);
}
// deploy wordao master contract
async function deployMaster() {

  // step1: deploy contract
  const holderDeployer = await deployHolder();
  const decimals = 1000000000000000000; 
  await showWordaoBalance(holderDeployer);

  console.log("begin createWorDAO :");

  let fakeNo_00 = "0xac0ccccccccccccccccccccccccccccccccc" 
  let wallet =new ethers.Wallet(fakeNo_00, holderDeployer.provider); 
  let balance1 = await wallet.getBalance()/decimals;
  console.log('===========> wallet balance before: ',balance1)
  
  let wordList = ['battle', 'trận đánh', '战争', 'боевой', 'معركة', '戦い', '전투', 'การต่อสู้', 'бій', 'savaş']
   
  console.log('createWorDAO ======>', wordList[0])
  await holderDeployer.createWorDAO(wordList[0], 'this is description!!', 'http://a.io/101.png', {
    value: ethers.utils.parseEther("0.01")
  });
  
  let balance2 = await wallet.getBalance()/decimals;
  console.log('===========> wallet balance after: ',balance1,balance2,balance1-balance2)
  return
  await sleep(1)
  await showWordaoBalance(holderDeployer);

  let holderBalance = await holderDeployer["balanceOf(uint256)"](1000); 
  console.log("holderBalance before:",holderBalance);  
  
  /*
   uint8 wordLevel,
        address inCreator,
        uint256 grantRate,
        uint256 exemptionRate
  */
  
  await holderDeployer.onCreateWordCallback(2,'0xf39Fcccccccccccc',5,0);

  holderBalance = await holderDeployer["balanceOf(uint256)"](1000);
  console.log("holderBalance after:",holderBalance);
  
  let buyerBalance = await holderDeployer["balanceOf(uint256)"](1001); 
  console.log("buyerBalance :",buyerBalance);  

  let balance3 = await wallet.getBalance()/decimals;
  console.log('===========> wallet balance after: ',balance2,balance3,balance2-balance3)
  // end
  console.log("createWorDAO done"); 
  await sleep(5) 
}
async function main() {
  await deployHolder();
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});