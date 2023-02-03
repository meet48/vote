// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @dev Meet token.
 */
interface IMeet is IERC20 {}

/**
 * @dev Stage nft.
 */
interface IStage is IERC721 {}

/**
 * @dev RewardPol.
 */
interface IRewardPool {
    function startTime() external view returns (uint256);
    function WEEK() external view returns (uint256);
    function withdrawWeekReward(address to , uint256 time) external returns (uint256 weekAmount);
    function withdrawYearReward(address to , uint256 time) external returns(uint256 yearAmount);
}

/**
 * @dev Vote.
 */
interface IVote {
    function getWeekVoteAddressVoteNum(uint256 weekStartTime) external view returns (address[] memory , uint256[] memory);
    function getYearVoteAddressVoteNum(uint256 yearStartTime) external view returns(address[] memory , uint256[] memory);
    function getDaysVoteAmount(address idol , uint256 startTime , uint256 endTime) external view returns(uint256[] memory);
    function getVoteAmount(address idol , uint256 startTime , uint256 endTime) external view returns (uint256);
}

/**
 * @dev SignStage.
 */
interface ISignStage {
    
    // Signing data.
    struct Info {
        address idol;   
        uint256 stageId;    
        uint256 startTime;  
        uint256 endTime;    
        uint256 fee;    // The percentage of revenue received by the stageId owner. 100% is equal to 10,000.
    }

    function MAXFEE() external view returns (uint256);
    function getAddressSign(address _address , uint256 startTime , uint256 endTime) external view returns(Info[] memory);
}

/**
 * @dev Claim.
 */
interface IClaim {
    function record(address[] memory addrs , uint256[] memory amounts) external;
}

/**
 * @dev RewardStorage.
 */
contract RewardStorage {
    IMeet public Meet;
    IStage public Stage;
    IRewardPool public RewardPool;
    IVote public Vote;
    ISignStage public SignStage;
    IClaim public Claim;

    // Stage data
    struct StageInfo {
        uint256 stageId;    
        address owner;  
        uint256 startTime;  
        uint256 endTime;    
        uint256 fee;    
        uint256 voteNum;    // The number of votes received.
        uint256 amount;     // Income earned during.
    }

    // Count data. used to calculate weekly and annual rewards.
    struct Count {
        address idol;   
        uint256 voteNum;    
        uint256 amount; 
        StageInfo[] stageInfos; 
        uint256 idolAmount; 
    }

    event UpdateMeet(address _address);
    event UpdateStage(address _address);
    event UpdateRewardPool(address _address);
    event UpdateVote(address _address);
    event UpdateSignStage(address _address);
    event UpdateClaim(address _address);
}


