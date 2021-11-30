// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./PartnerGameToken.sol";
import "../interfaces/IPartnerGameToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

// Entropy Game Token Reactor Contract
contract GameTokenNuclearReactor {
	using SafeMath for uint256;
	using MerkleProof for bytes32[];

	// Nuclear Engine
	bytes32 merkleRoot;
	// DAO contract address
	address public DAO;
	address public pendingDAO;
	// Info of game token.
	IERC20[] public gameTokenList;
	// PartnerToken <=====> GameToken
	mapping(address => address) public partnerToGameToken;
	// GameToken    <=====> PartnerToken
	mapping(address => address) public gameToPartnerToken;

	// lock modifier
	bool private _accepting = true;
	modifier lock() {
		require(_accepting == true, "GameTokenNuclearReactor: LOCKED");
		_accepting = false;
		_;
		_accepting = true;
	}

	modifier onlyWhitelisted(bytes32[] memory proof_) {
		require(proof_.verify(merkleRoot, keccak256(abi.encodePacked(msg.sender))), "GameTokenNuclearReactor: Only whitelisted players");
		_;
	}

	modifier onlyAddedGameToken(address gameToken_) {
		require(gameToPartnerToken[gameToken_] != address(0), "GameTokenNuclearReactor: Only added game token");
		_;
	}

	modifier onlyPartnerTokenExist(address partnerToken_) {
		require(partnerToGameToken[partnerToken_] != address(0), "GameTokenNuclearReactor: Only if partenrToken is legit");
		_;
	}

	modifier onlyDAO() {
		require(msg.sender == DAO, "GameTokenNuclearReactor: FORBIDDEN");
		_;
	}

	constructor(address DAO_) {
		require(DAO_ != address(0), "GameTokenNuclearReactor: DAO address cannot be ZERO");
		DAO = DAO_; // default is DAO
	}

	/**
	 * @dev update merkle root
	 * @notice only DAO can do
	 * @param root_ markle root
	 */
	function setMerkleRoot(bytes32 root_) external onlyDAO {
		require(root_ != 0, "GameTokenNuclearReactor: ZERO ROOT !");
		merkleRoot = root_;
	}

	/**
	 * @dev generate partner token
	 * @notice only DAO can do
	 * @param gameToken_ long / short game token address
	 * @param name_	partner game token name
	 * @param symbol_	partner game token symbol
	 */
	function gameTokenNuclearReactor(
		address gameToken_,
		string memory name_,
		string memory symbol_
	) external onlyDAO returns (address) {
		require(gameToPartnerToken[gameToken_] == address(0), "GameTokenNuclearReactor: Partner Token Existed !");
		bytes32 salt = keccak256(abi.encodePacked(gameToken_));
		PartnerGameToken newPartnerToken = new PartnerGameToken{ salt: salt }(name_, symbol_, ERC20(gameToken_).decimals(), address(this));
		partnerToGameToken[address(newPartnerToken)] = gameToken_;
		gameToPartnerToken[gameToken_] = address(newPartnerToken);
		gameTokenList.push(IERC20(gameToken_));
		return address(newPartnerToken);
	}

	/**
	 * @dev whitelisted users can convert game token to partner game token
	 * @notice locked and only added game token can be deposit
	 * @param gameToken_ long / short game token address
	 * @param amount_ aount of game token to deposit
	 */
	function reactorEncoder(
		bytes32[] memory proof_,
		address gameToken_,
		uint256 amount_
	) external lock onlyWhitelisted(proof_) onlyAddedGameToken(gameToken_) {
		require(IERC20(gameToken_).balanceOf(msg.sender) >= amount_, "GameTokenNuclearReactor: Insufficient Balance");
		// transfer game token to reactor
		IERC20(gameToken_).transferFrom(msg.sender, address(this), amount_);
		// mint partner token to msg.sender
		IPartnerGameToken(gameToPartnerToken[gameToken_]).mint(msg.sender, amount_);
	}

	/**
	 * @dev whitelisted users can convert partner game token to game token
	 * @notice locked and only added game partner token can be deposit
	 * @param partnerToken_ partner long / short game token address
	 * @param amount_ aount of partner game token to deposit
	 */
	function reactorDecoder(
		bytes32[] memory proof_,
		address partnerToken_,
		uint256 amount_
	) external lock onlyWhitelisted(proof_) onlyPartnerTokenExist(partnerToken_) {
		require(IERC20(partnerToken_).balanceOf(msg.sender) >= amount_, "GameTokenNuclearReactor: Insufficient Balance");
		// burn partner token from msg.sender
		IPartnerGameToken(partnerToken_).burn(msg.sender, amount_);
		// send game token back to msg.sender
		IERC20(partnerToGameToken[partnerToken_]).transfer(msg.sender, amount_);
	}

	/**
	 * @dev set pendingDAO
	 * @notice only DAO can set pendingDAO
	 * @param pendingDAO_ pending DAO address
	 */
	function setPendingDAO(address pendingDAO_) external onlyDAO {
		require(pendingDAO_ != address(0), "GameTokenNuclearReactor: set _pendingDAO to the zero address");
		pendingDAO = pendingDAO_;
	}

	/**
	 * @dev set DAO
	 * @notice only DAO can set the new DAO and it need to be pre added to pendingDAO
	 */
	function setDAO() external onlyDAO {
		require(pendingDAO != address(0), "GameTokenNuclearReactor: set _DAO to the zero address");
		DAO = pendingDAO;
		pendingDAO = address(0);
	}
}
