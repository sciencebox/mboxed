#!/bin/bash
# Parameters and functions to handle deployment of ScienceBox


# Minikube params
MINIKUBE_DRIVER='none'
MINIKUBE_NODE_LABEL='minikube'

# Kuboxed
KUBOXED_GIT='https://github.com/cernbox/kuboxed.git'
KUBOXED_FOLDER='kuboxed'

# EOS
EOS_FST_NUMBER=4

# SWAN listening ports
SWAN_HTTP_PORT='10080'
SWAN_HTTPS_PORT='10443'


start_minikube() {
  #TODO: Investigate other dirvers
  echo "Starting minikube..."
  minikube start --driver=$MINIKUBE_DRIVER --kubernetes-version=$KUBERNETES_VERSION
  if [ $? -ne 0 ]; then
    echo "  ✗ Error starting minikube"
    echo "Cannot continue."
    exit 1
  fi
}

stop_minikube() {
  echo "Stopping minikube..."
  minikube stop
}

delete_minikube() {
  echo "Deleting minikube..."
  minikube delete
}

configure_sysctl_param() {
  local param=$1
  local value

  value=$(sysctl $param --values)
  if [ $? -ne 0 ]; then
    echo "  ✗ Error configuring $param"
  fi
  if [ $value -eq 1 ]; then
    echo "  ✓ $param=$value (not modified)"
  else
    sysctl $param=1 > /dev/null 2>&1
    echo "  ✓ $param=$value (changed to 1)"
  fi
}


configure_network() {
  local iptables_save_file=$PWD"/iptables_"$(date +%s)".save"
  local netconf_list='net.ipv4.conf.all.forwarding net.ipv6.conf.all.forwarding net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables'
  local netconf

  echo "WARNING: iptables and IP forwarding rules need to be modified."
  echo "  - The existing iptables configuration will be saved to file ($iptables_save_file) in order to restore it, if needed."
  echo "  - Changes to IP forwarding rules will be reported to roll them back, if needed."
  echo "WARNING: Docker needs to be restarted to subsequently to the network changes."
  echo "  - The Docker configuration will be left untouched."
  echo "  - Running containers will temporarily stop while the Docker server restarts."
  prompt_user_to_continue

  echo "Configuring network forwarding parameters..."
  for netconf in $netconf_list
  do
    configure_sysctl_param $netconf
  done

  echo "Configuring iptables..."
  iptables-save > $iptables_save_file
  if [ $? -eq 0 ]; then
    echo "  ✓ iptables configuration saved to $iptables_save_file."
    #echo "  Restore it with \`iptables-restore < $iptables_save_file\` if needed"
  else
    echo "  ✗ Error saving iptables configuration to $iptables_save_file"
    echo "  Dumping iptable configuration now:"
    iptables-save
  fi
  iptables --flush
  #iptables --table nat --flush

  echo "Restarting Docker..."
  restart_docker
}


configure_selinux() {
  local selinux_status

  echo "Configuring SELinux..."
  if [[ "$OS_ID" == "centos" ]] && [[ "$OS_VERSION" == "8" ]]; then
    selinux_status=$(getenforce)
    if [ "$selinux_status" == "Enforcing" ]; then
      echo "WARNING: SELinux must be set to Permissive on CentOS 8."
      prompt_user_to_continue
      setenforce 0
      echo "  ✓ SELinux set to Permissive (was $selinux_status)"
    else
      echo "  ✓ SELinux unmodifies (was already $selinux_status)"
    fi
  fi

  #case "$OS_ID" in
  #  centos)
  #    case "$OS_VERSION" in
  #      7)
  #        ;;
  #      8)
  #        ;;
  #    esac
  #    ;;
  #  ubuntu)
  #    ;;
  #esac
}

suggest_iptables_restore() {
  echo "WARNING: iptables configuration was modified when setting up ScienceBox."
  echo "  Consider restoring the previous configuraton with \`iptables-restore < iptables_<timestamp>.save\`."
  echo "  If you ran the set up script multiple times, you should like restore the oldest file."

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
  sed -i "$swan_http_port_lineno s/^\( *value: *\)[^ ]*\(.*\)*$/\1\"$SWAN_HTTP_PORT\"\2/" $KUBOXED_FOLDER/SWAN.yaml
  ##   Change HTTPS port
  sed -i "s/^\( *hostPort: &HTTPS_PORT *\)[^ ]*\(.*\)*$/\1$SWAN_HTTPS_PORT\2/" $KUBOXED_FOLDER/SWAN.yaml
  local swan_https_port_lineno=$(cat $KUBOXED_FOLDER/SWAN.yaml | grep "name: HTTPS_PORT" -n | cut -d ':' -f 1)
  swan_https_port_lineno=$(($swan_https_port_lineno+1))
  sed -i "$swan_https_port_lineno s/^\( *value: *\)[^ ]*\(.*\)*$/\1\"$SWAN_HTTPS_PORT\"\2/" $KUBOXED_FOLDER/SWAN.yaml
  ##   Change upstream SWAN server port in CERNBOX nginx configuration
  sed -i 's/^\( *hostNetwork: *\)[^ ]*\(.*\)*$/\1false\2/' $KUBOXED_FOLDER/SWAN.yaml    # Swan should not use the host network
  local swan_port_lineno=$(cat $KUBOXED_FOLDER/CERNBOX.yaml | grep SWAN_BACKEND_PORT -n | cut -d ':' -f 1)
  swan_port_lineno=$(($swan_port_lineno+1))
  sed -i "$swan_port_lineno s/^\( *value: *\)[^ ]*\(.*\)*$/\1\"$SWAN_HTTPS_PORT\"\2/" $KUBOXED_FOLDER/CERNBOX.yaml

  # Create YAML files for EOS FSTs
  for no in $(seq 1 $EOS_FST_NUMBER)
  do 
    bash $KUBOXED_FOLDER/eos-storage-fst.sh $no eos-mgm.boxed.svc.cluster.local eos-mgm.boxed.svc.cluster.local docker default
    sed -i "s/fst_userdata/fst$no\_userdata/g" $KUBOXED_FOLDER/eos-storage-fst$no\.yaml
  done
}


get_persistent_storage_paths() {
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
  # - /var/kubeVolumes (subolders will be automatically created)

  # TODO:
  #   By now, they are inferred from the YAML files, but this will disappear with Helm
  #
  local folders_list
  folders_list=$(cat $KUBOXED_FOLDER/*.yaml | grep -i "hostPath:" -A 2 | grep -i -w "type: Directory" -B 1 | grep -i "path: " | awk '{print $NF}')
  folders_list=$(echo $folders_list "/var/kubeVolumes") # This is for logs and other non-critical storage #TODO: Hard-coded=Bad.

  echo $folders_list | tr ' ' '\n' | sort | uniq | tr '\n' ' '
}


create_persistent_storage() {
  local folders_list=$(get_persistent_storage_paths)
  local fld
  
  echo "Preparing persistent storage..."
  folders_list=$(get_persistent_storage_paths)
  for fld in $folders_list
  do
    if [ -d $fld ]; then
      echo "  ✓ $fld (already exists)"
    else
      mkdir -p $fld > /dev/null 2>&1
      if [ $? -eq 0 ]; then
        echo "  ✓ $fld"
      else
        echo "  ✗ $fld (error while creating folder)"
      fi
    fi
  done
}


delete_persistent_storage() {
  local folders_list
  local fld

  #
  # TODO: Does not delete parent folders
  # e.g., /mnt/ldap/config, only 'config' is deleted and not 'ldap'
  #
  echo "Deleting persistent storage..."
  folders_list=$(get_persistent_storage_paths)
  for fld in $folders_list
  do
    if [ -d $fld ]; then
      #TODO: This is dangerous. Not sure I want to `rm -rf` a list of folders inferred form other files
      #rm -rf $fld > /dev/null 2>&1
      echo "  --> Not deleting $fld. Do it manually if totally sure."
      #if [ $? -eq 0 ]; then
      #  echo "  ✓ $fld"
      #else
      #  echo "  ✗ $fld (error while deleting folder)"
      #fi
    else
      echo "  ✓ $fld (does not exist)"
    fi
  done
}


get_sciencebox_images_list() {
  local yaml_file
  local img
  local img_list=''

  if [ x"$KUBOXED_FOLDER" == x"" ]; then
    return 1
  fi
  for yaml_file in $(ls $KUBOXED_FOLDER)
  do
    if [ -f $KUBOXED_FOLDER/$yaml_file ]; then
    img=$(cat $KUBOXED_FOLDER/$yaml_file | grep 'image:' | awk '{print $NF}' | tr -d '"')
      if [ x"$img" != x"" ]; then
        img_list=$(echo $img_list $img)
      fi
    fi
  done
  echo $img_list
}


get_singleuser_image_name() {
  local img=''

  #TODO: This is bad as it is based on some design assumptions and naming conventions
  if [ -f $KUBOXED_FOLDER'/SWAN.yaml' ]; then
    img=$(cat $KUBOXED_FOLDER'/SWAN.yaml' | grep CONTAINER_IMAGE -A 1 | grep 'value:' | awk '{print $2}' | tr -d '"')
  fi
  echo $img
}


get_required_images_list() {
  local sciencebox_images
  local singleuser_image
  local images_list

  sciencebox_images=$(get_sciencebox_images_list)
  singleuser_image=$(get_singleuser_image_name)
  echo $sciencebox_images $singleuser_image | tr ' ' '\n' | sort | uniq | tr '\n' ' '
}


pre_pull_images() {
  local images_list=$(get_required_images_list)
  local img

  echo "Pre-pulling required Docker images locally:"
  for img in $images_list
  do
    echo "  Pulling $img..."
    pull_docker_image_async $img
  done
}


check_required_images() {
  local images_list=$(get_required_images_list)
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
  local images_list=$(get_required_images_list)
  local img

  echo "Deleting Docker images:"
  for img in $images_list
  do
    echo "  ✓ $img"
    docker image rm $img > /dev/null 2>&1
  done
}


create_namespace() {
  echo "Creating namespace..."
  kubectl apply -f $KUBOXED_FOLDER/BOXED.yaml > /dev/null 2>&1
}


get_namespace() {
  local namespace

  namespace=$(cat $KUBOXED_FOLDER/BOXED.yaml | grep -i "metadata:" -A 1 | grep -i "name:" | awk '{print $NF}')
  echo $namespace
}


check_service_running() {
  local pod_name=$1
  local pod_namespace=$(get_namespace)

  res=$(kubectl --namespace=$pod_namespace get pods --no-headers --field-selector=status.phase==Running -o custom-columns=NAME:.metadata.name | grep -i ^$pod_name)
  if [ x"$res" == x"" ]; then
    return 1
  fi
  return 0
}


_deploy_service() {
  local svc_name=$1
  local svc_yaml=$2
  local wait_time=0
  local timeout=300

  kubectl apply -f $svc_yaml > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "  ✗ Error deploying $svc_name"
    echo "Cannot continue."
    exit 1
  fi
  while ! $(check_service_running $svc_name)
  do
    sleep 5
    wait_time=$(($wait_time+5))
    if [ $wait_time -ge $timeout ]; then
      break
    fi
  done
  if [ $wait_time -ge $timeout ]; then
    echo "  ✗ Error deploying $svc_name (timeout after $wait_time)"
  else
    echo "  ✓ $svc_name"
  fi
}

exec_in_container() {
  local pod_name=$1
  local cmd=$2
  local pod_namespace=$(get_namespace)
  local container_fullname

  container_fullname=$(kubectl --namespace=$pod_namespace get pods --no-headers -o custom-columns=NAME:.metadata.name | grep -i ^$pod_name)
  if [ x"$container_fullname" == x"" ]; then
    echo "    ✗ Unable to find $pod_name to execute $cmd"
  fi

  kubectl --namespace=$pod_namespace exec -it $container_fullname $cmd > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "    ✗ Errors occurred while executing $cmd in $container_fullname"
  else
    echo "    ✓ $cmd in $container_fullname applied"
  fi
}


deploy_services() {
  echo "Deploying services (might take some time):"

  # LDAP
  _deploy_service "ldap" "$KUBOXED_FOLDER/LDAP.yaml"
  exec_in_container "ldap" "bash /root/addusers.sh"

  # EOS
  _deploy_service "eos-mgm" "$KUBOXED_FOLDER/eos-storage-mgm.yaml"
  # TODO: Actions to configure the MGM should go here
  sleep 30
  echo "    ✓ eos-mgm configuration"
  for no in $(seq 1 $EOS_FST_NUMBER)
  do
    _deploy_service "eos-fst$no" "$KUBOXED_FOLDER/eos-storage-fst$no.yaml"
  done

  # CERNBOX
  _deploy_service "cernbox" "$KUBOXED_FOLDER/CERNBOX.yaml"

  # SWAN
  #TODO: Check #sudo kubectl create clusterrolebinding add-on-cluster-admin --clusterrole=cluster-admin --serviceaccount=boxed:default
  _deploy_service "swan" "$KUBOXED_FOLDER/SWAN.yaml"
  #TODO: Check 
    #sudo kubectl exec -n boxed $SWAN_PODNAME -- sed -i 's/"0.0.0.0"/"127.0.0.1"/g' /srv/jupyterhub/jupyterhub_config.py
    #sudo kubectl exec -n boxed $SWAN_PODNAME -- sed -i '/8080/a hub_ip='"$HOSTNAME"'' /srv/jupyterhub/jupyterhub_config.py
}

enable_gpu_support(){
echo ""
    read -r -p "Do you want enable gpu support [y/N] " response
    case "$response" in
      [yY]) 
        echo "Installing the NVidia k8s-device-plugin..."
        kubectl create -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/1.0.0-beta4/nvidia-device-plugin.yml
      ;;
      *)
        echo "Continuing without GPU support"
      ;;
    esac
}
