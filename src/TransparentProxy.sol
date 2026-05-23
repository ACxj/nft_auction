// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";

/**
 * @title TransparentProxy
 * @dev 透明代理合约，用于 Auction 合约的升级
 * @notice 继承自 OpenZeppelin 的 TransparentUpgradeableProxy
 */
contract TransparentProxy is TransparentUpgradeableProxy {
    /**
     * @dev 构造函数
     * @param _logic 逻辑合约地址
     * @param admin_ 代理管理员地址
     * @param _data 初始化数据
     */
    constructor(
        address _logic,
        address admin_,
        bytes memory _data
    ) TransparentUpgradeableProxy(_logic, admin_, _data) {}
}
