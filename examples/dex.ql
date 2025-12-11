# Decentralized Exchange (DEX) Contract
# Automated Market Maker with liquidity pools

from std.math import safe_add, safe_sub, safe_mul, safe_div, sqrt

# Struct definition at top level
struct Pool:
    """Liquidity pool for token pair."""
    token_a_reserve: uint256
    token_b_reserve: uint256
    total_liquidity: uint256
    fee_percent: uint256  # Fee in basis points (e.g., 30 = 0.3%)

# Events at top level
event PoolCreated:
    pool_id: uint256
    initial_a: uint256
    initial_b: uint256

event LiquidityAdded:
    pool_id: uint256
    provider: address
    amount_a: uint256
    amount_b: uint256
    liquidity_minted: uint256

event LiquidityRemoved:
    pool_id: uint256
    provider: address
    amount_a: uint256
    amount_b: uint256
    liquidity_burned: uint256

event Swap:
    pool_id: uint256
    trader: address
    token_in: str
    amount_in: uint256
    amount_out: uint256

contract DEX:
    """Simple automated market maker (AMM) DEX."""
    
    pools: mapping[uint256, Pool]
    liquidity_providers: mapping[uint256, mapping[address, uint256]]
    pool_count: uint256
    owner: address
    
    @constructor
    fn __init__():
        """Initialize DEX."""
        self.pool_count = 0
        self.owner = msg.sender
    
    @external
    fn create_pool(initial_a: uint256, initial_b: uint256, fee_percent: uint256) -> uint256:
        """Create a new liquidity pool."""
        require(initial_a > 0 and initial_b > 0, "Initial amounts must be positive")
        require(fee_percent <= 1000, "Fee too high")  # Max 10%
        
        let pool_id: uint256 = self.pool_count
        self.pool_count = self.pool_count + 1
        
        // Calculate initial liquidity
        let initial_liquidity: uint256 = sqrt(safe_mul(initial_a, initial_b))
        
        // Create pool
        self.pools[pool_id] = Pool(
            token_a_reserve: initial_a,
            token_b_reserve: initial_b,
            total_liquidity: initial_liquidity,
            fee_percent: fee_percent
        )
        
        // Assign liquidity to creator
        self.liquidity_providers[pool_id][msg.sender] = initial_liquidity
        
        emit PoolCreated(pool_id, initial_a, initial_b)
        
        return pool_id
    
    @external
    fn add_liquidity(pool_id: uint256, amount_a: uint256, amount_b: uint256) -> uint256:
        """Add liquidity to a pool."""
        require(pool_id < self.pool_count, "Pool does not exist")
        require(amount_a > 0 and amount_b > 0, "Amounts must be positive")
        
        let pool: Pool = self.pools[pool_id]
        
        // Calculate optimal amounts to maintain ratio
        let ratio: uint256 = safe_div(pool.token_a_reserve, pool.token_b_reserve)
        let optimal_b: uint256 = safe_div(amount_a, ratio)
        
        require(amount_b >= optimal_b, "Insufficient token B")
        
        // Calculate liquidity to mint
        let liquidity_a: uint256 = safe_div(safe_mul(amount_a, pool.total_liquidity), pool.token_a_reserve)
        let liquidity_b: uint256 = safe_div(safe_mul(optimal_b, pool.total_liquidity), pool.token_b_reserve)
        let liquidity_minted: uint256 = min(liquidity_a, liquidity_b)
        
        // Update pool
        pool.token_a_reserve = safe_add(pool.token_a_reserve, amount_a)
        pool.token_b_reserve = safe_add(pool.token_b_reserve, optimal_b)
        pool.total_liquidity = safe_add(pool.total_liquidity, liquidity_minted)
        self.pools[pool_id] = pool
        
        // Update provider balance
        let current_liquidity: uint256 = self.liquidity_providers[pool_id][msg.sender]
        self.liquidity_providers[pool_id][msg.sender] = safe_add(current_liquidity, liquidity_minted)
        
        emit LiquidityAdded(pool_id, msg.sender, amount_a, optimal_b, liquidity_minted)
        
        return liquidity_minted
    
    @external
    fn remove_liquidity(pool_id: uint256, liquidity_amount: uint256) -> (uint256, uint256):
        """Remove liquidity from a pool."""
        require(pool_id < self.pool_count, "Pool does not exist")
        require(liquidity_amount > 0, "Amount must be positive")
        
        let provider_liquidity: uint256 = self.liquidity_providers[pool_id][msg.sender]
        require(provider_liquidity >= liquidity_amount, "Insufficient liquidity")
        
        let pool: Pool = self.pools[pool_id]
        
        // Calculate amounts to return
        let amount_a: uint256 = safe_div(safe_mul(liquidity_amount, pool.token_a_reserve), pool.total_liquidity)
        let amount_b: uint256 = safe_div(safe_mul(liquidity_amount, pool.token_b_reserve), pool.total_liquidity)
        
        // Update pool
        pool.token_a_reserve = safe_sub(pool.token_a_reserve, amount_a)
        pool.token_b_reserve = safe_sub(pool.token_b_reserve, amount_b)
        pool.total_liquidity = safe_sub(pool.total_liquidity, liquidity_amount)
        self.pools[pool_id] = pool
        
        // Update provider balance
        self.liquidity_providers[pool_id][msg.sender] = safe_sub(provider_liquidity, liquidity_amount)
        
        emit LiquidityRemoved(pool_id, msg.sender, amount_a, amount_b, liquidity_amount)
        
        return (amount_a, amount_b)
    
    @external
    fn swap_a_for_b(pool_id: uint256, amount_in: uint256, min_amount_out: uint256) -> uint256:
        """Swap token A for token B."""
        require(pool_id < self.pool_count, "Pool does not exist")
        require(amount_in > 0, "Amount must be positive")
        
        let pool: Pool = self.pools[pool_id]
        
        // Calculate amount out using constant product formula
        // (x + Δx)(y - Δy) = xy
        // Δy = y * Δx / (x + Δx)
        
        // Apply fee
        let fee: uint256 = safe_div(safe_mul(amount_in, pool.fee_percent), 10000)
        let amount_in_after_fee: uint256 = safe_sub(amount_in, fee)
        
        let amount_out: uint256 = self.get_amount_out(
            amount_in_after_fee,
            pool.token_a_reserve,
            pool.token_b_reserve
        )
        
        require(amount_out >= min_amount_out, "Slippage too high")
        
        // Update reserves
        pool.token_a_reserve = safe_add(pool.token_a_reserve, amount_in)
        pool.token_b_reserve = safe_sub(pool.token_b_reserve, amount_out)
        self.pools[pool_id] = pool
        
        emit Swap(pool_id, msg.sender, "A", amount_in, amount_out)
        
        return amount_out
    
    @external
    fn swap_b_for_a(pool_id: uint256, amount_in: uint256, min_amount_out: uint256) -> uint256:
        """Swap token B for token A."""
        require(pool_id < self.pool_count, "Pool does not exist")
        require(amount_in > 0, "Amount must be positive")
        
        let pool: Pool = self.pools[pool_id]
        
        // Apply fee
        let fee: uint256 = safe_div(safe_mul(amount_in, pool.fee_percent), 10000)
        let amount_in_after_fee: uint256 = safe_sub(amount_in, fee)
        
        let amount_out: uint256 = self.get_amount_out(
            amount_in_after_fee,
            pool.token_b_reserve,
            pool.token_a_reserve
        )
        
        require(amount_out >= min_amount_out, "Slippage too high")
        
        // Update reserves
        pool.token_b_reserve = safe_add(pool.token_b_reserve, amount_in)
        pool.token_a_reserve = safe_sub(pool.token_a_reserve, amount_out)
        self.pools[pool_id] = pool
        
        emit Swap(pool_id, msg.sender, "B", amount_in, amount_out)
        
        return amount_out
    
    @view
    fn get_amount_out(amount_in: uint256, reserve_in: uint256, reserve_out: uint256) -> uint256:
        """Calculate output amount using constant product formula."""
        require(amount_in > 0, "Amount must be positive")
        require(reserve_in > 0 and reserve_out > 0, "Insufficient liquidity")
        
        let numerator: uint256 = safe_mul(amount_in, reserve_out)
        let denominator: uint256 = safe_add(reserve_in, amount_in)
        
        return safe_div(numerator, denominator)
    
    @view
    fn get_pool(pool_id: uint256) -> Pool:
        """Get pool information."""
        require(pool_id < self.pool_count, "Pool does not exist")
        return self.pools[pool_id]
    
    @view
    fn get_liquidity(pool_id: uint256, provider: address) -> uint256:
        """Get provider's liquidity in a pool."""
        return self.liquidity_providers[pool_id][provider]
    
    @view
    fn get_price(pool_id: uint256) -> uint256:
        """Get current price of token A in terms of token B."""
        require(pool_id < self.pool_count, "Pool does not exist")
        let pool: Pool = self.pools[pool_id]
        return safe_div(pool.token_b_reserve, pool.token_a_reserve)

fn min(a: uint256, b: uint256) -> uint256:
    """Return minimum of two values."""
    if a < b:
        return a
    return b
