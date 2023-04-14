#!/bin/bash
# Common variables and functions


# Environment
HOSTNAME=$(hostname --fqdn)
CWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Software versions
#   - Docker release notes: https://docs.docker.com/engine/release-notes/
DOCKER_VERSION='23.0.3-1'
DOCKER_SCANPLUGIN_VERSION='0.23.0-3'       # Used by CentOS only
DOCKER_COMPOSE_PLUGIN_VERSION='2.6.0-3'
DOCKER_BUILDX_PLUGIN_VERSION='0.10.4-1'
#   - containerd releases: https://github.com/containerd/containerd/releases
CONTAINERD_VERSION='1.6.9-3'
#   - k8s releases: https://github.com/kubernetes/kubernetes/releases
KUBERNETES_VERSION='v1.23.17'
#   - minikube releases: https://github.com/kubernetes/minikube/releases
MINIKUBE_VERSION='v1.29.0'
#   - helm releases: https://github.com/helm/helm/releases
HELM_VERSION='v3.11.2'



# Functions
# Check to be root
#   If not root, bail out
need_root() {
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi
}

 
# Detect the host operating system
#   Parses '/etc/os-release' to detect the operating system
# Exports:
#   - OS_ID (example, 'ubuntu', 'centos')
#   - OS_VERSION (e.g., '18.04', '7')
#   - OS_CODENAME (e.g., 'bionic', 'focal') if exists
# Returns 0 if operating system is supported, bails out otherwise
guess_os() {
  local os_id
  local os_version
  local os_codename
  local os_release_file='/etc/os-release'
  local supported_oses='centos ubuntu'

  if [ ! -f $os_release_file ]; then
    echo "ERROR: Unable to detect the operating system."
    echo "Cannot continue."
    exit 1
  fi

  os_id=$(cat $os_release_file | grep "^ID=" | cut -d '=' -f 2- | tr '[:upper:]' '[:lower:]' | tr -d '"')
  os_version=$(cat $os_release_file | grep "^VERSION_ID=" | cut -d '=' -f 2- | tr -d '"')
  os_codename=$(cat $os_release_file | grep "^VERSION_CODENAME=" | cut -d '=' -f 2- | tr '[:upper:]' '[:lower:]')
  if [[ $supported_oses == *"$os_id"*  ]]; then
    export OS_ID="$os_id"
    export OS_VERSION="$os_version"
    export OS_CODENAME="$os_codename"
    return 0
  else
    echo "ERROR: $os_id is not supported."
    echo "Cannot continue."
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
  echo "Restarting Docker..."
  if ! stop_docker; then
    echo "  ✗ Error stopping Docker "
    return 1
  fi
  if ! start_docker; then
    echo "  ✗ Error starting Docker "
    return 1
  fi
  return 0
}

# Get Docker status
#   Prints the output of `systemctl status docker`
#   Returns exit code of `systemctl status docker`
get_docker_status() {
  systemctl status docker --no-pager
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


prompt_user_for_gpu_support() {
  read -r -p "Do you want to enable GPU support? [y/N] " response
  case "$response" in
    [yY])
      GPU_SUPPORT=true
      return 0
      ;;
    *)
      GPU_SUPPORT=false
      echo "  ✓ Continuing without GPU support"
      return 1
      ;;
  esac
}
