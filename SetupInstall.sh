#!/bin/bash

# Import variables and functions
source etc/common.sh
source etc/install.sh

need_root
guess_os

warn_about_software_requirements
prompt_user_to_continue

install_essentials
install_dependencies

install_docker
install_kubernetes
install_minikube
install_helm

warn_about_gpu_requirements
prompt_user_for_gpu_support
install_gpu_software
