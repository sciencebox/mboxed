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
#helm_repo_add cernbox ???
helm_repo_add swan https://registry.cern.ch/chartrepo/swan
helm_repo_add sciencebox https://registry.cern.ch/chartrepo/sciencebox
helm_repo_update

# Prepare persistent storage
# create_persistent_storage

# Bootstrap Minikube 
minikube_start
minikube_ingess
ingress_patch ocis-idp 9130

## # Deployment
## check_required_images
## create_namespace
## #deploy_services

# Deploy ScienceBox with Helm charts
#TODO: deploy_helm_charts

