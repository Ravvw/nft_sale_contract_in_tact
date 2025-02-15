import "@stdlib/ownable";
import "@stdlib/deploy";

struct SaleData {
    is_complete: Bool;
    created_at: Int;
    marketplace_address: Address;
    nft_address: Address;
    nft_owner_address: Address;
    full_price: Int as coins;
    fee_address: Address;
    marketplace_fee: Int;
    royalty_address: Address;
    royalty_amount: Int;
    sold_at: Int as uint32;
    query_id: Int as uint64;
}

message(0x05138d91) NFTOwnershipAssigned {
    queryId: Int as uint64;
    previousOwner:Address;
    forwardPayload:Slice as remaining;
}

message(0x3) Cancel {}

message(0xfd135f7b) ChangePrice {
    new_price: Int as coins;
}

message(0x5fcc3d14) NFTTransfer {
    queryId: Int as uint64;
    newOwner: Address;
    responseDestination: Address;
    customPayload: Cell? = null;
    forwardAmount: Int as coins;
    forwardPayload: Slice as remaining;
}

contract NftFixpriceSaleV1 with Deployable {
    is_complete: Bool;
    marketplace_address: Address;
    nft_owner_address: Address;
    full_price: Int as coins;
    sold_at: Int as uint32;
    query_id: Int as uint64;
    marketplace_fee_address: Address;
    royalty_address: Address;
    fee_percent: Int as uint17;  // 50 = 5%
    royalty_percent: Int as uint17;  // 50 = 5%
    nft_address: Address;
    created_at: Int as uint64;

    active: Bool = false;

    init(
        is_complete: Bool,
        created_at: Int,
        marketplace_address: Address,
        nft_address: Address,
        nft_owner_address: Address,
        full_price: Int,
        marketplace_fee_address: Address,
        royalty_address: Address,
        royalty_percent: Int,
        fee_percent: Int,
        sold_at: Int,
        query_id: Int
    ) {
        self.is_complete = is_complete;
        self.created_at = created_at;
        self.marketplace_address = marketplace_address;
        self.nft_owner_address = nft_owner_address;
        self.full_price = full_price;
        self.marketplace_fee_address = marketplace_fee_address;
        self.royalty_address = royalty_address;
        self.nft_address = nft_address;
        self.royalty_percent = royalty_percent;
        self.fee_percent = fee_percent;
        self.sold_at = sold_at;
        self.query_id = query_id;
    }


    // buy NFT
    receive() {
        let ctx: Context = context();
        require(self.active == true, "Not active");
        require(ctx.bounced == false, "Bounce error");
        require(ctx.value >= self.full_price + ton("1"), "not enough funds");
        require(myBalance() >= self.full_price + ton("1"), "Balance error");
        require(self.is_complete == false, "Sale ended");
        
        self.active = false;
        self.is_complete = true;
        self.sold_at = now();
        
        let royalty: Int = self.full_price / 1000 * self.royalty_percent;
        let market_fee: Int = self.full_price / 1000 * self.fee_percent;

        // ton transfer to nft previous owner
        send(SendParameters{
            to: self.nft_owner_address,
            value: self.full_price - royalty - market_fee,
            mode: SendIgnoreErrors,
            bounce: false
        });

        // nft transfer to nft new owner
        send(SendParameters{
            to: self.nft_address,
            value: 0,
            mode: ton("0.1"),
            body: NFTTransfer{
                queryId: 0,
                // FIXME: Change this according to your needs
                newOwner: sender(),
                responseDestination: sender(),
                customPayload: null,
                forwardAmount: 1,
                forwardPayload: rawSlice("F"), // precomputed beginCell().storeUint(0xF, 4).endCell().beginParse()
            }.toCell(),
        });

        // send royalty
        send(SendParameters{
            to: self.nft_owner_address,
            value: royalty,
            mode: SendIgnoreErrors,
            bounce: false
        });

        // send market_fee
        send(SendParameters{
            to: self.nft_owner_address,
            value: market_fee,
            mode: SendIgnoreErrors,
            bounce: false
        });

        // excess
        send(SendParameters{
            to: sender(), 
            value: 0, 
            mode: SendRemainingValue, 
            bounce: false
        });
    }

    // change price
    receive(msg: ChangePrice) {
        require(self.active == true, "Not active");
        require(sender() == self.nft_owner_address, "Not owner");
        require(msg.new_price > 0, "Price error");
        self.full_price = msg.new_price;
    }

    // cancel sale
    receive(msg: Cancel) {
        require(self.active == true, "Not active");
        require(sender() == self.nft_owner_address, "Not owner");
        self.active = false;
        send(SendParameters{
            to: self.nft_address,
            value: 0,
            mode: SendRemainingBalance,
            body: NFTTransfer{
                queryId: 0,
                // FIXME: Change this according to your needs
                newOwner: self.nft_owner_address,
                responseDestination: self.nft_owner_address,
                customPayload: null,
                forwardAmount: 1,
                forwardPayload: rawSlice("F"), // precomputed beginCell().storeUint(0xF, 4).endCell().beginParse()
            }.toCell(),
        });
    }

    // check nft and start sale
    receive(msg: NFTOwnershipAssigned) {
        require(self.nft_address == sender(), "NFT contract is not the sender");
        self.active = true;
    }
    
    // get sale data
    get fun get_fix_price_data(): SaleData {
        return SaleData {
            is_complete: self.is_complete,
            created_at: self.created_at,
            marketplace_address: self.marketplace_address,
            nft_address: self.nft_address,
            nft_owner_address: self.nft_owner_address,
            full_price: self.full_price,
            fee_address: self.marketplace_fee_address,
            marketplace_fee: self.full_price / 1000 * self.fee_percent,
            royalty_address: self.royalty_address,
            royalty_amount: self.full_price / 1000 * self.royalty_percent,
            sold_at: self.sold_at,
            query_id: self.query_id
        }
    }
}