// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./PriceOracle.sol";

/**
 * @title Auction
 * @dev NFT 拍卖市场核心合约，支持创建拍卖、出价、结束拍卖等功能
 * @notice 支持 ETH 和 ERC20 代币出价，使用 Chainlink 预言机进行美元换算
 */
contract Auction is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /**
     * @dev 拍卖信息结构体
     */
    struct AuctionInfo {
        address nftContract;      // NFT 合约地址
        uint256 tokenId;          // NFT 的 tokenId
        address seller;           // 卖家地址
        uint256 startingPrice;    // 起始价格
        uint256 highestBid;       // 最高出价
        address highestBidder;    // 最高出价者
        uint256 endTime;          // 拍卖结束时间
        bool ended;               // 拍卖是否已结束
        address acceptedToken;    // 接受的代币地址（address(0) 表示 ETH）
    }

    // 平台手续费比例：2.5%
    uint256 public constant PLATFORM_FEE_PERCENT = 250;
    // 手续费计算的分母
    uint256 public constant FEE_DENOMINATOR = 10000;

    // Chainlink 价格预言机合约
    PriceOracle public priceOracle;
    // 拍卖 ID 到拍卖信息的映射
    mapping(uint256 => AuctionInfo) public auctions;
    // 用户地址到其参与的拍卖 ID 数组的映射
    mapping(address => uint256[]) public userBids;
    // (拍卖 ID, 用户地址) 到用户出价金额的映射
    mapping(uint256 => mapping(address => uint256)) public bidAmounts;
    // 拍卖 ID 计数器
    uint256 private _auctionIdCounter;

    // 拍卖创建事件
    event AuctionCreated(
        uint256 auctionId,
        address nftContract,
        uint256 tokenId,
        address seller,
        uint256 startingPrice,
        uint256 endTime,
        address acceptedToken
    );
    // 出价事件
    event BidPlaced(uint256 auctionId, address bidder, uint256 amount, address token, uint256 amountInUsd);
    // 拍卖结束事件
    event AuctionEnded(uint256 auctionId, address winner, uint256 winningBid, address token);
    // 拍卖取消事件
    event AuctionCanceled(uint256 auctionId);
    // 提款完成事件
    event WithdrawCompleted(address user, uint256 amount);

    // 拍卖不存在错误
    error AuctionNotFound();
    // 拍卖已结束错误
    error AuctionHasEnded();
    // 拍卖未结束错误
    error AuctionNotEnded();
    // 出价过低错误
    error BidTooLow();
    // 非卖家操作错误
    error OnlySeller();
    // 转账失败错误
    error TransferFailed();
    // 无效价格错误
    error InvalidPrice();
    // 拍卖仍在进行错误
    error AuctionStillActive();

    /**
     * @dev 修饰符：确保拍卖处于活跃状态
     */
    modifier onlyActiveAuction(uint256 auctionId) {
        require(!auctions[auctionId].ended, "Auction already ended");
        require(block.timestamp < auctions[auctionId].endTime, "Auction time expired");
        _;
    }

    /**
     * @dev 初始化函数
     * @param _priceOracle 价格预言机合约地址
     */
    function initialize(address _priceOracle) initializer public {
        __Ownable_init(msg.sender);
        priceOracle = PriceOracle(_priceOracle);
    }

    /**
     * @dev UUPS 升级授权检查，仅所有者可以升级
     * @param newImplementation 新实现合约地址
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    /**
     * @dev 创建新的拍卖
     * @param nftContract NFT 合约地址
     * @param tokenId NFT 的 tokenId
     * @param startingPrice 起始价格
     * @param duration 拍卖持续时间（秒）
     * @param acceptedToken 接受的代币地址（address(0) 表示 ETH）
     * @return 新创建的拍卖 ID
     */
    function createAuction(
        address nftContract,
        uint256 tokenId,
        uint256 startingPrice,
        uint256 duration,
        address acceptedToken
    ) external nonReentrant returns (uint256) {
        require(startingPrice > 0, "Invalid price");

        // 将 NFT 从卖家转移到拍卖合约
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);

        // 创建新拍卖
        uint256 auctionId = _auctionIdCounter++;
        auctions[auctionId] = AuctionInfo({
            nftContract: nftContract,
            tokenId: tokenId,
            seller: msg.sender,
            startingPrice: startingPrice,
            highestBid: 0,
            highestBidder: address(0),
            endTime: block.timestamp + duration,
            ended: false,
            acceptedToken: acceptedToken
        });

        emit AuctionCreated(
            auctionId,
            nftContract,
            tokenId,
            msg.sender,
            startingPrice,
            block.timestamp + duration,
            acceptedToken
        );

        return auctionId;
    }

    /**
     * @dev 在拍卖中出价
     * @param auctionId 拍卖 ID
     * @param bidAmount 出价金额
     */
    function placeBid(uint256 auctionId, uint256 bidAmount) external payable nonReentrant onlyActiveAuction(auctionId) {
        AuctionInfo storage auction = auctions[auctionId];
        require(auction.highestBidder != msg.sender, "Already the highest bidder");

        // 计算总出价金额（加上之前的出价）
        uint256 totalBid = bidAmount;
        if (auction.highestBid > 0 && auction.highestBidder != address(0)) {
            totalBid += auction.highestBid;
        }

        require(totalBid >= auction.startingPrice, "Bid too low");

        // 根据接受的代币类型处理转账
        if (auction.acceptedToken == address(0)) {
            // 接受 ETH
            require(msg.value >= bidAmount, "Insufficient ETH sent");
        } else {
            // 接受 ERC20 代币
            IERC20(auction.acceptedToken).safeTransferFrom(msg.sender, address(this), bidAmount);
        }

        // 退还之前的最高出价
        if (auction.highestBidder != address(0) && auction.highestBid > 0) {
            address previousBidder = auction.highestBidder;
            uint256 previousBid = auction.highestBid;
            if (auction.acceptedToken == address(0)) {
                payable(previousBidder).transfer(previousBid);
            } else {
                IERC20(auction.acceptedToken).safeTransfer(previousBidder, previousBid);
            }
        }

        // 更新最高出价信息
        auction.highestBid = bidAmount;
        auction.highestBidder = msg.sender;

        // 计算出价的 USD 价值
        uint256 amountInUsd = auction.acceptedToken == address(0)
            ? priceOracle.convertEthToUsd(bidAmount)
            : priceOracle.convertTokenToUsd(auction.acceptedToken, bidAmount);

        emit BidPlaced(auctionId, msg.sender, bidAmount, auction.acceptedToken, amountInUsd);
    }

    /**
     * @dev 结束拍卖
     * @param auctionId 拍卖 ID
     */
    function endAuction(uint256 auctionId) external nonReentrant {
        AuctionInfo storage auction = auctions[auctionId];
        require(msg.sender == auction.seller || block.timestamp >= auction.endTime, "Auction still active");
        require(!auction.ended, "Auction already ended");

        auction.ended = true;

        // 如果没有出价者，将 NFT 退回给卖家
        if (auction.highestBidder == address(0)) {
            IERC721(auction.nftContract).transferFrom(address(this), auction.seller, auction.tokenId);
            emit AuctionCanceled(auctionId);
            return;
        }

        // 计算平台手续费和卖家收入
        uint256 platformFee = (auction.highestBid * PLATFORM_FEE_PERCENT) / FEE_DENOMINATOR;
        uint256 sellerProceeds = auction.highestBid - platformFee;

        // 将收入转给卖家
        if (auction.acceptedToken == address(0)) {
            payable(auction.seller).transfer(sellerProceeds);
        } else {
            IERC20(auction.acceptedToken).safeTransfer(auction.seller, sellerProceeds);
        }

        // 将 NFT 转给最高出价者
        IERC721(auction.nftContract).transferFrom(address(this), auction.highestBidder, auction.tokenId);

        emit AuctionEnded(auctionId, auction.highestBidder, auction.highestBid, auction.acceptedToken);
    }

    /**
     * @dev 取消拍卖（仅在无出价时可用）
     * @param auctionId 拍卖 ID
     */
    function cancelAuction(uint256 auctionId) external nonReentrant {
        AuctionInfo storage auction = auctions[auctionId];
        require(msg.sender == auction.seller, "Only seller can cancel");
        require(!auction.ended, "Auction already ended");
        require(auction.highestBid == 0, "Cannot cancel with existing bids");

        auction.ended = true;
        IERC721(auction.nftContract).transferFrom(address(this), auction.seller, auction.tokenId);
        emit AuctionCanceled(auctionId);
    }

    /**
     * @dev 获取拍卖详情
     * @param auctionId 拍卖 ID
     * @return 拍卖信息
     */
    function getAuction(uint256 auctionId) external view returns (AuctionInfo memory) {
        return auctions[auctionId];
    }

    /**
     * @dev 获取拍卖最高出价的 USD 价值
     * @param auctionId 拍卖 ID
     * @return USD 价值
     */
    function getBidInUsd(uint256 auctionId) external view returns (uint256) {
        AuctionInfo storage auction = auctions[auctionId];
        if (auction.highestBid == 0) return 0;
        if (auction.acceptedToken == address(0)) {
            return priceOracle.convertEthToUsd(auction.highestBid);
        } else {
            return priceOracle.convertTokenToUsd(auction.acceptedToken, auction.highestBid);
        }
    }

    /**
     * @dev 提现功能（用于未获胜的出价者取回资金）
     */
    function withdraw() external nonReentrant {
        uint256 totalBids = 0;
        // 遍历用户参与的所有拍卖
        for (uint256 i = 0; i < userBids[msg.sender].length; i++) {
            uint256 auctionId = userBids[msg.sender][i];
            // 只统计已结束且用户未获胜的拍卖
            if (auctions[auctionId].ended && auctions[auctionId].highestBidder != msg.sender) {
                totalBids += bidAmounts[auctionId][msg.sender];
                bidAmounts[auctionId][msg.sender] = 0;
            }
        }
        require(totalBids > 0, "No funds to withdraw");
        payable(msg.sender).transfer(totalBids);
        emit WithdrawCompleted(msg.sender, totalBids);
    }
}
