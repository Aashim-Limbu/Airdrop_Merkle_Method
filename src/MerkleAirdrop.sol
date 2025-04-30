// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;
/**
 * @title AirDrop Contract
 * @author Aashim Limbu
 * @notice Method - Merkle Proof.
 */

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {SafeERC20, IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

contract MerkleAirdrop is EIP712 {
    using SafeERC20 for IERC20;

    event Claim(address indexed claimer, uint256 amount);

    error MerkleAirdrop__InvalidProof();
    error MerkleAirdrop__AlreadyClaimed();
    error MerkleAirdrop__InvalidSignature();

    address[] claimers;
    bytes32 private immutable i_merkleRoot;
    IERC20 private immutable i_airdropToken;
    mapping(address claimer => bool claimed) private s_hasClaimed;
    bytes32 private constant MESSAGE_TYPE_HASH = keccak256("AirdropClaim(address account, uint256 amount)");

    struct AirdropClaim {
        address account;
        uint256 amount;
    }

    constructor(bytes32 _merkleRoot, IERC20 airdropToken) EIP712("MerkleAirdrop", "1") {
        i_merkleRoot = _merkleRoot;
        i_airdropToken = airdropToken;
    }

    function claim(address account, uint256 amount, bytes32[] calldata merkleProof, uint8 v, bytes32 r, bytes32 s)
        external
    {
        if (s_hasClaimed[account]) {
            revert MerkleAirdrop__AlreadyClaimed();
        }
        // check the signature
        // if signature is not valid revert
        if (!_isValidSignature(account, getMessageHash(account, amount), v, r, s)) {
            revert MerkleAirdrop__InvalidSignature();
        }
        // Calculate the hash using account and amount -> leaf node
        // We need to hash it twice while using Merkle Proofs or merkle trees as this avoid collision. As it is a general way to encode and hash the leaf nodes.
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount))));
        if (!MerkleProof.verify(merkleProof, i_merkleRoot, leaf)) {
            revert MerkleAirdrop__InvalidProof();
        }
        s_hasClaimed[account] = true;
        emit Claim(account, amount);
        i_airdropToken.safeTransfer(account, amount);
    }

    /**
     * @dev Generates an EIP-712 compliant message hash for a signed `AirdropClaim`.
     *
     * This function constructs a secure, replay-protected digest by:
     * 1. Encoding the structured data (address `account` and uint256 `amount`) into a payload hash
     *    using `abi.encode` and `keccak256`, conforming to the pre-defined `MESSAGE_TYPE_HASH`.
     * 2. Wrapping the payload hash with EIP-712's domain separator (chainId, contract address, etc.)
     *    via `_hashTypedDataV4`, which implements the full encoding scheme defined in EIP-712.
     *
     * The resulting digest is ready for off-chain signing (e.g., by a backend server) and subsequent
     * on-chain verification with `ECDSA.recover(digest, signature)`.
     *
     * Critical for:
     * - Preventing replay attacks (domain separator binds to chain/contract).
     * - Human-readable signing (wallets like MetaMask display structured data).
     *
     * See: https://eips.ethereum.org/EIPS/eip-712
     */
    function getMessageHash(address account, uint256 amount) public view returns (bytes32 digest) {
        return
            _hashTypedDataV4(keccak256(abi.encode(MESSAGE_TYPE_HASH, AirdropClaim({account: account, amount: amount}))));
    }

    function getMerkleRoot() external view returns (bytes32) {
        return i_merkleRoot;
    }

    function getAirdropToken() external view returns (IERC20) {
        return i_airdropToken;
    }

    function _isValidSignature(address account, bytes32 digest, uint8 v, bytes32 r, bytes32 s)
        internal
        pure
        returns (bool)
    {
        (address recoveredAddress,,) = ECDSA.tryRecover(digest, v, r, s);
        return recoveredAddress == account;
    }
}
