// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
/**
 * @title AirDrop Contract
 * @author Aashim Limbu
 * @notice Method - Merkle Proof.
 */

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MerkleAirdrop {
    using SafeERC20 for IERC20;

    event Claim(address indexed claimer, uint256 amount);

    error MerkleAirdrop_InvalidProof();
    error MerkleAirdrop_AlreadyClaimed();

    address[] claimers;
    bytes32 private immutable i_merkleRoot;
    IERC20 private immutable i_airdropToken;
    mapping(address claimer => bool claimed) private s_hasClaimed;

    constructor(bytes32 _merkleRoot, IERC20 airdropToken) {
        i_merkleRoot = _merkleRoot;
        i_airdropToken = airdropToken;
    }

    function claim(address account, uint256 amount, bytes32[] calldata merkleProof) external {
        if (s_hasClaimed[account]) {
            revert MerkleAirdrop_AlreadyClaimed();
        }
        // Calculate the hash using account and amount -> leaf node
        // We need to hash it twice while using Merkle Proofs or merkle trees as this avoid collision. As it is a general way to encode and hash the leaf nodes.
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
            revert MerkleAirdrop_InvalidProof();
        }
        s_hasClaimed[account] = true;
        emit Claim(account, amount);
        i_airdropToken.safeTransfer(account, amount);
    }

    function getMerkleRoot() external view returns (bytes32) {
        return i_merkleRoot;
    }

    function getAirdropToken() external view returns (IERC20) {
        return i_airdropToken;
    }
}
