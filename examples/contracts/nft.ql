# nft.ql — Universal NFT (Non-Fungible Token) Contract
# ERC-721 compatible, compiles to all blockchain backends

from std.math import safe_add, safe_sub
from std.log import emit_event, require, require_not_zero_address

contract NFT:
    """
    Universal NFT implementation that compiles to:
    - ERC-721 (EVM/Avalanche)
    - Metaplex NFT (Solana)
    - PSP34 (Polkadot)
    - Aptos Token Standard
    - StarkNet NFT
    
    Supports minting, transferring, approvals, and metadata URIs.
    """
    
    # State variables
    _name: str
    _symbol: str
    _owner: address
    
    # Token ownership and balances
    _owners: mapping[uint256, address]
    _balances: mapping[address, uint256]
    
    # Token metadata
    _token_uris: mapping[uint256, str]
    
    # Approvals
    _token_approvals: mapping[uint256, address]
    _operator_approvals: mapping[address, mapping[address, bool]]
    
    # Token ID counter
    _next_token_id: uint256
    
    # Royalty info (EIP-2981 compatible)
    _royalty_receiver: address
    _royalty_percentage: uint256  # Basis points (e.g., 500 = 5%)
    
    # Events
    event Transfer(from_addr: address, to: address, token_id: uint256)
    event Approval(owner: address, approved: address, token_id: uint256)
    event ApprovalForAll(owner: address, operator: address, approved: bool)
    event Minted(to: address, token_id: uint256, uri: str)
    event Burned(owner: address, token_id: uint256)
    event RoyaltySet(receiver: address, percentage: uint256)
    
    @constructor
    fn __init__(name: str, symbol: str, royalty_percentage: uint256):
        """
        Initialize the NFT collection.
        
        Args:
            name: Collection name (e.g., "My NFT Collection")
            symbol: Collection symbol (e.g., "MNFT")
            royalty_percentage: Default royalty in basis points (e.g., 500 = 5%)
        """
        self._name = name
        self._symbol = symbol
        self._owner = msg.sender
        self._next_token_id = 1
        self._royalty_receiver = msg.sender
        self._royalty_percentage = royalty_percentage
        
        require(royalty_percentage <= 10000, "Royalty percentage too high")
    
    # ========== View Functions ==========
    
    @view
    fn name() -> str:
        """Returns the collection name."""
        return self._name
    
    @view
    fn symbol() -> str:
        """Returns the collection symbol."""
        return self._symbol
    
    @view
    fn owner_of(token_id: uint256) -> address:
        """
        Returns the owner of a token.
        
        Args:
            token_id: Token ID to query
        
        Returns:
            Owner address
        """
        owner: address = self._owners[token_id]
        require_not_zero_address(owner, "Token does not exist")
        return owner
    
    @view
    fn balance_of(owner: address) -> uint256:
        """
        Returns the number of tokens owned by an address.
        
        Args:
            owner: Address to query
        
        Returns:
            Token count
        """
        require_not_zero_address(owner, "Zero address query")
        return self._balances[owner]
    
    @view
    fn token_uri(token_id: uint256) -> str:
        """
        Returns the metadata URI for a token.
        
        Args:
            token_id: Token ID to query
        
        Returns:
            Metadata URI (typically IPFS or HTTP URL)
        """
        require(self._exists(token_id), "Token does not exist")
        return self._token_uris[token_id]
    
    @view
    fn get_approved(token_id: uint256) -> address:
        """
        Returns the approved address for a token.
        
        Args:
            token_id: Token ID to query
        
        Returns:
            Approved address (or zero address if none)
        """
        require(self._exists(token_id), "Token does not exist")
        return self._token_approvals[token_id]
    
    @view
    fn is_approved_for_all(owner: address, operator: address) -> bool:
        """
        Checks if an operator is approved for all tokens of an owner.
        
        Args:
            owner: Token owner address
            operator: Operator address
        
        Returns:
            True if operator is approved for all
        """
        return self._operator_approvals[owner][operator]
    
    @view
    fn total_supply() -> uint256:
        """Returns the total number of minted tokens."""
        return self._next_token_id - 1
    
    @view
    fn royalty_info(token_id: uint256, sale_price: uint256) -> (address, uint256):
        """
        Returns royalty information (EIP-2981).
        
        Args:
            token_id: Token ID
            sale_price: Sale price to calculate royalty on
        
        Returns:
            Tuple of (receiver address, royalty amount)
        """
        royalty_amount: uint256 = (sale_price * self._royalty_percentage) / 10000
        return (self._royalty_receiver, royalty_amount)
    
    # ========== External Functions ==========
    
    @external
    fn mint(to: address, uri: str) -> uint256:
        """
        Mints a new NFT (owner only).
        
        Args:
            to: Recipient address
            uri: Metadata URI
        
        Returns:
            Token ID of minted NFT
        """
        self._only_owner()
        require_not_zero_address(to, "Cannot mint to zero address")
        
        token_id: uint256 = self._next_token_id
        self._next_token_id = safe_add(self._next_token_id, 1)
        
        self._mint(to, token_id, uri)
        
        return token_id
    
    @external
    fn batch_mint(to: address, uris: list[str]) -> list[uint256]:
        """
        Mints multiple NFTs in one transaction (owner only).
        
        Args:
            to: Recipient address
            uris: List of metadata URIs
        
        Returns:
            List of minted token IDs
        """
        self._only_owner()
        require_not_zero_address(to, "Cannot mint to zero address")
        require(uris.len() > 0, "Must mint at least one token")
        require(uris.len() <= 100, "Batch size too large")
        
        token_ids: list[uint256] = []
        
        for uri in uris:
            token_id: uint256 = self._next_token_id
            self._next_token_id = safe_add(self._next_token_id, 1)
            
            self._mint(to, token_id, uri)
            token_ids.push(token_id)
        
        return token_ids
    
    @external
    fn transfer(to: address, token_id: uint256):
        """
        Transfers an NFT to another address.
        
        Args:
            to: Recipient address
            token_id: Token ID to transfer
        """
        require(self._is_approved_or_owner(msg.sender, token_id), "Not authorized")
        self._transfer(self.owner_of(token_id), to, token_id)
    
    @external
    fn transfer_from(from_addr: address, to: address, token_id: uint256):
        """
        Transfers an NFT using approval mechanism.
        
        Args:
            from_addr: Current owner address
            to: Recipient address
            token_id: Token ID to transfer
        """
        require(self._is_approved_or_owner(msg.sender, token_id), "Not authorized")
        require(self.owner_of(token_id) == from_addr, "From address is not owner")
        self._transfer(from_addr, to, token_id)
    
    @external
    fn safe_transfer_from(from_addr: address, to: address, token_id: uint256):
        """
        Safely transfers an NFT (checks if recipient can receive NFTs).
        
        Args:
            from_addr: Current owner address
            to: Recipient address
            token_id: Token ID to transfer
        """
        self.transfer_from(from_addr, to, token_id)
        # Note: Safe transfer check would be implemented by backend
        # EVM: calls onERC721Received on recipient if it's a contract
        # Other chains: equivalent safety checks
    
    @external
    fn approve(approved: address, token_id: uint256):
        """
        Approves an address to transfer a specific token.
        
        Args:
            approved: Address to approve
            token_id: Token ID to approve for
        """
        owner: address = self.owner_of(token_id)
        require(msg.sender == owner or self.is_approved_for_all(owner, msg.sender),
                "Not authorized")
        
        self._approve(approved, token_id)
    
    @external
    fn set_approval_for_all(operator: address, approved: bool):
        """
        Approves or revokes an operator for all tokens.
        
        Args:
            operator: Operator address
            approved: True to approve, False to revoke
        """
        require(operator != msg.sender, "Cannot approve self")
        self._operator_approvals[msg.sender][operator] = approved
        emit ApprovalForAll(msg.sender, operator, approved)
    
    @external
    fn burn(token_id: uint256):
        """
        Burns an NFT (owner or approved only).
        
        Args:
            token_id: Token ID to burn
        """
        require(self._is_approved_or_owner(msg.sender, token_id), "Not authorized")
        owner: address = self.owner_of(token_id)
        self._burn(owner, token_id)
    
    @external
    fn set_token_uri(token_id: uint256, uri: str):
        """
        Updates the metadata URI for a token (owner only).
        
        Args:
            token_id: Token ID
            uri: New metadata URI
        """
        self._only_owner()
        require(self._exists(token_id), "Token does not exist")
        self._token_uris[token_id] = uri
    
    @external
    fn set_royalty_info(receiver: address, percentage: uint256):
        """
        Sets royalty information (owner only).
        
        Args:
            receiver: Royalty receiver address
            percentage: Royalty percentage in basis points
        """
        self._only_owner()
        require_not_zero_address(receiver, "Invalid receiver")
        require(percentage <= 10000, "Percentage too high")
        
        self._royalty_receiver = receiver
        self._royalty_percentage = percentage
        
        emit RoyaltySet(receiver, percentage)
    
    # ========== Internal Functions ==========
    
    fn _mint(to: address, token_id: uint256, uri: str):
        """Internal mint function."""
        self._owners[token_id] = to
        self._balances[to] = safe_add(self._balances[to], 1)
        self._token_uris[token_id] = uri
        
        emit Transfer(address(0), to, token_id)
        emit Minted(to, token_id, uri)
    
    fn _burn(owner: address, token_id: uint256):
        """Internal burn function."""
        # Clear approvals
        self._approve(address(0), token_id)
        
        # Update balances and ownership
        self._balances[owner] = safe_sub(self._balances[owner], 1)
        self._owners[token_id] = address(0)
        self._token_uris[token_id] = ""
        
        emit Transfer(owner, address(0), token_id)
        emit Burned(owner, token_id)
    
    fn _transfer(from_addr: address, to: address, token_id: uint256):
        """Internal transfer function."""
        require_not_zero_address(to, "Transfer to zero address")
        
        # Clear approvals
        self._approve(address(0), token_id)
        
        # Update balances and ownership
        self._balances[from_addr] = safe_sub(self._balances[from_addr], 1)
        self._balances[to] = safe_add(self._balances[to], 1)
        self._owners[token_id] = to
        
        emit Transfer(from_addr, to, token_id)
    
    fn _approve(approved: address, token_id: uint256):
        """Internal approve function."""
        self._token_approvals[token_id] = approved
        emit Approval(self.owner_of(token_id), approved, token_id)
    
    fn _exists(token_id: uint256) -> bool:
        """Checks if a token exists."""
        return self._owners[token_id] != address(0)
    
    fn _is_approved_or_owner(spender: address, token_id: uint256) -> bool:
        """Checks if spender is owner or approved for token."""
        owner: address = self.owner_of(token_id)
        return (spender == owner or 
                self.get_approved(token_id) == spender or
                self.is_approved_for_all(owner, spender))
    
    fn _only_owner():
        """Modifier: requires caller to be contract owner."""
        require(msg.sender == self._owner, "Caller is not the owner")
