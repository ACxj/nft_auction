// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/**
 * @title PriceOracle
 * @dev Chainlink 预言机集成合约，提供 ETH 和 ERC20 代币到美元的价格转换
 */
contract PriceOracle {
    // ETH/USD 价格源
    AggregatorV3Interface public ethUsdPriceFeed;
    // 各 ERC20 代币的 USD 价格源映射
    mapping(address => AggregatorV3Interface) public tokenPriceFeeds;

    // 代币金额的精度（18 位小数）
    uint256 public constant DECIMALS = 18;
    // Chainlink 价格的精度（8 位小数）
    uint256 public constant USD_DECIMALS = 8;

    // 价格更新事件
    event PriceUpdated(address token, int256 price);
    // ETH 价格更新事件
    event EthPriceUpdated(int256 price);

    /**
     * @dev 构造函数
     * @param _ethUsdPriceFeed ETH/USD 的 Chainlink 价格源地址
     */
    constructor(address _ethUsdPriceFeed) {
        ethUsdPriceFeed = AggregatorV3Interface(_ethUsdPriceFeed);
    }

    /**
     * @dev 获取当前 ETH/USD 价格
     * @return ETH 价格（以 USD 计，8 位小数精度）
     */
    function getEthUsdPrice() public view returns (int256) {
        (, int256 price,,,) = ethUsdPriceFeed.latestRoundData();
        return price;
    }

    /**
     * @dev 获取指定 ERC20 代币的 USD 价格
     * @param token 代币地址
     * @return 代币价格（以 USD 计，8 位小数精度）
     */
    function getTokenUsdPrice(address token) public view returns (int256) {
        AggregatorV3Interface priceFeed = tokenPriceFeeds[token];
        require(address(priceFeed) != address(0), "Price feed not set for this token");
        (, int256 price,,,) = priceFeed.latestRoundData();
        return price;
    }

    /**
     * @dev 设置代币的 Chainlink 价格源
     * @param token 代币地址
     * @param priceFeed Chainlink 价格源地址
     */
    function setTokenPriceFeed(address token, address priceFeed) external {
        tokenPriceFeeds[token] = AggregatorV3Interface(priceFeed);
    }

    /**
     * @dev 将 ETH 金额转换为 USD
     * @param ethAmount ETH 数量
     * @return 对应的 USD 金额
     */
    function convertEthToUsd(uint256 ethAmount) external view returns (uint256) {
        int256 ethPrice = getEthUsdPrice();
        uint256 ethPriceScaled = uint256(ethPrice) * (10 ** 10);
        return (ethAmount * ethPriceScaled) / (10 ** DECIMALS);
    }

    /**
     * @dev 将 ERC20 代币金额转换为 USD
     * @param token 代币地址
     * @param tokenAmount 代币数量
     * @return 对应的 USD 金额
     */
    function convertTokenToUsd(address token, uint256 tokenAmount) external view returns (uint256) {
        int256 tokenPrice = getTokenUsdPrice(token);
        int256 ethPrice = getEthUsdPrice();
        // 先将代币数量转换为 ETH 数量
        uint256 tokenAmountInEth = (uint256(tokenPrice) * tokenAmount) / (10 ** USD_DECIMALS);
        // 再将 ETH 数量转换为 USD 数量
        uint256 tokenAmountInUsd = (tokenAmountInEth * uint256(ethPrice)) / (10 ** USD_DECIMALS);
        return tokenAmountInUsd;
    }

    /**
     * @dev 将 USD 金额转换为 ETH
     * @param usdAmount USD 数量
     * @return 对应的 ETH 数量
     */
    function convertUsdToEth(uint256 usdAmount) external view returns (uint256) {
        int256 ethPrice = getEthUsdPrice();
        return (usdAmount * (10 ** DECIMALS)) / uint256(ethPrice);
    }
}
