const { expect } = require("chai");

describe("Reward" , function(){

  // deploy Reward
  async function deployReward(){
    // Reward
    const Reward = await hre.ethers.getContractFactory("Reward");
    const reward = await Reward.deploy();
    await reward.deployed();

    return {reward};
  }

  it("Owner" , async function(){
    const [owner] = await ethers.getSigners();
    let ownerAddress;
    await owner.getAddress().then((ret) => {
        ownerAddress = ret;
    });
    const {reward} = await deployReward();        
    expect(await reward.owner()).to.equal(ownerAddress);
  });


});
