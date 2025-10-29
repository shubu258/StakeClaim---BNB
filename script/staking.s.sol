// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";
import {staking} from "../src/staking.sol";
import {ERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

/// @dev Simple ERC20 used only for local deployment/testing
contract TestToken is ERC20 {
    constructor() ERC20("Test Token", "TST") {
        // mint 1_000_000 tokens to deployer
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }
}

contract StakingScript is Script {
    staking public stakingContract;
    TestToken public token;

    function setUp() public {}

    function run() public {
        // start broadcasting transactions (uses private key from env)
        vm.startBroadcast();

        // allow using an existing token on the network by setting TOKEN_ADDRESS env var
        address tokenAddr = vm.envAddress("TOKEN_ADDRESS");
        if (tokenAddr == address(0)) {
            // no token provided -> deploy a test token locally / on testnet
            token = new TestToken();
            tokenAddr = address(token);
        }

        // deploy staking contract using the token address
        stakingContract = new staking(IERC20(tokenAddr));

        // print deployed addresses for convenience
        console.log("Token:", tokenAddr);
        console.log("Staking:", address(stakingContract));

        vm.stopBroadcast();
    }
}
