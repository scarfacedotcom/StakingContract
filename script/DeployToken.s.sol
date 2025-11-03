// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {StakingToken} from "../src/StakingToken.sol";

contract DeployScript is Script {
    StakingToken public token;

    function setUp() public {}

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        token = new StakingToken();

        console.log("StakingToken deployed at: ", address(token));

        vm.stopBroadcast();
    }
}
