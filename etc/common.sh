#!/bin/bash
# Common variables and functions


# Environment
HOSTNAME=$(hostname -s)
CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Kubernetes params
KUBERNETES_VERSION='v1.15.0'


# Functions
# Check to be root
#   If not root, bail out
need_root() {
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi
}

 
# Ask the user to continue with the installation
#   Args:
#     - Message to print
#   According to the user choice, it either returns 0 or causes the installation script to bail out
prompt_user_to_continue() {
  local message=$1
  local response

  if [ x"$message" == x"" ]; then
    message='Do you want to continue?'
  fi
  read -r -p "$message [y/N] " response
  case "$response" in
    [yY])
      return 0
      ;;
    *)
      echo "Goodbye!"
      exit 0
      ;;
  esac
}


# Check if a command exists
#   Args:
#     - command
#   Returns the exit code of `command` utility
command_exists() {
  local cmd=$1
  command -v $cmd > /dev/null 2>&1
}

# Get the fullpath of the binary of a command
#   Args:
#     - command
#   Returns the fullpath of the binary
get_command_fullpath() {
  local cmd=$1
  local cmd_fullpath

  cmd_fullpath=$(which $cmd 2>/dev/null)
  if [ $? -eq 0 ]; then
    echo $cmd_fullpath
  fi    
}


# According to $PATH, decide where to land new binaries
#    Returns the destination directory for new binaries 
#    and prefers /usr/local/bin to /usr/bin if in $PATH
infer_binary_destination_from_PATH() {
  local path=$PATH

  if [[ $path == *"/usr/local/bin"* ]]; then
    echo "/usr/local/bin"
  else
    echo "/usr/bin"
  fi
}


# Get git repository from URL
#   Args:
#     - git repository to be cloned
#     - (optional) destination directory
#   Returns exit code of `git clone` command
get_git_repo() {
  local git_repo=$1
  local dst=$2
  local ret_code

  echo "Cloning repository $git_repo..."
  git clone $git_repo $dst > /dev/null 2>&1
  return $?
}


# Start Docker
#   Returns exit code of `systemctl start docker`
start_docker() {
  systemctl start docker > /dev/null 2>&1
  return $?
}

# Stop Docker
#   Returns exit code of `systemctl stop docker`
stop_docker() {
  systemctl stop docker > /dev/null 2>&1
  return $?
}

# Restart Docker
#   Returns 1 if either between stop and start operations fail, 0 otherwise
restart_docker() {
  if ! stop_docker; then
    echo "ERROR: Unable to stop Docker "
    return 1
  fi
  if ! start_docker; then
    echo "ERROR: Unable to start Docker "
    return 1
  fi
  return 0
}

# Get Docker status
#   Prints the output of `systemctl status docker`
#   Returns exit code of `systemctl status docker`
get_docker_status() {
  systemctl status docker
  return $?
}

# Pull Docker image asynchronously
#   Args:
#     - URI of the image to be pulled
pull_docker_image_async() {
  local img=$1

  docker pull $img > /dev/null 2>&1 &
}


# Get the Docker image ID
#   Args:
#     - URI of the image
#   Returns the ID of the Docker image
get_docker_image_id() {
  local uri=$1

  docker image ls --filter=reference=$uri --format "{{.ID}}"
}


# Check if a Docker image exists locally
#   Args:
#     - URI of the image
#   Returns 0 if exists, 1 if otherwise
check_docker_image_exists_locally() {
  local uri=$1
  local id

  id=$(get_docker_image_id $uri) 
  if [ x"$id" == x"" ]; then
    return 1
  fi
  return 0
}


##  # Infer which package provides the command
##  cmd_fullpath=$(get_command_fullpath $cmd)
##
##  # Get the package version
##  if [ x"$cmd_fullpath" != x"" ]; then
##    pkg=$(rpm -q --whatprovides $cmd_fullpath)
##    ver=$(rpm -q --qf "%{VERSION}" $pkg)
##    echo $ver
##  else
##    echo '-1' # command not found
##  fi

