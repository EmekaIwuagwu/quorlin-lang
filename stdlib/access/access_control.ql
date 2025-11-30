# access_control.ql — Role-based access control for Quorlin
# Provides a more granular role-based access control system

from std.errors import Unauthorized

# Events
event RoleGranted(role: bytes32, account: address, sender: address)
event RoleRevoked(role: bytes32, account: address, sender: address)
event RoleAdminChanged(role: bytes32, previous_admin: bytes32, new_admin: bytes32)

contract AccessControl:
    """
    Contract module that allows implementing role-based access control mechanisms.
    Roles are referred to by their bytes32 identifier.
    """

    # Constants
    DEFAULT_ADMIN_ROLE: bytes32 = 0x0000000000000000000000000000000000000000000000000000000000000000

    # State
    roles: mapping[bytes32, mapping[address, bool]]
    role_admins: mapping[bytes32, bytes32]

    @constructor
    def __init__():
        """Initialize with deployer having default admin role."""
        self._grant_role(self.DEFAULT_ADMIN_ROLE, msg.sender)

    # Internal functions
    def _has_role(role: bytes32, account: address) -> bool:
        """Returns true if account has been granted role."""
        return self.roles[role][account]

    def _check_role(role: bytes32):
        """Revert if sender doesn't have role."""
        require(self._has_role(role, msg.sender), "AccessControl: account missing role")

    def _get_role_admin(role: bytes32) -> bytes32:
        """Returns the admin role that controls role."""
        return self.role_admins[role]

    def _grant_role(role: bytes32, account: address):
        """Internal function to grant role to account."""
        if not self._has_role(role, account):
            self.roles[role][account] = True
            emit RoleGranted(role, account, msg.sender)

    def _revoke_role(role: bytes32, account: address):
        """Internal function to revoke role from account."""
        if self._has_role(role, account):
            self.roles[role][account] = False
            emit RoleRevoked(role, account, msg.sender)

    def _set_role_admin(role: bytes32, admin_role: bytes32):
        """Internal function to set admin role."""
        previous_admin: bytes32 = self._get_role_admin(role)
        self.role_admins[role] = admin_role
        emit RoleAdminChanged(role, previous_admin, admin_role)

    # Public functions
    @view
    def has_role(role: bytes32, account: address) -> bool:
        """Returns true if account has been granted role."""
        return self._has_role(role, account)

    @view
    def get_role_admin(role: bytes32) -> bytes32:
        """Returns the admin role that controls role."""
        return self._get_role_admin(role)

    @external
    def grant_role(role: bytes32, account: address):
        """
        Grants role to account.
        Caller must have role's admin role.
        """
        self._check_role(self._get_role_admin(role))
        self._grant_role(role, account)

    @external
    def revoke_role(role: bytes32, account: address):
        """
        Revokes role from account.
        Caller must have role's admin role.
        """
        self._check_role(self._get_role_admin(role))
        self._revoke_role(role, account)

    @external
    def renounce_role(role: bytes32):
        """
        Revokes role from the calling account.
        Allows users to renounce unwanted roles.
        """
        self._revoke_role(role, msg.sender)
