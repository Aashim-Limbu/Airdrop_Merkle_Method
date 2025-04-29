// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Token} from "../src/Token.sol";
import {MerkleAirdrop, IERC20} from "../src/MerkleAirdrop.sol";

contract DeployMerkleAirdrop is Script {
    uint256 private s_merkleRoot = 0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;
    uint256 private s_amountToTransfer; // total expense for airdrop
    uint256 private s_valueToAirdrop = 25 * 1e18; // value of airdrop

    function run() public returns (Token token, MerkleAirdrop airdrop) {
        string memory outputJson = vm.readFile("./script/target/output.json");
        bytes32 rootHash = vm.parseJsonBytes32(outputJson, "[0].root"); // first element in output json and getting root hash out of it.
        (token, airdrop) = deployMerkleAirdrop(rootHash);
    }

    function deployMerkleAirdrop(bytes32 rootHash) public returns (Token token, MerkleAirdrop airdrop) {
        string memory inputJson = vm.readFile("./script/target/input.json");
        uint256 count = vm.parseJsonUint(inputJson, ".count");
        s_amountToTransfer = count * s_valueToAirdrop;
        vm.startBroadcast();
        token = new Token();
        airdrop = new MerkleAirdrop(rootHash, IERC20(token));
        token.mint(address(airdrop), s_amountToTransfer);
        vm.stopBroadcast();
    }
}
