// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import './TokenPrivateSale.sol';

contract EMOPrivateSale is TokenPrivateSale {

    constructor(
            address _treasury, 
            address _keeper, 
            address _usdc,
            address _token, 
            uint256 _tokenPrice, 
            uint256 _basePrice,
            uint256 _minTokensAmount, 
            uint256 _maxTokensAmount, 
            uint256 _privateSaleTokenPool,
            uint256 _privateSaleStart, 
            uint256 _privateSaleEnd, 
            uint256 _vestingDuration
        ) public TokenPrivateSale (
            _treasury,
            _keeper,
            _usdc,
            _token,
            _tokenPrice,
            _basePrice,
            _minTokensAmount,
            _maxTokensAmount,
            _privateSaleTokenPool,
            _privateSaleStart,
            _privateSaleEnd,
            _vestingDuration
    ) {}

    function getName() external pure returns (string memory) {
        return "EMOPrivateSale";
    }
}