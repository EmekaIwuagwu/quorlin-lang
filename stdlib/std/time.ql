# time.ql — Time and block utilities for Quorlin
# Cross-chain compatible time/block information access

fn block_timestamp() -> uint64:
    """
    Returns the current block timestamp (Unix time in seconds).
    
    Backend implementations:
    - EVM: block.timestamp
    - Solana: Clock sysvar (slot converted to estimated timestamp)
    - Polkadot: env().block_timestamp()
    - Aptos: timestamp::now_seconds()
    - StarkNet: get_block_timestamp()
    - Avalanche: block.timestamp (EVM-compatible)
    
    Returns:
        Unix timestamp in seconds
    
    Note: Timestamps can be manipulated by validators/miners within bounds.
    Do not rely on exact precision for critical logic.
    """
    pass

fn block_number() -> uint64:
    """
    Returns the current block number/height.
    
    Backend implementations:
    - EVM: block.number
    - Solana: Clock sysvar slot
    - Polkadot: env().block_number()
    - Aptos: block::get_current_block_height()
    - StarkNet: get_block_number()
    - Avalanche: block.number (EVM-compatible)
    
    Returns:
        Current block number
    """
    pass

fn chain_id() -> uint64:
    """
    Returns the chain ID of the current network.
    
    Backend implementations:
    - EVM: block.chainid
    - Solana: Returns predefined constant (1 = mainnet, 2 = testnet, etc.)
    - Polkadot: Returns parachain ID or 0 for relay chain
    - Aptos: chain_id::get()
    - StarkNet: get_chain_id()
    - Avalanche: block.chainid (EVM-compatible)
    
    Returns:
        Chain identifier
    """
    pass

fn block_difficulty() -> uint256:
    """
    Returns the current block difficulty (EVM-specific).
    
    Backend implementations:
    - EVM: block.difficulty (or prevrandao post-merge)
    - Solana: Returns 0 (not applicable)
    - Polkadot: Returns 0 (not applicable)
    - Others: Returns 0 or equivalent randomness source
    
    Returns:
        Block difficulty or randomness value
    
    Note: Post-Ethereum merge, this returns PREVRANDAO instead of difficulty.
    """
    pass

fn block_gas_limit() -> uint64:
    """
    Returns the current block gas limit (EVM-specific).
    
    Backend implementations:
    - EVM: block.gaslimit
    - Solana: Returns compute unit limit
    - Polkadot: Returns weight limit
    - Others: Returns equivalent resource limit
    
    Returns:
        Block gas/compute limit
    """
    pass

fn tx_gas_price() -> uint256:
    """
    Returns the gas price of the current transaction (EVM-specific).
    
    Backend implementations:
    - EVM: tx.gasprice
    - Solana: Returns lamports per compute unit
    - Polkadot: Returns weight-to-fee conversion
    - Others: Returns equivalent fee rate
    
    Returns:
        Transaction gas price
    """
    pass

fn coinbase() -> address:
    """
    Returns the block producer/miner address.
    
    Backend implementations:
    - EVM: block.coinbase
    - Solana: Returns validator identity (converted to address)
    - Polkadot: Returns block author
    - Aptos: Returns proposer address
    - StarkNet: Returns sequencer address
    - Avalanche: block.coinbase (EVM-compatible)
    
    Returns:
        Address of block producer
    """
    pass

# Time utility functions

fn is_past(timestamp: uint64) -> bool:
    """
    Checks if a timestamp is in the past.
    
    Args:
        timestamp: Unix timestamp to check
    
    Returns:
        True if timestamp < current block timestamp
    """
    return timestamp < block_timestamp()

fn is_future(timestamp: uint64) -> bool:
    """
    Checks if a timestamp is in the future.
    
    Args:
        timestamp: Unix timestamp to check
    
    Returns:
        True if timestamp > current block timestamp
    """
    return timestamp > block_timestamp()

fn time_until(timestamp: uint64) -> uint64:
    """
    Calculates seconds until a future timestamp.
    Returns 0 if timestamp is in the past.
    
    Args:
        timestamp: Future Unix timestamp
    
    Returns:
        Seconds until timestamp, or 0 if already passed
    """
    current: uint64 = block_timestamp()
    if timestamp <= current:
        return 0
    return timestamp - current

fn time_since(timestamp: uint64) -> uint64:
    """
    Calculates seconds since a past timestamp.
    Returns 0 if timestamp is in the future.
    
    Args:
        timestamp: Past Unix timestamp
    
    Returns:
        Seconds since timestamp, or 0 if in future
    """
    current: uint64 = block_timestamp()
    if timestamp >= current:
        return 0
    return current - timestamp

fn add_seconds(timestamp: uint64, seconds: uint64) -> uint64:
    """
    Adds seconds to a timestamp with overflow protection.
    
    Args:
        timestamp: Base timestamp
        seconds: Seconds to add
    
    Returns:
        New timestamp
    """
    require(timestamp + seconds >= timestamp, "Timestamp overflow")
    return timestamp + seconds

fn add_minutes(timestamp: uint64, minutes: uint64) -> uint64:
    """Adds minutes to a timestamp."""
    return add_seconds(timestamp, minutes * 60)

fn add_hours(timestamp: uint64, hours: uint64) -> uint64:
    """Adds hours to a timestamp."""
    return add_seconds(timestamp, hours * 3600)

fn add_days(timestamp: uint64, days: uint64) -> uint64:
    """Adds days to a timestamp."""
    return add_seconds(timestamp, days * 86400)

fn add_weeks(timestamp: uint64, weeks: uint64) -> uint64:
    """Adds weeks to a timestamp."""
    return add_seconds(timestamp, weeks * 604800)

# Time constants (in seconds)

MINUTE: uint64 = 60
HOUR: uint64 = 3600
DAY: uint64 = 86400
WEEK: uint64 = 604800
MONTH: uint64 = 2592000  # 30 days
YEAR: uint64 = 31536000  # 365 days

# Block-based timelock utilities

fn blocks_until(target_block: uint64) -> uint64:
    """
    Calculates blocks until a target block number.
    Returns 0 if target is in the past.
    
    Args:
        target_block: Future block number
    
    Returns:
        Blocks until target, or 0 if already passed
    """
    current: uint64 = block_number()
    if target_block <= current:
        return 0
    return target_block - current

fn blocks_since(past_block: uint64) -> uint64:
    """
    Calculates blocks since a past block number.
    Returns 0 if block is in the future.
    
    Args:
        past_block: Past block number
    
    Returns:
        Blocks since past_block, or 0 if in future
    """
    current: uint64 = block_number()
    if past_block >= current:
        return 0
    return current - past_block

fn estimate_block_at_timestamp(timestamp: uint64, avg_block_time: uint64) -> uint64:
    """
    Estimates the block number at a future timestamp.
    
    Args:
        timestamp: Future Unix timestamp
        avg_block_time: Average block time in seconds (e.g., 12 for Ethereum)
    
    Returns:
        Estimated block number
    
    Note: This is an approximation. Actual block times vary.
    """
    current_time: uint64 = block_timestamp()
    current_block: uint64 = block_number()
    
    if timestamp <= current_time:
        return current_block
    
    time_diff: uint64 = timestamp - current_time
    blocks_to_add: uint64 = time_diff / avg_block_time
    
    return current_block + blocks_to_add

fn estimate_timestamp_at_block(block_num: uint64, avg_block_time: uint64) -> uint64:
    """
    Estimates the timestamp at a future block number.
    
    Args:
        block_num: Future block number
        avg_block_time: Average block time in seconds
    
    Returns:
        Estimated Unix timestamp
    """
    current_time: uint64 = block_timestamp()
    current_block: uint64 = block_number()
    
    if block_num <= current_block:
        return current_time
    
    blocks_diff: uint64 = block_num - current_block
    time_to_add: uint64 = blocks_diff * avg_block_time
    
    return current_time + time_to_add
