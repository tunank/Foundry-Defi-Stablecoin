// SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
import {Test, console} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {DeployDSC} from "../../script/DeployDSC.s.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Handler} from "./Handler.t.sol";

contract Invariant is StdInvariant, Test{
    DeployDSC deployer;
    DSCEngine dsce;
    DecentralizedStableCoin dsc;
    HelperConfig config;
    address weth;
    address wbtc;
    Handler handler;

    function setUp() external{
        deployer = new DeployDSC();
        (dsc, dsce, config) = deployer.run();
        (,,weth, wbtc,) = config.activeNetworkConfig();  
        // targetContract(address(dsce));
        handler = new Handler(dsce, dsc);
        // The Handler file runs first then invariant__ later
        targetContract(address(handler));
    }
    
    function invariant_protocolMustHaveMoreValueThanSupply() public view{
        uint256 totalSuplly = dsc.totalSupply();
        uint256 totalWethDeposited = IERC20(weth).balanceOf(address(dsce));
        uint256 totalBtcDeposited = IERC20(wbtc).balanceOf(address(dsce));

        uint256 wethValue = dsce.getUsdValue(weth, totalWethDeposited);
        uint256 btcValue = dsce.getUsdValue(wbtc, totalBtcDeposited);

        console.log("WETH Value: ", wethValue);
        console.log("BTC Value: ", btcValue);
        console.log("Total Supply: ", totalSuplly);
        console.log("Time mint: ", handler.timeMintIsCalled());

        assert(wethValue + btcValue >= totalSuplly);
    }
}