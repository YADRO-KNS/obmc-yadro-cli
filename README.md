# YADRO OpenBMC Command Line Interface for end users
Phosphor CLI is a Bash-based shell. This shell is used by non-system users
to manage the OpenBMC system.
This project contains scripts that simplify access to system setup.

## Access permission
Different users may have different access rights. Some of them need access
to system resources that belong to root.

Current implementation is based on Linux groups and `sudo` usage.

OpenBMC has three predefined groups:
- `priv-admin` (administrators);
- `priv-operator` (operators);
- `priv-user` (others).

Each group has its own permissions. The installer (`./install.sh`) creates a
sudo configuration for each script - links between executable modules and
Linux groups. This configuration allows for group members to run scripts with
elevated privileges.

## Adding new features
New script must be placed into one of the predefined directory:
- `admin` (administrators);
- `operator` (operators);
- `user` (others).

The script must contain description used for constructing system-wide help.
Description is a comment inside the script started with identifier `CLI:`,
for example:
`# CLI: One-line comment that describes command purpose`
