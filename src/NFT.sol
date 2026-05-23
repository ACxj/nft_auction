// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title NFT
 * @dev 基于 ERC721 标准的 NFT 合约，支持 NFT 的铸造和转移
 */
contract NFT is ERC721, ERC721URIStorage, Ownable {
    // 当前 tokenId 计数器
    uint256 private _currentTokenId;

    // 记录每个 NFT 的创建者地址
    mapping(uint256 => address) private _tokenCreators;

    // NFT 铸造事件
    event TokenMinted(uint256 tokenId, address to, string uri);

    /**
     * @dev 构造函数
     * @param initialOwner 合约初始所有者
     */
    constructor(address initialOwner)
        ERC721("NFT Auction", "NFTA")
        Ownable(initialOwner)
    {}

    /**
     * @dev 铸造新的 NFT
     * @param to NFT 接收者地址
     * @param uri NFT 的元数据 URI
     * @return 新铸造的 tokenId
     */
    function mint(address to, string memory uri) external onlyOwner returns (uint256) {
        _currentTokenId++;
        uint256 newTokenId = _currentTokenId;
        _safeMint(to, newTokenId);
        _setTokenURI(newTokenId, uri);
        _tokenCreators[newTokenId] = to;
        emit TokenMinted(newTokenId, to, uri);
        return newTokenId;
    }

    /**
     * @dev 获取 NFT 的元数据 URI
     * @param tokenId NFT 的 tokenId
     * @return NFT 的 URI
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    /**
     * @dev 检查合约是否支持某个接口
     * @param interfaceId 接口 ID
     * @return 是否支持该接口
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev 获取 NFT 的创建者
     * @param tokenId NFT 的 tokenId
     * @return 创建者地址
     */
    function getTokenCreator(uint256 tokenId) external view returns (address) {
        return _tokenCreators[tokenId];
    }
}
