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
restart_docker
 
# Set up repositories for charts
helm_repo_add sciencebox https://registry.cern.ch/chartrepo/sciencebox
helm_repo_add eos https://registry.cern.ch/chartrepo/eos
helm_repo_add swan https://registry.cern.ch/chartrepo/swan
helm_repo_add cs3org https://cs3org.github.io/charts
helm_repo_add bitnami https://charts.bitnami.com/bitnami
helm_repo_update

## Prepare for deployment
# create_persistent_storage
# pre_pull_images

# Bootstrap Minikube 
minikube_start
minikube_ingess
minikube_ingress_wait

# Deploy ScienceBox
## check_required_images
install_charts
