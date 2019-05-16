var SafeMath = artifacts.require("SafeMath");
var StandardToken = artifacts.require("StandardToken");
var BlockRegistry = artifacts.require("BlockRegistry");
var Elemmire = artifacts.require("Elemmire");
var QOT = artifacts.require("QOT");
var MemberShip = artifacts.require("MemberShip");
var Erebor = artifacts.require("Erebor");

module.exports = function(deployer) {
    deployer.deploy(SafeMath);
    deployer.link(SafeMath, [StandardToken, BlockRegistry, QOT]);
    deployer.deploy(StandardToken);
    deployer.deploy(BlockRegistry);
    deployer.deploy(Elemmire).then( (iElemmire) => {
        return deployer.deploy(QOT).then( (iQOT) => {
            return deployer.deploy(MemberShip, QOT.address).then( () => {
                return deployer.deploy(
                    Erebor,
                    "0xb44f3694da66770fa00b4bc40386726988a37a96dfad4d9e097c43938353cf14",  // keccak256('Optract')
                    QOT.address,
                    Elemmire.address,
                    MemberShip.address);
            }).then( (i) => {
                iElemmire.setMining(Erebor.address, 0);
                iQOT.setMining(Erebor.address, 0);
            })
        })
    })
}
