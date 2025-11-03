// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Staking} from "../src/Staking.sol";

contract DeployScript is Script {
    Staking public staking;

    address public tokenAddress = vm.envAddress("TOKEN_ADDRESS");

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        staking = new Staking(tokenAddress);

        console.log("Staking deployed at: ", address(staking));

        vm.stopBroadcast();
    }
}
