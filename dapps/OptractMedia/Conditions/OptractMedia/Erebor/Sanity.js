module.exports = 
{
	Erebor_withdraw_sanity(addr, jobObj) 
	{
		return true;
	},

	Erebor_fortify_sanity(addr, jobObj)
	{
		if ( addr === this.CUE[jobObj.type][jobObj.contract].defender()
		  && jobObj.txObj.value >= this.CUE[jobObj.type][jobObj.contract].fee()
		  && this.CUE[jobObj.type][jobObj.contract].setup() === false
		) {
			return true;
		} else {
			return false;
		}
	},

	Erebor_challenge_sanity(addr, jobObj)
	{
		return true;
	},

	Erebor_claimLotteReward_sanity(addr, jobObj)
	{
		return true;
	},

	Erebor_submitMerkleRoot_sanity(addr, jobObj)
	{
		return true;
        },
	Erebor_debugParams_sanity(addr, jobObj)
	{
		return true;
        },
	Erebor_getClaimHash_sanity(addr, jobObj)
	{
		return true;
        },
	Erebor_verifyWinnumber_sanity(addr, jobObj)
	{
		return true;
        },
	Erebor_generateTickets_sanity(addr, jobObj)
	{
		return true;
        },
	Erebor_getPlayerInfo_sanity(addr, jobObj)
	{
		return true;
        },
        Erebor_renewTicketsToWinNFT_sanity(addr, jobObj)
        {
                return true;
        }

    
}
