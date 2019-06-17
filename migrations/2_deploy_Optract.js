var SafeMath = artifacts.require("SafeMath");
var StandardToken = artifacts.require("StandardToken");
var BlockRegistry = artifacts.require("BlockRegistry");
var QOT = artifacts.require("QOT");
var MemberShip = artifacts.require("MemberShip");

module.exports = function(deployer) {
    deployer.deploy(SafeMath);
    deployer.link(SafeMath, [StandardToken, BlockRegistry, QOT]);
    deployer.deploy(StandardToken);
    deployer.deploy(BlockRegistry);
    return deployer.deploy(QOT).then( (iQOT) => {
        return deployer.deploy(MemberShip, QOT.address)
            // "0xb44f3694da66770fa00b4bc40386726988a37a96dfad4d9e097c43938353cf14",  // keccak256('Optract')
    })
}
