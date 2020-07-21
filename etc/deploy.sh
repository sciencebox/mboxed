#!/bin/bash
# Parameters and functions to handle deployment of ScienceBox


start_minikube() {
  #TODO: Investigate other dirvers
  minikube start --driver=$MINIKUBE_DRIVER --kubernetes-version=$KUBERNETES_VERSION

  #TODO: How to handle errors here
  return $?
}

stop_minikube() {
  minikube stop
}


label_node() {
  local node_name

  echo 'Labelling node...'
  node_name=$(kubectl get nodes --no-headers -o custom-columns=NAME:.metadata.name)
  kubectl label node $node_name nodeApp=minikube > /dev/null 2>&1
}


prepare_kuboxed() {
  #
  # TODO: This should all go away once we have helm charts!
  #
  local yaml_folder=$KUBOXED_FOLDER

  echo "Modifying kuboxed for the current setup..."

  # Change labels to minikube
  sed -i "s/^\( *nodeApp: *\)[^ ]*\(.*\)*$/\1$MINIKUBE_NODE_LABEL\2/" $KUBOXED_FOLDER/LDAP.yaml
  sed -i "s/^\( *nodeApp: *\)[^ ]*\(.*\)*$/\1$MINIKUBE_NODE_LABEL\2/" $KUBOXED_FOLDER/eos-storage-mgm.yaml
  sed -i "s/^\( *nodeApp: *\)[^ ]*\(.*\)*$/\1$MINIKUBE_NODE_LABEL\2/" $KUBOXED_FOLDER/eos-storage-fst.template.yaml
  sed -i "s/^\( *nodeApp: *\)[^ ]*\(.*\)*$/\1$MINIKUBE_NODE_LABEL\2/" $KUBOXED_FOLDER/CERNBOX.yaml
  sed -i "s/^\( *nodeApp: *\)[^ ]*\(.*\)*$/\1$MINIKUBE_NODE_LABEL\2/" $KUBOXED_FOLDER/SWAN.yaml
  sed -i 's/swan-users/minikube/g' $KUBOXED_FOLDER/SWAN.yaml

  # Change server names to hostname of the machine where ScienceBox runs
  sed -i "s/up2kube-cernbox.cern.ch/$HOSTNAME/" $KUBOXED_FOLDER/CERNBOX.yaml
  sed -i "s/up2kube-swan.cern.ch/$HOSTNAME/" $KUBOXED_FOLDER/CERNBOX.yaml
  sed -i "s/up2kube-cernbox.cern.ch/$HOSTNAME/" $KUBOXED_FOLDER/SWAN.yaml
  sed -i "s/up2kube-swan.cern.ch/$HOSTNAME/" $KUBOXED_FOLDER/SWAN.yaml

  # TODO: We should have a reverse proxy in front of all ScienceBox services to avoid this mapping on host ports
  # Change SWAN network params
  ##   Change HTTP port
  sed -i "s/^\( *hostPort: &HTTP_PORT *\)[^ ]*\(.*\)*$/\1$SWAN_HTTP_PORT\2/" $KUBOXED_FOLDER/SWAN.yaml
  local swan_http_port_lineno=$(cat $KUBOXED_FOLDER/SWAN.yaml | grep "name: HTTP_PORT" -n | cut -d ':' -f 1)
  swan_http_port_lineno=$(($swan_http_port_lineno+1))
  sed -i "$swan_http_port_lineno s/^\( *value: *\)[^ ]*\(.*\)*$/\1$SWAN_HTTP_PORT\2/" $KUBOXED_FOLDER/SWAN.yaml
  ##   Change HTTPS port
  sed -i "s/^\( *hostPort: &HTTPS_PORT *\)[^ ]*\(.*\)*$/\1$SWAN_HTTPS_PORT\2/" $KUBOXED_FOLDER/SWAN.yaml
  local swan_https_port_lineno=$(cat $KUBOXED_FOLDER/SWAN.yaml | grep "name: HTTPS_PORT" -n | cut -d ':' -f 1)
  swan_https_port_lineno=$(($swan_https_port_lineno+1))
  sed -i "$swan_https_port_lineno s/^\( *value: *\)[^ ]*\(.*\)*$/\1$SWAN_HTTPS_PORT\2/" $KUBOXED_FOLDER/SWAN.yaml
  ##   Change upstream SWAN server port in CERNBOX nginx configuration
  sed -i 's/^\( *hostNetwork: *\)[^ ]*\(.*\)*$/\1false\2/' $KUBOXED_FOLDER/SWAN.yaml    # Swan should not use the host network
  local swan_port_lineno=$(cat $KUBOXED_FOLDER/CERNBOX.yaml | grep SWAN_BACKEND_PORT -n | cut -d ':' -f 1)
  swan_port_lineno=$(($swan_port_lineno+1))
  sed -i "$swan_port_lineno s/^\( *value: *\)[^ ]*\(.*\)*$/\1$SWAN_HTTPS_PORT\2/" $KUBOXED_FOLDER/CERNBOX.yaml

  # Create YAML files for EOS FSTs
  for no in $(seq 1 $EOS_FST_NUMBER)
  do 
    bash $KUBOXED_FOLDER/eos-storage-fst.sh $no eos-mgm.boxed.svc.cluster.local eos-mgm.boxed.svc.cluster.local docker default
    sed -i "s/fst_userdata/fst$no\_userdata/g" $KUBOXED_FOLDER/eos-storage-fst$no\.yaml
  done
}

create_persistent_storage() {
  # These are the required folders:
  # - /mnt/cbox_shares_db/cbox_data
  # - /mnt/cbox_shares_db/cbox_MySQL
  # - /mnt/eos_namespace
  # - /mnt/fst1_userdata
  # - /mnt/fst2_userdata
  # - /mnt/fst3_userdata
  # - /mnt/fst4_userdata
  # - /mnt/jupyterhub_data
  # - /mnt/ldap/config
  # - /mnt/ldap/userdb

  # TODO:
  #   By now, they are inferred from the YAML files, but this will disappear with Helm
  #
  local folders_list
  local fld
  
  echo "Preparing persistent storage..."
  folders_list=$(cat $KUBOXED_FOLDER/*.yaml | grep -i "hostPath:" -A 2 | grep -i -w "type: Directory" -B 1 | grep -i "path: " | awk '{print $NF}')
  folders_list=$(echo $folders_list "/var/kubeVolumes") # This is for logs and other non-critical storage
  for fld in $folders_list
  do
    if [ -d $fld ]; then
      echo "  ✓ $fld (already exists)"
    else
      mkdir -p $fld > /dev/null 2>&1
      if [ $? -eq 0 ]; then
        echo "  ✓ $fld"
      else
        echo "  ✗ $fld"
      fi
    fi
  done
}


delete_persistent_storage() {
  echo 'delete_persiste_storage: tbi'
}



get_sciencebox_images_list() {
  local yaml_folder=$KUBOXED_FOLDER
  local yaml_file
  local img
  local img_list=''

  if [ x"$yaml_folder" == x"" ]; then
    return 1
  fi
  for yaml_file in $(ls $yaml_folder)
  do
    if [ -f $yaml_folder/$yaml_file ]; then
    img=$(cat $yaml_folder/$yaml_file | grep 'image:' | awk '{print $NF}' | tr -d '"')
      if [ x"$img" != x"" ]; then
        img_list=$(echo $img_list $img)
      fi
    fi
  done
  echo $img_list
}


get_singleuser_image_name() {
  local yaml_folder=$KUBOXED_FOLDER
  local img=''

  #TODO: This is bad as it is based on some design assumptions and naming conventions
  if [ -f $yaml_folder'/SWAN.yaml' ]; then
    img=$(cat $yaml_folder'/SWAN.yaml' | grep CONTAINER_IMAGE -A 1 | grep 'value:' | awk '{print $2}' | tr -d '"')
  fi
  echo $img
}


pre_pull_images() {
  local images_list=$1
  local img

  echo "Pre-pulling required Docker images locally:"
  for img in $images_list
  do
    echo "  Pulling $img..."
    pull_docker_image_async $img
  done
}


check_required_images() {
  local images_list=$1
  local img

  echo "Checking images availability:"
  for img in $images_list
  do
    if ! check_docker_image_exists_locally $img; then
      echo "  ✗ $img"
    else
      echo "  ✓ $img"
    fi
  done
}


delete_images() {
  local images_list=$1
  local img

  echo "Deleting Docker images:"
  for img in $images_list
  do
    echo "  ✓ $img"
    # TODO: Implement docker delete
  done
}


create_namespace() {
  local yaml_folder=$KUBOXED_FOLDER

  echo "Creating namespace..."
  kubectl apply -f $KUBOXED_FOLDER/BOXED.yaml > /dev/null 2>&1
}


deploy_services() {
  local yaml_folder=$KUBOXED_FOLDER

  echo "Deploying services:"
  #kubectl apply -f $KUBOXED_FOLDER/LDAP.yaml

  echo "dpeloy_services: tbi"
}

