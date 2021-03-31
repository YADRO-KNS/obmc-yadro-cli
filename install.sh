#!/bin/sh -eu
#
# YADRO OpenBMC Command Line Interface Installer
# Copyright (C) 2020-2021 YADRO
#
# SPDX-License-Identifier: Apache-2.0
#

THIS_DIR="$(realpath "$(dirname "$0")")"
INSTALL_ROOT=""
MACHINE="nicole"

ROLE_ADMIN="admin"
ROLE_OPERATOR="operator"
ROLE_USER="user"
ROLES_ALL="${ROLE_ADMIN} ${ROLE_OPERATOR} ${ROLE_USER}"

GROUP_ADMIN="priv-admin"
GROUP_OPERATOR="priv-operator"
GROUP_USER="priv-user"

# Single-quotes are a must, or extra escaping needs to be added
GROUP_REGEX='priv-[^ ]\\+'

BIN_DIR="/usr/bin"
SHARE_DIR="/usr/share/cli"
SUDO_DIR="/etc/sudoers.d"

DEFAULT_PROFILE="/etc/profile.d/default.sh"
HELP_FILE="${SHARE_DIR}/help"

# parse command line options
while [ $# -gt 0 ]; do
  case "$1" in
    -h | --help)
      echo "Phosphor CLI installer."
      echo "Use: ${0##*/} OPTION..."
      echo "Default options are specified in brackets."
      echo "  -d, --dir PATH        Path to sysroot (target root directory)"
      echo "  -m, --machine NAME    Target machine name [${MACHINE}]"
      echo "  -a, --admin NAME      Group name for administrators [${GROUP_ADMIN}]"
      echo "  -o, --operator NAME   Group name for operators [${GROUP_OPERATOR}]"
      echo "  -u, --user NAME       Group name for users [${GROUP_USER}]"
      echo "  -x, --regex REGEX     Regex to match all Groups, must have"
      echo "                        special chars escaped against shell"
      echo "                        expansion"
      echo "  -h, --help            Print this help and exit"
      exit 0
      ;;
    -d | --dir) INSTALL_ROOT="$2"; shift;;
    -m | --machine) MACHINE="$2"; shift;;
    -a | --admin) GROUP_ADMIN="$2"; shift;;
    -o | --operator) GROUP_OPERATOR="$2"; shift;;
    -u | --user) GROUP_USER="$2"; shift;;
    -x | --regex) GROUP_REGEX="$2"; shift;;
    *)
      echo "Invalid argument: $1" >&2
      exit 1
      ;;
  esac
  shift
done
if [ -z "${INSTALL_ROOT}" ]; then
  echo "ERROR: Installation directory was not specified." >&2
  exit 1
fi

# Install script file.
# param: path to the script file to install
install_cli_script() {
  src_file="$1"
  cmd_name="$(basename "${src_file}" | sed -r 's/(.+)\..+|(.*)/\1\2/')"
  cmd_desc="$(sed -n 's/^# *CLI: *//p' "${src_file}")"
  cmd_restrict="$(sed -n 's/^# *Restrict: *//p' "${src_file}")"
  real_file="${SHARE_DIR}/${cmd_name}"
  link_file="${BIN_DIR}/${cmd_name}"
  sudo_file="${INSTALL_ROOT}${SUDO_DIR}/cli_${cmd_name}"

  if [ -z "${cmd_restrict}" ]; then
    cmd_restrict="${ROLES_ALL}"
  fi

  # check
  for check_file in ${real_file} ${link_file} ${sudo_file}; do
    if [ -e "${INSTALL_ROOT}${check_file}" ]; then
      echo "ERROR: File ${check_file} already exist." >&2
      exit 1
    fi
  done
  unset check_file
  if [ -z "${cmd_desc}" ]; then
    echo "ERROR: Script ${cmd_name} doesn't contain description" >&2
    exit 1
  fi

  # create destination dirs
  install --mode 0755 -d "${INSTALL_ROOT}${BIN_DIR}"
  install --mode 0755 -d "${INSTALL_ROOT}${SHARE_DIR}"
  install --mode 0750 -d "${INSTALL_ROOT}${SUDO_DIR}"

  # install script file with link
  sed -e "s/%GROUP_ADMIN%/${GROUP_ADMIN}/g" \
      -e "s/%GROUP_OPERATOR%/${GROUP_OPERATOR}/g" \
      -e "s/%GROUP_USER%/${GROUP_USER}/g" \
      -e "s/%GROUP_REGEX%/${GROUP_REGEX}/g" \
      "${src_file}" > "${INSTALL_ROOT}${real_file}"
  chmod 0444 "${INSTALL_ROOT}${real_file}"
  ln -sr "${INSTALL_ROOT}${BIN_DIR}/clicmd" "${INSTALL_ROOT}${link_file}"

  # setup sudo
  # We don't need any backslashes to come through here,
  # so no `-r` on `read` is intentional.
  # shellcheck disable=SC2162
  sed -n '/#\s*@sudo/s/.*@sudo\s*cmd_//p' "${src_file}" | while read cmd roles; do
    if [ -z "${cmd}" ] || [ -z "${roles}" ]; then
      echo "ERROR: Invalid @sudo entry, file ${src_file}, command ${cmd}" >&2
      exit 1
    fi
    cmd="$(echo "${cmd}" | tr '_' ' ')"
    for role in $(echo "${roles}" | tr ',' ' '); do
      case "${role}" in
        "${ROLE_ADMIN}")    group="${GROUP_ADMIN}";;
        "${ROLE_OPERATOR}") group="${GROUP_OPERATOR}";;
        "${ROLE_USER}")     group="${GROUP_USER}";;
        *)
          echo "ERROR: Unknown role ${role} in file ${src_file}, command ${cmd}" >&2
          exit 1;;
      esac
      echo "%${group} ALL=(ALL) NOPASSWD: ${link_file} ${cmd}" >> "${sudo_file}"
      echo "%${group} ALL=(ALL) NOPASSWD: ${link_file} ${cmd} *" >> "${sudo_file}"
    done
  done
  unset cmd roles role group
  # The GROUP variable is used to pass the original group of the caller
  # to the escalated invocation, need to keep it
  echo "Defaults!${link_file} env_keep+=GROUP" >> "${sudo_file}"
  chmod 0440 "${sudo_file}"

  # add command to autocompletion
  echo "complete -F _cli_completion ${cmd_name}" >> "${INSTALL_ROOT}${DEFAULT_PROFILE}"

  # register command in help
  for role in ${cmd_restrict}; do
    echo "${cmd_name} ${cmd_desc}" >> "${INSTALL_ROOT}${HELP_FILE}.${role}"
  done
  unset role

  unset sudo_file link_file real_file cmd_desc cmd_name cmd_restrict src_file
}

echo "Installing Phosphor CLI environment to '${INSTALL_ROOT}' for '${MACHINE}':"

install -DT --mode 0555 "${THIS_DIR}/clicmd" "${INSTALL_ROOT}/usr/bin/clicmd"
sed -e "s/%GROUP_ADMIN%/${GROUP_ADMIN}/g" \
    -e "s/%GROUP_OPERATOR%/${GROUP_OPERATOR}/g" \
    -e "s/%GROUP_USER%/${GROUP_USER}/g" \
    -e "s/%GROUP_REGEX%/${GROUP_REGEX}/g" \
    -i "${INSTALL_ROOT}/usr/bin/clicmd"
install -DT --mode 0644 "${THIS_DIR}/profile.in" "${INSTALL_ROOT}${DEFAULT_PROFILE}"
install -DT --mode 0644 "${THIS_DIR}/functions" \
    "${INSTALL_ROOT}${SHARE_DIR}/.include/functions"

for SRC_FILE in "${THIS_DIR}/commands"/*; do
  # filter out by target machine
  SRC_TARGET="$(basename "${SRC_FILE}" | sed -r 's/.+\.(.+)|.*/\1/')"
  printf "Script %-25s" "'$(basename "${SRC_FILE}")'"
  if [ -n "${SRC_TARGET}" ] && [ "${SRC_TARGET}" != "${MACHINE}" ]; then
    echo "[SKIP]"
  else
    echo "[INSTALL]"
    install_cli_script "${SRC_FILE}"
  fi
done

# do not lecture users on the rules of sudo because
# sudo is prohibited by default when CLI is installed
echo "Defaults:ALL passwd_tries = 0, lecture = never" \
     > "${INSTALL_ROOT}${SUDO_DIR}/sudo_defaults"

echo "Installation completed successfully"
