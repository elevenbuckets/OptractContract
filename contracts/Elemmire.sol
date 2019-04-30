pragma solidity ^0.5.2;
// ERC721 adapted from https://github.com/0xcert/ethereum-erc721
import "./ERC721/tokens/nf-token-enumerable.sol";
import "./ERC721/tokens/nf-token-metadata.sol";


contract Elemmire is NFTokenEnumerable, NFTokenMetadata {
    // features to be implemented:
    // * finer access control other than "managerOnly" / "miningOnly"
    // * upgradable
    // * able or easy to integrate with the "Trade" contract + state channels

    // for now, only 5 managers and 5 minable/burnable contracts (see accessControl.sol)
    address public owner;
    bool public paused = false;

    constructor() public {
        nftName = "Elemmire";
        nftSymbol = "ELEM";
        owner = msg.sender;
    }

    // modifier ownerOnly() {  // defined in accessControl.sol
    //     require(msg.sender == owner);
    //     _;
    // }

    modifier whenNotPaused() {
        require(!paused);
        _;
    }

    modifier whenPaused {
        require(paused);
        _;
    }

    modifier miningOnly() {
        require(super.isMiner(msg.sender) == true || msg.sender == owner, "not miner");
        _;
    }

    modifier minerOrManager() {
        require(super.isMinerOrManager(msg.sender) == true, "neither miner nor manager");
        _;
    }

    function mint(address _to, uint256 _tokenId, string calldata _uri) external miningOnly whenNotPaused {
        super._mint(_to, _tokenId);
        super._setTokenUri(_tokenId, _uri);
    }

    function burn(uint256 _tokenId) external minerOrManager {
        super._burn(_tokenId);
    }

    // additional functions
    function pause() external managerOnly whenNotPaused {
        paused = true;
    }

    function unpause() public ownerOnly whenPaused {
        // set to ownerOnly in case accounts of other managers are compromised
        paused = false;
    }


}
