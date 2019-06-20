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
        return deployer.deploy(MemberShip, QOT.address).then ( () => {
            return deployer.deploy(BlockRegistry, MemberShip.address);
        })
    })
}
