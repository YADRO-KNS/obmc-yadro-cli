# YADRO OpenBMC Command Line Interface for end users
Phosphor CLI is a Bash-based shell. This shell is used by non-system users
to manage the OpenBMC system.
This project contains scripts that simplify access to system setup.

## Access permission
Different users may have different access rights. Some of them need access
to system resources that belong to root.

Current implementation is based on Linux groups and `sudo` usage.

OpenBMC has three predefined groups:
- `priv-admin` (users with role `administrator`);
- `priv-operator` (users with role `operator`);
- `priv-user` (other users).

Each group has its own permissions. The installer (`./install.sh`) creates a
sudo configuration for commands according to function meta data.

## Hierarchical command system
A command can have any number of children subcommands.
Each command must meet the following conditions:
- Function name starts with `cmd_`, each next level is followed by the
  underscore character, e.g. `cmd_sub1_myfunc`;
- Function must have `@doc` tag with description;
- Function may have `@sudo` tag with description;

## Top level (script)
The script must contain description used for constructing system-wide help.
Description is a comment inside the script started with identifier `CLI:`,
for example:
`# CLI: One-line comment that describes command purpose`

## Function declaration

### Execution privileges
End point functions (i.e. functions that do not have children) can have `@sudo`
tag. This tag describes access rights for executing.

Format: `@sudo NAME ROLES`, where `NAME` is the name of the function and `ROLES`
is a comma separated list of roles that can execute this function.

Possible roles:
- `admin` (users with role `administrator`);
- `operator` (users with role `operator`);
- `user` (other users).

Example: `@sudo cmd_reboot admin,operator`

### Function documentation
All public functions must have at least a brief description. A documentation
block starts with tag `@doc NAME` and ends at the function declaration line.
