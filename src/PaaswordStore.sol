// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.13;

//This code base do not pass the rekt test 

contract PasswordStore{
    error PasswordStore_NotOwner ();

    address private s_owner; 
    string private s_password;

    event PasswordSetNet();

    constructor() {
        s_owner = msg.sender;
    }

    /**
     * @notice This function allows only the owner to set a new password.
     * @dev Set the password
     * @param newPassword the new password to set
     */

    function SetPassword(string memory newPassword) external {
        s_password = newPassword;
        emit PasswordSetNet();
    }

    /**
     * @notice This function allows only the owner to get the password.
     * @dev Get the password
     * @return the password
     */

    function GetPassword() external view returns (string memory) {
        if (msg.sender != s_owner) {
            revert PasswordStore_NotOwner();
        }
        return s_password;
    }
}