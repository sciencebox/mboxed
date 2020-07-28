#!/bin/bash
# Parameters and functions to handle installation of upstream software


# Required packages
ESSENTIAL_PACKAGES='curl gawk git hostname iptables sed'
CONTAINER_PACKAGES='docker kubectl minikube'
DEPENDENCIES_CENTOS='conntrack-tools procps-ng which'
DEPENDENCIES_UBUNTU='conntrack debianutils procps'

DOCKER_VERSION='18.06.3'         # Since 2019-02-19 (Required for GPU support)
DOCKER_URL_CENTOS='https://download.docker.com/linux/centos/7/x86_64/stable/Packages/'
DOCKER_URL_UBUNTU='https://download.docker.com/linux/ubuntu/dists/'

#KUBERNETES_VERSION --> See common.sh
KUBECTL_URL="https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES_VERSION/bin/linux/amd64/kubectl"

MINIKUBE_VERSION='v1.12.0'
MINIKUBE_URL="https://storage.googleapis.com/minikube/releases/$MINIKUBE_VERSION/minikube-linux-amd64"


# Functions
# Warn about software that will be installed
warn_about_software_requirements() {
  local pkg
  local pkg_list

  echo "The following software will be installed (if not already available):"
  case "$OS_ID" in
    centos)
      pkg_list="$ESSENTIAL_PACKAGES $DEPENDENCIES_CENTOS $CONTAINER_PACKAGES"
      ;;
    ubuntu)
      pkg_list="$ESSENTIAL_PACKAGES $DEPENDENCIES_UBUNTU $CONTAINER_PACKAGES"
      ;;
  esac
  for pkg in $(echo $pkg_list | tr ' ' '\n' | sort)
  do
    echo "  - $pkg"
  done
}


verify_package_version_match() {
  local pkg=$1
  local ver_required=$2
  local ver_installed

  ver_installed=$(get_package_version $pkg)
  if [ $ver_required == '-1' ]; then
    return 1 # not installed
  elif [ $ver_required == $ver_installed ]; then
    return 0 # installed at the required version
  fi
  return 2 # installed at a different version
}

verify_string_version_match() {
  local required=$1
  local installed=$2

  if [ $required == $installed ]; then
    return 0 # installed at the required version
  fi
  return 1
}

print_version_mismatch() {
  local obj=$1
  local ver_required=$2
  local ver_installed=$3

  echo "WARNING: $obj is not installed at the required version (required: $ver_required, installed: $ver_installed)"
  #echo "  - Required: $ver_required"
  #echo "  - Installed: $ver_installed"
  #echo "  This might lead to unexpected behaviors."
}

print_version_correct() {
  local obj=$1
  local ver=$2

  echo "  ✓ $obj is installed at the required version ($ver)"
}


get_package_version() {
  local pkg=$1
  local ver

  case "$OS_ID" in
    centos)
      ver=$(rpm -q --qf="%{VERSION}")
      if [ $? -ne 0 ]; then
        ver=''
      fi
      ;;
    ubuntu)
      ver=$(dpkg-query --show --showformat='${Version}' $pkg 2>/dev/null) # | cut -d ':' -f 2- | cut -d '-' -f 1)
      if [ $? -ne 0 ]; then
        ver=''
      fi
      ;;
  esac
  echo $ver
}

install_package() {
  case "$OS_ID" in
    centos)
      echo "  Installing $pkg..."
      yum -y -q install $pkg
      ;;
    ubuntu)
      echo "  Installing $pkg..."
      apt-get install -qq -y $pkg > /dev/null
      ;;
  esac
}

check_or_install_package() {
  local pkg=$1
  local pkg_version

  pkg_version=$(get_package_version $pkg)
  if [ x"$pkg_version" == x"" ]; then
    install_package $pkg
    pkg_version=$(get_package_version $pkg)
  fi
  echo "  ✓ $pkg: found $pkg-$pkg_version"
}


install_package_list() {
  local pkg_list=$1
  local pkg

  for pkg in $pkg_list; do
    check_or_install_package $pkg
  done
}

install_essentials() {
  echo "Installing essential packages..."
  install_package_list "$ESSENTIAL_PACKAGES"
}

install_dependencies() {
  echo "Installing required dependencies..."

  case "$OS_ID" in
    centos)
      install_package_list "$DEPENDENCIES_CENTOS"
      ;;
    ubuntu)
      install_package_list "$DEPENDENCIES_UBUNTU"
      ;;
  esac
}


get_docker_version() {
  echo $(docker version --format '{{.Server.Version}}' | cut -d '-' -f 1)
}

_install_docker() {
  # TODO: We might need to explicitly install containerd.io for newer versions
  local docker_package_url
  local dst="$PWD/docker.deb"

  case "$OS_ID" in
    centos)
      docker_package_url=$DOCKER_URL_CENTOS'docker-ce-'$DOCKER_VERSION'.ce-3.el7.x86_64.rpm'
      yum install -y -q $docker_package_url
      ;;
    ubuntu)
      docker_package_url=$DOCKER_URL_UBUNTU$OS_CODENAME'/pool/stable/amd64/docker-ce_'$DOCKER_VERSION'~ce~3-0~ubuntu_amd64.deb'
      curl -s -L $docker_package_url -o $dst
      dpkg --install $dst > /dev/null 2>&1
      rm -rf $dst
      ;;
  esac
  start_docker
  get_docker_status
}

install_docker() {
  local docker_version

  echo "Installing Docker..."
  if ! command_exists 'docker'; then
    _install_docker
  else
    docker_version=$(get_docker_version)
    echo "docker version: "$docker_verision
    if ! verify_string_version_match $DOCKER_VERSION $docker_version; then
      print_version_mismatch 'docker' $DOCKER_VERSION $docker_version
      prompt_user_to_continue
    fi
  fi
  docker_version=$(get_docker_version)
  print_version_correct 'docker' $docker_version
}


get_kubectl_version() {
  echo $(kubectl version --client --short | awk '{print $NF}')
}

_install_kubectl() {
  local dst=$(infer_binary_destination_from_PATH)"/kubectl"

  curl -s -L $KUBECTL_URL -o $dst
  chmod +x $dst
}

install_kubernetes() {
  local kubectl_version

  echo "Installing Kubernetes..."
  if ! command_exists 'kubectl'; then
    _install_kubectl
  else
    kubectl_version=$(get_kubectl_version)
    if ! verify_string_version_match $KUBERNETES_VERSION $kubectl_version; then
      print_version_mismatch 'kubectl' $KUBERNETES_VERSION $kubectl_version
      prompt_user_to_continue
    fi
  fi
  kubectl_version=$(get_kubectl_version)
  print_version_correct 'kubectl' $kubectl_version
}


get_minikube_version() {
  echo $(minikube version --short | awk '{print $NF}')
}

_install_minikube() {
  local dst=$(infer_binary_destination_from_PATH)"/minikube"

  curl -s -L $MINIKUBE_URL -o $dst
  chmod +x $dst
}

install_minikube() {
  local minikube_version

  echo "Installing Minikube..."
  if ! command_exists 'minikube'; then
    _install_minikube
  else
    minikube_version=$(get_minikube_version)
    if ! verify_string_version_match $MINIKUBE_VERSION $minikube_version; then
      print_version_mismatch 'minikube' $MINIKUBE_VERSION $minikube_version
      prompt_user_to_continue
    fi
  fi
  minikube_version=$(get_minikube_version)
  print_version_correct 'minikube' $minikube_version
}

