#!/bin/bash

# Import variables and functions
source etc/common.sh
source etc/deploy.sh

# Preparation
need_root
echo "WARNING: This will stop all the ScienceBox services and *DELETE* all data stored in ScienceBox (CERNBox files, Jupyter notebooks, etc.)."
prompt_user_to_continue

# Stop services first
stop_minikube

# Delete pulled images to reclaim space
delete_images

# Delete stored configs, users' files, etc.
delete_persistent_storage
