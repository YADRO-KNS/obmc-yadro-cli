# Phosphor Command-line interface for mere mortals
Phosphor CLI is a Bash-based shell. This shell is used by non-system users
to manage the OpenBMC system.
This project contains scripts that simplify access to system setup.

## Access permission
Different users may have different access rights. Some of them need access
to system resources that belong to root.

Current implementation founded on Linux groups and `sudo` usage.

OpenBMC has three predefined groups:
- `priv-admin` (administrators);
- `priv-operator` (operators);
- `priv-user` (others).

Each group has its own permissions. The installer (`./install.sh`) creates a
sudo configuration for each script - links between executable modules and
Linux groups. This configuration allows group members to run scripts with
elevated privileges.
