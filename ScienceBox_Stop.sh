#!/bin/bash

# Import variables and functions
source etc/common.sh
source etc/deploy.sh

# Preparation
need_root
echo "WARNING: This will stop all the ScienceBox services, including CERNBox storage and SWAN sessions."
prompt_user_to_continue

# Stop ScienceBox
minikube_stop

# Restore previous config if the user wants
suggest_iptables_restore
suggest_docker_daemon_restore

