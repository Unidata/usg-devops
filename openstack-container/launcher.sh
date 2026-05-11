#!/bin/bash -f

function usage() {
  echo -e "Syntax: $(basename "$0") [-h] [-n <name>] [-o <openrc>]"
  echo -e "Script to access OpenStack environment."
  echo -e "  -h, --help            Show this help text"
  echo -e "  -n, --name            JupyterHub name"
  echo -e "  -o, --openrc          OpenRC file path"
  exit 1
}

# Argument parsing
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -h|--help)
            usage
            ;;
        -n|--name)
            JUPYTERHUB="$2"
            shift 2
            ;;
        -o|--openrc)
            OPENRC="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $key"
            usage
            ;;
    esac
done

# Check mandatory arguments
if [[  -z "$OPENRC" ]]; then
    echo "Error: OpenRC path."
    usage
fi

DOCKER_ARGS=(
    -it
    --name "openstack"
    -e "OPENSTACK_USER_ID=$(id -u)"
    -e "OPENSTACK_GROUP_ID=$(getent group "$USER" | cut -d':' -f3)"
    -v "${OPENRC}:/home/openstack/bin/openrc.sh"
)

if [[ -n "$JUPYTERHUB" ]]; then
    BASE_DIR="$(pwd)/jhubs/${JUPYTERHUB}"
    KUBE="$BASE_DIR/kube"
    SECRETS="$BASE_DIR/secrets.yaml"

    mkdir -p "$KUBE"
    touch "$SECRETS"

    DOCKER_ARGS=(
        -it
        --name "$JUPYTERHUB"
        -e "OPENSTACK_USER_ID=$(id -u)"
        -e "OPENSTACK_GROUP_ID=$(getent group "$USER" | cut -d':' -f3)"
        -v "${OPENRC}:/home/openstack/bin/openrc.sh"
        -v "${KUBE}:/home/openstack/.kube/"
        -v "${SECRETS}:/home/openstack/jupyterhub-deploy-kubernetes-jetstream/secrets.yaml"
        -e "CLUSTER=${JUPYTERHUB}"
        -e "K8S_CLUSTER_NAME=${JUPYTERHUB}"
    )
fi

docker run "${DOCKER_ARGS[@]}" unidata/usg-devops /bin/bash
