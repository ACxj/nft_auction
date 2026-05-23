## NFT 拍卖市场

基于 Foundry 框架开发的 NFT 拍卖市场，集成了 Chainlink 预言机获取实时价格数据，并使用 UUPS/透明代理模式实现合约升级。

## 项目概述

本项目实现了一个完整的 NFT 拍卖市场，具备以下核心功能：

- **NFT 铸造与交易**：基于 ERC721 标准，支持 NFT 的铸造和转移
- **拍卖系统**：支持创建拍卖、出价、结束拍卖等完整流程
- **多币种出价**：支持 ETH 和 ERC20 代币出价
- **美元价值换算**：使用 Chainlink 预言机将出价金额转换为美元
- **合约升级**：采用 UUPS/透明代理模式支持合约升级

## 技术栈

- **Foundry**：Ethereum 开发工具包
- **Solidity**：智能合约语言
- **OpenZeppelin**：安全可靠的智能合约库
- **Chainlink**：去中心化预言机服务

## 工具组件

Foundry 包含以下工具：

- **Forge**：以太坊智能合约测试框架（类似于 Truffle、Hardhat）
- **Cast**：与 EVM 智能合约交互的工具集
- **Anvil**：本地以太坊节点（类似于 Ganache）
- **Chisel**：快速 Solidity REPL 工具

## 使用说明

### 安装依赖

使用 Foundry 的 `forge install` 安装智能合约依赖：

```shell
forge install OpenZeppelin/openzeppelin-contracts@v5.0.0
forge install OpenZeppelin/openzeppelin-contracts-upgradeable@v5.0.0
forge install smartcontractkit/chainlink-brownie-contracts@1.1.1
forge install foundry-rs/forge-std
```

### 编译合约

```shell
forge build
# 或
npm run build
```

### 运行测试

```shell
forge test
# 或
npm run test
```

### 格式化代码

```shell
forge fmt
```

### Gas 快照

```shell
forge snapshot
```

### 启动本地节点

```shell
anvil
```

### 部署到 Sepolia 测试网

```shell
forge script script/Deploy.s.sol:DeployScript --rpc-url sepolia --broadcast --verify
# 或
npm run deploy
```

### 升级合约

```shell
forge script script/Upgrade.s.sol:UpgradeScript --rpc-url sepolia --broadcast --verify
# 或
npm run upgrade
```

### 使用 Cast 工具

```shell
cast <子命令>
```

### 获取帮助

```shell
forge --help
anvil --help
cast --help
```

## 项目结构

```
ft_auction/
├── src/
│   ├── NFT.sol           # NFT 合约
│   ├── Auction.sol        # 拍卖合约
│   ├── PriceOracle.sol   # Chainlink 价格预言机
│   └── TransparentProxy.sol  # 透明代理合约
├── script/
│   ├── Deploy.s.sol      # 部署脚本
│   └── Upgrade.s.sol     # 升级脚本
├── test/
│   ├── NFT.t.sol         # NFT 合约测试
│   └── Auction.t.sol     # 拍卖合约测试
└── foundry.toml         # Foundry 配置文件
```

## 合约说明

### NFT.sol

基于 ERC721 标准的 NFT 合约，支持：
- NFT 铸造 (mint)
- Token URI 管理
- NFT 转移

### Auction.sol

拍卖市场核心合约，支持：
- 创建拍卖：用户可以将 NFT 上架拍卖
- 出价：支持 ETH 和 ERC20 代币出价
- 结束拍卖：拍卖结束后 NFT 转移给最高出价者
- 价格换算：将出价金额转换为美元方便比较
- 平台手续费：2.5% 的手续费

### PriceOracle.sol

Chainlink 预言机集成合约，提供：
- ETH/USD 价格获取
- ERC20/USD 价格获取
- ETH 和代币到美元的换算

### TransparentProxy.sol

透明代理合约，用于 Auction 合约的升级。

## 环境变量

复制 `.env.example` 文件并重命名为 `.env`，填入以下配置：

- `PRIVATE_KEY`：部署钱包私钥
- `SEPOLIA_RPC_URL`：Sepolia 测试网 RPC 地址
- `ETHERSCAN_API_KEY`：Etherscan API 密钥（用于合约验证）

## 文档资料

更多详细信息请参考 [Foundry 官方文档](https://book.getfoundry.sh/)
