// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IPartnerGameToken is IERC20 {
	function mint(address to, uint256 amount) external returns (bool);

	function burn(address from, uint256 amount) external returns (bool);
}
