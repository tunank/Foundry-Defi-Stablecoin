// SPDX-Liense-Identifier: MIT

pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";

contract Handler is Test {
    DSCEngine dsce;
    DecentralizedStableCoin dsc;

    ERC20Mock weth;
    ERC20Mock wbtc;

    uint256 public timeMintIsCalled;
    address[] public userWithCollateral;
    MockV3Aggregator public ethUsdPriceFeed;

    // uint96 because if uint256 we exceed the max, it cause overflow
    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

    constructor(DSCEngine _dscEngine, DecentralizedStableCoin _dsc) {
        dsce = _dscEngine;
        dsc = _dsc;

        address[] memory getCollateral = dsce.getCollateralTokens();
        // Stimulate the tokens
        weth = ERC20Mock(getCollateral[0]);
        wbtc = ERC20Mock(getCollateral[1]);

        ethUsdPriceFeed = MockV3Aggregator(dsce.getCollateralTokenPriceFeed(address(weth)));
    }

    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public{
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
        // Set limit for the choosing number
        amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);
        // We need a msg.sender to be able to deposit
        vm.startPrank(msg.sender);
        collateral.mint(msg.sender, amountCollateral);
        collateral.approve(address(dsce), amountCollateral);
        dsce.depositCollateral(address(collateral), amountCollateral);
        vm.stopPrank();
        userWithCollateral.push(msg.sender);
    }

    function _getCollateralFromSeed(uint256 collateralSeed) private view returns(ERC20Mock){
        if(collateralSeed % 2 == 0){
            return weth;
        }
        return wbtc;
    }

    function redeemCollateral(uint256 collateral, uint256 amountCollateral) public{
        ERC20Mock collateral = _getCollateralFromSeed(collateral);
        uint256 depositMax = dsce.getCollateralBalanceOfUser(address(collateral), msg.sender);
        amountCollateral = bound(amountCollateral, 0, depositMax);
        if(amountCollateral == 0){
            return;
        }
        dsce.redeemCollateral(address(collateral), amountCollateral);
    }

    function mintDsc(uint256 amount, uint256 addressSeed) public{
        if(userWithCollateral.length == 0){
            return;
        }
        address sender = userWithCollateral[addressSeed % userWithCollateral.length];
        (uint256 totalDscMinted, uint256 collateralValueInUsd) = dsce.getAccountInformation(sender);
        int256 maxDscMint = int256(collateralValueInUsd) / 2 - int256(totalDscMinted);
        if(maxDscMint < 0){
            return;
        }
        amount = bound(amount, 0, uint256(maxDscMint));
        if(amount == 0){
            return;
        }
        vm.startPrank(sender);
        dsce.mintDsc(amount);
        vm.stopPrank();
        timeMintIsCalled++;
    }

    // function updateCollateralPrice(uint96 newPrice) public{
    //     int256 newPriceInt = int256(uint256(newPrice));
    //     ethUsdPriceFeed.updateAnswer(newPriceInt);
    // }
}