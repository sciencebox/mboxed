#!/bin/bash

# Import variables and functions
source etc/common.sh
source etc/deploy.sh

need_root
stop_minikube
sciencebox_images=$(get_sciencebox_images_list)
singleuser_image=$(get_singleuser_image_name)
images_list=$(echo $sciencebox_images $singleuser_image | tr ' ' '\n' | sort | uniq | tr '\n' ' ')
delete_images "$images_list"
delete_persistent_storage
