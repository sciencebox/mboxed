#!/bin/bash

# Import variables and functions
source etc/common.sh
source etc/deploy.sh

# Preparation
need_root
echo "WARNING: This will stop all the ScienceBox services and *DELETE* all data stored in ScienceBox (CERNBox files, Jupyter notebooks, etc.)."
prompt_user_to_continue

# Get kuboxed
get_git_repo $KUBOXED_GIT
prepare_kuboxed

# Stop services first
minikube_stop
minikube_delete

# Delete pulled images to reclaim space
delete_images

# Delete stored configs, users' files, etc.
delete_persistent_storage

# Restore previous config if the user wants
suggest_iptables_restore
suggest_docker_daemon_restore

