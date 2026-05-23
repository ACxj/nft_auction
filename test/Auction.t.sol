// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/NFT.sol";
import "../src/Auction.sol";
import "../src/PriceOracle.sol";

/**
 * @dev 模拟价格预言机，用于测试
 */
contract MockPriceOracle {
    // ETH 价格（默认 3000 USD）
    int256 public ethPrice = 3000 * 10 ** 8;
    // 代币价格映射
    mapping(address => int256) public tokenPrices;

    /**
     * @dev 设置 ETH 价格
     */
    function setEthPrice(int256 _price) external {
        ethPrice = _price;
    }

    /**
     * @dev 设置代币价格
     */
    function setTokenPrice(address token, int256 _price) external {
        tokenPrices[token] = _price;
    }

    /**
     * @dev 获取 ETH/USD 价格
     */
    function getEthUsdPrice() external view returns (int256) {
        return ethPrice;
    }

    /**
     * @dev 获取代币/USD 价格
     */
    function getTokenUsdPrice(address token) external view returns (int256) {
        return tokenPrices[token];
    }

    /**
     * @dev 将 ETH 转换为 USD
     */
    function convertEthToUsd(uint256 ethAmount) external view returns (uint256) {
        return (ethAmount * uint256(ethPrice)) / (10 ** 18);
    }

    /**
     * @dev 将代币转换为 USD
     */
    function convertTokenToUsd(address token, uint256 tokenAmount) external view returns (uint256) {
        int256 tokenPrice = tokenPrices[token];
        uint256 tokenAmountInEth = (uint256(tokenPrice) * tokenAmount) / (10 ** 8);
        return (tokenAmountInEth * uint256(ethPrice)) / (10 ** 8);
    }

    /**
     * @dev 将 USD 转换为 ETH
     */
    function convertUsdToEth(uint256 usdAmount) external view returns (uint256) {
        return (usdAmount * (10 ** 18)) / uint256(ethPrice);
    }
}

/**
 * @title NFT 测试合约
 * @dev 测试 NFT 合约的基本功能
 */
contract NFTTest is Test {
    NFT public nft;
    Auction public auction;
    MockPriceOracle public priceOracle;
    address public owner;
    address public user1;
    address public user2;

    /**
     * @dev 测试前置设置
     */
    function setUp() public {
        owner = address(this);
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");

        nft = new NFT(owner);
        priceOracle = new MockPriceOracle();
        auction = new Auction();

        auction.initialize(address(priceOracle));
    }

    /**
     * @dev 测试 NFT 铸造功能
     */
    function testNFTMint() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(user1, "ipfs://example.com/1");

        assertEq(nft.ownerOf(tokenId), user1);
        assertEq(nft.tokenURI(tokenId), "ipfs://example.com/1");
    }

    /**
     * @dev 测试 NFT 所有权转移
     */
    function testNFTOwnershipTransfer() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(user1, "ipfs://example.com/1");

        vm.prank(user1);
        nft.transferFrom(user1, user2, tokenId);

        assertEq(nft.ownerOf(tokenId), user2);
    }
}

/**
 * @title 拍卖测试合约
 * @dev 测试拍卖合约的各项功能
 */
contract AuctionTest is Test {
    NFT public nft;
    Auction public auction;
    MockPriceOracle public priceOracle;
    address public owner;
    address public seller;
    address public bidder1;
    address public bidder2;

    /**
     * @dev 测试前置设置
     */
    function setUp() public {
        owner = makeAddr("owner");
        seller = makeAddr("seller");
        bidder1 = makeAddr("bidder1");
        bidder2 = makeAddr("bidder2");

        vm.prank(owner);
        nft = new NFT(owner);

        priceOracle = new MockPriceOracle();
        vm.prank(owner);
        auction = new Auction();
        vm.prank(owner);
        auction.initialize(address(priceOracle));
    }

    /**
     * @dev 测试创建拍卖
     */
    function testCreateAuction() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(seller, "ipfs://example.com/1");

        vm.prank(seller);
        nft.approve(address(auction), tokenId);

        vm.prank(seller);
        uint256 auctionId = auction.createAuction(
            address(nft),
            tokenId,
            1 ether,
            7 days,
            address(0)
        );

        assertEq(nft.ownerOf(tokenId), address(auction));
        Auction.AuctionInfo memory auctionInfo = auction.getAuction(auctionId);
        assertEq(auctionInfo.seller, seller);
        assertEq(auctionInfo.startingPrice, 1 ether);
        assertGt(auctionInfo.endTime, block.timestamp);
    }

    /**
     * @dev 测试出价功能
     */
    function testPlaceBid() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(seller, "ipfs://example.com/1");

        vm.prank(seller);
        nft.approve(address(auction), tokenId);

        vm.prank(seller);
        uint256 auctionId = auction.createAuction(
            address(nft),
            tokenId,
            1 ether,
            7 days,
            address(0)
        );

        vm.deal(bidder1, 10 ether);
        vm.prank(bidder1);
        auction.placeBid{value: 2 ether}(auctionId, 2 ether);

        Auction.AuctionInfo memory auctionInfo2 = auction.getAuction(auctionId);
        assertEq(auctionInfo2.highestBid, 2 ether);
        assertEq(auctionInfo2.highestBidder, bidder1);
    }

    /**
     * @dev 测试结束拍卖
     */
    function testEndAuction() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(seller, "ipfs://example.com/1");

        vm.prank(seller);
        nft.approve(address(auction), tokenId);

        vm.prank(seller);
        uint256 auctionId = auction.createAuction(
            address(nft),
            tokenId,
            1 ether,
            1 days,
            address(0)
        );

        vm.deal(bidder1, 10 ether);
        vm.prank(bidder1);
        auction.placeBid{value: 2 ether}(auctionId, 2 ether);

        vm.warp(block.timestamp + 2 days);

        vm.prank(seller);
        auction.endAuction(auctionId);

        assertEq(nft.ownerOf(tokenId), bidder1);
    }

    /**
     * @dev 测试取消拍卖
     */
    function testCancelAuction() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(seller, "ipfs://example.com/1");

        vm.prank(seller);
        nft.approve(address(auction), tokenId);

        vm.prank(seller);
        uint256 auctionId = auction.createAuction(
            address(nft),
            tokenId,
            1 ether,
            7 days,
            address(0)
        );

        vm.prank(seller);
        auction.cancelAuction(auctionId);

        assertEq(nft.ownerOf(tokenId), seller);
    }

    /**
     * @dev 测试出价过低的情况
     */
    function testBidTooLow() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(seller, "ipfs://example.com/1");

        vm.prank(seller);
        nft.approve(address(auction), tokenId);

        vm.prank(seller);
        uint256 auctionId = auction.createAuction(
            address(nft),
            tokenId,
            5 ether,
            7 days,
            address(0)
        );

        vm.deal(bidder1, 10 ether);
        vm.prank(bidder1);
        vm.expectRevert("Bid too low");
        auction.placeBid{value: 1 ether}(auctionId, 1 ether);
    }

    /**
     * @dev 测试只有卖家可以取消拍卖
     */
    function testOnlySellerCanCancel() public {
        vm.prank(owner);
        uint256 tokenId = nft.mint(seller, "ipfs://example.com/1");

        vm.prank(seller);
        nft.approve(address(auction), tokenId);

        vm.prank(seller);
        uint256 auctionId = auction.createAuction(
            address(nft),
            tokenId,
            1 ether,
            7 days,
            address(0)
        );

        vm.prank(bidder1);
        vm.expectRevert("Only seller can cancel");
        auction.cancelAuction(auctionId);
    }
}
