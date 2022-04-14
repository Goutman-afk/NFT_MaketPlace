// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract ShopTrade {
    using Counters for Counters.Counter;
    Counters.Counter private _itemCounter;
    Counters.Counter private _itemSoldCounter;
    enum State {
        Sold,
        Release,
        Inactive
    }
    mapping(uint256 => MarketItem) public marketItems;
    struct MarketItem {
        uint256 id;
        address nftContract;
        uint256 tokenId;
        address payable seller;
        address payable buyer;
        uint256 price;
        State state;
    }
    uint256 public listingFee = 0.025 ether;

    function getListingFee() public view returns (uint256) {
        return listingFee;
    }

    function createMarketItem(
        uint256 price,
        address contractsAddr,
        uint256 tokenId
    ) public {
        require(price > 0, "Price must be at least 1 wei");
        
        ERC721 Token = ERC721(contractsAddr);
        require(Token.balanceOf(msg.sender) > 0, "caller must have the token");
        require(
            Token.isApprovedForAll(msg.sender, address(this)),
            "contract must be approved"
        );
        _itemCounter.increment();
        uint256 id = _itemCounter.current();
        Token.transferFrom(msg.sender, address(this), tokenId);
        marketItems[id] = MarketItem(
            id,
            contractsAddr,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            price,
            State.Release
        );
    }

    function returnNFT(uint256 itemId) public {
        
        require(itemId <= _itemCounter.current(), "non existing item");
        require(
            marketItems[itemId].state == State.Release,
            "item must be on market"
        );
        MarketItem storage item = marketItems[itemId];
        ERC721 Token = ERC721(item.nftContract);
        require(
            item.seller == msg.sender,
            "must be the owner"
        );
        
        Token.safeTransferFrom(address(this), msg.sender, item.tokenId);

        item.state = State.Inactive;
    }

    function purchasItem(uint256 itemId, address gold) public {
        MarketItem storage item = marketItems[itemId];
        ERC20 buyer = ERC20(gold);
        ERC721 Token = ERC721(item.nftContract);
        buyer.transferFrom(msg.sender, item.seller, item.price);
        Token.safeTransferFrom(address(this), msg.sender, item.tokenId);
        item.state = State.Sold;
        item.buyer = payable(msg.sender);
    }

    enum FetchOperator {
        ActiveItems,
        MyPurchasedItems,
        UnactiveItems
    }

    function fetchHepler(FetchOperator _op)
        private
        view
        returns (MarketItem[] memory)
    {
        uint256 total = _itemCounter.current();

        uint256 itemCount = 0;
        for (uint256 i = 1; i <= total; i++) {
            if (isCondition(marketItems[i], _op)) {
                itemCount++;
            }
        }

        uint256 index = 0;
        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 1; i <= total; i++) {
            if (isCondition(marketItems[i], _op)) {
                items[index] = marketItems[i];
                index++;
            }
        }
        return items;
    }

    function isCondition(MarketItem memory item, FetchOperator _op)
        private
        view
        returns (bool)
    {
        if (_op == FetchOperator.UnactiveItems) {
            return
                (item.seller == msg.sender && item.state != State.Inactive)
                    ? true
                    : false;
        } else if (_op == FetchOperator.MyPurchasedItems) {
            return (item.buyer == msg.sender) ? true : false;
        } else if (_op == FetchOperator.ActiveItems) {
            return
                (item.buyer == address(0) &&
                    item.state == State.Release)
                    ? true
                    : false;
        } else {
            return false;
        }
    }

    function fetchActiveItems() public view returns (MarketItem[] memory) {
        return fetchHepler(FetchOperator.ActiveItems);
    }

    function fetchMyPurchasedItems() public view returns (MarketItem[] memory) {
        return fetchHepler(FetchOperator.MyPurchasedItems);
    }
}
