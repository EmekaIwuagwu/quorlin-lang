# NFT Marketplace Contract
# Buy, sell, and auction NFTs

contract NFTMarketplace:
    """Decentralized NFT marketplace with auctions."""
    
    struct Listing:
        """NFT listing for sale."""
        seller: address
        nft_contract: address
        token_id: uint256
        price: uint256
        active: bool
    
    struct Auction:
        """NFT auction."""
        seller: address
        nft_contract: address
        token_id: uint256
        starting_price: uint256
        highest_bid: uint256
        highest_bidder: address
        end_time: uint256
        active: bool
    
    listings: mapping[uint256, Listing]
    auctions: mapping[uint256, Auction]
    listing_count: uint256
    auction_count: uint256
    platform_fee_percent: uint256  # In basis points
    owner: address
    
    event Listed:
        listing_id: uint256
        seller: address
        nft_contract: address
        token_id: uint256
        price: uint256
    
    event Sold:
        listing_id: uint256
        buyer: address
        price: uint256
    
    event AuctionCreated:
        auction_id: uint256
        seller: address
        nft_contract: address
        token_id: uint256
        starting_price: uint256
        end_time: uint256
    
    event BidPlaced:
        auction_id: uint256
        bidder: address
        amount: uint256
    
    event AuctionEnded:
        auction_id: uint256
        winner: address
        final_price: uint256
    
    @constructor
    fn __init__(fee_percent: uint256):
        """Initialize marketplace."""
        require(fee_percent <= 1000, "Fee too high")  # Max 10%
        self.listing_count = 0
        self.auction_count = 0
        self.platform_fee_percent = fee_percent
        self.owner = msg.sender
    
    @external
    fn list_nft(nft_contract: address, token_id: uint256, price: uint256) -> uint256:
        """List an NFT for sale."""
        require(price > 0, "Price must be positive")
        
        let listing_id = self.listing_count
        self.listing_count = self.listing_count + 1
        
        self.listings[listing_id] = Listing(
            seller: msg.sender,
            nft_contract: nft_contract,
            token_id: token_id,
            price: price,
            active: true
        )
        
        emit Listed(listing_id, msg.sender, nft_contract, token_id, price)
        
        return listing_id
    
    @external
    @payable
    fn buy_nft(listing_id: uint256):
        """Buy a listed NFT."""
        require(listing_id < self.listing_count, "Invalid listing")
        
        let listing = self.listings[listing_id]
        require(listing.active, "Listing not active")
        require(msg.value >= listing.price, "Insufficient payment")
        
        // Calculate platform fee
        let fee = (listing.price * self.platform_fee_percent) / 10000
        let seller_amount = listing.price - fee
        
        // Transfer payment to seller
        // transfer(listing.seller, seller_amount)
        
        // Transfer NFT to buyer
        // nft_contract.transfer_from(listing.seller, msg.sender, listing.token_id)
        
        // Deactivate listing
        listing.active = false
        self.listings[listing_id] = listing
        
        emit Sold(listing_id, msg.sender, listing.price)
    
    @external
    fn cancel_listing(listing_id: uint256):
        """Cancel an active listing."""
        require(listing_id < self.listing_count, "Invalid listing")
        
        let listing = self.listings[listing_id]
        require(listing.active, "Listing not active")
        require(msg.sender == listing.seller, "Not the seller")
        
        listing.active = false
        self.listings[listing_id] = listing
    
    @external
    fn create_auction(
        nft_contract: address,
        token_id: uint256,
        starting_price: uint256,
        duration: uint256
    ) -> uint256:
        """Create an NFT auction."""
        require(starting_price > 0, "Starting price must be positive")
        require(duration > 0, "Duration must be positive")
        
        let auction_id = self.auction_count
        self.auction_count = self.auction_count + 1
        
        let end_time = block.timestamp + duration
        
        self.auctions[auction_id] = Auction(
            seller: msg.sender,
            nft_contract: nft_contract,
            token_id: token_id,
            starting_price: starting_price,
            highest_bid: 0,
            highest_bidder: address(0),
            end_time: end_time,
            active: true
        )
        
        emit AuctionCreated(auction_id, msg.sender, nft_contract, token_id, starting_price, end_time)
        
        return auction_id
    
    @external
    @payable
    fn place_bid(auction_id: uint256):
        """Place a bid on an auction."""
        require(auction_id < self.auction_count, "Invalid auction")
        
        let auction = self.auctions[auction_id]
        require(auction.active, "Auction not active")
        require(block.timestamp < auction.end_time, "Auction ended")
        
        if auction.highest_bid == 0:
            require(msg.value >= auction.starting_price, "Bid below starting price")
        else:
            require(msg.value > auction.highest_bid, "Bid not high enough")
        
        // Refund previous highest bidder
        if auction.highest_bidder != address(0):
            // transfer(auction.highest_bidder, auction.highest_bid)
            pass
        
        // Update auction
        auction.highest_bid = msg.value
        auction.highest_bidder = msg.sender
        self.auctions[auction_id] = auction
        
        emit BidPlaced(auction_id, msg.sender, msg.value)
    
    @external
    fn end_auction(auction_id: uint256):
        """End an auction and transfer NFT to winner."""
        require(auction_id < self.auction_count, "Invalid auction")
        
        let auction = self.auctions[auction_id]
        require(auction.active, "Auction not active")
        require(block.timestamp >= auction.end_time, "Auction still ongoing")
        
        if auction.highest_bidder != address(0):
            // Calculate platform fee
            let fee = (auction.highest_bid * self.platform_fee_percent) / 10000
            let seller_amount = auction.highest_bid - fee
            
            // Transfer payment to seller
            // transfer(auction.seller, seller_amount)
            
            // Transfer NFT to winner
            // nft_contract.transfer_from(auction.seller, auction.highest_bidder, auction.token_id)
            
            emit AuctionEnded(auction_id, auction.highest_bidder, auction.highest_bid)
        else:
            // No bids, return NFT to seller
            emit AuctionEnded(auction_id, address(0), 0)
        
        // Deactivate auction
        auction.active = false
        self.auctions[auction_id] = auction
    
    @view
    fn get_listing(listing_id: uint256) -> Listing:
        """Get listing details."""
        require(listing_id < self.listing_count, "Invalid listing")
        return self.listings[listing_id]
    
    @view
    fn get_auction(auction_id: uint256) -> Auction:
        """Get auction details."""
        require(auction_id < self.auction_count, "Invalid auction")
        return self.auctions[auction_id]
    
    @external
    fn update_platform_fee(new_fee: uint256):
        """Update platform fee (owner only)."""
        require(msg.sender == self.owner, "Not the owner")
        require(new_fee <= 1000, "Fee too high")
        self.platform_fee_percent = new_fee
