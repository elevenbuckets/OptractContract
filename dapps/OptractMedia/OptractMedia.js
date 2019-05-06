'use strict';

const ethUtils = require('ethereumjs-utils');
const BladeIronClient = require('bladeiron_api'); // 11BE BladeIron Client API
const leveldb  = require('level');
const mkdirp = require('mkdirp');

// Helper functions, may go into bladeiron_api later
const toBool = (str) =>
{
        if (typeof(str) === 'boolean') return str;
        if (typeof(str) === 'undefined') return false;

        if (str.toLowerCase() === 'true') {
                return true
        } else {
                return false
        }
}

const mkdir_promise = (dirpath) =>
{
        const __mkdirp = (dirpath) => (resolve, reject) =>
        {
                mkdirp(dirpath, (err) => {
                        if (err) return reject(err);
                        resolve(true);
                })
        }

        return new Promise(__mkdirp(dirpath));
}

// Common actions
// - connect to Ethereum, Optract Pubsub, and IPFS
// * Get latest Optract block and IPFS location from smart contract
// - loading the block and active records from IPFS.
// - at the same time, send pending pool ID with last block info. <----- SPAMMING !!!!!!!!!!
// Validator extra:
// - getting newer snapshot IPFS location and start merging with real-time new tx received
// - determine effective merged pending state and send pending pool ID of it. This message frequency is critical, can't be too often, can't be too long.
// - repeat previous two steps in loops (until all master nodes agree?)
// - Once reaching new block snapshot time, determine and send out effective merged pending pool ID
// - Once reaching new block commition time, sync last round of pending pool ID before commiting new block merkle root on IPFS hashes to smart contract.
// Client extra:
// - getting newer snapshot IPFS location and start render UI
// - whenever receiving valid new snapshot, rerender UI.
// - indevidual pending tx can also be rendered, if desired. 
// - if previously sent tx by client not found in latest snapshot, resend.
// * Once detect new block commited, loop back to the begining star (*) 
class OptractMedia extends BladeIronClient {
	constructor(rpcport, rpchost, options)
        {
                super(rpcport, rpchost, options);

		// There are three parts of data in an Optract block:
		// ---------------------------------------------------
		// First is the main block chain by design:
		//  - Notary Records: original, applause, praise, and critcize. 
		// The following two are deduced from Notary records:
		//  - Nonce Records: for each and every account, records summary of AP / TX usage.  
		//  - Active Articles: for all active articles, records all accumulated interactions.   
		//  
		// In all these records above, referencing using blockNo and txHash (leaf) is a must.
		//
		// websocket-proxied pubsub event handler
		this.handleValidate = (msgObj) =>
		{
			//TODO:
			// - everything should be put into leveldb after loaded from IPFS for better search performance.
			// If RLPx:
			// 	- check necessary fields
			// 	- nonce verification from pending txpool
			// 	- baseBlock & baseActiveLeaf verifications, if any.
			// - valid membership from main optract smart contract
			// - prevent duplicated payload within same side block 
			// - validate actions
			//    - no double likes
			//    - AP balance 
			// - valid signature
			// If receiving valid snapshot, compare and generate merged records.
			// - adding to pending txpool
			// - updating nonce & AP records 
			// - updating active article records (not on chain)
			//
			// Note: account summary records and tickets will be generated and added before generating and submitting merkle root
		}

		this.handleMsgs = (msgObj) =>
		{
			// - check necessary fields if RLPx
			// - valid membership from main optract smart contract
			// - valid signature
			// - if receiving valid snapshot, start rendering updates.
		}

		// membership related
                this.memberStatus = (address) => {  // "status", "token (hex)", "since", "penalty"
                        return this.call('MemberShip')('getMemberInfo')(address).then( (res) => {
                                let status = res[0];
                                let statusDict = ["failed connection", "active", "expired", "not member"];
                                return [statusDict[status], res[1], res[2], res[3], res[4]]  // "status", "id", "since", "penalty", "kycid"
                        })
                }

		// Merkle related
                this.generateBlock = (blkObj) =>
                {
                        const __genBlockBlob = (blkObj) => (resolve, reject) =>
                        {
                                fs.writeFile(path.join(this.configs.database, String(blkObj.initHeight), 'blockBlob'), JSON.stringify(blkObj), (err) => {
                                        if (err) return reject(err);
                                        resolve(path.join(this.configs.database, String(blkObj.initHeight), 'blockBlob'));
                                })
                        }

                        let stage = new Promise(__genBlockBlob(blkObj));
                        stage = stage.then((blockBlobPath) =>
                        {
                                console.log(`Local block data cache: ${blockBlobPath}`);
                                return this.ipfsPut(blockBlobPath);
                        })
                        .catch((err) => { console.log(`ERROR in generateBlock`); console.trace(err); });

                        return stage;
                }

		this.uniqRLP = (address) =>
                {
                        const compare = (a,b) => { if (ethUtils.bufferToInt(a.nonce) > ethUtils.bufferToInt(b.nonce)) { return 1 } else { return -1 }; return 0 };

                        let pldlist = []; let nclist = [];
                        let rlplist = this.bidRecords[this.initHeight][address].sort(compare);

                        let rlpObjs = rlplist.map((r) => {
                                nclist.push(r.toJSON()[0]); // nonce
                                pldlist.push(r.toJSON()[5]); // payload
                                return r.toJSON();
                        });

                        /*console.log(`>>>>>>>>`);
                        console.log(`DEBUG: rlpObjs`); console.dir(rlpObjs);
                        console.log(`DEBUG: nclist`); console.dir(nclist);
                        console.log(`DEBUG: pldlist`); console.dir(pldlist);
                        console.log(`<<<<<<<<`); */

                        rlpObjs.map((ro, idx) => {
                                if (ro[0] === nclist[idx-1]) { // overwrite previous tx with later one of same nonce
                                        rlplist[idx-1] = rlplist[idx];
                                        rlplist[idx] = null;
                                        pldlist[idx-1] = ro[5];
                                        pldlist[idx] = null;
                                } else if (pldlist.indexOf(ro[5]) !== pldlist.lastIndexOf(ro[5])) { // remote duplicates
                                        rlplist[idx] = null;
                                        pldlist[idx] = null;
                                }
                        })

                        return {data: rlplist.filter((x) => { return x !== null }), leaves: pldlist.filter((x) => { return x !== null })};
                }

		this.makeMerkleTreeAndUploadRoot = () =>
                {
                        // Currently, we will group all block data into single JSON and publish it on IPFS
                        let blkObj =  {initHeight: this.initHeight, data: {} };
                        let leaves = [];

                        // is this block data structure good enough?
                        Object.keys(this.bidRecords[blkObj.initHeight]).map((addr) => {
                                if (this.bidRecords[blkObj.initHeight][addr].length === 0) return;

                                let out = this.uniqRLP(addr);
                                blkObj.data[addr] = out.data;
                                leaves = [ ...leaves, ...out.leaves ];
                        });

                        console.log(`DEBUG: Final Leaves for initHeight = ${blkObj.initHeight}:`); console.dir(leaves);

                        let merkleTree = this.makeMerkleTree(leaves);
                        let merkleRoot = ethUtils.bufferToHex(merkleTree.getMerkleRoot());
                        console.log(`Block Merkle Root: ${merkleRoot}`);

                        let stage = this.generateBlock(blkObj);
                        stage = stage.then((rc) => {
                                console.log('IPFS Put Results'); console.dir(rc);
                                return this.sendTk('BlockRegistry')('submitMerkleRoot')(blkObj.initHeight, merkleRoot, rc[0].hash)();
                        })
                        .catch((err) => { console.log(`ERROR in makeMerkleTreeAndUploadRoot`); console.trace(err); });

                        return stage;
                }

		this.validateMerkleProof = (targetLeaf, ipfsHash) =>
                {
                        return this.loadPreviousLeaves(ipfsHash).then((leaves) => {
                                let results;
                                targetLeaf = ethUtils.bufferToHex(targetLeaf);
                                results = this.getMerkleProof(leaves, targetLeaf);
                                if (!results) {
                                        console.log('Warning! On-chain merkle validation will FAIL!!!');
                                        return false
                                }
                                let proof = results[0];
                                let isLeft = results[1];
                                let merkleRoot = results[2];
                                return this.call('BlockRegistry')('merkleTreeValidator')(proof, isLeft, targetLeaf, merkleRoot).then((rc) => {
                                        if (rc) {
                                                this.myClaims = { ...this.myClaims, proof:proof, isLeft:isLeft, targetLeaf:targetLeaf };
                                        } else {
                                                console.log('Warning! On-chain merkle validation will FAIL!!!');
                                        }
                                        return rc;
                                })
                        })
                        .catch((err) => { console.log(`ERROR in validateMerkleProof`); console.trace(err); return false; })
                }

                this.loadPreviousLeaves = (ipfsHash) =>
                {
                        // load block data from IPFS
                        // put them in leaves for merkleTree calculation
                        return this.ipfsRead(ipfsHash).then((blockBuffer) => {
                                let blockJSON = JSON.parse(blockBuffer.toString());

                                if (Number(blockJSON.initHeight) !== Number(this.initHeight)) {
                                        console.log(`Oh No! Did not get IPFS data for ${this.initHeight}, got data for round ${blockJSON.initHeight} instead`);
                                        return [];
                                }

                                let leaves = [];
                                Object.values(blockJSON.data).map((obj) => { return leaves = [ ...leaves, obj[0].payload ]; });

                                return leaves;
                        })
                }

	}
}

module.exports = OptractMedia;
