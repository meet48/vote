// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev RewardPool.
 */
interface IRewardPool {
    function startTime() external view returns (uint256);
}

/**
 * @dev SignStage.
 */
interface ISignStage {
    function isSignEffective(address _address , uint256 stageId) external returns (bool);
}

/**
 * @dev Pick.
 */
interface IPick is IERC20 {
    function burnFrom(address account, uint256 amount) external;
}

/**
 * @dev VoteStorage.
 */
contract VoteStorage {
    IRewardPool public RewardPool;
    ISignStage public SignStage;
    IPick public Pick;
    uint256 public startTime;

    // Address the number of votes received in one day.
    mapping(address => mapping(uint256 => uint256)) internal dayVotes;

    // Addresses that have been voted on within a week.
    mapping(uint256 => address[]) internal weekVoteAddress;

    // Address the number of votes received in a week.
    mapping(address => mapping(uint256 => uint256)) internal weekVotes;

    // Addresses that have been voted on within a year.
    mapping(uint256 => address[]) internal yearVoteAddress;

    // Address the number of votes received in a year.
    mapping(address => mapping(uint256 => uint256)) internal yearVotes;

    event SetRewardPool(address _address);
    event SetSignStage(address _address);
    event SetPick(address _address);
    event SetStartTime(uint256 startTime);
    event RecordVote(address _address , uint256 stageId , uint256 amount);
}
