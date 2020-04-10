#!/bin/sh -eu

#
# Installer.
#

INSTALL_ROOT=""
MACHINE="nicole"
GROUP_ADMIN="priv-admin"
GROUP_OPERATOR="priv-operator"
GROUP_USER="priv-user"
HELP_FILE="/usr/share/cli.help"

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

# Install files from specified directory and configure sudo.
# param 1: path to source directory with executable scripts
# param 2: group name whose users may execute scripts
install_exec_dir() {
  src_dir="$1"
  group_name="$2"

  # prepare installation directories
  bin_dir="/usr/bin"
  install --mode 0755 -d ${INSTALL_ROOT}${bin_dir}
  sudo_dir="/etc/sudoers.d"
  install --mode 0750 -d ${INSTALL_ROOT}${sudo_dir}
  install --mode 0755 -d $(dirname ${INSTALL_ROOT}${HELP_FILE})

  sudo_file="${INSTALL_ROOT}${sudo_dir}/cli_$(echo ${group_name} | sed 's/-//g')"

  for src_file in ${src_dir}/*; do
    file_name="$(basename ${src_file})"

    # filter out by target machine
    postfix="$(echo "${file_name}" | sed -r 's/.+\.(.+)|.*/\1/')"
    if [ -n "${postfix}" ]; then
      if [ "${postfix}" != "${MACHINE}" ]; then
        echo "Skip ${file_name} (${postfix}!=${MACHINE})"
        continue
      fi
      # remove postfix (target machine) from file name
      file_name="$(echo ${file_name} | sed -r 's/(.+)\..+|(.*)/\1\2/')"
    fi

    echo "Install ${file_name}"
    real_file="${bin_dir}/cli_${file_name}"
    link_file="${bin_dir}/${file_name}"
    if [ -f "${INSTALL_ROOT}${real_file}" -o -f "${INSTALL_ROOT}${link_file}" ]; then
      echo "ERROR: File ${file_name} already exist." >&2
      exit 1
    fi

    # install script file
    sed -e "s/%GROUP_ADMIN%/${GROUP_ADMIN}/g" \
        -e "s/%GROUP_OPERATOR%/${GROUP_OPERATOR}/g" \
        -e "s/%GROUP_USER%/${GROUP_USER}/g" \
        ${src_file} > ${INSTALL_ROOT}${real_file}
    chmod 0400 ${INSTALL_ROOT}${real_file}
    ln -sr ${INSTALL_ROOT}${bin_dir}/clicmd ${INSTALL_ROOT}${link_file}

    # setup sudo
    echo "%${group_name} ALL=(ALL) NOPASSWD: ${link_file}" >> ${sudo_file}

    # register command in help
    cmd_desc="$(sed -n 's/^# *CLI: *//p' ${src_file})"
    if [ -z "${cmd_desc}" ]; then
      echo "ERROR: Script ${file_name} doesn't contain description" >&2
      exit 1
    fi
    echo "${group_name} ${file_name} ${cmd_desc}" >> ${INSTALL_ROOT}${HELP_FILE}
  done

  chmod 0440 ${sudo_file}
}

echo "Install Phosphor CLI environment to ${INSTALL_ROOT}"

THIS_DIR="$(realpath $(dirname $0))"

install -DT --mode 0555 ${THIS_DIR}/clicmd ${INSTALL_ROOT}/usr/bin/clicmd
install_exec_dir ${THIS_DIR}/admin ${GROUP_ADMIN}
install_exec_dir ${THIS_DIR}/operator ${GROUP_OPERATOR}
install_exec_dir ${THIS_DIR}/user ${GROUP_USER}

echo "Install help"
install -DT --mode 0555 ${THIS_DIR}/help.in ${INSTALL_ROOT}/usr/bin/help

echo "Install default profile"
install -DT --mode 0444 ${THIS_DIR}/profile.in ${INSTALL_ROOT}/etc/profile.d/default.sh

echo "Installation completed successfully"
