#!/bin/bash
# Parameters and functions to handle installation of upstream software


# Required packages
ESSENTIAL_PACKAGES='curl gawk git hostname iptables jq sed tar'
CONTAINER_PACKAGES='docker kubectl minikube'
DEPENDENCIES_CENTOS='conntrack-tools libselinux-utils procps-ng socat which'
DEPENDENCIES_UBUNTU='conntrack debianutils procps socat'
GPU_DEPENDENCIES='moreutils runc'

# Docker
DOCKER_URL_CENTOS7='https://download.docker.com/linux/centos/7/x86_64/stable/Packages/'
DOCKER_URL_CENTOS8='https://download.docker.com/linux/centos/8/x86_64/stable/Packages/'
DOCKER_URL_UBUNTU='https://download.docker.com/linux/ubuntu/dists/'
CONTAINERD_URL_CENTOS7='https://download.docker.com/linux/centos/7/x86_64/stable/Packages/'
CONTAINERD_URL_CENTOS8='https://download.docker.com/linux/centos/8/x86_64/stable/Packages/'
CONTAINERD_URL_UBUNTU='https://download.docker.com/linux/ubuntu/dists/'

# Kubernetes
KUBECTL_URL="https://storage.googleapis.com/kubernetes-release/release/$KUBERNETES_VERSION/bin/linux/amd64/kubectl"

# Minikube
MINIKUBE_URL="https://storage.googleapis.com/minikube/releases/$MINIKUBE_VERSION/minikube-linux-amd64"

# Helm
HELM_URL="https://get.helm.sh/helm-$HELM_VERSION-linux-amd64.tar.gz"

# GPU packages versions
LIBNVIDIA_CONTAINER_VERSION="1.2.0"
NVIDIA_DOCKER_VERSION="2.4.0" 
NVIDIA_CONTAINER_RUNTIME_VERSION="3.3.0"
NVIDIA_CONTAINER_TOOLKIT_VERSION="1.2.1"

declare -A GPU_PKGs_CENTOS=( ["nvidia-container-runtime"]="https://nvidia.github.io/nvidia-container-runtime/centos7/x86_64/nvidia-container-runtime-$NVIDIA_CONTAINER_RUNTIME_VERSION-1.x86_64.rpm"
                             ["nvidia-container-toolkit"]="https://nvidia.github.io/nvidia-container-runtime/centos7/x86_64/nvidia-container-toolkit-$NVIDIA_CONTAINER_TOOLKIT_VERSION-2.x86_64.rpm"
                             ["libnvidia-container1"]="https://nvidia.github.io/libnvidia-container/centos7/x86_64/libnvidia-container1-$LIBNVIDIA_CONTAINER_VERSION-1.x86_64.rpm"
                             ["libnvidia-container-tools"]="https://nvidia.github.io/libnvidia-container/centos7/x86_64/libnvidia-container-tools-$LIBNVIDIA_CONTAINER_VERSION-1.x86_64.rpm"
                             ["nvidia-docker2"]="https://nvidia.github.io/nvidia-docker/centos7/x86_64/nvidia-docker2-$NVIDIA_DOCKER_VERSION-1.noarch.rpm" )
declare -A GPU_PKGs_UBUNTU=( ["nvidia-container-runtime"]="https://nvidia.github.io/nvidia-container-runtime/ubuntu20.04/amd64/nvidia-container-runtime_"$NVIDIA_CONTAINER_RUNTIME_VERSION"-1_amd64.deb"
                             ["nvidia-container-toolkit"]="https://nvidia.github.io/nvidia-container-runtime/ubuntu20.04/amd64/nvidia-container-toolkit_"$NVIDIA_CONTAINER_TOOLKIT_VERSION"-1_amd64.deb"
                             ["libnvidia-container1"]="https://nvidia.github.io/libnvidia-container/stable/ubuntu20.04/amd64/libnvidia-container1_"$LIBNVIDIA_CONTAINER_VERSION"-1_amd64.deb"
                             ["libnvidia-container-tools"]="https://nvidia.github.io/libnvidia-container/stable/ubuntu20.04/amd64/libnvidia-container-tools_"$LIBNVIDIA_CONTAINER_VERSION"-1_amd64.deb"
                             ["nvidia-docker2"]="https://nvidia.github.io/nvidia-docker/ubuntu20.04/amd64/nvidia-docker2_"$NVIDIA_DOCKER_VERSION"-1_all.deb"
)

# Functions
# Print list of packages
print_packages_list(){
  local pkg_list=$1

  for pkg in $(echo $pkg_list | tr ' ' '\n' | sort)
  do
    echo "  - $pkg"
  done
}

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
  print_packages_list "$pkg_list"
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
      ver=$(rpm -q --qf="%{VERSION}" $pkg)
      if [ $? -ne 0 ]; then
        ver=''
      fi
      ;;
    ubuntu)
      ver=$(dpkg-query --show --showformat='${Status}|${Version}' $pkg 2>/dev/null | grep "^install ok installed" | cut -d '|' -f 2-)
      if [ $? -ne 0 ]; then
        ver=''
      fi
      ;;
  esac
  echo $ver
}

install_package() {
  local pkg=$1

  case "$OS_ID" in
    centos)
      echo "  Installing $pkg..."
      yum install -y -q $pkg > /dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo "  ✗ Error installing $pkg "
      fi
      ;;
    ubuntu)
      echo "  Installing $pkg..."
      apt-get install -qq -y $pkg > /dev/null 2>&1
      if [ $? -ne 0 ]; then
        echo "  ✗ Error installing $pkg "
      fi
      ;;
  esac
}

install_deb() {
  local pkg_url=$1
  local pkg_deb='/tmp/to_install.deb'

  curl -s -L $pkg_url -o $pkg_deb
  dpkg --install $pkg_deb > /dev/null 2>&1
  rm -rf $pkg_deb
}

#check_package() {
#  local pkg_name=$1
#  local pkg_url=$2
#  local pkg_version
#
#  # If the URL to download the package is not provided,
#  # assume we can fetch it from a configured repo
#  if [ x"$pkg_url" == x"" ]; then
#    pkg_url=$pkg_name
#  fi
#
#  pkg_version=$(get_package_version $pkg_name)
#  if [ x"$pkg_version" == x"" ]; then
#    install_package $pkg
#    pkg_version=$(get_package_version $pkg_name)
#  fi
#  echo "  ✓ $pkg_name: found $pkg_name-$pkg_version"
#}

check_package() {
  local pkg_name=$1
  local pkg_version

  pkg_version=$(get_package_version $pkg_name)
  if [ x"$pkg_version" == x"" ]; then
    return 1
  fi
  echo "  ✓ $pkg_name: found $pkg_name-$pkg_version"
  return 0
}

install_package_list() {
  local pkg_list=$1
  local pkg

  for pkg in $pkg_list; do
    if ! check_package $pkg; then
      install_package $pkg
      check_package $pkg
  fi
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
  local docker_version

  if systemctl status docker > /dev/null 2>&1; then
    docker_version=$(docker version --format '{{.Server.Version}}' | cut -d '-' -f 1)
  else
    docker_version=$(get_package_version 'docker-ce')
    if [ $(echo $docker_version | cut -c 8-) == ".ce" ]; then
      docker_version=$(echo $docker_version | cut -c -7)
    fi
  fi
  echo $docker_version
}

_install_docker() {
  local docker_package_url
  local docker_package_cli

  case "$OS_ID" in
    centos)
      case "$OS_VERSION" in
        7)
          docker_package_url=$DOCKER_URL_CENTOS7'docker-ce-'$DOCKER_VERSION'-3.el7.x86_64.rpm'
          docker_cli_url=$DOCKER_URL_CENTOS7'docker-ce-cli-'$DOCKER_VERSION'-3.el7.x86_64.rpm'
          containerd_package_url=$CONTAINERD_URL_CENTOS7'containerd.io-'$CONTAINERD_VERSION'.el7.x86_64.rpm'
          ;;
        8)
          docker_package_url=$DOCKER_URL_CENTOS8'docker-ce-'$DOCKER_VERSION'-3.el8.x86_64.rpm'
          docker_cli_url=$DOCKER_URL_CENTOS8'docker-ce-cli-'$DOCKER_VERSION'-3.el8.x86_64.rpm'
          containerd_package_url=$CONTAINERD_URL_CENTOS8'containerd.io-'$CONTAINERD_VERSION'.el8.x86_64.rpm'
          ;;
      esac
      yum install -y -q $docker_package_url $docker_cli_url $containerd_package_url
      ;;
    ubuntu)
      docker_package_url=$DOCKER_URL_UBUNTU$OS_CODENAME'/pool/stable/amd64/docker-ce_'$DOCKER_VERSION'~3-0~ubuntu-'$OS_CODENAME'_amd64.deb'
      docker_package_deb='/tmp/docker.deb'
      curl -s -L $docker_package_url -o $docker_package_deb
      docker_cli_url=$DOCKER_URL_UBUNTU$OS_CODENAME'/pool/stable/amd64/docker-ce-cli_'$DOCKER_VERSION'~3-0~ubuntu-'$OS_CODENAME'_amd64.deb'
      docker_cli_deb='/tmp/docker_cli.deb'
      curl -s -L $docker_cli_url -o $docker_cli_deb
      containerd_package_url=$CONTAINERD_URL_UBUNTU$OS_CODENAME'/pool/stable/amd64/containerd.io_'$CONTAINERD_VERSION'_amd64.deb'
      containerd_package_deb='/tmp/containerd.deb'
      curl -s -L $containerd_package_url -o $containerd_package_deb

      dpkg --install $docker_package_deb $docker_cli_deb $containerd_package_deb > /dev/null 2>&1
      rm -f $docker_package_deb $docker_cli_deb $containerd_package_deb
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

get_helm_version() {
  echo $(helm version --short | cut -d '+' -f 1)
}

_install_helm() {
  local tmp_fld='/tmp/helm'
  local tmp_dst="$tmp_fld/helm.tar.gz"
  local dst_helm=$(infer_binary_destination_from_PATH)"/helm"

  mkdir -p $tmp_fld
  curl -s -L $HELM_URL -o $tmp_dst
  tar -xf $tmp_dst -C $tmp_fld
  cp $tmp_fld/linux-amd64/helm $dst_helm
  rm -rf $tmp_fld
  chmod +x $dst_helm
}

install_helm() {
  local helm_version

  echo "Installing Helm..."
  if ! command_exists 'helm'; then
    _install_helm
  else
    helm_version=$(get_helm_version)
    if ! verify_string_version_match $HELM_VERSION $helm_version; then
      print_version_mismatch 'helm' $HELM_VERSION $helm_version
      prompt_user_to_continue
    fi
  fi
  helm_version=$(get_helm_version)
  print_version_correct 'helm' $helm_version
}


# ----- GPU Support ----- #
# Warn about required software for GPU support
warn_about_gpu_requirements() {
echo "The following software is required for GPU support:"
  print_packages_list "$GPU_DEPENDENCIES nvidia-docker2 nvidia-container-runtime libnvidia-container1 libnvidia-container-tools nvidia-container-runtime-hook"
}

install_gpu_software()
{
  local docker_daemon_config_file='/etc/docker/daemon.json'
  local docker_daemon_save_file=$PWD"/docker_daemon.json_"$(date +%s)".save"
  local pkg_name
  local pkg_local
  local pkg_local_list

  if ! $GPU_SUPPORT; then
    return
  fi

  # Backup Docker daemon configuration first
  echo "Saving docker daemon configuration... (nvidia-docker2 might change it)"
  if [ ! -f $docker_daemon_config_file ]; then
    echo "  ✓ Docker daemon configuration file not found. Consider removing $docker_daemon_config_file when removing ScienceBox."
  else
    cp $docker_daemon_config_file $docker_daemon_save_file
    echo "  ✓ Docker daemon configuration saved to $docker_daemon_save_file."
  fi

  case "$OS_ID" in
    centos)
      case "$OS_VERSION" in
        7)
          echo "Installing dependencies for GPU support..."
          install_package_list "$GPU_DEPENDENCIES"
          echo "Installing nvidia-docker2 (and related packages)..."
          yum install -y -q "${GPU_PKGs_CENTOS[@]}" > /dev/null 2>&1
          for pkg_name in "${!GPU_PKGs_CENTOS[@]}"
          do
            check_package $pkg_name
          done
          ;;
      esac
      ;;
    ubuntu)
      case "$OS_VERSION" in
        18.04|18.10|19.04|19.10|20.04)
           echo "Installing dependencies for GPU support..."
          install_package_list "$GPU_DEPENDENCIES"
	  echo "Installing nvidia-docker2 (and related dependencies)..."
	  # Get packages first
	  for pkg_name in "${!GPU_PKGs_UBUNTU[@]}"
          do
            pkg_local="/tmp/$pkg_name.deb"
	    pkg_local_list=$(echo $pkg_local_list $pkg_local)
            curl -s -L ${GPU_PKGs_UBUNTU["$pkg_name"]} -o $pkg_local
          done
	  # Install all of them in one go
	  dpkg --install $pkg_local_list > /dev/null 2>&1
	  # Check
	  for pkg_name in "${!GPU_PKGs_UBUNTU[@]}"
	  do
            check_package $pkg_name
	  done
	  # Clean-up
	  for pkg_name in $pkg_local_list
	  do
            rm -rf $pkg_name
	  done
          ;;
      esac
  esac
}

