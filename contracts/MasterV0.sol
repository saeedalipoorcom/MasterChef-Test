//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./DEXToken.sol";
import "./Syrup.sol";

interface IMigratorChef {
    // Perform LP token migration from legacy PanDEXSwap to DEXSwap.
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    // Return the new LP token address.
    //
    // XXX Migrator must have allowance access to PanDEXSwap LP tokens.
    // DEXSwap must mint EXACTLY the same amount of DEXSwap LP tokens or
    // else something bad will happen. Traditional PanDEXSwap does not
    // do that so be careful!
    function migrate(ERC20 token) external returns (ERC20);
}

contract DEXMasterChef is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        // ما از فرمول زیر برای محاسبه پندینگ ریوارد استفاده میکنیم
        //   pending reward = (user.amount * pool.accDEXPerShare) - user.rewardDebt
        //در هر دیپوزیت و برداشت توسط کاربر / فرآیند زیر انجام میشه
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accDEXPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    struct PoolInfo {
        ERC20 lpToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accDEXPerShare;
    }

    // The DEX TOKEN!
    DEXToken public DEX;
    // The SYRUP TOKEN!
    Syrup public syrup;
    // Dev address.
    address public devaddr;
    // DEX tokens created per block.
    uint256 public DEXPerBlock;
    // Bonus muliplier for early DEX makers.
    uint256 public BONUS_MULTIPLIER = 1;
    // The migrator contract. It has a lot of power. Can only be set through governance (owner).
    IMigratorChef public migrator;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when DEX mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );

    constructor(
        DEXToken _DEX,
        Syrup _syrup,
        uint256 _DEXPerBlock,
        uint256 _startBlock
    ) {
        DEX = _DEX;
        syrup = _syrup;
        devaddr = msg.sender;
        DEXPerBlock = _DEXPerBlock;
        startBlock = _startBlock;

        // staking pool
        poolInfo.push(
            PoolInfo({
                lpToken: _DEX,
                allocPoint: 1000,
                lastRewardBlock: startBlock,
                accDEXPerShare: 0
            })
        );

        totalAllocPoint = 1000;
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function add(
        uint256 _allocPoint,
        ERC20 _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accDEXPerShare: 0
            })
        );
        updateStakingPool();
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updateStakingPool() internal {
        uint256 length = poolInfo.length;
        uint256 points = 0;
        for (uint256 pid = 1; pid < length; ++pid) {
            points = points.add(poolInfo[pid].allocPoint);
        }
        if (points != 0) {
            points = points.div(3);
            totalAllocPoint = totalAllocPoint.sub(poolInfo[0].allocPoint).add(
                points
            );
            poolInfo[0].allocPoint = points;
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 DEXReward = multiplier
            .mul(DEXPerBlock)
            .mul(pool.allocPoint)
            .div(totalAllocPoint);
        DEX.mint(devaddr, DEXReward.div(10));
        DEX.mint(address(syrup), DEXReward);
        pool.accDEXPerShare = pool.accDEXPerShare.add(
            DEXReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    function enterStaking(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        updatePool(0);
        if (user.amount > 0) {
            uint256 pending = user
                .amount
                .mul(pool.accDEXPerShare)
                .div(1e12)
                .sub(user.rewardDebt);
            if (pending > 0) {
                safeDEXTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.lpToken.safeTransferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accDEXPerShare).div(1e12);

        syrup.mint(msg.sender, _amount);
        emit Deposit(msg.sender, 0, _amount);
    }

    // Safe DEX transfer function, just in case if rounding error causes pool to not have enough DEXs.
    function safeDEXTransfer(address _to, uint256 _amount) internal {
        syrup.safeDEXTransfer(_to, _amount);
    }

    function pendingDEX(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accDEXPerShare = pool.accDEXPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardBlock,
                block.number
            );
            uint256 DEXReward = multiplier
                .mul(DEXPerBlock)
                .mul(pool.allocPoint)
                .div(totalAllocPoint);
            accDEXPerShare = accDEXPerShare.add(
                DEXReward.mul(1e12).div(lpSupply)
            );
        }
        return user.amount.mul(accDEXPerShare).div(1e12).sub(user.rewardDebt);
    }

    // Withdraw DEX tokens from STAKING.
    function leaveStaking(uint256 _amount) public {
        PoolInfo storage pool = poolInfo[0];
        UserInfo storage user = userInfo[0][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(0);
        uint256 pending = user.amount.mul(pool.accDEXPerShare).div(1e12).sub(
            user.rewardDebt
        );
        if (pending > 0) {
            safeDEXTransfer(msg.sender, pending);
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.lpToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accDEXPerShare).div(1e12);

        syrup.burn(msg.sender, _amount);
        emit Withdraw(msg.sender, 0, _amount);
    }
}
