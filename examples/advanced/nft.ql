# nft.ql — A simple NFT (ERC-721 style) contract in Quorlin

from std.math import safe_add
from std.access import Ownable

# Events
event Transfer(from_addr: address, to: address, token_id: uint256)
event Approval(owner: address, approved: address, token_id: uint256)
event ApprovalForAll(owner: address, operator: address, approved: bool)

contract NFT(Ownable):
    """
    Simple NFT implementation compatible with ERC-721.
    Supports minting, transferring, and approvals.
    """

    # State variables
    name: str = "Quorlin NFT"
    symbol: str = "QNFT"

    total_supply: uint256
    owners: mapping[uint256, address]
    balances: mapping[address, uint256]
    token_approvals: mapping[uint256, address]
    operator_approvals: mapping[address, mapping[address, bool]]
    token_uris: mapping[uint256, str]

    @constructor
    def __init__():
        """Initialize the NFT contract."""
        Ownable.__init__()
        self.total_supply = 0

    # View functions
    @view
    def balance_of(owner: address) -> uint256:
        """Get the number of tokens owned by an address."""
        require(owner != address(0), "NFT: balance query for zero address")
        return self.balances[owner]

    @view
    def owner_of(token_id: uint256) -> address:
        """Get the owner of a token."""
        owner: address = self.owners[token_id]
        require(owner != address(0), "NFT: owner query for nonexistent token")
        return owner

    @view
    def get_approved(token_id: uint256) -> address:
        """Get the approved address for a token."""
        require(self._exists(token_id), "NFT: approved query for nonexistent token")
        return self.token_approvals[token_id]

    @view
    def is_approved_for_all(owner: address, operator: address) -> bool:
        """Check if operator is approved for all tokens of owner."""
        return self.operator_approvals[owner][operator]

    @view
    def token_uri(token_id: uint256) -> str:
        """Get the URI for a token."""
        require(self._exists(token_id), "NFT: URI query for nonexistent token")
        return self.token_uris[token_id]

    # External functions
    @external
    def approve(to: address, token_id: uint256):
        """Approve an address to transfer a specific token."""
        owner: address = self.owner_of(token_id)
        require(to != owner, "NFT: approval to current owner")
        require(
            msg.sender == owner or self.is_approved_for_all(owner, msg.sender),
            "NFT: approve caller is not owner nor approved for all"
        )

        self._approve(to, token_id)

    @external
    def set_approval_for_all(operator: address, approved: bool):
        """Approve or revoke operator for all tokens."""
        require(operator != msg.sender, "NFT: approve to caller")
        self.operator_approvals[msg.sender][operator] = approved
        emit ApprovalForAll(msg.sender, operator, approved)

    @external
    def transfer_from(from_addr: address, to: address, token_id: uint256):
        """Transfer a token from one address to another."""
        require(
            self._is_approved_or_owner(msg.sender, token_id),
            "NFT: transfer caller is not owner nor approved"
        )
        self._transfer(from_addr, to, token_id)

    @external
    def safe_transfer_from(from_addr: address, to: address, token_id: uint256):
        """Safely transfer a token (checks receiver)."""
        self.transfer_from(from_addr, to, token_id)
        # TODO: Add receiver check for contracts

    @external
    def mint(to: address, token_id: uint256, uri: str):
        """Mint a new token (only owner)."""
        self._only_owner()
        require(to != address(0), "NFT: mint to zero address")
        require(not self._exists(token_id), "NFT: token already minted")

        self.balances[to] = safe_add(self.balances[to], 1)
        self.owners[token_id] = to
        self.token_uris[token_id] = uri
        self.total_supply = safe_add(self.total_supply, 1)

        emit Transfer(address(0), to, token_id)

    @external
    def burn(token_id: uint256):
        """Burn a token."""
        require(
            self._is_approved_or_owner(msg.sender, token_id),
            "NFT: burn caller is not owner nor approved"
        )

        owner: address = self.owner_of(token_id)
        self._approve(address(0), token_id)

        self.balances[owner] -= 1
        self.owners[token_id] = address(0)
        self.token_uris[token_id] = ""

        emit Transfer(owner, address(0), token_id)

    # Internal functions
    def _exists(token_id: uint256) -> bool:
        """Check if a token exists."""
        return self.owners[token_id] != address(0)

    def _is_approved_or_owner(spender: address, token_id: uint256) -> bool:
        """Check if spender is owner or approved for token."""
        require(self._exists(token_id), "NFT: operator query for nonexistent token")
        owner: address = self.owner_of(token_id)
        return (
            spender == owner or
            self.get_approved(token_id) == spender or
            self.is_approved_for_all(owner, spender)
        )

    def _transfer(from_addr: address, to: address, token_id: uint256):
        """Internal transfer function."""
        require(self.owner_of(token_id) == from_addr, "NFT: transfer from incorrect owner")
        require(to != address(0), "NFT: transfer to zero address")

        self._approve(address(0), token_id)

        self.balances[from_addr] -= 1
        self.balances[to] = safe_add(self.balances[to], 1)
        self.owners[token_id] = to

        emit Transfer(from_addr, to, token_id)

    def _approve(to: address, token_id: uint256):
        """Internal approve function."""
        self.token_approvals[token_id] = to
        emit Approval(self.owner_of(token_id), to, token_id)
