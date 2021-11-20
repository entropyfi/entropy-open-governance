// SPDX-License-Identifier: GPL 3.0
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract EntropySponsorFarm is Ownable {
	using SafeMath for uint256;
	using SafeERC20 for IERC20;
	// Info of each user.
	struct UserInfo {
		uint256 amount; // How many sponsor tokens the user has provided.
		uint256 rewardDebt; // Reward debt. See explanation below.
		//
		// We do some fancy math here. Basically, any point in time, the amount of ENTROPYs
		// entitled to a user but is pending to be distributed is:
		//
		//   pending reward = (user.amount * pool.accEntropyPerShare) - user.rewardDebt
		//
		// Whenever a user deposits or withdraws sponsor tokens to a pool. Here's what happens:
		//   1. The pool's `accEntropyPerShare` (and `lastRewardBlock`) gets updated.
		//   2. User receives the pending reward sent to his/her address.
		//   3. User's `amount` gets updated.
		//   4. User's `rewardDebt` gets updated.
	}
	// Info of each pool.
	struct PoolInfo {
		uint256 allocPoint; // How many allocation points assigned to this pool. ENTROPYs to distribute per block.
		uint256 lastRewardBlock; // Last block number that ENTROPYs distribution occurs.
		uint256 accEntropyPerShare; // Accumulated ENTROPYs per share, times 1e12. See below.
	}
	// The ENTROPY TOKEN!
	IERC20 public immutable entropy;
	// ENTROPY tokens created per block.
	uint256 public entropyPerBlock;
	// Info of each pool.
	PoolInfo[] public poolInfo;
	// Info of sponsor token.
	IERC20[] public sponsorToken;
	// check if the sponsor token already been added or not
	mapping(address => bool) public isTokenAdded;
	// check the pool ID from a specific sponsor token
	mapping(address => uint256) public getPoolID;
	// Info of each user that stakes sponsor tokens.
	mapping(uint256 => mapping(address => UserInfo)) public userInfo;
	// Total allocation poitns. Must be the sum of all allocation points in all pools.
	uint256 public totalAllocPoint = 0;

	// user actions event
	event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
	event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
	event Claim(address indexed user, uint256 indexed pid, uint256 amount);
	event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
	// admin actions event
	event LogPoolAddition(uint256 indexed pid, uint256 allocPoint, IERC20 indexed sponsorToken, bool withUpdate);
	event LogSetPool(uint256 indexed pid, uint256 allocPoint, IERC20 indexed sponsorToken, bool withUpdate);
	event LogUpdatePool(uint256 indexed pid, uint256 lastRewardBlock, IERC20 indexed sponsorToken, uint256 accEntropyPerShare);

	modifier validatePoolByPid(uint256 _pid) {
		require(_pid < poolInfo.length, "SPFARM: Pool does not exist");
		_;
	}

	constructor(address _entropy, uint256 _entropyPerBlock) {
		entropy = IERC20(_entropy);
		entropyPerBlock = _entropyPerBlock;
	}

	function poolLength() external view returns (uint256) {
		return poolInfo.length;
	}

	// Add a new sponsor token to the pool. Can only be called by the owner.
	function add(
		uint256 _allocPoint,
		address _sponsorToken,
		bool _withUpdate
	) external onlyOwner {
		require(isTokenAdded[_sponsorToken] == false, "SPFARM: SPONSOR TOKEN ALREADY IN POOL");
		isTokenAdded[_sponsorToken] = true;
		if (_withUpdate) {
			massUpdatePools();
		}
		uint256 lastRewardBlock = block.number;
		totalAllocPoint = totalAllocPoint.add(_allocPoint);
		sponsorToken.push(IERC20(_sponsorToken));
		poolInfo.push(PoolInfo({ allocPoint: _allocPoint, lastRewardBlock: lastRewardBlock, accEntropyPerShare: 0 }));
		getPoolID[_sponsorToken] = poolInfo.length.sub(1);
		emit LogPoolAddition(poolInfo.length.sub(1), _allocPoint, IERC20(_sponsorToken), _withUpdate);
	}

	// Update the given pool's ENTROPY allocation point. Can only be called by the owner.
	function set(
		uint256 _pid,
		uint256 _allocPoint,
		bool _withUpdate
	) external onlyOwner validatePoolByPid(_pid) {
		if (_withUpdate) {
			massUpdatePools();
		}
		totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
		poolInfo[_pid].allocPoint = _allocPoint;
		emit LogSetPool(_pid, _allocPoint, sponsorToken[_pid], _withUpdate);
	}

	// View function to see pending ENTROPYs on frontend.
	function pendingEntropy(uint256 _pid, address _user) external view validatePoolByPid(_pid) returns (uint256) {
		PoolInfo memory pool = poolInfo[_pid];
		UserInfo storage user = userInfo[_pid][_user];
		uint256 accEntropyPerShare = pool.accEntropyPerShare;
		uint256 sponsorSupply = sponsorToken[_pid].balanceOf(address(this));
		if (block.number > pool.lastRewardBlock && sponsorSupply != 0) {
			uint256 blocks = block.number.sub(pool.lastRewardBlock);
			uint256 entropyReward = blocks.mul(entropyPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
			accEntropyPerShare = accEntropyPerShare.add(entropyReward.mul(1e12).div(sponsorSupply));
		}
		return user.amount.mul(accEntropyPerShare).div(1e12).sub(user.rewardDebt);
	}

	// Update reward vairables for all pools. Be careful of gas spending!
	function massUpdatePools() public {
		uint256 length = poolInfo.length;
		for (uint256 pid = 0; pid < length; ++pid) {
			updatePool(pid);
		}
	}

	// Update reward variables of the given pool to be up-to-date.
	function updatePool(uint256 _pid) public validatePoolByPid(_pid) {
		PoolInfo storage pool = poolInfo[_pid];
		if (block.number <= pool.lastRewardBlock) {
			return;
		}
		uint256 sponsorSupply = sponsorToken[_pid].balanceOf(address(this));
		if (sponsorSupply == 0) {
			pool.lastRewardBlock = block.number;
			return;
		}
		uint256 blocks = block.number.sub(pool.lastRewardBlock);
		uint256 entropyReward = blocks.mul(entropyPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
		pool.accEntropyPerShare = pool.accEntropyPerShare.add(entropyReward.mul(1e12).div(sponsorSupply));
		pool.lastRewardBlock = block.number;
		emit LogUpdatePool(_pid, pool.lastRewardBlock, sponsorToken[_pid], pool.accEntropyPerShare);
	}

	// Deposit sponsor tokens to MasterChef for ENTROPY allocation.
	function deposit(uint256 _pid, uint256 _amount) external validatePoolByPid(_pid) {
		PoolInfo storage pool = poolInfo[_pid];
		UserInfo storage user = userInfo[_pid][msg.sender];
		updatePool(_pid);
		if (user.amount > 0) {
			uint256 pending = user.amount.mul(pool.accEntropyPerShare).div(1e12).sub(user.rewardDebt);
			safeEntropyTransfer(msg.sender, pending);
		}
		sponsorToken[_pid].safeTransferFrom(address(msg.sender), address(this), _amount);
		user.amount = user.amount.add(_amount);
		user.rewardDebt = user.amount.mul(pool.accEntropyPerShare).div(1e12);
		emit Deposit(msg.sender, _pid, _amount);
	}

	// Withdraw sponsor tokens from MasterChef.
	function withdraw(uint256 _pid, uint256 _amount) external validatePoolByPid(_pid) {
		PoolInfo storage pool = poolInfo[_pid];
		UserInfo storage user = userInfo[_pid][msg.sender];
		require(user.amount >= _amount, "SPFARM: INSUFFICIENT BALANCE");
		updatePool(_pid);

		uint256 pending = user.amount.mul(pool.accEntropyPerShare).div(1e12).sub(user.rewardDebt);
		safeEntropyTransfer(msg.sender, pending);
		emit Claim(msg.sender, _pid, pending);

		user.amount = user.amount.sub(_amount);
		user.rewardDebt = user.amount.mul(pool.accEntropyPerShare).div(1e12);
		sponsorToken[_pid].safeTransfer(address(msg.sender), _amount);
		emit Withdraw(msg.sender, _pid, _amount);
	}

	// Claim mint entropy tokens
	function claim(uint256 _pid) external validatePoolByPid(_pid) {
		PoolInfo storage pool = poolInfo[_pid];
		UserInfo storage user = userInfo[_pid][msg.sender];
		updatePool(_pid);
		uint256 accumulatedEntropy = user.amount.mul(pool.accEntropyPerShare).div(1e12);
		uint256 pending = accumulatedEntropy.sub(user.rewardDebt);
		user.rewardDebt = accumulatedEntropy;
		safeEntropyTransfer(msg.sender, pending);
		emit Claim(msg.sender, _pid, pending);
	}

	// Withdraw without caring about rewards. EMERGENCY ONLY.
	function emergencyWithdraw(uint256 _pid) external validatePoolByPid(_pid) {
		UserInfo storage user = userInfo[_pid][msg.sender];

		uint256 amount = user.amount;
		user.amount = 0;
		user.rewardDebt = 0;

		sponsorToken[_pid].safeTransfer(address(msg.sender), amount);
		emit EmergencyWithdraw(msg.sender, _pid, user.amount);
	}

	// Safe entropy transfer function, just in case if rounding error causes pool to not have enough ENTROPYs.
	function safeEntropyTransfer(address _to, uint256 _amount) private {
		uint256 entropyBal = entropy.balanceOf(address(this));
		if (_amount > entropyBal) {
			entropy.transfer(_to, entropyBal);
		} else {
			entropy.transfer(_to, _amount);
		}
	}

	// Rescue left over ERP token
	function rescue(uint256 amount_) external onlyOwner {
		IERC20(entropy).transfer(owner(), amount_);
	}
}
