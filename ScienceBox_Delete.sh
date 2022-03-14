#!/bin/bash

# Import variables and functions
source etc/common.sh
source etc/deploy.sh

# Preparation
need_root
echo "WARNING: This will stop all the ScienceBox services and *DELETE* all data stored in ScienceBox (CERNBox files, Jupyter notebooks, etc.)."
prompt_user_to_continue

# Stop ScienceBox
minikube_stop

# Delete minikube installation
minikube_delete

# Restore previous config if the user wants
suggest_iptables_restore
suggest_docker_daemon_restore

