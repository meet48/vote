// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./storage/SignStageStorage.sol";

/**
 * @dev SignStage.
 */
contract SignStage is Ownable , SignStageStorage {

    constructor() {}

    function init(IStage _stage) external onlyOwner {
        Stage = _stage;
        emit SetStage(address(_stage));
    }

    /**
     * @dev The caller can only be the stage owner.
     */
    modifier onlyStageOwner(uint256 stageId) {
        require(msg.sender == Stage.ownerOf(stageId) , "SIGNSTAGE: caller is not a stage owner");
        _;
    }

    function setStageMinSignTime(uint256 stageId , uint256 minSignTime) external onlyStageOwner(stageId) {
        require(minSignTime > 0 , "SIGNSTAGE: the value of time must be greater than 0");
        stageSets[stageId].minSignTime = minSignTime;
        emit SetStageMinSignTime(stageId , minSignTime);
    }

    function setStageFee(uint256 stageId , uint256 _fee) external onlyStageOwner(stageId) {
        require(_fee > 0 && _fee <= MAXFEE , "SIGNSTAGE: value out of range");
        stageSets[stageId].fee = _fee;
        emit SetStageFee(stageId , _fee);
    }

    function startSign(uint256 stageId) external onlyStageOwner(stageId) {
        require(!stageSets[stageId].isStart , "SIGNSTAGE: start");
        require(stageSets[stageId].minSignTime > 0 , "SIGNSTAGE: the minSignTime is not set");
        require(stageSets[stageId].fee > 0 , "SIGNSTAGE: the stage fee is not set");

        stageSets[stageId].isStart = true;
        emit StartSign(stageId);
    }

    function closeSign(uint256 stageId) external onlyStageOwner(stageId) {
        require(stageSets[stageId].isStart , "SIGNSTAGE: close");
        stageSets[stageId].isStart = false;
        emit CloseSign(stageId);
    }

    /**
     * @dev Sign.
     * Idol can only sign one stage at a time.
     */
    function sign(uint256 stageId , uint256 startTime , uint256 endTime) external {
        require(stageSets[stageId].isStart , "SIGNSTAGE: the stage is closed for signing");
        require(startTime <= endTime , "SIGNSTAGE: the startTime is smaller than the endTime");

        // Whether the stage has been signed between the start time and the end time.
        startTime = getMinTimeOf(startTime);
        endTime = getMinTimeOf(endTime);        
        bool _isSign;
        (_isSign , ) = isSign(msg.sender , stageId , startTime , endTime);

        require(!_isSign , "SIGNSTAGE: signed up for the stage");

        _sign(stageId , startTime , endTime , stageSets[stageId].fee);
    }

    function _sign(uint256 stageId , uint256 startTime , uint256 endTime , uint256 fee) internal {
        startTime = getMinTimeOf(startTime);
        endTime = getMaxTimeOf(endTime);
        require(startTime >= getMinTimeOf(block.timestamp) && startTime <= endTime , "SIGNSTAGE: startTime, endTime is incorrect");
        require(endTime - startTime >= stageSets[stageId].minSignTime , "SIGNSTAGE: the signing time is less than required");

        bytes32 _bytes = _getBytes(stageId , startTime , endTime);
        Info memory _info;
        _info.idol = msg.sender;
        _info.stageId = stageId;
        _info.startTime = startTime;
        _info.endTime = endTime;
        _info.fee = fee;

        signInfos[_bytes] = _info;
        idols[msg.sender].push(_bytes);
        stages[stageId].push(_bytes);
        idolStages[msg.sender][stageId] = _bytes;

        emit SignInfo(msg.sender , stageId , startTime , endTime , fee);
    }

    /**
     * @dev Returns whether idol is signing with the stage.
     */
    function isSignEffective(address _address , uint256 stageId) external view returns (bool) {
        bool _isSign;
        (_isSign , ) = isSign(_address , stageId , block.timestamp , block.timestamp);
        return _isSign;
    }

    /**
     * @dev Returns whether idol is signed to the stage during the start time and end time.
     */
    function isSign(address _address , uint256 stageId , uint256 startTime , uint256 endTime) public view returns (bool , Info[] memory) {
        startTime = getMinTimeOf(startTime);
        endTime = getMinTimeOf(endTime);

        uint256 length = idols[_address].length;
        bytes32[] memory _bytes = new bytes32[](length);
        uint256 count;

        for(uint256 i; i < length ; i++){
            bytes32 _b = idols[_address][i];
            Info memory _info = signInfos[_b]; 
            if(_info.stageId == stageId && _info.startTime <= endTime && startTime <= _info.endTime){
                _bytes[count++] = _b;
            }
        }

        // Return info.
        Info[] memory infos = new Info[](count);
        for(uint256 j; j < count ; j++){
            infos[j] = signInfos[_bytes[j]];
        }


        return ( (count > 0 ? true : false) , infos);
    }

    /**
     * @dev Returns idol and stage the final signing.
     */
    function getLastSign(address _address , uint256 stageId) external view returns (bool , Info memory) {
        bytes32 _bytes = idolStages[_address][stageId];
        return (signInfos[_bytes].startTime > 0 ? true : false , signInfos[_bytes]);
    }

    /**
     * @dev Returns idol's last signing information.
     */
    function getLastSignOfAddress(address _address) public view returns(bool , uint256 , Info memory) {
        uint256 stageId;
        Info memory _info;
        uint256 _length = idols[_address].length;
        if(_length > 0){
            bytes32 _bytes = idols[_address][_length - 1];
            stageId = signInfos[_bytes].stageId;
            _info = signInfos[_bytes];
        }

        return (stageId > 0 ? true : false , stageId , _info);
    }

    /**
     * @dev Returns all idol signings during the start time and end time.
     */
    function getAddressSign(address _address , uint256 startTime , uint256 endTime) public view returns(Info[] memory) {
        startTime = getMinTimeOf(startTime);
        endTime = getMinTimeOf(endTime);
        require(startTime < endTime , "SIGNSTAGE: the startTime is smaller than the endTime");

        uint256 length = idols[_address].length;
        uint256 count;
        bytes32[] memory _bytes = new bytes32[](length);

        for(uint256 i; i < length ; i++){
            bytes32 _bi = idols[_address][i];
            if(signInfos[_bi].startTime <= endTime && startTime <= signInfos[_bi].endTime){
                _bytes[count++] = _bi;
            }
        }
        
        Info[] memory infos = new Info[](count);
        for(uint256 j; j < count ; j++){
            infos[j] = signInfos[_bytes[j]];
        }

        return infos;
    }

    /**
     * @dev Returns the signing data from the start time to the end time of the stage.
     */
    function getStageSign(uint256 stageId , uint256 startTime , uint256 endTime) external view returns (Info[] memory) {
        startTime = getMinTimeOf(startTime);
        endTime = getMinTimeOf(endTime);
        require(startTime <= endTime , "SIGNSTAGE: the startTime is smaller than the endTime");
        
        uint256 length = stages[stageId].length;
        uint256 count;
        bytes32[] memory _bytes = new bytes32[](length);

        for(uint256 i; i < length; i++){
            bytes32 _bi = stages[stageId][i];
            if(signInfos[_bi].startTime <= endTime && startTime <= signInfos[_bi].endTime){
                _bytes[count++] = _bi;
            }
        }

        Info[] memory infos = new Info[](count);
        for(uint256 j; j < count; j++){
            infos[j] = signInfos[_bytes[j]];
        }

        return infos;
    }

    /**
     * @dev Returns idol signing total.
     */    
    function getAddressSignTotal(address _address) external view returns (uint256) {
        return idols[_address].length;
    }

    /**
     * @dev Returns stage signing total.
     */
    function getStageSignTotal(uint256 stageId) external view returns (uint256) {
        return stages[stageId].length;
    }

    function getStageSet(uint256 stageId) external view returns(StageSet memory) {
        return stageSets[stageId];
    }

    function getMinTimeOf(uint256 time) public pure returns(uint256) {
        return time / 1 days * 1 days;
    }

    function getMaxTimeOf(uint256 time) public pure returns(uint256) {
        return getMinTimeOf(time) + 1 days - 1;
    }

    function _getBytes(uint256 stageId , uint256 startTime , uint256 endTime) internal view returns (bytes32) {
        return keccak256(abi.encode(msg.sender , stageId , startTime , endTime , block.timestamp));
    }

}
