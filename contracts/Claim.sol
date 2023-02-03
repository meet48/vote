// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./storage/ClaimStorage.sol";

/**
 * @dev Claim.
 */
contract Claim is Ownable , ClaimStorage {
    
    constructor() {}

    /**
     * @dev Set up meet and recordRole.
     */
    function init(IMeet _meet , address _recordRole) external onlyOwner {
        Meet = _meet;
        emit UpdateMeet(address(_meet));
        emit SetRecordRole(recordRole , recordRole = _recordRole);
    }

    modifier onlyRecord {
        require(msg.sender == recordRole , "Claim: Caller is not record role");
        _;
    }

    modifier noReentrant() {
        require(!_locked , "no re-entrancy");
        _locked = true;
        _;
        _locked = false;
    }

    /**
     * @dev Record the amount withdrawn.
     */
    function record(address[] memory addrs , uint256[] memory nums) external onlyRecord {
        require(addrs.length == nums.length , "Claim: The length of addrs is not the same as the length of nums");
        uint256 length = addrs.length;

        for(uint256 i ; i < length; i++){
            _balances[addrs[i]] += nums[i];
            emit AddAmount(addrs[i] , nums[i]);
        }
    }

    /**
     * @dev Return the amount that can be withdrawn.
     */
    function getClaimAmount(address _address) external view returns (uint256) {
        return _balances[_address];
    }

    /**
     * @dev Withdraw.
     */
    function withdraw() external noReentrant {
        require(_balances[msg.sender] > 0 , "Claim: The balance is zero");
        require(address(Meet) != address(0) , "Claim: Meet address is zero");

        uint256 amount = _balances[msg.sender];
        _balances[msg.sender] = 0;        
        Meet.transfer(msg.sender , amount);
        
        emit Withdraw(msg.sender , amount);
    }

}

