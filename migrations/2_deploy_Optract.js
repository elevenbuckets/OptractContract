var SafeMath = artifacts.require("SafeMath");
var StandardToken = artifacts.require("StandardToken");
var BlockRegistry = artifacts.require("BlockRegistry");
var MemberShip = artifacts.require("MemberShip");
var QOT = artifacts.require("QOT");
var Elemmire = artifacts.require("Elemmire");
var Erebor = artifacts.require("Erebor");

module.exports = function(deployer) {
    deployer.deploy(SafeMath);
    deployer.link(SafeMath, [StandardToken, BlockRegistry, QOT]);
    deployer.deploy(StandardToken);
    deployer.deploy(BlockRegistry);
    deployer.deploy(Elemmire).then( (iElemmire) => {  // 'i' stand for 'instance'
        deployer.deploy(QOT).then( (iQOT) => {
            deployer.deploy(MemberShip, QOTAddr).then( (iMemberShip) => {
                deployer.deploy(
                    Erebor,
                    "0xb44f3694da66770fa00b4bc40386726988a37a96dfad4d9e097c43938353cf14",  // keccak256('Optract')
                    iQOT.address,
                    iElemmire.address,
                    iMemberShip.address);
            }).then( (iErebor) => {
                iElemmire.setMining(iErebor.address, 0);
                iQOT.setMining(iErebor.address, 0);
            })
        })
    })
}
