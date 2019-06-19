#!/bin/sh

TARGET='./dapps/OptractMedia/ABI'
cp build/contracts/BlockRegistry.json build/contracts/QOT.json build/contracts/MemberShip.json $TARGET && \
     cd $TARGET && \
     jq -r '.abi' BlockRegistry.json > BlockRegistry.abi && \
     jq -r '.abi' QOT.json > QOT.abi && \
     jq -r '.abi' MemberShip.json > MemberShip.abi

if [ "$?"=="0" ]; then
    echo "# copied artifact and abi to dapps directory"
else
    echo "# Error while copy file to dapps or parse .abi"
fi
