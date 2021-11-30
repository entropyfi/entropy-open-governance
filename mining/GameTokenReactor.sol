// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "./PartnerGameToken.sol";
import "../interfaces/IPartnerGameToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

// Entropy Game Token Reactor Contract
contract GameTokenReactor {
	using SafeMath for uint256;
	// DAO contract address
	address public DAO;
	address public pendingDAO;
	// Info of game token.
	IERC20[] public gameTokenList;
	// Check whether the address is whitelisted or not
	mapping(address => bool) public isUserWhitelisted;
	// PartnerToken <=====> GameToken
	mapping(address => address) public partnerToGameToken;
	// GameToken    <=====> PartnerToken
	mapping(address => address) public gameToPartnerToken;

	// lock modifier
	bool private accepting = true;
	modifier lock() {
		require(accepting == true, "GameTokenReactor: LOCKED");
		accepting = false;
		_;
		accepting = true;
	}

	modifier onlyWhitelisted() {
		require(isUserWhitelisted[msg.sender] == true, "GameTokenReactor: Only whitelisted players");
		_;
	}

	modifier onlyAddedGameToken(address _gameToken) {
		require(gameToPartnerToken[_gameToken] != address(0), "GameTokenReactor: Only added game token");
		_;
	}

	modifier onlyPartnerTokenExist(address _partnerToken) {
		require(partnerToGameToken[_partnerToken] != address(0), "GameTokenReactor: Only if partenrToken is legit");
		_;
	}

	modifier onlyDAO() {
		require(msg.sender == DAO, "GameTokenReactor: FORBIDDEN");
		_;
	}

	constructor(address _DAO) {
		require(_DAO != address(0), "GameTokenReactor:  DAO address cannot be ZERO");
		DAO = _DAO; // default is DAO
	}

	/**
	 * @dev update whitelist user
	 * @notice only DAO can do
	 * @param addrs list of whitelist user address
	 * @param whitelisted True - adding to whitelist False - delete from the whitelist
	 */
	function updateUserWhitelist(address[] memory addrs, bool whitelisted) external onlyDAO {
		for (uint256 i = 0; i < addrs.length; i++) {
			isUserWhitelisted[addrs[i]] = whitelisted;
		}
	}

	/**
	 * @dev generate partner token
	 * @notice only DAO can do
	 * @param gameToken_ long / short game token address
	 * @param _name	partner game token name
	 * @param _symbol	partner game token symbol
	 */
	function gameTokenReactor(
		address gameToken_,
		string memory _name,
		string memory _symbol
	) external onlyDAO returns (address) {
		require(gameToPartnerToken[gameToken_] == address(0), "GameTokenReactor: Partner Token Existed !");
		bytes32 salt = keccak256(abi.encodePacked(gameToken_));
		PartnerGameToken newPartnerToken = new PartnerGameToken{ salt: salt }(_name, _symbol, ERC20(gameToken_).decimals(), address(this));
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
	function reactorEncoder(address gameToken_, uint256 amount_) external lock onlyWhitelisted onlyAddedGameToken(gameToken_) {
		require(IERC20(gameToken_).balanceOf(msg.sender) >= amount_, "GameTokenReactor: Insufficient Balance");
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
	function reactorDecoder(address partnerToken_, uint256 amount_) external lock onlyWhitelisted onlyPartnerTokenExist(partnerToken_) {
		require(IERC20(partnerToken_).balanceOf(msg.sender) >= amount_, "GameTokenReactor: Insufficient Balance");
		// burn partner token from msg.sender
		IPartnerGameToken(partnerToken_).burn(msg.sender, amount_);
		// send game token back to msg.sender
		IERC20(partnerToGameToken[partnerToken_]).transfer(msg.sender, amount_);
	}

	/**
	 * @dev set pendingDAO
	 * @notice only DAO can set pendingDAO
	 * @param _pendingDAO pending DAO address
	 */
	function setPendingDAO(address _pendingDAO) external onlyDAO {
		require(_pendingDAO != address(0), "GameTokenReactor: set _pendingDAO to the zero address");
		pendingDAO = _pendingDAO;
	}

	/**
	 * @dev set DAO
	 * @notice only DAO can set the new DAO and it need to be pre added to pendingDAO
	 */
	function setDAO() external onlyDAO {
		require(pendingDAO != address(0), "GameTokenReactor: set _DAO to the zero address");
		DAO = pendingDAO;
		pendingDAO = address(0);
	}
}
