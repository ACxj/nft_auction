// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/NFT.sol";
import "../src/Auction.sol";
import "../src/PriceOracle.sol";
import "../src/TransparentProxy.sol";

/**
 * @title DeployScript
 * @dev 部署脚本，用于将 NFT 拍卖市场合约部署到 Sepolia 测试网
 */
contract DeployScript is Script {
    // Sepolia 测试网上的 ETH/USD 价格源地址
    address constant ETH_USD_PRICE_FEED = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    /**
     * @dev 运行部署脚本
     * @notice 需要在 .env 文件中设置 PRIVATE_KEY 环境变量
     */
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        console.log("Deployer address:", deployer);
        vm.startBroadcast(deployerPrivateKey);

        // 部署 NFT 合约
        NFT nft = new NFT(deployer);

        // 部署价格预言机合约
        PriceOracle priceOracle = new PriceOracle(ETH_USD_PRICE_FEED);

        // 部署 Auction 实现合约
        Auction auctionImplementation = new Auction();
        auctionImplementation.initialize(address(priceOracle));

        // 准备初始化数据
        bytes memory initData = abi.encodeWithSelector(
            Auction.initialize.selector,
            address(priceOracle)
        );

        // 部署透明代理合约
        TransparentProxy auctionProxy = new TransparentProxy(
            address(auctionImplementation),
            deployer,
            initData
        );

        // 将代理合约转换为 Auction 类型
        Auction auction = Auction(payable(auctionProxy));

        vm.stopBroadcast();

        // 打印部署地址
        console.log("NFT deployed to:", address(nft));
        console.log("PriceOracle deployed to:", address(priceOracle));
        console.log("Auction Implementation deployed to:", address(auctionImplementation));
        console.log("Auction Proxy deployed to:", address(auctionProxy));
    }
}
