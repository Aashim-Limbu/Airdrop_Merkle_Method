#!/bin/bash

# Define constants
CLAIMER_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80" #claimer
SPONSER_PRIVATE_KEY="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d" #sponser
CLAIMER_ACCOUNT="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266" #claimer account
SPONSER_ACCOUNT="0x70997970C51812dc3A010C7d01b50e0d17dc79C8" #sponser account

ROOT="0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4"
PROOF_1="0xd1445c931158119b00449ffcac3c947d028c0c359c34a6646d95962b3b55c6ad"
PROOF_2="0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576"


# Compile and deploy Token contract
echo "Running anvil zkSync local node..."
anvil-zksync
echo "Deploying token contract..."
TOKEN_ADDRESS=$(forge create src/Token.sol:Token --rpc-url http://0.0.0.0:8011 --private-key ${CLAIMER_PRIVATE_KEY}  --zksync | awk '/Deployed to:/ {print $3}' )
echo "Token contract deployed at: $TOKEN_ADDRESS"

# Deploy MerkleAirdrop contract
echo "Deploying MerkleAirdrop contract..."
AIRDROP_ADDRESS=$(forge create src/MerkleAirdrop.sol:MerkleAirdrop --rpc-url http://0.0.0.0:8011 --private-key ${CLAIMER_PRIVATE_KEY}   --zksync --constructor-args ${ROOT} ${TOKEN_ADDRESS} | awk '/Deployed to:/ {print $3}' )
echo "MerkleAirdrop contract deployed at: $AIRDROP_ADDRESS"

# Get message hash
MESSAGE_HASH=$(cast call ${AIRDROP_ADDRESS} "getMessageHash(address,uint256)" ${CLAIMER_ACCOUNT} 25000000000000000000 --rpc-url http://0.0.0.0:8011)

# Sign message
echo "Signing message..."
SIGNATURE=$(cast wallet sign --private-key ${CLAIMER_PRIVATE_KEY} --no-hash ${MESSAGE_HASH})
CLEAN_SIGNATURE=$(echo "$SIGNATURE" | sed 's/^0x//')
echo -n "$CLEAN_SIGNATURE" >> signature.txt

# Split signature
SIGN_OUTPUT=$(forge script script/SplitSignature.s.sol:SplitSignature)

V=$(echo "$SIGN_OUTPUT" | grep -A 1 "v value:" | tail -n 1 | xargs)
R=$(echo "$SIGN_OUTPUT" | grep -A 1 "r value:" | tail -n 1 | xargs)
S=$(echo "$SIGN_OUTPUT" | grep -A 1 "s value:" | tail -n 1 | xargs)

# Execute remaining steps
echo "Sending tokens to the token contract owner..."
cast send ${TOKEN_ADDRESS} 'mint(address,uint256)' ${CLAIMER_ACCOUNT} 100000000000000000000 --private-key ${CLAIMER_PRIVATE_KEY} --rpc-url http://0.0.0.0:8011 > /dev/null
echo "Sending tokens to the airdrop contract..."
cast send ${TOKEN_ADDRESS} 'transfer(address,uint256)' ${AIRDROP_ADDRESS} 100000000000000000000 --private-key ${CLAIMER_PRIVATE_KEY} --rpc-url http://0.0.0.0:8011 > /dev/null
echo "Claiming tokens on behalf of 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266..."
cast send ${AIRDROP_ADDRESS} 'claim(address,uint256,bytes32[],uint8,bytes32,bytes32)' ${CLAIMER_ACCOUNT} 25000000000000000000 "[${PROOF_1},${PROOF_2}]" ${V} ${R} ${S} --private-key ${SPONSER_PRIVATE_KEY} --rpc-url http://0.0.0.0:8011 > /dev/null

HEX_BALANCE=$(cast call ${TOKEN_ADDRESS} 'balanceOf(address)' ${CLAIMER_ACCOUNT} --rpc-url http://0.0.0.0:8011)

# Assuming OUTPUT is defined somewhere in your process or script
echo "Balance of the claiming address (0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266): $(cast --to-dec ${HEX_BALANCE})"

# Clean up
rm signature.txt
