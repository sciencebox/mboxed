#!/bin/bash

# Import variables and functions
source etc/common.sh
source etc/deploy.sh


# Preparation
need_root
#warn_about_interfence_eos_cvmfs

# Get kuboxed
get_git_repo $KUBOXED_GIT
prepare_kuboxed

# Get Docker images
sciencebox_images=$(get_sciencebox_images_list)
singleuser_image=$(get_singleuser_image_name)
images_list=$(echo $sciencebox_images $singleuser_image | tr ' ' '\n' | sort | uniq | tr '\n' ' ')
pre_pull_images "$images_list"

# Prepare persistent storage
create_persistent_storage

# Bootstrap Minikube 
start_minikube
label_node

# Deployment
check_required_images "$images_list"
create_namespace
deploy_services
