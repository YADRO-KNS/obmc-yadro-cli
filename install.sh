#!/bin/sh -eu

#
# Installer.
#

THIS_DIR="$(realpath "$(dirname "$0")")"
INSTALL_ROOT=""
MACHINE="nicole"

ROLE_ADMIN="admin"
ROLE_OPERATOR="operator"
ROLE_USER="user"

GROUP_ADMIN="priv-admin"
GROUP_OPERATOR="priv-operator"
GROUP_USER="priv-user"

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
      echo "  -h, --help            Print this help and exit"
      exit 0
      ;;
    -d | --dir) INSTALL_ROOT="$2"; shift;;
    -m | --machine) MACHINE="$2"; shift;;
    -a | --admin) GROUP_ADMIN="$2"; shift;;
    -o | --operator) GROUP_OPERATOR="$2"; shift;;
    -u | --user) GROUP_USER="$2"; shift;;
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
  real_file="${SHARE_DIR}/${cmd_name}"
  link_file="${BIN_DIR}/${cmd_name}"
  sudo_file="${INSTALL_ROOT}${SUDO_DIR}/cli_${cmd_name}"

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
      "${src_file}" > "${INSTALL_ROOT}${real_file}"
  chmod 0444 "${INSTALL_ROOT}${real_file}"
  ln -sr "${INSTALL_ROOT}${BIN_DIR}/clicmd" "${INSTALL_ROOT}${link_file}"

  # setup sudo
  sed -n '/#\s*@sudo/s/.*@sudo\s*cmd_//p' "${src_file}" | while read cmd roles; do
    if [ -z "${cmd}" -o -z "${roles}" ]; then
      echo "ERROR: Invalid @sudo entry, file ${src_file}, command ${cmd}" >&2
      exit 1
    fi
    cmd="$(echo "${cmd}" | tr '_' ' ')"
    for role in $(echo "${roles}" | tr ',' ' '); do
      case "${role}" in
        ${ROLE_ADMIN})    group="${GROUP_ADMIN}";;
        ${ROLE_OPERATOR}) group="${GROUP_OPERATOR}";;
        ${ROLE_USER})     group="${GROUP_USER}";;
        *)
          echo "ERROR: Unknown role ${role} in file ${src_file}, command ${cmd}" >&2
          exit 1;;
      esac
      echo "%${group} ALL=(ALL) NOPASSWD: ${link_file} ${cmd}" >> "${sudo_file}"
      echo "%${group} ALL=(ALL) NOPASSWD: ${link_file} ${cmd} *" >> "${sudo_file}"
    done
  done
  unset cmd roles role group
  chmod 0440 "${sudo_file}"

  # add command to autocompletion
  echo "complete -F _cli_completion ${cmd_name}" >> "${INSTALL_ROOT}${DEFAULT_PROFILE}"

  # register command in help
  echo "${cmd_name} ${cmd_desc}" >> "${INSTALL_ROOT}${HELP_FILE}"

  unset sudo_file link_file real_file cmd_desc cmd_name src_file
}

echo "Install Phosphor CLI environment to ${INSTALL_ROOT}"

install -DT --mode 0555 "${THIS_DIR}/clicmd" "${INSTALL_ROOT}/usr/bin/clicmd"
install -DT --mode 0644 "${THIS_DIR}/profile.in" "${INSTALL_ROOT}${DEFAULT_PROFILE}"
install -DT --mode 0644 "${THIS_DIR}/functions" \
    "${INSTALL_ROOT}${SHARE_DIR}/.include/functions"

for SRC_FILE in "${THIS_DIR}/commands"/*; do
  # filter out by target machine
  SRC_TARGET="$(basename "${SRC_FILE}" | sed -r 's/.+\.(.+)|.*/\1/')"
  if [ -n "${SRC_TARGET}" -a "${SRC_TARGET}" != "${MACHINE}" ]; then
    echo "Skip '$(basename "${SRC_FILE}")' (${SRC_TARGET}!=${MACHINE})"
  else
    echo "Install '$(basename "${SRC_FILE}")' command script"
    install_cli_script "${SRC_FILE}"
  fi
done

echo "Installation completed successfully"
