# amm.ql — Automated Market Maker (Constant Product AMM)
# Uniswap V2 style DEX with x * y = k invariant

from std.math import safe_add, safe_sub, safe_mul, safe_div, min
from std.log import emit_event, require, require_not_zero_address

contract SimpleAMM:
    """
    Constant Product Automated Market Maker (AMM).
    
    Implements the x * y = k invariant for token swaps.
    Features:
    - Add/remove liquidity
    - Token swaps with 0.3% fee
    - LP token tracking
    - Price oracle (TWAP-ready)
    - Cross-chain compatible
    
    Based on Uniswap V2 design.
    """
    
    # State variables
    _token0: address
    _token1: address
    _factory: address
    
    # Reserves
    _reserve0: uint256
    _reserve1: uint256
    _block_timestamp_last: uint64
    
    # Cumulative prices (for TWAP oracle)
    _price0_cumulative_last: uint256
    _price1_cumulative_last: uint256
    
    # Liquidity tracking
    _total_liquidity: uint256
    _liquidity_balances: mapping[address, uint256]
    
    # Fee configuration
    _fee_percent: uint256  # Basis points (30 = 0.3%)
    _protocol_fee_percent: uint256  # Basis points (5 = 0.05%)
    _fee_to: address  # Protocol fee recipient
    
    # Minimum liquidity (locked forever)
    MINIMUM_LIQUIDITY: uint256 = 1000
    
    # Events
    event Mint(sender: address, amount0: uint256, amount1: uint256, liquidity: uint256)
    event Burn(sender: address, amount0: uint256, amount1: uint256, liquidity: uint256, to: address)
    event Swap(
        sender: address,
        amount0_in: uint256,
        amount1_in: uint256,
        amount0_out: uint256,
        amount1_out: uint256,
        to: address
    )
    event Sync(reserve0: uint256, reserve1: uint256)
    event FeeUpdated(fee_percent: uint256, protocol_fee_percent: uint256)
    
    @constructor
    fn __init__(token0: address, token1: address, fee_percent: uint256):
        """
        Initialize the AMM pool.
        
        Args:
            token0: First token address
            token1: Second token address
            fee_percent: Trading fee in basis points (e.g., 30 = 0.3%)
        """
        require_not_zero_address(token0, "Invalid token0")
        require_not_zero_address(token1, "Invalid token1")
        require(token0 != token1, "Identical tokens")
        require(fee_percent <= 1000, "Fee too high")  # Max 10%
        
        self._token0 = token0
        self._token1 = token1
        self._factory = msg.sender
        self._fee_percent = fee_percent
        self._protocol_fee_percent = 5  # 0.05% protocol fee
        self._fee_to = msg.sender
    
    # ========== View Functions ==========
    
    @view
    fn get_reserves() -> (uint256, uint256, uint64):
        """
        Returns current reserves and last update timestamp.
        
        Returns:
            Tuple of (reserve0, reserve1, block_timestamp_last)
        """
        return (self._reserve0, self._reserve1, self._block_timestamp_last)
    
    @view
    fn get_tokens() -> (address, address):
        """Returns the token pair addresses."""
        return (self._token0, self._token1)
    
    @view
    fn total_liquidity() -> uint256:
        """Returns total liquidity tokens."""
        return self._total_liquidity
    
    @view
    fn liquidity_balance(account: address) -> uint256:
        """
        Returns liquidity balance of an account.
        
        Args:
            account: Address to query
        
        Returns:
            Liquidity token balance
        """
        return self._liquidity_balances[account]
    
    @view
    fn get_amount_out(amount_in: uint256, reserve_in: uint256, reserve_out: uint256) -> uint256:
        """
        Calculates output amount for a swap (including fees).
        
        Args:
            amount_in: Input token amount
            reserve_in: Input token reserve
            reserve_out: Output token reserve
        
        Returns:
            Output token amount
        """
        require(amount_in > 0, "Insufficient input amount")
        require(reserve_in > 0 and reserve_out > 0, "Insufficient liquidity")
        
        # Apply fee
        amount_in_with_fee: uint256 = safe_mul(amount_in, 10000 - self._fee_percent)
        numerator: uint256 = safe_mul(amount_in_with_fee, reserve_out)
        denominator: uint256 = safe_add(safe_mul(reserve_in, 10000), amount_in_with_fee)
        
        return safe_div(numerator, denominator)
    
    @view
    fn get_amount_in(amount_out: uint256, reserve_in: uint256, reserve_out: uint256) -> uint256:
        """
        Calculates required input amount for desired output (including fees).
        
        Args:
            amount_out: Desired output amount
            reserve_in: Input token reserve
            reserve_out: Output token reserve
        
        Returns:
            Required input amount
        """
        require(amount_out > 0, "Insufficient output amount")
        require(reserve_in > 0 and reserve_out > 0, "Insufficient liquidity")
        require(amount_out < reserve_out, "Insufficient liquidity")
        
        numerator: uint256 = safe_mul(safe_mul(reserve_in, amount_out), 10000)
        denominator: uint256 = safe_mul(safe_sub(reserve_out, amount_out), 10000 - self._fee_percent)
        
        return safe_add(safe_div(numerator, denominator), 1)
    
    @view
    fn quote(amount_a: uint256, reserve_a: uint256, reserve_b: uint256) -> uint256:
        """
        Quotes equivalent amount of token B for amount of token A.
        
        Args:
            amount_a: Amount of token A
            reserve_a: Reserve of token A
            reserve_b: Reserve of token B
        
        Returns:
            Equivalent amount of token B
        """
        require(amount_a > 0, "Insufficient amount")
        require(reserve_a > 0 and reserve_b > 0, "Insufficient liquidity")
        
        return safe_div(safe_mul(amount_a, reserve_b), reserve_a)
    
    # ========== Liquidity Functions ==========
    
    @external
    fn add_liquidity(
        amount0_desired: uint256,
        amount1_desired: uint256,
        amount0_min: uint256,
        amount1_min: uint256,
        to: address
    ) -> (uint256, uint256, uint256):
        """
        Adds liquidity to the pool.
        
        Args:
            amount0_desired: Desired amount of token0
            amount1_desired: Desired amount of token1
            amount0_min: Minimum amount of token0 (slippage protection)
            amount1_min: Minimum amount of token1 (slippage protection)
            to: Recipient of liquidity tokens
        
        Returns:
            Tuple of (amount0, amount1, liquidity)
        """
        require_not_zero_address(to, "Invalid recipient")
        
        # Calculate optimal amounts
        amount0: uint256
        amount1: uint256
        
        if self._reserve0 == 0 and self._reserve1 == 0:
            # First liquidity provision
            amount0 = amount0_desired
            amount1 = amount1_desired
        else:
            # Subsequent liquidity provision - maintain ratio
            amount1_optimal: uint256 = self.quote(amount0_desired, self._reserve0, self._reserve1)
            
            if amount1_optimal <= amount1_desired:
                require(amount1_optimal >= amount1_min, "Insufficient token1 amount")
                amount0 = amount0_desired
                amount1 = amount1_optimal
            else:
                amount0_optimal: uint256 = self.quote(amount1_desired, self._reserve1, self._reserve0)
                require(amount0_optimal <= amount0_desired, "Invalid amounts")
                require(amount0_optimal >= amount0_min, "Insufficient token0 amount")
                amount0 = amount0_optimal
                amount1 = amount1_desired
        
        # Transfer tokens from user
        self._transfer_from(self._token0, msg.sender, address(this), amount0)
        self._transfer_from(self._token1, msg.sender, address(this), amount1)
        
        # Mint liquidity tokens
        liquidity: uint256 = self._mint_liquidity(to, amount0, amount1)
        
        emit Mint(msg.sender, amount0, amount1, liquidity)
        
        return (amount0, amount1, liquidity)
    
    @external
    fn remove_liquidity(
        liquidity: uint256,
        amount0_min: uint256,
        amount1_min: uint256,
        to: address
    ) -> (uint256, uint256):
        """
        Removes liquidity from the pool.
        
        Args:
            liquidity: Amount of liquidity tokens to burn
            amount0_min: Minimum amount of token0 to receive
            amount1_min: Minimum amount of token1 to receive
            to: Recipient of tokens
        
        Returns:
            Tuple of (amount0, amount1)
        """
        require_not_zero_address(to, "Invalid recipient")
        require(liquidity > 0, "Insufficient liquidity")
        require(self._liquidity_balances[msg.sender] >= liquidity, "Insufficient balance")
        
        # Calculate proportional amounts
        total_supply: uint256 = self._total_liquidity
        amount0: uint256 = safe_div(safe_mul(liquidity, self._reserve0), total_supply)
        amount1: uint256 = safe_div(safe_mul(liquidity, self._reserve1), total_supply)
        
        require(amount0 >= amount0_min, "Insufficient token0 amount")
        require(amount1 >= amount1_min, "Insufficient token1 amount")
        require(amount0 > 0 and amount1 > 0, "Insufficient liquidity burned")
        
        # Burn liquidity tokens
        self._liquidity_balances[msg.sender] = safe_sub(self._liquidity_balances[msg.sender], liquidity)
        self._total_liquidity = safe_sub(self._total_liquidity, liquidity)
        
        # Update reserves
        self._reserve0 = safe_sub(self._reserve0, amount0)
        self._reserve1 = safe_sub(self._reserve1, amount1)
        
        # Transfer tokens to user
        self._transfer(self._token0, to, amount0)
        self._transfer(self._token1, to, amount1)
        
        self._update_oracle()
        
        emit Burn(msg.sender, amount0, amount1, liquidity, to)
        emit Sync(self._reserve0, self._reserve1)
        
        return (amount0, amount1)
    
    # ========== Swap Functions ==========
    
    @external
    fn swap(
        amount0_out: uint256,
        amount1_out: uint256,
        to: address
    ):
        """
        Swaps tokens.
        
        Args:
            amount0_out: Amount of token0 to receive (0 if swapping token0 for token1)
            amount1_out: Amount of token1 to receive (0 if swapping token1 for token0)
            to: Recipient address
        
        Note: Caller must have already sent input tokens to this contract.
        """
        require_not_zero_address(to, "Invalid recipient")
        require(amount0_out > 0 or amount1_out > 0, "Insufficient output amount")
        require(amount0_out < self._reserve0 and amount1_out < self._reserve1, "Insufficient liquidity")
        require(to != self._token0 and to != self._token1, "Invalid recipient")
        
        # Get current balances
        balance0: uint256 = self._balance_of(self._token0, address(this))
        balance1: uint256 = self._balance_of(self._token1, address(this))
        
        # Calculate input amounts
        amount0_in: uint256 = 0
        amount1_in: uint256 = 0
        
        if balance0 > self._reserve0 - amount0_out:
            amount0_in = balance0 - (self._reserve0 - amount0_out)
        
        if balance1 > self._reserve1 - amount1_out:
            amount1_in = balance1 - (self._reserve1 - amount1_out)
        
        require(amount0_in > 0 or amount1_in > 0, "Insufficient input amount")
        
        # Verify K invariant (with fee)
        balance0_adjusted: uint256 = safe_sub(safe_mul(balance0, 10000), safe_mul(amount0_in, self._fee_percent))
        balance1_adjusted: uint256 = safe_sub(safe_mul(balance1, 10000), safe_mul(amount1_in, self._fee_percent))
        
        require(
            safe_mul(balance0_adjusted, balance1_adjusted) >= safe_mul(safe_mul(self._reserve0, self._reserve1), 10000 * 10000),
            "K invariant violated"
        )
        
        # Transfer output tokens
        if amount0_out > 0:
            self._transfer(self._token0, to, amount0_out)
        if amount1_out > 0:
            self._transfer(self._token1, to, amount1_out)
        
        # Update reserves
        self._reserve0 = self._balance_of(self._token0, address(this))
        self._reserve1 = self._balance_of(self._token1, address(this))
        
        self._update_oracle()
        
        emit Swap(msg.sender, amount0_in, amount1_in, amount0_out, amount1_out, to)
        emit Sync(self._reserve0, self._reserve1)
    
    @external
    fn swap_exact_tokens_for_tokens(
        amount_in: uint256,
        amount_out_min: uint256,
        token_in: address,
        to: address
    ) -> uint256:
        """
        Swaps exact input tokens for output tokens.
        
        Args:
            amount_in: Exact input amount
            amount_out_min: Minimum output amount (slippage protection)
            token_in: Input token address
            to: Recipient address
        
        Returns:
            Output amount
        """
        require(token_in == self._token0 or token_in == self._token1, "Invalid token")
        
        is_token0: bool = (token_in == self._token0)
        reserve_in: uint256 = self._reserve0 if is_token0 else self._reserve1
        reserve_out: uint256 = self._reserve1 if is_token0 else self._reserve0
        
        amount_out: uint256 = self.get_amount_out(amount_in, reserve_in, reserve_out)
        require(amount_out >= amount_out_min, "Insufficient output amount")
        
        # Transfer input tokens from user
        self._transfer_from(token_in, msg.sender, address(this), amount_in)
        
        # Execute swap
        if is_token0:
            self.swap(0, amount_out, to)
        else:
            self.swap(amount_out, 0, to)
        
        return amount_out
    
    # ========== Internal Functions ==========
    
    fn _mint_liquidity(to: address, amount0: uint256, amount1: uint256) -> uint256:
        """Mints liquidity tokens."""
        liquidity: uint256
        
        if self._total_liquidity == 0:
            # First liquidity provision
            liquidity = self._sqrt(safe_mul(amount0, amount1))
            liquidity = safe_sub(liquidity, self.MINIMUM_LIQUIDITY)
            
            # Lock minimum liquidity forever
            self._liquidity_balances[address(0)] = self.MINIMUM_LIQUIDITY
            self._total_liquidity = safe_add(liquidity, self.MINIMUM_LIQUIDITY)
        else:
            # Subsequent liquidity provision
            liquidity0: uint256 = safe_div(safe_mul(amount0, self._total_liquidity), self._reserve0)
            liquidity1: uint256 = safe_div(safe_mul(amount1, self._total_liquidity), self._reserve1)
            liquidity = min(liquidity0, liquidity1)
            
            self._total_liquidity = safe_add(self._total_liquidity, liquidity)
        
        require(liquidity > 0, "Insufficient liquidity minted")
        
        self._liquidity_balances[to] = safe_add(self._liquidity_balances[to], liquidity)
        
        # Update reserves
        self._reserve0 = safe_add(self._reserve0, amount0)
        self._reserve1 = safe_add(self._reserve1, amount1)
        
        self._update_oracle()
        
        emit Sync(self._reserve0, self._reserve1)
        
        return liquidity
    
    fn _update_oracle():
        """Updates price oracle (TWAP)."""
        block_timestamp: uint64 = block_timestamp()
        time_elapsed: uint64 = block_timestamp - self._block_timestamp_last
        
        if time_elapsed > 0 and self._reserve0 > 0 and self._reserve1 > 0:
            # Update cumulative prices
            self._price0_cumulative_last = safe_add(
                self._price0_cumulative_last,
                safe_mul(safe_div(self._reserve1, self._reserve0), time_elapsed)
            )
            self._price1_cumulative_last = safe_add(
                self._price1_cumulative_last,
                safe_mul(safe_div(self._reserve0, self._reserve1), time_elapsed)
            )
        
        self._block_timestamp_last = block_timestamp
    
    fn _sqrt(y: uint256) -> uint256:
        """Babylonian square root method."""
        if y > 3:
            z: uint256 = y
            x: uint256 = y / 2 + 1
            while x < z:
                z = x
                x = (y / x + x) / 2
            return z
        elif y != 0:
            return 1
        return 0
    
    # Compiler intrinsics (backend-specific implementations)
    
    fn _transfer(token: address, to: address, amount: uint256):
        """Transfers tokens."""
        pass
    
    fn _transfer_from(token: address, from_addr: address, to: address, amount: uint256):
        """Transfers tokens using allowance."""
        pass
    
    fn _balance_of(token: address, account: address) -> uint256:
        """Returns token balance."""
        pass
