// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {staking} from "../src/staking.sol";

contract TestToken is ERC20 {
    constructor() ERC20("Test Token", "TST") {
        // mint 1_000 tokens with 18 decimals to the deployer (test contract)
        _mint(msg.sender, 1_000 ether);
    }
}

contract StakingFlowTest is Test {
    staking public st;
    TestToken public token;
    address public user = address(0xBEEF);

    function setUp() public {
        token = new TestToken();
        st = new staking(IERC20(address(token)));

        // send some tokens to the mock user
        token.transfer(user, 1_000 ether);
    }

    function test_stake_claim_unstake_flow() public {
        // combined flow is now split into separate tests; keep this as a compatibility check
        uint256 stakeAmount = 100 ether;

        // user must approve staking contract
        vm.prank(user);
        token.approve(address(st), stakeAmount);

        // stake
        vm.prank(user);
        st.stake(stakeAmount, address(0));

        // basic checks
        (uint256 amountStaked,,,,uint256 balance,uint256 roiAvilable) = st.user(user);
        assertEq(amountStaked, stakeAmount);
        assertEq(balance, stakeAmount);
        assertEq(roiAvilable, (stakeAmount * 100) / 10_000);
    }

    function test_stake_only() public {
        uint256 stakeAmount = 200 ether;
        vm.prank(user);
        token.approve(address(st), stakeAmount);
        vm.prank(user);
        st.stake(stakeAmount, address(0));

        (uint256 amountStaked,,,,uint256 balance,uint256 roiAvilable) = st.user(user);
        assertEq(amountStaked, stakeAmount);
        assertEq(balance, stakeAmount);
        assertEq(roiAvilable, (stakeAmount * 100) / 10_000);
    }

    function test_claim_only() public {
        uint256 stakeAmount = 150 ether;
        vm.prank(user);
        token.approve(address(st), stakeAmount);
        vm.prank(user);
        st.stake(stakeAmount, address(0));

        // warp 24h
        vm.warp(block.timestamp + 24 hours);

        vm.prank(user);
        st.claimRoiAmount();

        uint256 expectedRoi = (stakeAmount * 100) / 10_000;
        // initial balance was 1000 - stakeAmount
        uint256 expectedBalanceAfterClaim = (1_000 ether - stakeAmount) + expectedRoi;
        assertEq(token.balanceOf(user), expectedBalanceAfterClaim);

        // roi should be cleared
        (,,,,,uint256 roiAvilable) = st.user(user);
        assertEq(roiAvilable, 0);
    }

    function test_unstake_only() public {
        uint256 stakeAmount = 120 ether;
        vm.prank(user);
        token.approve(address(st), stakeAmount);
        vm.prank(user);
        st.stake(stakeAmount, address(0));

        uint256 unstakeAmount = 60 ether;
        vm.prank(user);
        st.unstake(unstakeAmount);

    // user balance increases by unstakeAmount plus any roi paid during unstake
    uint256 roiPaid = (stakeAmount * 100) / 10_000;
    assertEq(token.balanceOf(user), (1_000 ether - stakeAmount) + unstakeAmount + roiPaid);

        // contract recorded balance decreased
        (,,uint256 lastStaked,,uint256 balance,) = st.user(user);
        assertEq(balance, stakeAmount - unstakeAmount);
    }
}
