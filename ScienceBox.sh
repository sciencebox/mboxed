#!/bin/bash

# Import variables and functions
source etc/common.sh
source etc/deploy.sh


# Preparation
need_root
#warn_about_interfence_eos_cvmfs
configure_network

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
