// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./storage/VoteStorage.sol";

/**
 * @dev Vote.
 */
contract Vote is Ownable , VoteStorage {

    constructor() {}

    /**
     * @dev init.
     */
    function init(IRewardPool _rewardPool , ISignStage _signStage , IPick _pick) external onlyOwner {
        RewardPool = _rewardPool;
        SignStage = _signStage;
        Pick = _pick;
        syncStartTime();

        emit SetRewardPool(address(_rewardPool));
        emit SetSignStage(address(_signStage));
        emit SetPick(address(_pick));
    }

    /**
     * @dev Synchronize the startTime in the rewardPool contract.
     */
    function syncStartTime() public onlyOwner {
        if(startTime == 0) {
            uint256 _startTime = RewardPool.startTime();
            if(_startTime > 0){
                emit SetStartTime(startTime = _startTime);
            }
        }
    }

    modifier _vote() {
        require(address(RewardPool) != address(0) , "VOTE: RewardPool zero address");
        require(address(SignStage) != address(0) , "VOTE: SignStage zero address");
        require(address(Pick) != address(0) , "VOTE: Pick zero address");
        require(startTime > 0 , "VOTE: StartTime is not synchronized");
        require(block.timestamp > startTime , "VOTE: No start vote");
        _;
    }

    function vote(address idol , uint256 stageId , uint256 amount) external _vote {
        require(SignStage.isSignEffective(idol , stageId) , "VOTE: There is no valid contract with Stage");

        // Burn pick.
        Pick.burnFrom(msg.sender , amount);

        // Record.
        uint256 time = getMinTimeOf(block.timestamp);       // Get the minimum time of block.timestamp.
        dayVotes[idol][time] += amount;
        _record(idol , amount , block.timestamp);

        emit RecordVote(idol , stageId , amount);
    }

    function _record(address idol , uint256 amount , uint256 time) internal {
        uint256 _weekStartTime;
        uint256 _yearStartTime;
        (_weekStartTime , _yearStartTime) = getTimeInfo(time);        

        // Record weekly votes.
        if(weekVotes[idol][_weekStartTime] == 0){
            weekVoteAddress[_weekStartTime].push(idol);
        }
        weekVotes[idol][_weekStartTime] += amount;

        // Recording year votes.
        if(yearVotes[idol][_yearStartTime] == 0){
            yearVoteAddress[_yearStartTime].push(idol);
        }
        yearVotes[idol][_yearStartTime] += amount;
    }

    /**
     * @dev Returns the address that was voted for within a week.
     */
    function getWeekVoteAddress(uint256 weekStartTime) external view returns(address[] memory) {
        return weekVoteAddress[weekStartTime];
    }

    /**
     * @dev Returns the address and the number of votes received within a week.
     */
    function getWeekVoteAddressVoteNum(uint256 weekStartTime) external view returns (address[] memory , uint256[] memory) {
        address[] memory addrs = weekVoteAddress[weekStartTime];
        uint256 length = addrs.length;
        uint256[] memory nums = new uint256[](length);

        for(uint256 i; i < length; i++){
            nums[i] = weekVotes[addrs[i]][weekStartTime];
        }

        return (addrs , nums);
    }

    /**
     * @dev Returns the address that was voted for within a year.
     */
    function getYearVoteAddress(uint256 yearStartTime) external view returns(address[] memory) {
        return yearVoteAddress[yearStartTime];
    }

    /**
     * @dev Returns the address and the number of votes received within a year.
     */
    function getYearVoteAddressVoteNum(uint256 yearStartTime) external view returns(address[] memory , uint256[] memory) {
        address[] memory addrs = yearVoteAddress[yearStartTime];
        uint256 length = addrs.length;
        uint256[] memory nums = new uint256[](length);

        for(uint256 i; i < length; i++){
            nums[i] = yearVotes[addrs[i]][yearStartTime];
        }

        return (addrs , nums);
    }

    /**
     * @dev Returns the number of idol votes from the startTime to the endTime.
     */
    function getVoteAmount(address idol , uint256 startTime , uint256 endTime) external view returns (uint256) {
        startTime = getMinTimeOf(startTime);
        endTime = getMinTimeOf(endTime);
        uint256 amount;
        for( ; startTime <= endTime ; startTime += 1 days) {
            amount += dayVotes[idol][startTime];
        }

        return amount;
    }

    /**
     * @dev Returns idol's number of votes for the day.
     */
    function getDayVoteAmount(address idol , uint256 time) external view returns (uint256) {
        return dayVotes[idol][getMinTimeOf(time)];
    }

    /**
     * @dev Returns the number of votes received each day.
     */
    function getDaysVoteAmount(address idol , uint256 startTime , uint256 endTime) external view returns(uint256[] memory) {
        startTime = getMinTimeOf(startTime);
        endTime = getMinTimeOf(endTime);
        uint256[] memory nums = new uint256[]((endTime - startTime) / (1 days) + 1);
        for(uint256 i ; startTime <= endTime ; startTime += 1 days) {
            nums[i++] = dayVotes[idol][startTime];
        }
        return nums;
    }

    /**
     * @dev Returns the number of votes received by idol for the week.
     */
    function getWeekVoteAmount(address idol , uint256 weekStartTime) external view returns (uint256) {
        return weekVotes[idol][weekStartTime];
    }

    /**
     * @dev Returns the number of votes received by idol for the year.
     */
    function getYearVoteAmount(address idol , uint256 yearStartTime) external view returns (uint256) {
        return yearVotes[idol][yearStartTime];
    }

    function getMinTimeOf(uint256 time) public pure returns(uint256) {
        return time / 1 days * 1 days;
    }
    
    function getTimeInfo(uint256 time) public view returns (uint256 , uint256) {
        uint256 _days = (time - startTime) % (1 days) > 0 ? (time - startTime) / (1 days) + 1 : (time - startTime) / (1 days);

        uint256 _week = _days % 7 > 0 ? _days / 7 + 1 : _days / 7;
        uint256 _weekStartTime = (_week - 1) * (7 days) + startTime;
        
        uint256 _year = _week % 52 > 0 ? _week / 52 + 1 : _week / 52;
        uint256 _yearStartTime = (_year - 1) * (52 * 7 days) + startTime;
        
        return (_weekStartTime , _yearStartTime);
    }

    
}
