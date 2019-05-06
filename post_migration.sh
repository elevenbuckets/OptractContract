#!/bin/sh

cp build/contracts/BlockRegistry.json build/contracts/QOT.json build/contracts/MemberShip.json build/contracts/Elemmire.json build/contracts/Erebor.json ./dapps/Optract/ABI && \
     cd dapps/Optract/ABI && \
     jq -r '.abi' BlockRegistry.json > BlockRegistry.abi && \
     jq -r '.abi' QOT.json > QOT.abi && \
     jq -r '.abi' MemberShip.json > MemberShip.abi
     jq -r '.abi' Elemmire.json > Elemmire.abi && \
     jq -r '.abi' Erebor.json > Erebor.abi && \

echo $?
echo "# copied artifact and abi to dapps directory"
