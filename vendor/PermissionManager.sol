// SPDX-License-Identifier: MIT

/*
 * This file is part of the Autumn aVault Smart Contract
 */

pragma solidity ^0.7.3;
pragma experimental ABIEncoderV2;

import "./Ownable.sol";

/**
 * @title Manage and restrict permission by roles
 */
contract PermissionManager is Ownable {

    // Roles

    struct RoleInfo {
        bool exists;
        uint256 limit;
        uint256 index;
    }

    mapping (string => RoleInfo) roles;

    string[] public roleList;

    function listRoles() external view returns (string[] memory) {
        return roleList;
    }

    function addRole(string memory role, uint256 limit) onlyOwner() public {
        require(!roles[role].exists, "PermissionManager@addRole: already added");
        roles[role] = RoleInfo(true, limit, roleList.length);
        roleList.push(role);

        emit RoleAdded(role);
    }

    function removeRole(string memory role) onlyOwner() public {
        require(roles[role].exists, "PermissionManager@addRole: role not added");
        uint256 atArray = roles[role].index;
        roleList[atArray] = roleList[roleList.length - 1];
        roleList.pop();
        delete roles[role];

        emit RoleRemoved(role);
    }

    event RoleAdded(string indexed role);
    event RoleRemoved(string indexed role);

    // Permissions

    struct PermissonInfo {
        bool has;
        uint256 index;
    }
    
    mapping (string => mapping (address => PermissonInfo)) permissions;

    mapping (string => address[]) permissionList;

    function listPermissions(string memory role) external view returns (address[] memory) {
        return permissionList[role];
    }

    modifier requirePermission(string memory role) {
        require(
            permissions[role][_msgSender()].has,
            string(abi.encodePacked("PermissionManager@requirePermission: no permission ", role)));
        _;
    }

    function setPermission(string memory role, address user, bool permit) onlyOwner() public {
        RoleInfo memory roleInfo = roles[role];
        require(roleInfo.exists, "PermissionManager@setPermission: role not exists");
        require(permissions[role][user].has != permit, "PermissionManager@setPermission: already set");
        
        uint256 permissionListSize = permissionList[role].length;

        if (permit) {
            require(roleInfo.limit == 0 || roleInfo.limit > permissionListSize, "PermissionManager@setPermission: exceeds role limit");
            permissions[role][user] = PermissonInfo(true, permissionListSize);
            permissionList[role].push(user);

        } else {
            uint256 atList = permissions[role][user].index;
            permissionList[role][atList] = permissionList[role][permissionListSize - 1];
            permissionList[role].pop();
            delete permissions[role][user];
        }

        emit PermissionUpdated(role, user, permit);
    }

    event PermissionUpdated(string indexed role, address indexed user, bool permission);

    // Wrappers

    function setSingletonPermission(string memory role, address user) onlyOwner() public {
        PermissionManager.addRole(role, 1);
        PermissionManager.setPermission(role, user, true);
    }
}