var SafeMath = artifacts.require("SafeMath");
var StandardToken = artifacts.require("StandardToken");
var BlockRegistry = artifacts.require("BlockRegistry");
var QOT = artifacts.require("QOT");
var MemberShip = artifacts.require("MemberShip");
var Flag = artifacts.require("flag");

module.exports = function(deployer) {
    deployer.deploy(SafeMath, {overwrite: false});
    deployer.link(SafeMath, [StandardToken, BlockRegistry, QOT]);
    deployer.deploy(StandardToken, {overwrite: false});
    deployer.deploy(QOT).then( (iQOT) => {
        return deployer.deploy(MemberShip, QOT.address).then ( (iMemberShip) => {
            return deployer.deploy(BlockRegistry, MemberShip.address, QOT.address).then( ()=>{
                return deployer.deploy(Flag, MemberShip.address, BlockRegistry.address, QOT.address).then(()=>{
                    // TODO: promise all all 3 setmining
                    iQOT.setMining(BlockRegistry.address, 0);
                    iQOT.setMining(MemberShip.address, 1);  // mainly for giveMembership
                    iQOT.setMining(Flag.address, 2);  // mainly for giveMembership
                    return iMemberShip.addAppWhitelist(BlockRegistry.address, 3);  // 0, 1, 2 are for coreManagers
                })
            })
        })
    })
}
