// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "../src/Kiosk.sol";
import "@openzeppelin/contracts/mocks/ERC1155Mock.sol";

contract KioskTest is Test {
    Kiosk public kiosk;
    ERC1155Mock public realmTicket;
    address admin = address(0x01);
    address treasury = address(0x02);
    address alice = address(0x03);
    address bob = address(0x04);

    event ExperienceSet(
        uint256 indexed _id,
        uint256 price,
        uint256 deadline,
        uint256 quota
    );

    function setUp() public {
        // Deploy mock realm ticket
        realmTicket = new ERC1155Mock("");
        kiosk = new Kiosk(address(realmTicket), treasury, admin);
    }

    function testRealmTicketAddress() public {
        assertEq(kiosk.REALM_TICKET(), address(realmTicket));
    }

    function testTreasury() public {
        assertEq(kiosk.treasury(), treasury);
    }

    function testOwnershipTransferred() public {
        assertEq(kiosk.owner(), admin);
    }

    function testOwnerCanSetTreasury() public {
        assertEq(kiosk.treasury(), treasury);

        vm.startPrank(admin);
        kiosk.setTreasury(alice);
        vm.stopPrank();

        assertEq(kiosk.treasury(), alice);
    }

    function testNonOwnerCannotSetTreasury() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));
        kiosk.setTreasury(alice);
        vm.stopPrank();
    }

    function testOwnerCanSetExperienceDetails() public {
        uint256 price;
        uint256 deadline;
        uint256 quota;
        uint256 remaining;

        (price, deadline, quota, remaining) = kiosk.mocaExperience(0);
        assertEq(price, 0);
        assertEq(deadline, 0);
        assertEq(quota, 0);
        assertEq(remaining, 0);

        vm.startPrank(admin);
        vm.expectEmit(true, true, false, true);
        emit ExperienceSet(0, 1, 2, 3);
        kiosk.setExperienceDetails(0, 1, 2, 3);
        vm.stopPrank();

        (price, deadline, quota, remaining) = kiosk.mocaExperience(0);
        assertEq(price, 1);
        assertEq(deadline, 2);
        assertEq(quota, 3);
        assertEq(remaining, 3);
    }

    function testNonOwnerCannotSetExperienceDetails() public {
        vm.startPrank(alice);
        vm.expectRevert(abi.encodePacked("Ownable: caller is not the owner"));
        kiosk.setExperienceDetails(0, 1, 2, 3);
        vm.stopPrank();
    }

    function testCannotSetZeroPriceForExperienceDetails() public {
        vm.startPrank(admin);
        vm.expectRevert(abi.encodePacked("Kiosk: zero price"));
        kiosk.setExperienceDetails(0, 0, 2, 3);
        vm.stopPrank();
    }

    function testCannotSetPassedDeadlineForExperienceDetails() public {
        vm.startPrank(admin);
        kiosk.setExperienceDetails(1, 1, block.timestamp, 3);
        vm.expectRevert(abi.encodePacked("Kiosk: deadline passed"));
        kiosk.setExperienceDetails(0, 1, block.timestamp - 1, 3);
        vm.stopPrank();
    }

    function testCanPurchaseExperienceWhenQuotaIsAvailable() public {
        vm.startPrank(admin);
        kiosk.setExperienceDetails(0, 1, 2, 3);
        vm.stopPrank();

        // check balance of treasury
        uint256 pre = realmTicket.balanceOf(treasury, 0);

        vm.startPrank(alice);
        uint256 aliceTicketAmount = 2;
        realmTicket.mint(alice, 0, aliceTicketAmount, "");
        realmTicket.setApprovalForAll(address(kiosk), true);
        kiosk.purchaseExperience(0, 2);
        vm.stopPrank();

        uint256 post = realmTicket.balanceOf(treasury, 0);
        assertEq(post - pre, aliceTicketAmount);

        vm.startPrank(bob);
        realmTicket.mint(bob, 0, 1, "");
        realmTicket.setApprovalForAll(address(kiosk), true);
        kiosk.purchaseExperience(0, 1);
        vm.stopPrank();

        uint256 postPost = realmTicket.balanceOf(treasury, 0);
        assertEq(postPost - post, 1);
    }

    function testCannotPurchaseExperienceWhenQuotaIsNotAvailable() public {
        vm.startPrank(admin);
        kiosk.setExperienceDetails(0, 1, 3, 2);
        vm.stopPrank();

        vm.startPrank(alice);
        realmTicket.mint(alice, 0, 3, "");
        realmTicket.setApprovalForAll(address(kiosk), true);
        vm.expectRevert(abi.encodePacked("Kiosk: amount > remaining"));
        kiosk.purchaseExperience(0, 3);
        vm.stopPrank();
    }

    function testUnlimitedQuota() public {
        vm.startPrank(admin);
        kiosk.setExperienceDetails(0, 1, block.timestamp + 1000, 0);
        vm.stopPrank();

        uint256 max = 2 ** 256 - 1;

        vm.startPrank(alice);
        realmTicket.mint(alice, 0, max, "");
        realmTicket.setApprovalForAll(address(kiosk), true);
        kiosk.purchaseExperience(0, max);
        vm.stopPrank();
    }

    function testCannotPurchaseExperienceWhenDeadlineHasPassed(
        uint256 id,
        uint256 price,
        uint256 quota
    ) public {
        vm.assume(price > 0);

        vm.startPrank(admin);
        kiosk.setExperienceDetails(id, price, block.timestamp, quota);
        vm.stopPrank();

        vm.warp(1);

        vm.startPrank(alice);
        realmTicket.mint(alice, 0, price, "");
        realmTicket.setApprovalForAll(address(kiosk), true);
        vm.expectRevert(abi.encodePacked("Kiosk: missed deadline"));
        kiosk.purchaseExperience(0, 1);
        vm.stopPrank();
    }
}
