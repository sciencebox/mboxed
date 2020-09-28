#!/bin/bash

# Import variables and functions
source etc/common.sh
source etc/deploy.sh


# Preparation
need_root
guess_os
#warn_about_interfence_eos_cvmfs
configure_selinux
configure_network
configure_gpu_support

# Restart Docker after network (and GPU) changes
echo "Restarting Docker..."
restart_docker
exit
 
# Get kuboxed
get_git_repo $KUBOXED_GIT
prepare_kuboxed

# Get Docker images
pre_pull_images

# Prepare persistent storage
create_persistent_storage

# Bootstrap Minikube 
start_minikube
label_node

# Deployment
check_required_images
create_namespace
deploy_services

