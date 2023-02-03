// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./storage/RewardStorage.sol";

/**
 * @dev Reward.
 */
contract Reward is Ownable , RewardStorage {

    constructor() {}

    function init(
            IMeet _meet , 
            IStage _stage , 
            IRewardPool _rewardPool , 
            IVote _vote , 
            ISignStage _signStage , 
            IClaim _claim
        ) external onlyOwner {
        
        Meet = _meet;
        Stage = _stage;
        RewardPool = _rewardPool;
        Vote = _vote;
        SignStage = _signStage;
        Claim = _claim;

        emit UpdateMeet(address(_meet));
        emit UpdateStage(address(_stage));
        emit UpdateRewardPool(address(_rewardPool));
        emit UpdateVote(address(_vote));
        emit UpdateSignStage(address(_signStage));
        emit UpdateClaim(address(_claim));
    }

    modifier _reward() {
        require(address(Meet) == address(0) , "REWARD: Meet zero address");
        require(address(RewardPool) == address(0) , "REWARD: RewardPool zero address");
        require(address(Vote) == address(0) , "REWARD: Vote zero address");
        require(address(SignStage) == address(0) , "REWARD: SignStage zero address");
        require(address(Claim) == address(0) , "REWARD: Claim zero address");
        _;
    }

    /**
     * @dev weekReward, the week before time.
     * Steps:
     * 1. Extract weekly reward to claim contract.
     * 2. Calculate weekly rewards, idol and stage income.
     * 3. Record income in the claim contract.
     */
    function weekReward(uint256 time) external onlyOwner {
        uint256 rewardAddressNum;   // The total number of accounts that can earn rewards.
        uint256 weekStartTime;      
        uint256 weekEndTime;        
                
        // Calculate the start time and end time of the week.
        (weekStartTime) = getWeekStartTime(time);
        weekStartTime -= 7 days;
        weekEndTime = weekStartTime + (7 days) - 1;

        // 1. Extract weekly reward to claim contract.
        uint256 weekAmount;    
        (weekAmount) = RewardPool.withdrawWeekReward(address(Claim) , time);

        // 2. Calculate weekly rewards, idol and stage income.
        address[] memory addrs;     
        uint256[] memory nums;      
        uint256 length;             
        Count[] memory counts;     
        uint256 totalNum;          
        uint256 MAXFEE;             

        (addrs , nums) = Vote.getWeekVoteAddressVoteNum(weekStartTime);
        length = addrs.length;
        counts = new Count[](length);
        (MAXFEE) = SignStage.MAXFEE();
        rewardAddressNum += length;

        // Total votes cast.
        for(uint256 i = 0 ; i < length ; i++){
            totalNum += nums[i];
        }
        
        // Initializes the counts array.
        for(uint256 i = 0 ; i < length; i++){
            counts[i].idol = addrs[i];
            counts[i].voteNum = nums[i];
            counts[i].amount = nums[i] * weekAmount / totalNum;     

            // Signing stageId.
            ISignStage.Info[] memory _infos;
            (_infos) = SignStage.getAddressSign(addrs[i] , weekStartTime , weekEndTime);     

            // Initializes the stage data for the signing.
            counts[i].stageInfos = new StageInfo[](_infos.length);
            for(uint256 k ; k < _infos.length; k++){
                counts[i].stageInfos[k].stageId = _infos[k].stageId;
                counts[i].stageInfos[k].owner = Stage.ownerOf(_infos[k].stageId);
                counts[i].stageInfos[k].startTime = _infos[k].startTime;
                counts[i].stageInfos[k].endTime = _infos[k].endTime;
                counts[i].stageInfos[k].fee = _infos[k].fee;
            }

            rewardAddressNum += _infos.length;
        }

        // Calculate the reward.
        for(uint256 i = 0 ; i < length; i++){
            Count memory _count = counts[i];

            // Signing data.
            StageInfo[] memory infos = counts[i].stageInfos;

            // There's only one signing.
            if(infos.length == 1){
                counts[i].stageInfos[0].voteNum = _count.voteNum;       
                uint256 a1 = _count.amount * infos[0].fee / MAXFEE;     
                counts[i].stageInfos[0].amount = a1;                    
                counts[i].idolAmount = _count.amount - a1;              
                continue;
            }

            // There are multiple signings.
            uint256[] memory dayNums = Vote.getDaysVoteAmount(_count.idol , weekStartTime , weekEndTime);
            uint256 _time = weekStartTime;

            // The day you sign with the stage, the votes go to the stage.
            for(uint256 j ; j < dayNums.length ; j++){

                for(uint256 k ; k < infos.length; k++){
                    if(infos[k].startTime <= _time && _time <= infos[k].endTime){
                        counts[i].stageInfos[k].voteNum += dayNums[j];
                        break;
                    }
                }
                
                _time += 1 days;
            }

            // Calculate stage income.
            counts[i].idolAmount = counts[i].amount;
            for(uint256 j ; j < infos.length; j++){
                counts[i].stageInfos[j].amount = infos[j].voteNum * counts[i].amount * infos[j].fee / counts[i].voteNum / MAXFEE;
                counts[i].idolAmount -= counts[i].stageInfos[j].amount;
            }
        }

        // 3. Record income in the claim contract.
        recordReward(counts , rewardAddressNum);
        
    }

    /**
     * @dev Record reward.
     */
    function recordReward(Count[] memory counts , uint256 addressNum) internal {
        address[] memory addres = new address[](addressNum);
        uint256[] memory nums = new uint256[](addressNum);
        uint256 length = counts.length;
        uint256 k;

        for(uint256 i ; i < length; i++){
            addres[k] = counts[i].idol;
            nums[k] = counts[i].idolAmount;
            k++;
            for(uint256 j ; j < counts[i].stageInfos.length; j++){
                addres[k] = counts[i].stageInfos[j].owner;
                nums[k] = counts[i].stageInfos[j].amount;
                k++;
            }            

        }

        Claim.record(addres , nums);
    }

    /**
     * @dev YearReward, the year before time.
     * Steps:
     * 1. Extract year reward to claim contract.
     * 2. Calculate year rewards, idol and stage income.
     * 3. Record income in the claim contract.
     */
    function yearReward(uint256 time) external onlyOwner {
        uint256 rewardAddressNum;   // The total number of accounts that can earn rewards.
        uint256 yearStartTime;      
        uint256 yearEndTime;        
                
        // Calculate the start time and end time of the year.
        (yearStartTime , yearEndTime) = getPreYearTime(time);

        // 1. Extract year reward to claim contract.
        uint256 yearAmount;
        (yearAmount) = RewardPool.withdrawYearReward(address(Claim) , time);

        // 2. Calculate year rewards, idol and stage income.
        address[] memory addrs;     
        uint256[] memory nums;      
        uint256 length;             
        Count[] memory counts;      
        uint256 totalNum;           
        uint256 MAXFEE;             

        (addrs , nums) = Vote.getYearVoteAddressVoteNum(yearStartTime);
        length = addrs.length;
        counts = new Count[](length);
        (MAXFEE) = SignStage.MAXFEE();
        rewardAddressNum += length;

        // Total votes cast.
        for(uint256 i = 0 ; i < length ; i++){
            totalNum += nums[i];
        }

        // Initializes the counts array.
        for(uint256 i = 0 ; i < length; i++){
            counts[i].idol = addrs[i];
            counts[i].voteNum = nums[i];
            counts[i].amount = nums[i] * yearAmount / totalNum;     
            
            // Signing stageId.
            ISignStage.Info[] memory _infos;
            (_infos) = SignStage.getAddressSign(addrs[i] , yearStartTime , yearEndTime);     

            // Initializes the stage data for the signing.
            counts[i].stageInfos = new StageInfo[](_infos.length);     
            for(uint256 k ; k < _infos.length; k++){
                counts[i].stageInfos[k].stageId = _infos[k].stageId;
                counts[i].stageInfos[k].owner = Stage.ownerOf(_infos[k].stageId);
                counts[i].stageInfos[k].startTime = _infos[k].startTime;
                counts[i].stageInfos[k].endTime = _infos[k].endTime;
                counts[i].stageInfos[k].fee = _infos[k].fee;
            }

            rewardAddressNum += _infos.length;
        }

        // Calculate the reward.
        for(uint256 i = 0 ; i < length; i++){
            Count memory _count = counts[i];

            // Signing data.
            StageInfo[] memory infos = counts[i].stageInfos;

            // There's only one signing.
            if(infos.length == 1){
                counts[i].stageInfos[0].voteNum = _count.voteNum;       
                uint256 a1 = _count.amount * infos[0].fee / MAXFEE;     
                counts[i].stageInfos[0].amount = a1;                    
                counts[i].idolAmount = _count.amount - a1;              
                continue;
            }

            // There are multiple signings.
            for(uint256 j ; j < infos.length ; j++){
                uint256 _start;
                uint256 _end;

                if(infos[j].startTime <= yearStartTime){
                    _start = yearStartTime;
                    _end = (infos[j].endTime <= yearEndTime)? infos[j].endTime : yearEndTime;
                }

                if(infos[j].startTime > yearStartTime){
                    _start = infos[j].startTime;
                    _end = (infos[j].endTime <= yearEndTime)? infos[j].endTime : yearEndTime;
                }

                counts[i].stageInfos[j].voteNum = Vote.getVoteAmount(_count.idol, _start , _end);
            }

            // Calculate stage income.
            counts[i].idolAmount = counts[i].amount;
            for(uint256 j ; j < infos.length; j++){
                counts[i].stageInfos[j].amount = infos[j].voteNum * counts[i].amount * infos[j].fee / counts[i].voteNum / MAXFEE;
                counts[i].idolAmount -= counts[i].stageInfos[j].amount;
            }

        }

        // 3. Record income in the claim contract.
        recordReward(counts , rewardAddressNum); 

    }

    /**
     * @dev Returns the minimum time of day.
     */
    function getMinTimeOf(uint256 time) public pure returns(uint256) {
        return time / 1 days * 1 days;
    }

    /**
     * @dev Returns the startTime of the previous week.
     */
    function getWeekStartTime(uint256 time) public view returns (uint256) {
        uint256 startTime = RewardPool.startTime();
        require(startTime > 0 , "REWAED: rewardPool startTime value zero");

        uint256 _days = (time - startTime) % (1 days) > 0 ? (time - startTime) / (1 days) + 1 : (time - startTime) / (1 days);
        uint256 _week = _days % 7 > 0 ? (_days / 7) + 1 : _days / 7;
        uint256 weekStartTime = (_week - 1) * (7 days) + startTime;

        return weekStartTime;
    }

    /**
     * @dev Returns the startTime and endTime of the previous year.
     */
    function getPreYearTime(uint256 time) public view returns (uint256 , uint256) {
        uint256 startTime = RewardPool.startTime();
        require(startTime > 0 , "REWAED: rewardPool startTime value zero");

        uint256 _days = (time - startTime) % (1 days) > 0 ? (time - startTime) / (1 days) + 1 : (time - startTime) / (1 days);
        uint256 _yearDays = RewardPool.WEEK() * 7;
        uint256 _year = _days % _yearDays > 0 ? (_days / _yearDays) + 1 : _days / 7;
        uint256 yearStartTime = (_year - 1) * _yearDays * (1 days) + startTime;
        require(yearStartTime > startTime , "REWARD: Awards for the previous year");

        uint256 yearEndTime = yearStartTime - 1;    // EndTime of the previous year.
        yearStartTime -= _yearDays * (1 days);      // StartTime of the previous year.

        return (yearStartTime , yearEndTime);
    }


}
