pragma solidity ^0.5.2;

import "./ERC721/math/safe-math.sol";
import "./QOTInterface.sol";
import "./ElemmireInterface.sol";
import "./MemberShip.sol";

// Comments for the adaption for OptractContract
// * The main purpose of this "game" is to output random numbers AND give NFT (for endorsement in Optract)
// * What if there are no sufficient players? Use bots to ensure the game is running?
// * What's the cost to join the game apart from become a member?


// About the game
// # Roles
//  * defender : setup the game (only the fee)
//  * player : join the game, max 1000 players, pay 0.01 eth and may win some QOT
//  * validator: provide merkle proof at `end` block
//
// # time line of a game:
//    start ------------ n ------- m -------------------------------- end --------
//          calc           reg to    lottery, each round: 0-n winners     mr submit to chain;
//                         sc        (only on sc)                         withdraw eth/claim QOT in several blks
//          (period1)      (period2) (period3)                            could start next round
//
//  * sc: state channel; mr: merkle root
//  * period_all = period1 + period2 + period3
//  * during period2 (btw. `n` and `m`) players get tickets on sc
//  * player obtain ticket in the form `ticket[i] = hash(score + bn[m-1] + i)` where 0<=i<5, depend on score
//
contract Erebor{
	using SafeMath for uint256;
	// Variables
	address public defender;
	address public winner;
	address public validator;
	address public QOTAddr;
	address public ELEMAddr;
	address public memberContractAddr;
	uint constant public maxPlayer = 1000;
	uint constant public period_all = 20;  // 7 + 3 + 10
	uint public initHeight;
	bytes32 public difficulty = 0x0000000fffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
	uint public fee = 10000000000000000;
	bool public setup = false;
	uint public playercount = 0;
        uint public ticketsToWinNFT = 2;  // use small number for debug only

	struct playerInfo {
		// uint since;     // block height when joined
		uint initHeightJoined;
		bytes32 scoreHash;
		bool claimed;
	}

        struct battleStat{
            bytes32 merkleRoot;
            string ipfsAddr;
        }

        bytes32 public ticketSeed;  // blockhash(initHeight+8) of each game
        bytes32 public board;
        bytes32 public prevboard;

	mapping (address => playerInfo) public playerDB;
	mapping (uint => battleStat) public battleHistory;

	// Modifiers
	modifier defenderOnly() {
		require(msg.sender == defender);
		_;
	}

	modifier WinnerOnly() {
		require(winner != address(0) && msg.sender == winner);
		_;
	}

	modifier ValidatorOnly() {
	        require(validator != address(0) && msg.sender == validator);
	        _;
        }

	modifier NewGameOnly() {
		require(setup == false);
		_;
	}

	modifier feePaid() {
		require(msg.value >= fee);
		_;
	}

	modifier isActiveMember(){
                require(MemberShip(memberContractAddr).addrIsActiveMember(msg.sender));
                _;
        }

	modifier gameStarted() {
		require(setup == true);
		_;
	}

	modifier gameStalled() {
		// require(setup == true && block.number > initHeight + period_all && winner == address(0));
		require(setup == true && block.number > initHeight + 10 && winner == address(0));  // for debug
		_;
	}

	modifier notDefender() {
		require(msg.sender != defender);
		_;
	}

	// Contract constructor
	constructor(bytes32 _init, address _QOTAddr, address _ELEMAddr, address _memberContracAddr) public {
		// require(msg.value >= fee);
		defender = msg.sender;
		validator = msg.sender;
		QOTAddr  = _QOTAddr;
                ELEMAddr = _ELEMAddr;
                memberContractAddr = _memberContracAddr;

		require(fortify(_init) == true);
	}

	// WinnerOnly
	// function withdraw(uint _tokenId) internal WinnerOnly returns (bool) {
	//         // only one player win NFT; make sure winner can claim the reward after next game started
	// 	require(block.number > playerDB[msg.sender].initHeightJoined + period_all);
	// 	require(block.number < playerDB[msg.sender].initHeightJoined + period_all + 7);

	// 	// uint256 reward = uint256(address(this).balance).mul(uint256(6)) / uint256(10);
	// 	// require(QOTInterface(QOTAddr).mint(msg.sender) == true);
	// 	// require(msg.sender.send(reward) == true);
                // winner = msg.sender;
                // // NFTClaimed = true;
                // require(iELEM(ELEMAddr).mint(msg.sender, _tokenId, uri) == true);
	// 	return true;
	// }

        // for debug purpose
	bool public debug1 = false;
	bool public debug2 = true;
	bool public debug3 = true;
	function debugParams(bool _debug1, bool _debug2, bool _debug3) public{
                debug1 = _debug1;
                debug2 = _debug2;
                debug3 = _debug3;
        }

	function claimLotteReward( // this happens after end of a game, next round may started
	    bytes32 secret,
	    string memory slots,
	    uint blockNo,
	    uint[] memory submitBlocks,  // the winning blocks the player claimed
	    uint[] memory winningTickets, // the idx of generateTickets. same order as submitBlocks.
	    bytes32[] memory proof,
	    bool[] memory isLeft,
	    bytes32 score
	) public returns (bool) {
		// require(playerDB[msg.sender].claimed == false, "already claimed");  // for debug
		require(winningTickets.length <= 10, "you cannot claim more tickets");
	        require(proof.length == isLeft.length, "len of proof/isLeft mismatch");
	        require(winningTickets.length == submitBlocks.length, "submitBlocks and winningTickets mismatch");
                require(battleHistory[playerDB[msg.sender].initHeightJoined].merkleRoot != bytes32(0), "no merkle root yet");
		if (debug1){  // set debug1 to flase to have more time to debug
                        require(block.number > playerDB[msg.sender].initHeightJoined + period_all + 1, "too early");
                        require(block.number < playerDB[msg.sender].initHeightJoined + period_all + 7, "too late");
                }

                bytes32 _board;
                if (playerDB[msg.sender].initHeightJoined == initHeight) {
                        _board = board;
                } else if (initHeight - playerDB[msg.sender].initHeightJoined > period_all) {
                        _board = prevboard;
                } else {  // should not happen
                        revert();
                }

                // No second chance: if one of the following verification failed, the player cannot call this function again.
                playerDB[msg.sender].claimed = false;  // set to false for debug only

                // verify score
                require(compareScore(secret, slots, blockNo, _board, score));
                require(keccak256(abi.encodePacked(score)) == playerDB[msg.sender].scoreHash,
                        "wrong score base on the given secret/blockNo");

		bytes32[] memory genTickets = new bytes32[](getNumOfTickets(score));
		genTickets = generateTickets(score, getNumOfTickets(score));

                // generate "claimHash", which is hash(msg.sender, submitBlocks[i], winningTickets[i], ...) where i=0,1,2,...
		// bytes32[5] memory genTickets = generateTickets(score);
		bytes32 claimHash;
                claimHash = getClaimHash(submitBlocks, winningTickets, genTickets);

                require(merkleTreeValidator(proof, isLeft, claimHash,
                                            battleHistory[playerDB[msg.sender].initHeightJoined].merkleRoot),
                        "merkle proof failed");

                // count number of winning tickets and mint QOT
                if (debug2) {
                    require(verifyWinnumber(_board, submitBlocks, winningTickets, genTickets) == true, "found a wrong ticket");
                }

                // determine the only winner who win a Elemire
                // TODO: better ways to determine the only winner of NFT
                if (debug3) {
                    if (winningTickets.length >= ticketsToWinNFT) {  // use small number for debug only
                            string memory uri = bytes32ToString(claimHash);
                            ElemmireInterface(ELEMAddr).mint(msg.sender, uint(claimHash), uri);
                    }
                }

		return true;
        }

	function getClaimHash(uint[] memory submitBlocks, uint[] memory winningTickets, bytes32[] memory genTickets) public view returns(bytes32 claimHash){
                bytes memory packed = abi.encodePacked(uint256(msg.sender));
                for (uint i=0; i<winningTickets.length; i++){
                        packed = abi.encodePacked(packed, submitBlocks[i], genTickets[winningTickets[i]]);
                }
                claimHash = keccak256(packed);
        }

        function verifyWinnumber(bytes32 _board, uint[] memory submitBlocks, uint[] memory winningTickets, bytes32[] memory genTickets) public returns(bool){
                bytes32 winNumber;
                uint prevBlock;
                uint prevWinningTicket;
                for (uint i=0; i<submitBlocks.length; i++){
                            require(submitBlocks[i] >= prevBlock);
                            if (submitBlocks[i] == prevBlock){
                                    require(winningTickets[i] > prevWinningTicket);
                            }
                            winNumber = keccak256(abi.encodePacked(_board, blockhash(submitBlocks[i])));
                            if (uint8(winNumber[31])%16 != uint8(genTickets[winningTickets[i]][31])%16 ){
                                    return false;
                            }
                            // require(winNumber[31] == genTickets[winningTickets[i]][31]);  // last 1 byte = 2 digits of hex
                            // require(winNumber[31] == genTickets[winningTickets[i]][31] &&
                            //         uint(winNumber[30])%16 == uint(genTickets[winningTickets[i]][30])%16 );  // last 3 digits of hex
                            // require(winNumber[31] == genTickets[winningTickets[i]][31] &&
                            //         winNumber[30] == genTickets[winningTickets[i]][30]);  // last 4 digits of hex

                            require(QOTInterface(QOTAddr).mint(msg.sender, 150) == true);  // DEBUG: use 150 for now
                            prevBlock = submitBlocks[i];
                            prevWinningTicket = winningTickets[i];
                }
                return true;
        }

        function generateTickets(bytes32 score, uint numTickets) public view returns (bytes32[] memory){
                // require(score != bytes32(0));
                bytes32[] memory tickets = new bytes32[](numTickets);
		for (uint i = 0; i < numTickets; i++) {
		        tickets[i] = keccak256(abi.encodePacked(score, ticketSeed, i+1));  // idx of ticket start from 1
                }
                return tickets;
        }

        function getNumOfTickets(bytes32 score) public pure returns(uint){
                if (score > 0x00ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) {
                        return 1;  // min: 1 ticket
                } else if (score > 0x000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) {
                        return 2;
                } else if (score > 0x0000ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) {
                        return 3;
                } else if (score > 0x00000fffffffffffffffffffffffffffffffffffffffffffffffffffffffffff) {
                        return 4;
                } else {
                        return 5;  // max: 5 tickets
                }
        }

	function getPlayerInfo(address _addr) public view returns (uint, bytes32, bool) {
		return (playerDB[_addr].initHeightJoined, playerDB[_addr].scoreHash, playerDB[_addr].claimed);
	}

	function fortify(bytes32 defense) public payable defenderOnly NewGameOnly returns (bool) {
		require(defense > difficulty);

		initHeight = block.number;

                playerDB[msg.sender] = playerInfo(initHeight, bytes32(0), false);
		playercount += 1;
		setup = true;

	        prevboard = board;
	        board = defense;

		return true;
	}

	// Join game
	function challenge(bytes32 scoreHash) public payable isActiveMember notDefender gameStarted returns (bool) {
		require(playerDB[msg.sender].initHeightJoined < initHeight, "challange: 1");
		require(block.number > initHeight + 7 && block.number <= initHeight + 10, "challange: 2");
		require(playercount + 1 <= maxPlayer, "challange: 3");

		playerDB[msg.sender] = playerInfo(initHeight, scoreHash, false);

		playercount += 1;

		return true;
	}

	function testOutcome(bytes32 secret, uint blockNo) public gameStarted view returns (bytes32 _board, bool[32] memory _slots) {
		require(block.number > initHeight + 7 && block.number <= initHeight + 10, 'testoutcome: 1');
		require(block.number - blockNo < 7, 'testoutcome: 2');
		require(blockNo <= block.number - 1 && blockNo >= initHeight + 7 && blockNo < initHeight + 10, 'testoutcome: 3');

		_board = keccak256(abi.encodePacked(msg.sender, secret, blockhash(blockNo)));

		for (uint i = 0; i <= 31; i++) {
			if(_board[i] < board[i]) {
				_slots[i] = true;
			}
		}

		return (_board, _slots);
	}

	function winningNumber(uint blockNo, bytes32 _board) public view returns (bytes32) {
	        require(blockNo <= block.number - 1);
	        return keccak256(abi.encodePacked(_board, blockhash(blockNo)));
        }

        function merkleTreeValidator(bytes32[] memory proof, bool[] memory isLeft, bytes32 targetLeaf, bytes32 _merkleRoot) public pure returns (bool) {
                require(proof.length < 32);  // 2**32 ~ 4.3e9 leaves!
                require(proof.length == isLeft.length);

                bytes32 targetHash = targetLeaf;
                for (uint256 i = 0; i < proof.length; i++) {
                        bytes32 proofEle = proof[i];
                        if (isLeft[i]) {
                                targetHash = keccak256(abi.encodePacked(proofEle, targetHash));
                        } else if (!isLeft[i]) {
                                targetHash = keccak256(abi.encodePacked(targetHash, proofEle));
                        } else {
                                return false;
                        }
                }
                return targetHash == _merkleRoot;
        }

	function submitMerkleRoot(uint _initHeight, bytes32 _merkleRoot, string memory _ipfsAddr) public ValidatorOnly returns (bool) {
		require(block.number >= _initHeight + period_all && block.number <= _initHeight + period_all + 4);
	        battleHistory[_initHeight]= battleStat(_merkleRoot, _ipfsAddr);
	        ticketSeed = blockhash(_initHeight+8);

                // reset the status of previous game (or put it in challange?)
	        // NFTClaimed = false;   // reset the status of previous game
	        winner = address(0);
	        return true;
        }

        function getBlockInfo(uint _initHeight) public view returns(bytes32, string memory){
	        return (battleHistory[_initHeight].merkleRoot, battleHistory[_initHeight].ipfsAddr);
        }

        function getBlockhash(uint blockNo) external view returns (bytes32) {
                return blockhash(blockNo);
        }

        function compareScore(bytes32 secret, string memory slotString, uint blockNo, bytes32 _board, bytes32 score) public view returns (bool){
	        // verification: the secret belongs to the player
		bytes32 myboard = keccak256(abi.encodePacked(msg.sender, secret, blockhash(blockNo))); // initialize for the loop below
                bytes memory slots = bytes(slotString);
                bytes32 out;
                for (uint i = 0; i < 32; i++) {
		        if(slots[i] == 0x30) {  // see decimal ascii chart, '0' = 48 (decimal) = 0x30 (hex)
		                out |= bytes32(_board[i] & 0xff ) >> (i*8);
                        } else if (slots[i] == 0x31) {
		                out |= bytes32(myboard[i] & 0xff ) >> (i*8);
			}
                }

		return out == score;
	}

        function computeScore(bytes32 secret, string memory slotString, uint blockNo, bytes32 _board) public view returns (bytes32 out){
		bytes32 myboard = keccak256(abi.encodePacked(msg.sender, secret, blockhash(blockNo))); // initialize for the loop below
                bytes memory slots = bytes(slotString);
                bytes memory outscore = new bytes(32);
                for (uint i = 0; i < 32; i++) {
		        if(slots[i] == 0x30) {  // see decimal ascii chart, '0' = 48 (decimal) = 0x30 (hex)
		                outscore[i] = _board[i];
                        } else if (slots[i] == 0x31) {
                                outscore[i] = myboard[i];
			}
                }

                // bytes to bytes32
                for (uint i=0; i<32; i++){
                        out |= bytes32( outscore[i] & 0xff ) >> (i * 8);
                }
		return out;
	}

        function hexToChar(byte _b) internal pure returns (byte c) {
                // convert a hex value (0-f) to it's corresponding string
                if (uint8(_b) < 10) {
                        return byte(uint8(_b) + 0x30);  // '0' to '9'
                } else {
                        return byte(uint8(_b) + 0x57);  // 'a' to 'z'
                }
        }

        // convert bytes32 to hex "string"
        function bytes32ToString(bytes32 b32) public pure returns (string memory out) {
                bytes memory s = new bytes(64);
                for (uint8 i = 0; i < 32; i++) {
                        byte _b = byte(b32[i]);
                        byte hi = byte(uint8(_b) / 16);
                        byte lo = byte(uint8(_b) - 16 * uint8(hi));
                        s[i*2] = hexToChar(hi);
                        s[i*2+1] = hexToChar(lo);
                }
                out = string(s);
        }

        // upgrade and ownership
        function newValidator(address _newValidator) public defenderOnly returns (bool){
                require(_newValidator != address(0));
                validator = _newValidator;
                return true;
        }

        function newDefender(address _newDefender) public defenderOnly returns (bool){
                require(_newDefender != address(0));
                require(setup == false);
		defender = _newDefender;
                return true;
        }

        function newQOTAddr(address _newAddr) public defenderOnly returns (bool){
                QOTAddr = _newAddr;
                return true;
        }

        function newELEMAddr(address _newAddr) public defenderOnly returns (bool){
                ELEMAddr = _newAddr;
                return true;
        }

        function newMemberAddr(address _addr) public defenderOnly returns (bool){
                memberContractAddr = _addr;
                return true;
        }

        function renewTicketsToWinNFT(uint _n) public defenderOnly returns (bool){
                require(_n > 1 && _n < 10);
                ticketsToWinNFT = _n;
                return true;
        }

        // fallback
        function () defenderOnly gameStalled external {
            winner = address(0);
            setup = false;
            // board = bytes32(0);
            playercount = 0;
            // require(withdraw());
	    // require(msg.sender.send(address(this).balance) == true);  // for debug
        }
}
