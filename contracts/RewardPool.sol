// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./storage/RewardPoolStorage.sol";

/**
 * @dev RewardPool.
 * Linear reward, 15% in the first year, 12% in the second year, 8% in the third year.
 * Total annual reward = linear reward for the current year + meet conversion pick for the previous year.
 * Annual awards, 70% for weekly awards and 30% for annual awards.
 */
contract RewardPool is Ownable , RewardPoolStorage {
    
    constructor(IMeet _meet) {
        Meet = _meet;
    }

    function setRewardRole(address _address) external onlyOwner {
        require(_address != address(0) , "RewardPool: zero address");
        emit SetRewardRole(address(rewardRole) , rewardRole = _address);
    }

    modifier _canWithdraw() {
        require(msg.sender == rewardRole , "RewardPool: caller not reward role");
        _;
    }

    /**
     * @dev start.
     */
    function start() external onlyOwner {
        require(startTime == 0 , "RewardPool: startTime has been set");
        _start(block.timestamp);
    }

    function _start(uint256 _startTime) internal {
        startTime = getMinTimeOf(_startTime);
        uint256 totalSupply = 10 ** 26 * 48;

        // 15% of the total in the first year.
        _initReward(startTime , totalSupply * 15 / 100 , 0 , true);

        // 12% of the total in the first year.
        _initReward(rewards[0].endTime + 1 days , totalSupply * 12 / 100 , 0 , false);
        
        // 8% of the total in the first year.
        _initReward(rewards[1].endTime + 1 days , totalSupply * 8 / 100 , 0 , false);

        emit SetStartTime(startTime);
    }

    /**
     * @dev Initialize one year's worth of reward data.
     */
    function _initReward(uint256 _startTime , uint256 amount , uint256 exchangeAmount , bool isInit) internal {
        Info memory info;
        info.startTime = getMinTimeOf(_startTime);
        info.endTime = info.startTime + WEEK * 7 days - 1 days;
        info.totalAmount = amount + exchangeAmount;
        info.weekAmount = info.totalAmount * 70 / 100 / WEEK;
        info.yearAmount = info.totalAmount - info.weekAmount * WEEK;
        info.isWeekReward = new bool[](WEEK);
        info.isInit = isInit;

        rewards.push(info);
    }

    /**
     * @dev update one year's worth of reward data.
     */
    function _updateReward(uint256 i , uint256 totalAmount , bool isInit) internal {
        Info storage info = rewards[i];
        info.totalAmount = totalAmount;
        info.weekAmount = info.totalAmount * 70 / 100 / WEEK;
        info.yearAmount = info.totalAmount - info.weekAmount * WEEK;
        info.isInit = isInit;
    }

    /**
     * @dev Initialize this year's reward data.
     */
    function initYearReward() external onlyOwner {
        uint256 i;
        uint256 _startTime;
        (i , _startTime , ) = _getTimeInfo(block.timestamp);
        if(i < rewards.length){
            require(!rewards[i].isInit , "RewardPool: it has been initialized");
        }

        // Get the previous year's exchange rewards.
        uint256 preAmount = _getPreYearExchange(block.timestamp);

        if(i < rewards.length) {
            _updateReward(i , rewards[i].totalAmount + preAmount , true);
        }else{
            _initReward(_startTime , 0 , preAmount , true);
        }

    }

    function setExchangeContract(address _address) external onlyOwner {
        require(_address != address(0) , "RewardPool: Zero address");
        emit SetExchangeContract(exchangeContract , exchangeContract = _address);
    }

    /**
     * @dev Only the exchange contract can be called. Record exchange rewards.
     */
    function exchangeRecord(uint256 amount) external {
        require(msg.sender == exchangeContract , "RewardPool: caller not exchange Contract");
        uint256 _startTime;
        (, _startTime , ) = _getTimeInfo(block.timestamp);
        _yearExchangeAmounts[_startTime] += amount;
        emit ExchangeRecord(block.timestamp , amount);
    }

    /**
     * @dev Return the previous year's exchange rewards.
     */
    function _getPreYearExchange(uint256 time) internal view returns(uint256) {
        uint256 amount;
        uint256 i;
        (i , , ) = _getTimeInfo(time);

        if(i > 0){
            amount = _yearExchangeAmounts[rewards[i - 1].startTime];
        }

        return amount;
    }

    /**
     * @dev Withdraw the previous week's rewards.
     * Call the function only from the address where you can withdraw money.
     */
    function withdrawWeekReward(address to) external _canWithdraw returns (uint256 weekAmount) {
        require(to != address(0) , "RewardPool: zero address");
        weekAmount = _withdrawWeekReward(to , block.timestamp);
    }

    /**
     * @dev Extract the last week's reward of the week in which time is located.
     */
    function withdrawWeekReward(address to , uint256 time) external _canWithdraw returns (uint256 weekAmount) {
        require(to != address(0) , "RewardPool: zero address");
        require(time <= block.timestamp , "RewardPool: time is greater than the current time");
        weekAmount = _withdrawWeekReward(to , time);
    }

    function _withdrawWeekReward(address to , uint256 time) internal _canWithdraw returns (uint256 weekAmount) {
        uint256 i;      
        uint256 iWeek;  // Week number. the first week value is 1.
        uint256 index;  // IsWeekReward index.
        (i , , iWeek) = _getTimeInfo(time);
        require(!(i == 0 && iWeek == 1) , "RewardPool: the first week");

        if(iWeek == 1){ // Last week of the previous year.
            i--;
            iWeek = WEEK;
            index = iWeek - 1;
        }else {
            index = iWeek - 2;
        }

        require(rewards[i].isInit , "RewardPool: not initialized");
        require(!rewards[i].isWeekReward[index] , "RewardPool: has been rewarded");

        weekAmount = rewards[i].weekAmount;

        Meet.transfer(to , weekAmount);
        rewards[i].isWeekReward[index] = true;

        emit WeekWithdraw(rewards[i].startTime , iWeek , weekAmount);
    }

    /**
     * @dev Withdraw the previous year's rewards.
     * Call the function only from the address where you can withdraw money.
     */
    function withdrawYearReward(address to) external _canWithdraw returns(uint256 yearAmount) {
        require(to != address(0) , "RewardPool: zero address");
        yearAmount = _withdrawYearReward(to , block.timestamp);
    }

    function withdrawYearReward(address to , uint256 time) external _canWithdraw returns(uint256 yearAmount) {
        require(to != address(0) , "RewardPool: zero address");
        require(time <= block.timestamp , "RewardPool: time is greater than the current time");
        yearAmount = _withdrawYearReward(to , time);
    }

    function _withdrawYearReward(address to , uint256 time) internal _canWithdraw returns (uint256 yearAmount) {
        uint256 i;
        (i , , ) = _getTimeInfo(time);
        require(i > 0 , "RewardPool: the first year");

        i--;

        require(rewards[i].isInit , "RewardPool: not initialized");
        require(!rewards[i].isYearReward , "RewardPool: has been rewarded");

        yearAmount = rewards[i].yearAmount;

        Meet.transfer(to , yearAmount);
        rewards[i].isYearReward = true;

        emit YearWithdraw(rewards[i].startTime , yearAmount);
    }

    /**
     * @dev Returns whether the weekly reward has been withdrawn.
     */
    function getWeekReward(uint256 time) external view returns (bool , uint256) {
        uint256 i;
        uint256 iWeek;
        (i , , iWeek) = _getTimeInfo(time);
        return (rewards[i].isWeekReward[iWeek - 1] , rewards[i].weekAmount);
    }

    /**
     * @dev Returns data for years.
     */
    function getYearInfo(uint256 time) external view returns (Info memory) {
        uint256 i;
        (i , , ) = _getTimeInfo(time);
        return rewards[i];
    }

    /**
     * @dev Return the total amount of the annual redemption award.
     */
    function getYearExchangeAmount(uint256 time) external view returns (uint256) {
        uint256 _startTime;
        ( , _startTime , ) = _getTimeInfo(time);
        return _yearExchangeAmounts[_startTime];
    }

    function getTimeInfo(uint256 time) external view returns (uint256 , uint256 , uint256) {
        uint256 i;
        uint256 _startTime;
        uint256 iWeek;
        (i , _startTime , iWeek) = _getTimeInfo(time);
        return (i , _startTime , iWeek);
    }

    /**
     * @dev Returns the minimum time of day.
     */
    function getMinTimeOf(uint256 time) public pure returns(uint256) {
        return time / 1 days * 1 days;
    }

    function _getTimeInfo(uint256 time) internal view returns (uint256 , uint256 , uint256) {
        uint256 _days = (time - startTime) % (1 days) > 0 ? (time - startTime) / (1 days) + 1 : (time - startTime) / (1 days);

        uint256 yearDays = WEEK * 7;
        uint256 year = _days % yearDays > 0 ? _days / yearDays + 1 : _days / yearDays; 
        
        uint256 iYear = year - 1;   // The index of rewards starts at 0.
        
        uint256 yearStartTime = rewards[iYear].startTime;   // The beginning time of the year.

        // Week number. The first week value is 1.
        uint256 _weekDays = (time - yearStartTime) % (1 days) > 0 ? (time - yearStartTime) / (1 days) + 1 : (time - yearStartTime) / (1 days);
        uint256 currentWeek = _weekDays % 7 > 0 ? _weekDays / 7 + 1 : _weekDays / 7;

        return (iYear , yearStartTime , currentWeek);
    }

}
