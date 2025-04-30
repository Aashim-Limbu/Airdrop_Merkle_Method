// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 < 0.9.0;

import {Test, console} from "forge-std/Test.sol";
import {Token} from "../src/Token.sol";
import {MerkleAirdrop, IERC20} from "../src/MerkleAirdrop.sol";
import {ZkSyncChainChecker} from "@foundry-devops/src/ZkSyncChainChecker.sol";
import {DeployMerkleAirdrop} from "../script/DeployMerkleAirdrop.s.sol";

contract MerkleAridopTest is ZkSyncChainChecker, Test {
    MerkleAirdrop public merkleAirdrop;
    Token public token;
    bytes32 public ROOT = 0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4; // first generate input and then generate output and copy the root hash damn it!! .
    uint256 public AMOUNT_TO_CLAIM = 25 * 1e18;
    uint256 public AMOUNT_TO_SEND = AMOUNT_TO_CLAIM * 4;
    address sponsor;
    address user;
    uint256 userPrivateKey;
    bytes32[] public PROOF = [
        bytes32(0x0fd7c981d39bece61f7499702bf59b3114a90e66b51ba2c53abdf7b62986c00a),
        bytes32(0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576)
    ];

    function setUp() public {
        if (!isZkSyncChain()) {
            //deploy with script - zksync do not support deplying of contract with deploy script
            DeployMerkleAirdrop deployer = new DeployMerkleAirdrop();
            (token, merkleAirdrop) = deployer.deployMerkleAirdrop(ROOT);
        } else {
            token = new Token();
            merkleAirdrop = new MerkleAirdrop(ROOT, IERC20(token));
            token.mint(token.owner(), AMOUNT_TO_SEND);
            token.transfer(address(merkleAirdrop), AMOUNT_TO_SEND);
            // Since this user is going to claim the Airdrop we need to add user address to generate input.json and then recreate input and output json file. so we could get the proofs and the expected root.
            // Thus the address must be in Merkle Tree.
        }
        (user, userPrivateKey) = makeAddrAndKey("user");
        sponsor = makeAddr("gasPayer");
    }

    function testUserCanClaim() public {
        // console.log("The address of user is ",user); // add the user address to merkle input by adding it to whitelist in MerkleAirdrop script contract .
        uint256 startingBalance = token.balanceOf(user);
        bytes32 digest = merkleAirdrop.getMessageHash(user, AMOUNT_TO_CLAIM);
        // vm.prank(user);
        // sign a message
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPrivateKey, digest);

        //gasPayer/sponsor calls claim using the signed message
        vm.prank(sponsor);
        merkleAirdrop.claim(user, AMOUNT_TO_CLAIM, PROOF, v, r, s);
        uint256 endingBalance = token.balanceOf(user);
        console.log("ending balance: ", endingBalance);
        assertEq(endingBalance - startingBalance, AMOUNT_TO_CLAIM);
    }
}
