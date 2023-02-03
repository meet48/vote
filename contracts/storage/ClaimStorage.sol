// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @dev Meet token.
 */
interface IMeet is IERC20 {}

/**
 * @dev Claim storage.
 */
contract ClaimStorage {

    // Meet token.
    IMeet public Meet;

    // This address, it records how much the user withdrew.
    address public recordRole;

    // locked.
    bool internal _locked;

    // Record the amount withdrawn by the user.
    mapping(address => uint256) internal _balances;    

    event UpdateMeet(address _address);
    event SetRecordRole(address _old , address _new);
    event AddAmount(address _address , uint256 amount);
    event Withdraw(address _address , uint256 amount);

}
