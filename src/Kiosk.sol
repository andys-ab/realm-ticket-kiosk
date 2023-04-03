// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";

contract Kiosk is Ownable {
    struct MocaExperience {
        // TODO: make it more gas efficient with diff types
        uint256 price;
        uint256 deadline;
        uint256 quota;
        uint256 remaining;
    }

    address public immutable REALM_TICKET;
    address public treasury;
    mapping(uint256 => MocaExperience) public mocaExperience;

    event ExperiencePurchased(
        uint256 indexed _id,
        address indexed _user,
        uint256 _amount
    );
    event ExperienceSet(
        uint256 indexed _id,
        uint256 price,
        uint256 deadline,
        uint256 quota
    );
    event TreasurySet(address indexed _treasury);

    constructor(address _realmTicket, address _treasury, address _admin) {
        require(
            _realmTicket != address(0) &&
                _treasury != address(0) &&
                _admin != address(0),
            "Kiosk: zero address in parameters"
        );
        REALM_TICKET = _realmTicket;
        treasury = _treasury;
        _transferOwnership(_admin);
    }

    function purchaseExperience(uint256 _id, uint256 _amount) external {
        require(treasury != address(0), "Kiosk: treasury not set");

        MocaExperience storage experience = mocaExperience[_id];
        require(
            block.timestamp < experience.deadline,
            "Kiosk: missed deadline"
        );

        // When quota is set to 0, it means unlimited quota
        if (experience.quota == 0) {
            IERC1155Upgradeable(REALM_TICKET).safeTransferFrom(
                msg.sender,
                treasury,
                0,
                _amount * experience.price,
                ""
            );
        } else {
            require(
                _amount <= experience.remaining,
                "Kiosk: amount > remaining"
            );

            IERC1155Upgradeable(REALM_TICKET).safeTransferFrom(
                msg.sender,
                treasury,
                0,
                _amount * experience.price,
                ""
            );

            experience.remaining -= _amount;
        }

        emit ExperiencePurchased(_id, msg.sender, _amount);
    }

    function setExperienceDetails(
        uint256 _id,
        uint256 _price,
        uint256 _deadline,
        uint256 _quota
    ) external onlyOwner {
        require(_price != 0, "Kiosk: zero price");
        require(_deadline >= block.timestamp, "Kiosk: deadline passed");
        mocaExperience[_id] = MocaExperience(_price, _deadline, _quota, _quota);

        emit ExperienceSet(_id, _price, _deadline, _quota);
    }

    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "Kiosk: _treasury cannot be zero");
        treasury = _treasury;

        emit TreasurySet(_treasury);
    }
}
