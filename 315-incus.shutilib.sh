#!/usr/bin/env bash

# This old huge script is just included for inspiration and reference.
#  It is part of a larger project; 'shutilib',
#  so there are some calls external functions,
#  that are not included here.

_INCUS_BIN='/usr/bin/incus'
_INCUS_SERVICE_NAME='incus.service'
#_INCUS_REMOTE='blam:'
_INCUS_REMOTE=''
_INCUS_DATA_DIR='/opt/optulation/mixed/incus/data'
_INCUS_DUMPS_DIR="${_INCUS_DATA_DIR}/dumps"

_incus_test() {
  _shutilib_funcname
  echo 'incus_test'
}

_incus_list() {
  _shutilib_funcname
  #  _incus_do list
  _incus_do list "${_INCUS_REMOTE}"
}

_incus_network_list() {
  _shutilib_funcname
  _incus_do network list "${_INCUS_REMOTE}"
}

_incus_things_dump() {
  _shutilib_funcname
  _incus_thing_dump 'profile'
  _incus_thing_dump 'network'
  _incus_thing_dump 'image'
  _incus_thing_dump 'project'
  _incus_thing_dump 'storage'
}

_incus_profiles_dump() {
  _shutilib_funcname
  _incus_thing_dump 'profile'
}

_incus_thing_dump() {
  _shutilib_funcname
  local thing csv name line txt file
  thing=$1
  print_yellow "${thing}s"
  dump_dir="${_INCUS_DATA_DIR}/dumps/${thing}"
  if [[ -d ${dump_dir} ]]; then
    rm -rf "${dump_dir}"
  fi

  if csv=$(_incus_do "${thing}" list "${_INCUS_REMOTE}" --format=csv); then
    #    print_yellow " - csv: ${csv}"
    declare -a names long_names
    declare -A name_map
    while IFS= read -r line; do
      #    echo "${line}"
      if [[ ${thing} == 'image' ]]; then
        # split line by comma.
        # fingerprint= second element
        # description= fourth element
        # respect sc2206
        IFS="," read -r -a splat <<<"${line}"
        fingerprint="${splat[1]}"
        description="${splat[3]}"
        # replace spaces with underscores in description
        description="${description// /_}"
        # replace colon with nothing in description
        description="${description//:/}"
        name="${fingerprint}"
        long_name="${description}__${fingerprint}"
      else
        # get before first comma
        name="${line%%,*}"
        long_name="${name}"
      fi
      name="${name%% *}"
      # replace slashes with underscores in long_name
      long_name="${long_name//\//_}"
      name_map[${name}]="${long_name}"
      if [[ $name == '' ]]; then
        print_red "No ${thing}s"
        #        print_yellow "csv: ${csv}"
        return 1
      fi
      #    echo "${name}"
      names+=("${name}")
      long_names+=("${long_name}")
    done <<<"${csv}"
    #  echo
    #    echo "${names[@]}"
    echo "${long_names[@]}"

    mkdir -p "${dump_dir}"

    #    for name in "${names[@]}"; do
    #      #      echo
    #      #      echo "name: ${name}"
    #      txt=$(_incus_do "${thing}" show "${_INCUS_REMOTE}${name}")
    #      #    echo "${txt}"
    #      file="${dump_dir}/${name}.${thing}.yaml"
    #      echo "${txt}" >"${file}"
    #    done

    for name in "${!name_map[@]}"; do
      long_name="${name_map[${name}]}"
      txt=$(_incus_do "${thing}" show "${_INCUS_REMOTE}${name}")
      file="${dump_dir}/${long_name}.${thing}.yaml"
      echo "${txt}" >"${file}"
    done
  fi
}

_incus_networks_dump() {
  _shutilib_funcname
  local csv name line txt file

  declare -a names=()
  csv=$(_incus_do network list "${_INCUS_REMOTE}" --format=csv)

  while IFS= read -r line; do
    #    echo "${line}"
    name="${line%%,*}"
    #    echo "${name}"
    names+=("${name}")
  done <<<"${csv}"
  #  echo
  echo "${names[@]}"

  dump_dir="${_INCUS_DATA_DIR}/dumps/net"
  if [[ -d ${dump_dir} ]]; then
    rm -rf "${dump_dir}"
  fi
  mkdir -p "${dump_dir}"

  for name in "${names[@]}"; do
    echo
    echo "name: ${name}"
    txt=$(_incus_do network show "${_INCUS_REMOTE}${name}")
    #    echo "${txt}"
    file="${dump_dir}/${name}.yaml"
    echo "${txt}" >"${file}"
  done
}

_incus_do() {
  _shutilib_funcname
  ${_INCUS_BIN} "$@"
}

_incus_start_container_if_not_running() {
  _shutilib_funcname
  declare name=$1
  if [[ $(${_INCUS_BIN} info "${name}") != *RUNNING* ]]; then
    print_green "STARTING '${name}'"
    _incus_do start "${name}"
  else
    print_green "${name} is already running"
  fi
}

_incus_stop_container_if_running() {
  _shutilib_funcname
  declare name=$1
  if [[ $(${_INCUS_BIN} info "${name}") == *RUNNING* ]]; then
    print_green "STOPPING ${name}"
    _incus_do stop "${name}"
  else
    print_green "${name} is already stopped"
  fi
}

_incus_restart_container() {
  _shutilib_funcname
  declare name=$1
  _incus_stop_container_if_running "${name}"
  _incus_start_container_if_not_running "${name}"
}

#function that receives a container name and a user name and login executes a bash shell as that user
_incus_exec_user_bash() {
  _shutilib_funcname
  declare container_name=$1
  declare user_name=$2
  if [[ -z $container_name ]]; then
    print_red "ERROR: No container name supplied"
    return 1
  fi
  if [[ -z $user_name ]]; then
    print_red "ERROR: No user name supplied"
    return 1
  fi
  _incus_do exec "${container_name}" -- su - "${user_name}" --login --command="bash"
}

#function that receives a container name and a user name and login executes a bash shell as that user
_incus_exec_login_user_bash() {
  _incus_exec_login_user_command "$@"
}

_incus_exec_login_user_command() {
  _shutilib_funcname
  declare container_name=$1
  declare user_name=$2
  declare _command=$3

  _incus_start_container_if_not_running "${container_name}"
  if [[ -z $container_name ]]; then
    print_red "ERROR: No container name supplied"
    return 1
  fi
  if [[ -z $user_name ]]; then
    print_red "ERROR: No user name supplied"
    return 1
  fi
  #  echo "_command: ${_command}"
  if [[ -z $_command ]]; then
    print_green "logging in as ${user_name} in ${container_name}"
    _incus_do exec "${container_name}" -- sudo --user "${user_name}" --login
    #--_command="bash"
  else
    print_green "executing command as ${user_name} in ${container_name}"
    _incus_do exec "${container_name}" -- sudo --user "${user_name}" --login "${_command}"
  fi
  #  echo "LOGOUT: ${LOGOUT}"
  #  print_yellow "$(hostname))"
  #  if [[ ${LOGOUT} -eq 1 ]]; then
  #    print_red "logging out of ${container_name}"
  #    exit 0
  #  else
  #    print_green "not logging out of ${container_name}"
  #  fi
}

#    alias _debsid='_incus_exec_login_user_bash debsid root'

_incus_is_service_running() {
  _shutilib_funcname
  #  declare service_name
  #  _INCUS_SERVICE_NAME='lxd.service'
  if systemctl is-active --quiet "${_INCUS_SERVICE_NAME}"; then
    print_green "${_INCUS_SERVICE_NAME} is running"
    return 0
  else
    print_red "${_INCUS_SERVICE_NAME} is not running"
    return 1
  fi
}

_incus_service_start() {
  _shutilib_funcname
  if _incus_is_service_running; then
    print_green "${_INCUS_SERVICE_NAME} is already running"
  else
    print_green "Starting ${_INCUS_SERVICE_NAME}"
    sudo systemctl start "${_INCUS_SERVICE_NAME}"
  fi
  _incus_is_service_running
}

_incus_debsid() {
  echo "_incus_debsid"
  _incus_service_start
  _incus_exec_login_user_command debsid root
  #  _incus_exec_user_bash debsid root
  #  #  _incus_exec_login_user_bash debsid root
}

#_incus_exec_user_bash() {
#  _shutilib_funcname
#  declare container_name=$1
#  declare user_name=$2
#  if [[ -z $container_name ]]; then
#    print_red "ERROR: No container name supplied"
#    return 1
#  fi
#  if [[ -z $user_name ]]; then
#    print_red "ERROR: No user name supplied"
#    return 1
#  fi
#  _incus_do exec "${container_name}" -- su - "${user_name}" --login --command="bash"
#}

#_incus_exec_user_bash

#_shutilib_sourced_example() {
#  :
#  #  _debug "_shutilib_sourced_example: $1"
#}
#
#_shutilib_sourced_example "$@"
