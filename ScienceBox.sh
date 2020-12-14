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
 
# Get Helm charts for EOS
#get_git_repo $HELM_CHARTS_EOS

# Get Helm charts for SWAN
#get_git_repo $HELM_CHARTS_SWAN

## # Get Docker images
## pre_pull_images

# Prepare persistent storage
create_persistent_storage

# Bootstrap Minikube 
start_minikube
#label_node

## Configure Helm
#configure_helm	# Not needed with Helm v3

## # Deployment
## check_required_images
## create_namespace
## #deploy_services

# Deploy services with Helm charts
#TODO: deploy_helm_charts

echo "


The eos-chart repo is not (yet) public.
Please, run what follows one you have a valid KRB5 token:
  git clone https://:@gitlab.cern.ch:8443/eos/eos-charts.git
  cd eos-charts
  git checkout enbodev
  git pull
  
  ./install.sh
"

