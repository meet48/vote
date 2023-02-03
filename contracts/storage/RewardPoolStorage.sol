// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Meet token.
 */
interface IMeet is IERC20 {}

/**
 * @dev RewardPoolStorage.
 */
contract RewardPoolStorage {
    
    // This address can extract weekly rewards, annual rewards.
    address public rewardRole;
    
    IMeet public Meet;
    
    // Exchange contract, meet exchange pick.
    address public exchangeContract;

    uint256 public startTime;

    uint256 public constant WEEK = 52;
    
    // One year of reward data.
    struct Info {
        uint256 startTime;
        uint256 endTime;
        uint256 totalAmount;
        uint256 weekAmount;
        uint256 yearAmount;
        bool[] isWeekReward;    // Record whether the weekly reward has been drawn. The subscript is the serial number of the week.
        bool isYearReward;      // Record whether annual awards have been drawn.
        bool isInit;            // Records whether the reward data has been initialized.
    }

    Info[] public rewards;

    // Record the amount of exchange rewards for one year. uint256 is the startTime of the year.
    mapping(uint256 => uint256) internal _yearExchangeAmounts;

    event SetRewardRole(address oldAddress , address newAddress);
    event SetExchangeContract(address oldAddress , address newAddress);
    event SetStartTime(uint256 startTime);
    event ExchangeRecord(uint256 time , uint256 amount);
    event WeekWithdraw(uint256 yearStartTime , uint256 week , uint256 amount);
    event YearWithdraw(uint256 yearStartTime , uint256 amount);
    
}
