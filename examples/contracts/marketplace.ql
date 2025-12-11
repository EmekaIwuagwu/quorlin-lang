# marketplace.ql — NFT Marketplace Contract
# Buy, sell, and auction NFTs with royalty support

from std.math import safe_add, safe_sub, safe_mul, safe_div
from std.time import block_timestamp, add_days
from std.log import require_not_zero_address

# Structs
struct Listing:
    listing_id: uint256
    seller: address
    nft_contract: address
    token_id: uint256
    price: uint256
    active: bool
    created_at: uint64

struct Auction:
    auction_id: uint256
    seller: address
    nft_contract: address
    token_id: uint256
    start_price: uint256
    reserve_price: uint256
    current_bid: uint256
    highest_bidder: address
    start_time: uint64
    end_time: uint64
    ended: bool
    auction_type: AuctionType

struct Offer:
    offer_id: uint256
    offerer: address
    nft_contract: address
    token_id: uint256
    price: uint256
    expiration: uint64
    accepted: bool
    canceled: bool

enum AuctionType:
    English  # Ascending price
    Dutch    # Descending price

# Events
event Listed(
    listing_id: uint256,
    seller: address,
    nft_contract: address,
    token_id: uint256,
    price: uint256
)
event ListingCanceled(listing_id: uint256)
event Sold(
    listing_id: uint256,
    buyer: address,
    nft_contract: address,
    token_id: uint256,
    price: uint256
)
event AuctionCreated(
    auction_id: uint256,
    seller: address,
    nft_contract: address,
    token_id: uint256,
    start_price: uint256,
    end_time: uint64
)
event BidPlaced(auction_id: uint256, bidder: address, amount: uint256)
event AuctionEnded(auction_id: uint256, winner: address, amount: uint256)
event OfferMade(
    offer_id: uint256,
    offerer: address,
    nft_contract: address,
    token_id: uint256,
    price: uint256
)
event OfferAccepted(offer_id: uint256)
event OfferCanceled(offer_id: uint256)
event PlatformFeeUpdated(old_fee: uint256, new_fee: uint256)

contract NFTMarketplace:
    """
    NFT marketplace with fixed-price listings and auctions.
    
    Features:
    - Fixed-price listings
    - English auctions (highest bidder wins)
    - Dutch auctions (descending price)
    - Royalty support (EIP-2981)
    - Platform fees
    - Offer system
    - Bundle sales
    - Cross-chain compatible
    """
    
    # State variables
    _owner: address
    _platform_fee: uint256  # Basis points (e.g., 250 = 2.5%)
    _fee_recipient: address
    
    # Listings
    _listing_count: uint256
    _listings: mapping[uint256, Listing]
    _nft_to_listing: mapping[address, mapping[uint256, uint256]]  # NFT contract -> token ID -> listing ID
    
    # Auctions
    _auction_count: uint256
    _auctions: mapping[uint256, Auction]
    _nft_to_auction: mapping[address, mapping[uint256, uint256]]
    
    # Offers
    _offer_count: uint256
    _offers: mapping[uint256, Offer]
    _nft_offers: mapping[address, mapping[uint256, list[uint256]]]  # NFT -> offer IDs
    
    @constructor
    fn __init__(platform_fee: uint256):
        """
        Initialize the marketplace.
        
        Args:
            platform_fee: Platform fee in basis points (e.g., 250 = 2.5%)
        """
        require(platform_fee <= 1000, "Fee too high")  # Max 10%
        
        self._owner = msg.sender
        self._platform_fee = platform_fee
        self._fee_recipient = msg.sender
        self._listing_count = 0
        self._auction_count = 0
        self._offer_count = 0
    
    # ========== View Functions ==========
    
    @view
    fn get_listing(listing_id: uint256) -> Listing:
        """Returns listing details."""
        require(listing_id < self._listing_count, "Listing does not exist")
        return self._listings[listing_id]
    
    @view
    fn get_auction(auction_id: uint256) -> Auction:
        """Returns auction details."""
        require(auction_id < self._auction_count, "Auction does not exist")
        return self._auctions[auction_id]
    
    @view
    fn get_offer(offer_id: uint256) -> Offer:
        """Returns offer details."""
        require(offer_id < self._offer_count, "Offer does not exist")
        return self._offers[offer_id]
    
    @view
    fn calculate_fees(price: uint256) -> (uint256, uint256):
        """
        Calculates platform fee and seller proceeds.
        
        Args:
            price: Sale price
        
        Returns:
            Tuple of (platform_fee, seller_proceeds)
        """
        platform_fee: uint256 = safe_div(safe_mul(price, self._platform_fee), 10000)
        seller_proceeds: uint256 = safe_sub(price, platform_fee)
        return (platform_fee, seller_proceeds)
    
    @view
    fn get_current_dutch_price(auction_id: uint256) -> uint256:
        """
        Calculates current price for Dutch auction.
        
        Args:
            auction_id: Auction ID
        
        Returns:
            Current price
        """
        auction: Auction = self._auctions[auction_id]
        require(auction.auction_type == AuctionType.Dutch, "Not a Dutch auction")
        
        if block_timestamp() >= auction.end_time:
            return auction.reserve_price
        
        time_elapsed: uint64 = block_timestamp() - auction.start_time
        total_duration: uint64 = auction.end_time - auction.start_time
        
        price_drop: uint256 = safe_sub(auction.start_price, auction.reserve_price)
        current_drop: uint256 = safe_div(
            safe_mul(price_drop, time_elapsed),
            total_duration
        )
        
        return safe_sub(auction.start_price, current_drop)
    
    # ========== Listing Functions ==========
    
    @external
    fn create_listing(nft_contract: address, token_id: uint256, price: uint256) -> uint256:
        """
        Creates a fixed-price listing.
        
        Args:
            nft_contract: NFT contract address
            token_id: Token ID
            price: Sale price
        
        Returns:
            Listing ID
        """
        require_not_zero_address(nft_contract, "Invalid NFT contract")
        require(price > 0, "Price must be positive")
        require(
            self._nft_owner_of(nft_contract, token_id) == msg.sender,
            "Not token owner"
        )
        require(
            self._nft_to_listing[nft_contract][token_id] == 0,
            "Already listed"
        )
        
        listing_id: uint256 = self._listing_count
        self._listing_count = safe_add(self._listing_count, 1)
        
        self._listings[listing_id] = Listing(
            listing_id=listing_id,
            seller=msg.sender,
            nft_contract=nft_contract,
            token_id=token_id,
            price=price,
            active=True,
            created_at=block_timestamp()
        )
        
        self._nft_to_listing[nft_contract][token_id] = listing_id
        
        emit Listed(listing_id, msg.sender, nft_contract, token_id, price)
        
        return listing_id
    
    @external
    fn cancel_listing(listing_id: uint256):
        """
        Cancels a listing.
        
        Args:
            listing_id: Listing ID
        """
        listing: Listing = self._listings[listing_id]
        require(listing.active, "Listing not active")
        require(listing.seller == msg.sender, "Not seller")
        
        listing.active = False
        self._listings[listing_id] = listing
        
        self._nft_to_listing[listing.nft_contract][listing.token_id] = 0
        
        emit ListingCanceled(listing_id)
    
    @external
    @payable
    fn buy(listing_id: uint256):
        """
        Purchases an NFT from a listing.
        
        Args:
            listing_id: Listing ID
        """
        listing: Listing = self._listings[listing_id]
        require(listing.active, "Listing not active")
        require(msg.value >= listing.price, "Insufficient payment")
        
        # Calculate fees
        platform_fee: uint256
        seller_proceeds: uint256
        (platform_fee, seller_proceeds) = self.calculate_fees(listing.price)
        
        # Get royalty info if supported
        royalty_recipient: address
        royalty_amount: uint256
        (royalty_recipient, royalty_amount) = self._get_royalty_info(
            listing.nft_contract,
            listing.token_id,
            listing.price
        )
        
        # Deactivate listing
        listing.active = False
        self._listings[listing_id] = listing
        self._nft_to_listing[listing.nft_contract][listing.token_id] = 0
        
        # Transfer NFT to buyer
        self._nft_transfer_from(
            listing.nft_contract,
            listing.seller,
            msg.sender,
            listing.token_id
        )
        
        # Distribute payments
        if royalty_amount > 0 and royalty_recipient != address(0):
            seller_proceeds = safe_sub(seller_proceeds, royalty_amount)
            self._transfer_eth(royalty_recipient, royalty_amount)
        
        self._transfer_eth(listing.seller, seller_proceeds)
        self._transfer_eth(self._fee_recipient, platform_fee)
        
        # Refund excess payment
        if msg.value > listing.price:
            self._transfer_eth(msg.sender, safe_sub(msg.value, listing.price))
        
        emit Sold(listing_id, msg.sender, listing.nft_contract, listing.token_id, listing.price)
    
    # ========== Auction Functions ==========
    
    @external
    fn create_auction(
        nft_contract: address,
        token_id: uint256,
        start_price: uint256,
        reserve_price: uint256,
        duration_days: uint64,
        auction_type: AuctionType
    ) -> uint256:
        """
        Creates an auction.
        
        Args:
            nft_contract: NFT contract address
            token_id: Token ID
            start_price: Starting price
            reserve_price: Reserve/minimum price
            duration_days: Auction duration in days
            auction_type: English or Dutch
        
        Returns:
            Auction ID
        """
        require_not_zero_address(nft_contract, "Invalid NFT contract")
        require(start_price > 0, "Invalid start price")
        require(
            self._nft_owner_of(nft_contract, token_id) == msg.sender,
            "Not token owner"
        )
        
        if auction_type == AuctionType.English:
            require(reserve_price >= start_price, "Reserve must be >= start price")
        else:
            require(reserve_price <= start_price, "Reserve must be <= start price")
        
        auction_id: uint256 = self._auction_count
        self._auction_count = safe_add(self._auction_count, 1)
        
        start_time: uint64 = block_timestamp()
        end_time: uint64 = add_days(start_time, duration_days)
        
        self._auctions[auction_id] = Auction(
            auction_id=auction_id,
            seller=msg.sender,
            nft_contract=nft_contract,
            token_id=token_id,
            start_price=start_price,
            reserve_price=reserve_price,
            current_bid=0,
            highest_bidder=address(0),
            start_time=start_time,
            end_time=end_time,
            ended=False,
            auction_type=auction_type
        )
        
        self._nft_to_auction[nft_contract][token_id] = auction_id
        
        emit AuctionCreated(auction_id, msg.sender, nft_contract, token_id, start_price, end_time)
        
        return auction_id
    
    @external
    @payable
    fn bid(auction_id: uint256):
        """
        Places a bid on an English auction.
        
        Args:
            auction_id: Auction ID
        """
        auction: Auction = self._auctions[auction_id]
        require(not auction.ended, "Auction ended")
        require(auction.auction_type == AuctionType.English, "Not an English auction")
        require(block_timestamp() < auction.end_time, "Auction expired")
        require(msg.value > auction.current_bid, "Bid too low")
        require(msg.value >= auction.start_price, "Bid below start price")
        
        # Refund previous bidder
        if auction.highest_bidder != address(0):
            self._transfer_eth(auction.highest_bidder, auction.current_bid)
        
        # Update auction
        auction.current_bid = msg.value
        auction.highest_bidder = msg.sender
        self._auctions[auction_id] = auction
        
        emit BidPlaced(auction_id, msg.sender, msg.value)
    
    @external
    @payable
    fn buy_dutch_auction(auction_id: uint256):
        """
        Buys from a Dutch auction at current price.
        
        Args:
            auction_id: Auction ID
        """
        auction: Auction = self._auctions[auction_id]
        require(not auction.ended, "Auction ended")
        require(auction.auction_type == AuctionType.Dutch, "Not a Dutch auction")
        require(block_timestamp() < auction.end_time, "Auction expired")
        
        current_price: uint256 = self.get_current_dutch_price(auction_id)
        require(msg.value >= current_price, "Insufficient payment")
        
        # End auction
        auction.ended = True
        auction.current_bid = current_price
        auction.highest_bidder = msg.sender
        self._auctions[auction_id] = auction
        
        # Process sale
        self._finalize_auction(auction_id)
        
        # Refund excess
        if msg.value > current_price:
            self._transfer_eth(msg.sender, safe_sub(msg.value, current_price))
    
    @external
    fn end_auction(auction_id: uint256):
        """
        Ends an auction and transfers NFT to winner.
        
        Args:
            auction_id: Auction ID
        """
        auction: Auction = self._auctions[auction_id]
        require(not auction.ended, "Auction already ended")
        require(block_timestamp() >= auction.end_time, "Auction not yet ended")
        
        auction.ended = True
        self._auctions[auction_id] = auction
        
        if auction.current_bid >= auction.reserve_price:
            self._finalize_auction(auction_id)
        else:
            # Reserve not met - refund bidder
            if auction.highest_bidder != address(0):
                self._transfer_eth(auction.highest_bidder, auction.current_bid)
            
            emit AuctionEnded(auction_id, address(0), 0)
        
        self._nft_to_auction[auction.nft_contract][auction.token_id] = 0
    
    # ========== Offer Functions ==========
    
    @external
    @payable
    fn make_offer(nft_contract: address, token_id: uint256, expiration_days: uint64) -> uint256:
        """
        Makes an offer on an NFT.
        
        Args:
            nft_contract: NFT contract address
            token_id: Token ID
            expiration_days: Offer expiration in days
        
        Returns:
            Offer ID
        """
        require_not_zero_address(nft_contract, "Invalid NFT contract")
        require(msg.value > 0, "Offer must be positive")
        
        offer_id: uint256 = self._offer_count
        self._offer_count = safe_add(self._offer_count, 1)
        
        expiration: uint64 = add_days(block_timestamp(), expiration_days)
        
        self._offers[offer_id] = Offer(
            offer_id=offer_id,
            offerer=msg.sender,
            nft_contract=nft_contract,
            token_id=token_id,
            price=msg.value,
            expiration=expiration,
            accepted=False,
            canceled=False
        )
        
        self._nft_offers[nft_contract][token_id].push(offer_id)
        
        emit OfferMade(offer_id, msg.sender, nft_contract, token_id, msg.value)
        
        return offer_id
    
    @external
    fn accept_offer(offer_id: uint256):
        """
        Accepts an offer (NFT owner only).
        
        Args:
            offer_id: Offer ID
        """
        offer: Offer = self._offers[offer_id]
        require(not offer.accepted and not offer.canceled, "Offer not available")
        require(block_timestamp() < offer.expiration, "Offer expired")
        require(
            self._nft_owner_of(offer.nft_contract, offer.token_id) == msg.sender,
            "Not token owner"
        )
        
        offer.accepted = True
        self._offers[offer_id] = offer
        
        # Calculate fees
        platform_fee: uint256
        seller_proceeds: uint256
        (platform_fee, seller_proceeds) = self.calculate_fees(offer.price)
        
        # Transfer NFT
        self._nft_transfer_from(offer.nft_contract, msg.sender, offer.offerer, offer.token_id)
        
        # Distribute payment
        self._transfer_eth(msg.sender, seller_proceeds)
        self._transfer_eth(self._fee_recipient, platform_fee)
        
        emit OfferAccepted(offer_id)
    
    @external
    fn cancel_offer(offer_id: uint256):
        """
        Cancels an offer (offerer only).
        
        Args:
            offer_id: Offer ID
        """
        offer: Offer = self._offers[offer_id]
        require(offer.offerer == msg.sender, "Not offerer")
        require(not offer.accepted and not offer.canceled, "Offer not available")
        
        offer.canceled = True
        self._offers[offer_id] = offer
        
        # Refund offer amount
        self._transfer_eth(msg.sender, offer.price)
        
        emit OfferCanceled(offer_id)
    
    # ========== Admin Functions ==========
    
    @external
    fn set_platform_fee(new_fee: uint256):
        """Updates platform fee (owner only)."""
        self._only_owner()
        require(new_fee <= 1000, "Fee too high")
        
        old_fee: uint256 = self._platform_fee
        self._platform_fee = new_fee
        
        emit PlatformFeeUpdated(old_fee, new_fee)
    
    @external
    fn set_fee_recipient(new_recipient: address):
        """Updates fee recipient (owner only)."""
        self._only_owner()
        require_not_zero_address(new_recipient, "Invalid recipient")
        self._fee_recipient = new_recipient
    
    # ========== Internal Functions ==========
    
    fn _finalize_auction(auction_id: uint256):
        """Finalizes auction and distributes payments."""
        auction: Auction = self._auctions[auction_id]
        
        # Calculate fees
        platform_fee: uint256
        seller_proceeds: uint256
        (platform_fee, seller_proceeds) = self.calculate_fees(auction.current_bid)
        
        # Transfer NFT to winner
        self._nft_transfer_from(
            auction.nft_contract,
            auction.seller,
            auction.highest_bidder,
            auction.token_id
        )
        
        # Distribute payment
        self._transfer_eth(auction.seller, seller_proceeds)
        self._transfer_eth(self._fee_recipient, platform_fee)
        
        emit AuctionEnded(auction_id, auction.highest_bidder, auction.current_bid)
    
    fn _only_owner():
        """Modifier: requires caller to be owner."""
        require(msg.sender == self._owner, "Caller is not the owner")
    
    # Compiler intrinsics
    fn _nft_owner_of(nft_contract: address, token_id: uint256) -> address:
        """Returns NFT owner."""
        pass
    
    fn _nft_transfer_from(nft_contract: address, from_addr: address, to: address, token_id: uint256):
        """Transfers NFT."""
        pass
    
    fn _get_royalty_info(nft_contract: address, token_id: uint256, sale_price: uint256) -> (address, uint256):
        """Gets royalty info (EIP-2981)."""
        pass
    
    fn _transfer_eth(to: address, amount: uint256):
        """Transfers ETH."""
        pass
