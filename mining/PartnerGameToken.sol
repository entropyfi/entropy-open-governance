// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Entropy Partner Game Token
contract PartnerGameToken is ERC20 {
	address public gameTokenReactor;
	uint8 decimals_;

	// limit only pool can mint token
	modifier onlyGameTokenReactor() {
		require(msg.sender == gameTokenReactor, "PartnerGameToken: FORBIDDEN");
		_;
	}

	constructor(
		string memory _name,
		string memory _symbol,
		uint8 _decimals,
		address _gameTokenReactor
	) ERC20(_name, _symbol) {
		require(_gameTokenReactor != address(0), "PartnerGameToken: Reactor Zero Address");
		gameTokenReactor = _gameTokenReactor;
		decimals_ = _decimals;
	}

	/**
	 * @dev mint partner token
	 * @notice only GameTokenReactor can do
	 * @param _to user address
	 * @param _amount	amount of partner token to mint
	 */
	function mint(address _to, uint256 _amount) external onlyGameTokenReactor returns (bool) {
		_mint(_to, _amount);
		return true;
	}

	/**
	 * @dev burn partner token
	 * @notice only GameTokenReactor can do
	 * @param _from user address
	 * @param _amount	amount of partner token to burn
	 */
	function burn(address _from, uint256 _amount) external onlyGameTokenReactor returns (bool) {
		_burn(_from, _amount);
		return true;
	}

	/**
	 * @dev decimals for frontend
	 * @notice override ERC20 contract
	 */
	function decimals() public view virtual override returns (uint8) {
		return decimals_;
	}
}
