var SafeMath = artifacts.require("SafeMath");
var StandardToken = artifacts.require("StandardToken");
var BlockRegistry = artifacts.require("BlockRegistry");
var QOT = artifacts.require("QOT");
var MemberShip = artifacts.require("MemberShip");

module.exports = function(deployer) {
    deployer.deploy(SafeMath);
    deployer.link(SafeMath, [StandardToken, BlockRegistry, QOT]);
    deployer.deploy(StandardToken);
    return deployer.deploy(QOT).then( () => {
        return deployer.deploy(MemberShip, QOT.address).then ( (iMemberShip) => {
            return deployer.deploy(BlockRegistry, MemberShip.address).then( (iBlock)=>{
                // iMemberShip.addWhitelistApps(BlockRegistry.address, (err,r) => {  // cannot work?
                iMemberShip.addWhitelistApps(iBlock.address, (err,r) => {  // need test
                    if (err) { console.trace(err); throw "bad2" };
                })
            })
        })
    })
}
