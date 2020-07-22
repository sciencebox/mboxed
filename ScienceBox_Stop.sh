#!/bin/bash

# Import variables and functions
source etc/common.sh
source etc/deploy.sh

need_root

echo "WARNING: This will stop all the ScienceBox services, including CERNBox storage and SWAN sessions."
prompt_user_to_continue
stop_minikube
