module.exports = {
    compilers: {
        solc:{
            version: '0.5.2',
            docker: true
        },
    },
    networks: {
        development: {
            // host: "172.17.0.2",  // for docker
            host: "127.0.0.1",
            // host: "rinkeby.infura.io/v3/f50fa6bf08fb4918acea4aadabb6f537",  // useless?
            port: 8545,
            gas: 6900000,
            network_id: "*" // Match any network id
        }
    }
};
