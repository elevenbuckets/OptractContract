var SafeMath = artifacts.require("SafeMath");
var StandardToken = artifacts.require("StandardToken");
var BlockRegistry = artifacts.require("BlockRegistry");
var QOT = artifacts.require("QOT");
var MemberShip = artifacts.require("MemberShip");

module.exports = function(deployer) {
    deployer.deploy(SafeMath, {overwrite: false});
    deployer.link(SafeMath, [StandardToken, BlockRegistry, QOT]);
    deployer.deploy(StandardToken, {overwrite: false});
    deployer.deploy(QOT).then( (iQOT) => {
        return deployer.deploy(MemberShip, QOT.address).then ( (iMemberShip) => {
            return deployer.deploy(BlockRegistry, MemberShip.address).then( ()=>{
                // iQOT.setMining(BlockRegistry.address, 0);  // leave it for future, or manually
                return iMemberShip.addAppWhitelist(BlockRegistry.address, 3);  // 0, 1, 2 are for coreManagers
            })
        })
    })
}
