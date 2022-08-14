//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Staking {
    address public owner;

    //Stuct to show the position of a particular address
    struct Position {
        uint256 positionId;
        address walletAddress;
        uint256 createdDate;
        uint256 unlockDate;
        uint256 percentInterest;
        uint256 weiStaked;
        uint256 weiInterest;
        bool open;
    }

    Position position;

    //creating a variable to keep track of each position
    uint256 public currentPositionId;

    //every position will be queryable by id of the key its stored under
    mapping(uint256 => Position) public positions;

    //mapping address to array of integers, lets us query all positions created by user
    mapping(address => uint256[]) public positionIdsByAddress;

    //mapping int to int , that includes number of days and its corresponding interest, that a user can stake their Ether
    mapping(uint256 => uint256) public tiers;

    //array of integers that contains different lock periods 30,90,180 days
    uint256[] public lockPeriods;

    //constructor ,payable allows the deployer of contract to send some ether to it,which in this case allows to pay interest on the staked ether
    constructor() payable {
        owner = msg.sender;
        currentPositionId = 0;

        tiers[30] = 700; //7%
        tiers[90] = 1000; //10%
        tiers[180] = 1200; //12%

        lockPeriods.push(30);
        lockPeriods.push(90);
        lockPeriods.push(180);
    }

    //fucntion to stake ether and recieve ether transfers
    function stakeEther(uint256 numDays) external payable {
        require(tiers[numDays] > 0, "Mapping not found");

        //position of the msg.sender
        positions[currentPositionId] = Position(
            currentPositionId,
            msg.sender,
            block.timestamp,
            block.timestamp + (numDays * 1 days),
            tiers[numDays],
            msg.value,
            calculateInterest(tiers[numDays], numDays, msg.value),
            true
        );

        //Allow user to pass in their address and query the positions they own by Id
        positionIdsByAddress[msg.sender].push(currentPositionId);

        currentPositionId += 1;
    }

    ///function to calculate Interest
    function calculateInterest(
        uint256 basisPoints,
        uint256 numDays,
        uint256 weiAmount
    ) private pure returns (uint256) {
        return (basisPoints * weiAmount) / 10000; // 1000 /10000 => 0.1
    }

    //function to allow the owner/deployer of cotnracts to create/change lock periods
    function modifyLockPeriods(uint256 numDays, uint256 basisPoints) external {
        require(owner == msg.sender, "Only owner may modify staking periods");

        tiers[numDays] = basisPoints;
        lockPeriods.push(numDays);
    }

    //function to query all lock periods
    function getLockPeriods() external view returns (uint256[] memory) {
        return lockPeriods;
    }

    //function to return basis point for specific lock duration
    function getInterestRate(uint256 numDays) external view returns (uint256) {
        return tiers[numDays];
    }

    //function to query about amount of staked ether, for a specific wallet
    function getPositionById(uint256 positionId)
        external
        view
        returns (Position memory)
    {
        return positions[positionId];
    }

    //function to get all the positions of a user
    function getPositionIdsForAddress(address walletAddress)
        external
        view
        returns (uint256[] memory)
    {
        return positionIdsByAddress[walletAddress];
    }

    //function to change the unlock date for a Position
    function changeUnlockDate(uint256 positionId, uint256 newUnlockDate)
        external
    {
        require(owner == msg.sender, "Only owner may modify staking dates");

        positions[positionId].unlockDate = newUnlockDate;
    }

    //function to close the position
    function closePosition(uint256 positionId) external {
        require(
            positions[positionId].walletAddress == msg.sender,
            "Only position creator may modify position"
        );
        require(positions[positionId].open == true, "Position is closed");

        positions[positionId].open = false;

        // give amount and rewards,No rewards if unstaked before maturity
        if (block.timestamp > positions[positionId].unlockDate) {
            uint256 amount = positions[positionId].weiStaked +
                positions[positionId].weiInterest;
            payable(msg.sender).call{value: amount}("");
        } else {
            payable(msg.sender).call{value: positions[positionId].weiStaked}(
                ""
            );
        }
    }
}
