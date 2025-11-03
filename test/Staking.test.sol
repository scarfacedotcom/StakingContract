// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import { Test } from "forge-std/Test.sol";
import { Staking } from "../src/Staking.sol";
import { StakingToken } from "../src/StakingToken.sol";
import { Event } from "../src/libraries/Event.sol";
import { Error } from "../src/libraries/Error.sol";
import { IERC20 } from "../src/interfaces/IERC20.sol";
import { IERC20Errors } from "openzeppelin-contracts/contracts/interfaces/draft-IERC6093.sol";

contract StakingTest is Test {
    Staking public stakingContract;
    StakingToken public tokenContract;
    address stakingOperator = mkaddr("Staking Operator");
    address tokenAddress = mkaddr("Token");
    address staker = mkaddr("Staker");

    function mkaddr(string memory name) public returns (address) {
        address addr = address(
            uint160(uint256(keccak256(abi.encodePacked(name))))
        );
        vm.label(addr, name);
        return addr;
    }

    function setUp() public {
        vm.prank(tokenAddress);
        tokenContract = new StakingToken();

        vm.prank(stakingOperator);
        stakingContract = new Staking(address(tokenContract));

    }

    // ======================================================================
    // =================== createPool() Tests ===============================
    // ======================================================================

    function test_Only_staking_operator_can_create_a_pool() public {
        vm.prank(stakingOperator);

        vm.expectEmit(true, true, false, true);
        emit Event.PoolCreatedSuccessfully("pool 1", 10, 1000);

        stakingContract.createPool("pool 1", 10, 1000);

        (string memory name, uint8 percentageYield, uint minFee) = stakingContract.pools(0);
        assertEq(name, "pool 1");
        assertEq(percentageYield, 10);
        assertEq(minFee, 1000);
    }

    function test_random_address_can_not_create_a_pool() public {
        vm.prank(staker);

        vm.expectRevert(Error.NOT_AUTHORIZED.selector);

        stakingContract.createPool("pool 1", 10, 1000);
    }

    // // ======================================================================
    // // =================== stakeInPool() Tests ==============================
    // // ======================================================================

    function test_staker_can_not_stake_if_poolID_is_incorrect() public {
        vm.prank(staker);

        vm.expectRevert(Error.INVALID_POOL.selector);

        stakingContract.stakeInPool(1, 1000);
    }

    function test_address0_can_not_stake_in_pool() public {
        vm.prank(stakingOperator);
        stakingContract.createPool("pool 1", 10, 1000);

        vm.prank(stakingOperator);
        stakingContract.createPool("pool 2", 15, 5000);

        vm.prank(stakingOperator);
        stakingContract.createPool("pool 3", 30, 15000);

        vm.prank(address(0));
        vm.expectRevert(Error.ADDRESS_NOT_SUPPORTED.selector);
        stakingContract.stakeInPool(1, 1000);
    }

    function test_staker_can_not_stake_in_a_particular_pool_if_amount_passed_is_below_minimum_fee() public {
        vm.prank(stakingOperator);
        stakingContract.createPool("pool 1", 10, 1000);

        vm.prank(stakingOperator);
        stakingContract.createPool("pool 2", 15, 5000);

        vm.prank(stakingOperator);
        stakingContract.createPool("pool 3", 30, 15000);

        vm.prank(staker);
        vm.expectRevert(Error.AMOUNT_IS_BELOW_MINIMUM_FEE.selector);
        stakingContract.stakeInPool(1, 1000);
    }

    function test_staker_can_not_stake_if_balance_is_insufficient() public {
        vm.prank(stakingOperator);
        stakingContract.createPool("pool 1", 10, 1000);

        vm.prank(stakingOperator);
        stakingContract.createPool("pool 2", 15, 5000);

        vm.prank(stakingOperator);
        stakingContract.createPool("pool 3", 30, 15000);

        vm.prank(staker);
        vm.expectRevert(Error.INSUFICIENT_STAKE_BALANCE.selector);
        stakingContract.stakeInPool(1, 5000);
    }

    function test_staker_can_not_stake_if_balance_is_sufficient_but_doesnt_approve_the_contract_to_spend() public {
        vm.prank(stakingOperator);
        stakingContract.createPool("pool 1", 10, 1_000);

        vm.prank(stakingOperator);
        stakingContract.createPool("pool 2", 15, 5_000);

        vm.prank(stakingOperator);
        stakingContract.createPool("pool 3", 30, 15_000);

        vm.prank(tokenAddress);
        tokenContract.transfer(staker, 10_000);

        vm.prank(staker);
        vm.expectRevert();
        stakingContract.stakeInPool(1, 5_000);
    }

    function test_staker_can_stake_if_token_balance_is_sufficient() public {
        uint pool2Amount = 5_000;

        vm.prank(stakingOperator);
        stakingContract.createPool("pool 1", 10, 1000);

        vm.prank(stakingOperator);
        stakingContract.createPool("pool 2", 15, pool2Amount);

        vm.prank(stakingOperator);
        stakingContract.createPool("pool 3", 30, 15000);

        vm.prank(tokenAddress);
        tokenContract.transfer(staker, 10_000);

        vm.prank(staker);
        tokenContract.approve(address(stakingContract), 10_000);

        uint8 pool2Id = 1;

        vm.prank(staker);
        stakingContract.stakeInPool(pool2Id, 5000);

        (uint amount, uint startedAt, uint endedAt, bool rewardClaimed) = stakingContract.stakes(pool2Id,staker);
        assertEq(amount, pool2Amount);
        assertEq(endedAt, 0);
        assertEq(rewardClaimed, false);
    }

    // // ======================================================================
    // // =================== claimReward() Tests ==============================
    // // ======================================================================

    function test_staker_can_not_claimReward_if_poolID_is_incorrect() public {
        vm.prank(staker);

        vm.expectRevert(Error.INVALID_POOL.selector);

        stakingContract.claimReward(1);
    }

    function test_address0_can_not_claimReward() public {
        vm.prank(stakingOperator);
        stakingContract.createPool("pool 1", 10, 1000);

        vm.prank(stakingOperator);
        stakingContract.createPool("pool 2", 15, 5000);

        vm.prank(stakingOperator);
        stakingContract.createPool("pool 3", 30, 15000);

        vm.prank(address(0));
        vm.expectRevert(Error.ADDRESS_NOT_SUPPORTED.selector);
        stakingContract.claimReward(1);
    }

    function test_staker_can_not_claimReward_for_stake_the_didnt_make() public {
        vm.prank(stakingOperator);
        stakingContract.createPool("pool 1", 10, 1000);

        vm.prank(stakingOperator);
        stakingContract.createPool("pool 2", 15, 5000);

        vm.prank(staker);
        vm.expectRevert(Error.UNIDENTIFIED_STAKE.selector);
        stakingContract.claimReward(1);
    }

    // function test_staker_can_claimReward() public {
    //     uint pool2Amount = 5_000;

    //     vm.prank(stakingOperator);
    //     stakingContract.createPool("pool 1", 10, 1000);

    //     vm.prank(stakingOperator);
    //     stakingContract.createPool("pool 2", 15, pool2Amount);

    //     vm.prank(stakingOperator);
    //     stakingContract.createPool("pool 3", 30, 15000);

    //     vm.prank(tokenAddress);
    //     tokenContract.transfer(staker, 10_000);

    //     vm.prank(staker);
    //     tokenContract.approve(address(stakingContract), 10_000);

    //     uint8 pool2Id = 1;

    //     vm.prank(staker);
    //     stakingContract.stakeInPool(pool2Id, 5000);

    //     vm.warp(block.timestamp + 10 days);
    //     uint diff = block.timestamp + 10 days - block.timestamp;
    //     emit log_uint(diff);
    //     emit log_uint(diff/ 1 days);


    //     vm.prank(tokenAddress);
    //     tokenContract.approve(address(stakingContract), 10_000);

    //     vm.prank(staker);
    //     stakingContract.claimReward(pool2Id);
    // }
}
