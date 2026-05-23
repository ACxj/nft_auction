// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/Auction.sol";

/**
 * @title UpgradeScript
 * @dev 升级脚本，用于升级 Auction 合约到新的实现版本
 */
contract UpgradeScript is Script {
    /**
     * @dev 运行升级脚本
     * @notice 需要在 .env 文件中设置 PRIVATE_KEY 和 AUCTION_PROXY 环境变量
     */
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("AUCTION_PROXY");

        vm.startBroadcast(deployerPrivateKey);

        // 部署新的 Auction 实现合约
        Auction newImplementation = new Auction();
        // 通过代理升级到新实现
        Auction(proxyAddress).upgradeToAndCall(address(newImplementation), "");

        vm.stopBroadcast();

        console.log("Auction upgraded to:", address(newImplementation));
    }
}
