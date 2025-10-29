// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
// import "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "lib/openzeppelin-contracts/contracts/access/Ownable.sol";

// ...existing code...
contract staking is Ownable {
    using SafeERC20 for IERC20;

    IERC20 public immutable stakingToken;

    struct UserInfo{
        uint256 amountStaked;
        uint256 roi;
        uint256 lastStaked;
        uint256 totalEarned;
        uint256 balance;
        uint256 roiAvilable;
    }

    mapping(address => UserInfo) public user;

    event amountStaked(uint256 indexed amount, address user);
    event roiClaimed(uint256 roi);
    event refrealPaid(uint256 amountPaid);
    event amountUnstaked(uint256 amount);

    uint256 public constant ROI_CLAIM_AVILABLE = 24 hours; 
    uint256 public constant BPS_PRECISION = 10_000; // 10000 => 100%
    uint256 public constant ROI_BPS = 100;         // 1% = 100 bps
    uint256 public constant REFERRAL_BPS = 50;


    constructor(IERC20 _stakingToken) Ownable(msg.sender) {
        require(address(_stakingToken) != address(0), "token-zero");
        stakingToken = _stakingToken;
    }

    function stake(uint256 amount, address referrer) external {
        require(amount > 0, "amount should be greater than zero");
        address sender = msg.sender;

        stakingToken.safeTransferFrom(sender,address(this), amount);


        uint256 refAmount = 0;
        if (referrer != address(0) && referrer != sender) {
            refAmount = _referrerAmount(amount);
            stakingToken.safeTransfer(referrer, refAmount);
            emit refrealPaid(refAmount);
        }

        uint256 amountStake = amount - refAmount;
        uint256 roiAvilable = _roiClamableAmount(amount);

        UserInfo storage u = user[sender];
        u.amountStaked += amountStake;
        u.lastStaked = block.timestamp;
        u.balance += amountStake;
        u.roiAvilable += roiAvilable;

        emit amountStaked(amountStake, sender);
    }

    function claimRoiAmount() external {
        UserInfo storage u = user[msg.sender];
        require(u.amountStaked > 0, "no stake for user");
        require(u.roiAvilable > 0, "ROI not available");

        // ensure claim interval has passed
        require(block.timestamp >= u.lastStaked + ROI_CLAIM_AVILABLE, "ROI not yet claimable");

        uint256 roiAmount = u.roiAvilable;

        // update state before external call
        u.roiAvilable = 0;
        u.totalEarned += roiAmount;

        stakingToken.safeTransfer(msg.sender, roiAmount);
        emit roiClaimed(roiAmount);
    }

    function unstake(uint256 amount) external {
        require(amount > 0, "amount should be greater than zero");

        UserInfo storage u = user[msg.sender];
        uint256 amountStakedNow = u.amountStaked;
        require(amountStakedNow > 0, "no amount for unstake");

        require(u.balance > amount, "balance is less than amount");

        uint256 roiAvilableNow = u.roiAvilable;
        if(roiAvilableNow > 0){
            u.roiAvilable = 0;
            u.totalEarned += roiAvilableNow;
            stakingToken.safeTransfer(msg.sender, roiAvilableNow);
        }

        u.balance -= amount;
        
        stakingToken.safeTransfer(msg.sender, amount);

        emit amountUnstaked(amount);
    }

    function _roiClamableAmount(uint256 amount) public view returns(uint256){
        return (amount * ROI_BPS) / BPS_PRECISION;
    }

    function _referrerAmount(uint256 amount) public view returns(uint256){
        return (amount * REFERRAL_BPS) / BPS_PRECISION;
    }

}
