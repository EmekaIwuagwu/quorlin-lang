# staking.ql — Token Staking Contract with Rewards
# Stake tokens, earn rewards over time

from std.math import safe_add, safe_sub, safe_mul, safe_div
from std.time import block_timestamp, add_days
from std.log import require, require_not_zero_address, emit_event

contract TokenStaking:
    """
    Token staking contract with time-based rewards.
    
    Features:
    - Stake tokens to earn rewards
    - Configurable reward rate
    - Lock periods with early withdrawal penalties
    - Multiple staking pools
    - Compound rewards
    - Emergency withdrawal
    - Cross-chain compatible
    """
    
    # State variables
    _staking_token: address
    _reward_token: address
    _owner: address
    
    # Reward configuration
    _reward_rate: uint256  # Tokens per second per staked token
    _min_stake_amount: uint256
    _lock_period: uint64  # Seconds
    _early_withdrawal_penalty: uint256  # Basis points (e.g., 1000 = 10%)
    
    # Global state
    _total_staked: uint256
    _total_rewards_distributed: uint256
    _reward_pool_balance: uint256
    
    # User stakes
    _stakes: mapping[address, Stake]
    _user_reward_debt: mapping[address, uint256]
    
    # Accumulated reward per share (scaled by 1e18)
    _acc_reward_per_share: uint256
    _last_reward_time: uint64
    
    # Staking pools
    _pool_count: uint256
    _pools: mapping[uint256, StakingPool]
    _user_pool_stakes: mapping[address, mapping[uint256, PoolStake]]
    
    # Structs
    struct Stake:
        amount: uint256
        start_time: uint64
        last_claim_time: uint64
        accumulated_rewards: uint256
    
    struct StakingPool:
        name: str
        reward_rate: uint256
        lock_period: uint64
        total_staked: uint256
        active: bool
    
    struct PoolStake:
        amount: uint256
        start_time: uint64
        last_claim_time: uint64
        rewards: uint256
    
    # Events
    event Staked(user: address, amount: uint256, timestamp: uint64)
    event Unstaked(user: address, amount: uint256, reward: uint256, penalty: uint256)
    event RewardClaimed(user: address, amount: uint256)
    event RewardRateUpdated(old_rate: uint256, new_rate: uint256)
    event PoolCreated(pool_id: uint256, name: str, reward_rate: uint256)
    event PoolStaked(user: address, pool_id: uint256, amount: uint256)
    event EmergencyWithdrawal(user: address, amount: uint256)
    
    @constructor
    fn __init__(
        staking_token: address,
        reward_token: address,
        reward_rate: uint256,
        min_stake: uint256,
        lock_period_days: uint64
    ):
        """
        Initialize the staking contract.
        
        Args:
            staking_token: Token to be staked
            reward_token: Token given as rewards
            reward_rate: Reward tokens per second per staked token (scaled by 1e18)
            min_stake: Minimum stake amount
            lock_period_days: Lock period in days
        """
        require_not_zero_address(staking_token, "Invalid staking token")
        require_not_zero_address(reward_token, "Invalid reward token")
        require(reward_rate > 0, "Invalid reward rate")
        
        self._staking_token = staking_token
        self._reward_token = reward_token
        self._reward_rate = reward_rate
        self._min_stake_amount = min_stake
        self._lock_period = lock_period_days * 86400  # Convert days to seconds
        self._early_withdrawal_penalty = 1000  # 10% penalty
        self._owner = msg.sender
        self._last_reward_time = block_timestamp()
        self._pool_count = 0
    
    # ========== View Functions ==========
    
    @view
    fn get_stake(user: address) -> Stake:
        """Returns user's stake information."""
        return self._stakes[user]
    
    @view
    fn total_staked() -> uint256:
        """Returns total amount staked."""
        return self._total_staked
    
    @view
    fn calculate_pending_rewards(user: address) -> uint256:
        """
        Calculates pending rewards for a user.
        
        Args:
            user: User address
        
        Returns:
            Pending reward amount
        """
        stake: Stake = self._stakes[user]
        
        if stake.amount == 0:
            return 0
        
        time_elapsed: uint64 = block_timestamp() - stake.last_claim_time
        reward: uint256 = safe_mul(
            safe_mul(stake.amount, self._reward_rate),
            time_elapsed
        ) / 1e18
        
        return safe_add(stake.accumulated_rewards, reward)
    
    @view
    fn get_pool(pool_id: uint256) -> StakingPool:
        """Returns staking pool information."""
        require(pool_id < self._pool_count, "Pool does not exist")
        return self._pools[pool_id]
    
    @view
    fn get_pool_stake(user: address, pool_id: uint256) -> PoolStake:
        """Returns user's stake in a specific pool."""
        return self._user_pool_stakes[user][pool_id]
    
    @view
    fn calculate_pool_rewards(user: address, pool_id: uint256) -> uint256:
        """Calculates pending rewards in a specific pool."""
        pool_stake: PoolStake = self._user_pool_stakes[user][pool_id]
        pool: StakingPool = self._pools[pool_id]
        
        if pool_stake.amount == 0:
            return 0
        
        time_elapsed: uint64 = block_timestamp() - pool_stake.last_claim_time
        reward: uint256 = safe_mul(
            safe_mul(pool_stake.amount, pool.reward_rate),
            time_elapsed
        ) / 1e18
        
        return safe_add(pool_stake.rewards, reward)
    
    @view
    fn is_locked(user: address) -> bool:
        """Checks if user's stake is still locked."""
        stake: Stake = self._stakes[user]
        if stake.amount == 0:
            return False
        
        unlock_time: uint64 = stake.start_time + self._lock_period
        return block_timestamp() < unlock_time
    
    @view
    fn time_until_unlock(user: address) -> uint64:
        """Returns seconds until stake is unlocked."""
        stake: Stake = self._stakes[user]
        if stake.amount == 0:
            return 0
        
        unlock_time: uint64 = stake.start_time + self._lock_period
        current_time: uint64 = block_timestamp()
        
        if current_time >= unlock_time:
            return 0
        
        return unlock_time - current_time
    
    # ========== Staking Functions ==========
    
    @external
    fn stake(amount: uint256):
        """
        Stakes tokens.
        
        Args:
            amount: Amount to stake
        """
        require(amount >= self._min_stake_amount, "Amount below minimum")
        
        # Update rewards before modifying stake
        self._update_rewards(msg.sender)
        
        # Transfer tokens from user
        self._transfer_from(self._staking_token, msg.sender, address(this), amount)
        
        # Update stake
        stake: Stake = self._stakes[msg.sender]
        
        if stake.amount == 0:
            # New stake
            self._stakes[msg.sender] = Stake(
                amount=amount,
                start_time=block_timestamp(),
                last_claim_time=block_timestamp(),
                accumulated_rewards=0
            )
        else:
            # Add to existing stake
            stake.amount = safe_add(stake.amount, amount)
            self._stakes[msg.sender] = stake
        
        self._total_staked = safe_add(self._total_staked, amount)
        
        emit Staked(msg.sender, amount, block_timestamp())
    
    @external
    fn unstake(amount: uint256):
        """
        Unstakes tokens and claims rewards.
        
        Args:
            amount: Amount to unstake
        """
        stake: Stake = self._stakes[msg.sender]
        require(stake.amount >= amount, "Insufficient stake")
        
        # Update rewards
        self._update_rewards(msg.sender)
        
        # Calculate penalty if locked
        penalty: uint256 = 0
        actual_amount: uint256 = amount
        
        if self.is_locked(msg.sender):
            penalty = safe_div(safe_mul(amount, self._early_withdrawal_penalty), 10000)
            actual_amount = safe_sub(amount, penalty)
        
        # Calculate and transfer rewards
        rewards: uint256 = stake.accumulated_rewards
        
        # Update stake
        stake.amount = safe_sub(stake.amount, amount)
        stake.accumulated_rewards = 0
        stake.last_claim_time = block_timestamp()
        self._stakes[msg.sender] = stake
        
        self._total_staked = safe_sub(self._total_staked, amount)
        
        # Transfer tokens back to user
        self._transfer(self._staking_token, msg.sender, actual_amount)
        
        # Transfer penalty to owner if applicable
        if penalty > 0:
            self._transfer(self._staking_token, self._owner, penalty)
        
        # Transfer rewards
        if rewards > 0:
            self._transfer(self._reward_token, msg.sender, rewards)
            self._total_rewards_distributed = safe_add(self._total_rewards_distributed, rewards)
        
        emit Unstaked(msg.sender, amount, rewards, penalty)
    
    @external
    fn claim_rewards():
        """Claims accumulated rewards without unstaking."""
        self._update_rewards(msg.sender)
        
        stake: Stake = self._stakes[msg.sender]
        rewards: uint256 = stake.accumulated_rewards
        
        require(rewards > 0, "No rewards to claim")
        
        # Reset accumulated rewards
        stake.accumulated_rewards = 0
        stake.last_claim_time = block_timestamp()
        self._stakes[msg.sender] = stake
        
        # Transfer rewards
        self._transfer(self._reward_token, msg.sender, rewards)
        self._total_rewards_distributed = safe_add(self._total_rewards_distributed, rewards)
        
        emit RewardClaimed(msg.sender, rewards)
    
    @external
    fn compound_rewards():
        """
        Compounds rewards by staking them.
        Only works if staking and reward tokens are the same.
        """
        require(self._staking_token == self._reward_token, "Cannot compound different tokens")
        
        self._update_rewards(msg.sender)
        
        stake: Stake = self._stakes[msg.sender]
        rewards: uint256 = stake.accumulated_rewards
        
        require(rewards > 0, "No rewards to compound")
        
        # Add rewards to stake
        stake.amount = safe_add(stake.amount, rewards)
        stake.accumulated_rewards = 0
        stake.last_claim_time = block_timestamp()
        self._stakes[msg.sender] = stake
        
        self._total_staked = safe_add(self._total_staked, rewards)
        
        emit Staked(msg.sender, rewards, block_timestamp())
        emit RewardClaimed(msg.sender, rewards)
    
    # ========== Pool Functions ==========
    
    @external
    fn create_pool(name: str, reward_rate: uint256, lock_period_days: uint64):
        """
        Creates a new staking pool (owner only).
        
        Args:
            name: Pool name
            reward_rate: Reward rate for this pool
            lock_period_days: Lock period in days
        """
        self._only_owner()
        require(reward_rate > 0, "Invalid reward rate")
        
        pool_id: uint256 = self._pool_count
        self._pool_count = safe_add(self._pool_count, 1)
        
        self._pools[pool_id] = StakingPool(
            name=name,
            reward_rate=reward_rate,
            lock_period=lock_period_days * 86400,
            total_staked=0,
            active=True
        )
        
        emit PoolCreated(pool_id, name, reward_rate)
    
    @external
    fn stake_in_pool(pool_id: uint256, amount: uint256):
        """
        Stakes tokens in a specific pool.
        
        Args:
            pool_id: Pool ID
            amount: Amount to stake
        """
        require(pool_id < self._pool_count, "Pool does not exist")
        pool: StakingPool = self._pools[pool_id]
        require(pool.active, "Pool is not active")
        require(amount >= self._min_stake_amount, "Amount below minimum")
        
        # Transfer tokens
        self._transfer_from(self._staking_token, msg.sender, address(this), amount)
        
        # Update pool stake
        pool_stake: PoolStake = self._user_pool_stakes[msg.sender][pool_id]
        
        if pool_stake.amount == 0:
            self._user_pool_stakes[msg.sender][pool_id] = PoolStake(
                amount=amount,
                start_time=block_timestamp(),
                last_claim_time=block_timestamp(),
                rewards=0
            )
        else:
            # Update existing rewards
            pending: uint256 = self.calculate_pool_rewards(msg.sender, pool_id)
            pool_stake.amount = safe_add(pool_stake.amount, amount)
            pool_stake.rewards = pending
            pool_stake.last_claim_time = block_timestamp()
            self._user_pool_stakes[msg.sender][pool_id] = pool_stake
        
        pool.total_staked = safe_add(pool.total_staked, amount)
        self._pools[pool_id] = pool
        
        emit PoolStaked(msg.sender, pool_id, amount)
    
    @external
    fn claim_pool_rewards(pool_id: uint256):
        """Claims rewards from a specific pool."""
        rewards: uint256 = self.calculate_pool_rewards(msg.sender, pool_id)
        require(rewards > 0, "No rewards to claim")
        
        pool_stake: PoolStake = self._user_pool_stakes[msg.sender][pool_id]
        pool_stake.rewards = 0
        pool_stake.last_claim_time = block_timestamp()
        self._user_pool_stakes[msg.sender][pool_id] = pool_stake
        
        self._transfer(self._reward_token, msg.sender, rewards)
        self._total_rewards_distributed = safe_add(self._total_rewards_distributed, rewards)
        
        emit RewardClaimed(msg.sender, rewards)
    
    # ========== Admin Functions ==========
    
    @external
    fn set_reward_rate(new_rate: uint256):
        """Updates the reward rate (owner only)."""
        self._only_owner()
        require(new_rate > 0, "Invalid reward rate")
        
        old_rate: uint256 = self._reward_rate
        self._reward_rate = new_rate
        
        emit RewardRateUpdated(old_rate, new_rate)
    
    @external
    fn fund_rewards(amount: uint256):
        """
        Funds the reward pool (owner only).
        
        Args:
            amount: Amount of reward tokens to add
        """
        self._only_owner()
        self._transfer_from(self._reward_token, msg.sender, address(this), amount)
        self._reward_pool_balance = safe_add(self._reward_pool_balance, amount)
    
    @external
    fn emergency_withdraw():
        """
        Emergency withdrawal without rewards (no penalty).
        Only use in case of contract issues.
        """
        stake: Stake = self._stakes[msg.sender]
        require(stake.amount > 0, "No stake to withdraw")
        
        amount: uint256 = stake.amount
        
        # Clear stake
        self._stakes[msg.sender] = Stake(
            amount=0,
            start_time=0,
            last_claim_time=0,
            accumulated_rewards=0
        )
        
        self._total_staked = safe_sub(self._total_staked, amount)
        
        # Transfer tokens back
        self._transfer(self._staking_token, msg.sender, amount)
        
        emit EmergencyWithdrawal(msg.sender, amount)
    
    # ========== Internal Functions ==========
    
    fn _update_rewards(user: address):
        """Updates accumulated rewards for a user."""
        stake: Stake = self._stakes[user]
        
        if stake.amount == 0:
            return
        
        time_elapsed: uint64 = block_timestamp() - stake.last_claim_time
        
        if time_elapsed > 0:
            reward: uint256 = safe_mul(
                safe_mul(stake.amount, self._reward_rate),
                time_elapsed
            ) / 1e18
            
            stake.accumulated_rewards = safe_add(stake.accumulated_rewards, reward)
            stake.last_claim_time = block_timestamp()
            self._stakes[user] = stake
    
    fn _only_owner():
        """Modifier: requires caller to be owner."""
        require(msg.sender == self._owner, "Caller is not the owner")
    
    # Compiler intrinsics
    fn _transfer(token: address, to: address, amount: uint256):
        """Transfers tokens."""
        pass
    
    fn _transfer_from(token: address, from_addr: address, to: address, amount: uint256):
        """Transfers tokens using allowance."""
        pass
