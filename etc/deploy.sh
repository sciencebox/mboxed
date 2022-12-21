#!/bin/bash
# Parameters and functions to handle deployment of ScienceBox


# Minikube params
MINIKUBE_DRIVER='none'
MINIKUBE_NODE_LABEL='minikube'


minikube_start() {
  #TODO: Investigate other drivers
  echo "Starting minikube..."
  minikube start --driver=$MINIKUBE_DRIVER --kubernetes-version=$KUBERNETES_VERSION
  if [ $? -ne 0 ]; then
    echo "  ✗ Error starting minikube"
    echo "Cannot continue."
    exit 1
  fi
}


minikube_stop() {
  echo "Stopping minikube..."
  minikube stop
}


minikube_delete() {
  echo "Deleting minikube..."
  minikube delete
}


minikube_ingess() {
  echo "Enabling ingress addon... "
  minikube addons enable ingress
  if [ $? -ne 0 ]; then
    echo "  ✗ Error with ingress addon"
    echo "Cannot continue."
    exit 1
  fi
}

minikube_ingress_wait() {
  echo "Waiting for ingress controller to be available..."
  kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=120s > /dev/null 2>&1
  if [ $? -ne 0 ]; then
    echo "  ✗ Ingress controller timed out. Please check for issues on the ingress control plane."
  fi
}


ingress_patch() {
  # As per:
  # - https://kubernetes.io/docs/tasks/access-application-cluster/ingress-minikube/
  # - https://github.com/kubernetes/ingress-nginx
  # - https://kubernetes.io/docs/tasks/manage-kubernetes-objects/update-api-object-kubectl-patch/

  local service_name=$1
  local container_port=$2
  local host_port=$3
  local namespace=$4

  if [ x"$host_port" == x"" ]; then
    host_port=$container_port
  fi
  if [ x"$namespace" == x"" ]; then
    namespace='default'
  fi

  echo "Configuring ingress for $service_name on port $host_port..."
  target="$namespace/$service_name:$container_port"
  json_patch=$(jq --null-input --compact-output \
    --arg host_port "$host_port" \
    --arg target "$target" \
    '{"data":{($host_port):($target)}}'
    )
  kubectl -n kube-system patch configmap tcp-services --patch=$json_patch

  json_patch=$(jq --null-input --compact-output \
    --arg hp "$host_port" \
    --arg cp "$container_port" \
    '{"spec":{"template":{"spec":{"containers":[{"name":"controller","ports":[{"containerPort":($cp | tonumber),"hostPort":($hp | tonumber)}]}]}}}}' \
    )
 kubectl -n kube-system patch deployment ingress-nginx-controller --patch=$json_patch
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
      echo "  ✓ SELinux unmodified (was already $selinux_status)"
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


configure_network() {
  local iptables_save_file=$PWD"/iptables_"$(date +%s)".save"
  local netconf_list='net.ipv4.conf.all.forwarding net.ipv6.conf.all.forwarding net.bridge.bridge-nf-call-iptables net.bridge.bridge-nf-call-ip6tables'
  local netconf

  echo "Configuring networking..."
  echo "  WARNING: iptables and IP forwarding rules need to be modified."
  echo "    - The existing iptables configuration will be saved to file ($iptables_save_file) in order to restore it, if needed."
  echo "    - Changes to IP forwarding rules will be reported to roll them back, if needed."
  echo "    - The Docker daemon needs to be restarted. Running containers will temporarily stop while the Docker server restarts."
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
  else
    echo "  ✗ Error saving iptables configuration to $iptables_save_file"
    echo "  Dumping current iptable configuration on screen:"
    iptables-save
  fi
  iptables --flush
  #iptables --table nat --flush
}


configure_gpu_support() {
  if ! prompt_user_for_gpu_support; then
    return
  fi
  check_nvidia_driver
}


check_nvidia_driver()
{
    echo "Checking if the nvidia kernel driver is loaded..."
    if lsmod | grep "nvidia" &> /dev/null ; then
      echo "  ✓ nvidia kernel driver is loaded"
    else
      echo "  ✗ nvidia kernel driver is not loaded. Please configure your GPU driver first."
      echo "  ✗ GPU support disabled."
      GPU_SUPPORT=false
    fi
}


suggest_iptables_restore() {
  echo "WARNING: iptables configuration was modified when setting up ScienceBox."
  echo "  Consider restoring the previous configuraton with \`iptables-restore < iptables_<timestamp>.save\`."
  echo "  If you ran the set up script multiple times, you should likely restore the oldest file."
}

suggest_docker_daemon_restore() {
  echo "WARNING: If GPU support was enabled, the docker daemon configuration has been modified."
  echo "  Consider restoring the previous configuraton (if any) by moving docker_daemon.json_<timestamp>.save to /etc/docker/daemon.json"
  echo "  If you ran the set up script multiple times, you should likely restore the oldest file."
}


helm_repo_add() {
  local repo_name=$1
  local url=$2

  echo "Adding helm repo $repo_name..."
  helm repo add $repo_name $url
  helm_repo_update > /dev/null
}

helm_repo_update() {
  helm repo update
}


get_sciencebox_images_list() {
  # TODO
  return
}


get_singleuser_image_name() {
  # TODO
  return
}


get_required_images_list() {
  local sciencebox_images
  local singleuser_image

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


_install_inform_user() {
  echo ""
  echo ""
  echo "ScienceBox is being installed!"
  echo "  Now it is a good time to grab a coffee..."
  echo ""
  echo "  The deployment should be ready in a few minutes."
  echo "  You can check the containers status by typing \`kubectl get pods\`."
  echo ""
  echo "  Once all the containers are running (or completed), you can reach ScienceBox from your browser at"
  echo "  https://$HOSTNAME/sciencebox"
  echo ""
}

install_charts() {
  helm upgrade --install \
    --set nginx-welcome-page.ingress.hostname=${HOSTNAME} \
    --set nginx-cernbox-theme.ingress.hostname=${HOSTNAME} \
    --set eos-instance-config.config.oauth.enabled=true \
    --set eos-instance-config.config.oauth.resourceEndpoint=${HOSTNAME}/konnect/v1/userinfo \
    --set cernbox.ocis.env.IDP_ISS=https://${HOSTNAME} \
    --set cernbox.ocis.env.OCIS_URL=https://${HOSTNAME} \
    --set cernbox.ocis.ingress.hosts="{${HOSTNAME}}" \
    --set cernbox.cernboxconfig.server="https://${HOSTNAME}" \
    --set cernbox.gateway.hostname="https://${HOSTNAME}" \
    --set cernbox.authproviderbearer.oidc.issuer="https://${HOSTNAME}" \
    --set cernbox.ocis.config.server="https://${HOSTNAME}" \
    --set swan.jupyterhub.hub.config.KeyCloakAuthenticator.oidc_issuer=https://${HOSTNAME} \
    --set swan.jupyterhub.hub.config.KeyCloakAuthenticator.oauth_callback_url=https://${HOSTNAME}/swan/hub/oauth_callback \
    --set swan.jupyterhub.ingress.hosts="{${HOSTNAME}}" \
    sciencebox sciencebox/sciencebox

  _install_inform_user
}
