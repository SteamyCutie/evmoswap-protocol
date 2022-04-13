// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;

import '../libraries/TransferHelper.sol';
import '../interfaces/IEvmoSwapMigrator.sol';
import '../interfaces/IEvmoSwapFactory.sol';
import '../interfaces/IEvmoSwapRouter01.sol';
import '../interfaces/IERC20.sol';

contract EvmoSwapMigrator is IEvmoSwapMigrator {
    IEvmoSwapRouter01 immutable router;
    IEvmoSwapFactory immutable factoryV1;

    constructor(address _factoryV1, address _router) public {
        factoryV1 = IEvmoSwapFactory(_factoryV1);
        router = IEvmoSwapRouter01(_router);
    }

    function migrate(address token, uint amountTokenMin, uint amountETHMin, address to, uint deadline) external override {
        //
    }
}