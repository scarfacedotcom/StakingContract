// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import { Error } from "./libraries/Error.sol";
import { Event } from "./libraries/Event.sol";
import { IERC20 } from "contracts/interfaces/IERC20.sol";
import { StakingToken } from "./StakingToken.sol";

contract Staking {
    address stakingOperator;
    IERC20 token;

    struct PoolInfo {
        string name;
        uint8 percentageYield;
        uint minFee;
    }
    PoolInfo[] public pools;

    struct StakeInfo{
        uint amount;
        uint startedAt;
        uint endedAt;
        bool rewardClaimed;
    }

    mapping(uint => mapping(address => StakeInfo)) public stakes;

    constructor(address _token) {
        stakingOperator = msg.sender;
        token = IERC20(_token);
    }

    modifier onlyStakingOperator {
        require(msg.sender == stakingOperator, Error.NOT_AUTHORIZED());
        _;
    }

    function createPool(string memory _name, uint8 _percentageYield, uint _minFee) 
    external 
    onlyStakingOperator {

        PoolInfo memory newPool = PoolInfo({
            name: _name,
            percentageYield: _percentageYield,
            minFee: _minFee
        });

        pools.push(newPool);

        emit Event.PoolCreatedSuccessfully(_name, _percentageYield, _minFee);
    }

    function stakeInPool(uint8 _poolId, uint _amount) external {
        require(msg.sender != address(0), Error.ADDRESS_NOT_SUPPORTED());
        require(pools.length > 0, Error.INVALID_POOL());
        require(_poolId < pools.length, Error.INVALID_POOL());

        PoolInfo memory selectedPool = pools[_poolId];

        require(selectedPool.minFee <= _amount, Error.AMOUNT_IS_BELOW_MINIMUM_FEE());
        require(token.balanceOf(msg.sender) >= _amount, Error.INSUFICIENT_STAKE_BALANCE());
    
        token.transferFrom(msg.sender, address(this), _amount);
        
        stakes[_poolId][msg.sender] = StakeInfo({
            amount: _amount,
            startedAt: block.timestamp,
            endedAt: 0,
            rewardClaimed: false
        });

        emit Event.StakeCreatedSuccessfully(msg.sender, _amount, stakes[_poolId][msg.sender].startedAt, _poolId);
    }

    function claimReward(uint8 _poolId) external {
        require(msg.sender != address(0), Error.ADDRESS_NOT_SUPPORTED());
        require(_poolId < pools.length, Error.INVALID_POOL());
        
        StakeInfo memory stake = stakes[_poolId][msg.sender];

        require(stake.startedAt != 0, Error.UNIDENTIFIED_STAKE());
        require(stake.amount != 0, Error.INSUFICIENT_STAKE_BALANCE());

        uint amount = stake.amount;
        stake.endedAt = block.timestamp;
        stake.rewardClaimed = true;

        uint reward = calculateReward(_poolId);

        stake.amount = 0; 

        StakingToken tokenContract = StakingToken(address(token));
        address ownerAddress = tokenContract.owner();

        token.transferFrom(ownerAddress, msg.sender, reward + amount);
    }

    function calculateReward(uint8 _poolId) 
    internal
    view 
    returns (uint reward) 
    {
        // A is the future value of the investment/loan, including interest.
        // P is the principal investment amount (initial deposit or loan amount).
        // r is the annual interest rate (in decimal form).
        // t is the number of years.

        PoolInfo memory pool = pools[_poolId];
        StakeInfo memory stake = stakes[_poolId][msg.sender];
        require(stake.startedAt / 1 days > 1, Error.CLAIM_AFTER_24_HOURS());

        uint noOfdaysStaked = (stake.endedAt - stake.startedAt) / 1 days;
        uint yearsStaked = noOfdaysStaked / 365;

        uint r = pool.percentageYield / 100;
        uint P = stake.amount;

        // Calculate reward using the formula: A = P * (1 + r/n)^(nt)
        uint rewardFactor = (100 + r);  // (1 + r), where r is in percentage, so add 100
        reward = P * rewardFactor * yearsStaked / 100;  // Applying simple reward calculation without exponentiation

        return reward;
    }
}
