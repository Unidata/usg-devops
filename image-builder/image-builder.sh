usage () {
cat <<USAGE
Usage: export or set environment variables when running
Usage: Only OPENRC_PATH, SOURCE_IMAGE, and NETWORK are necessary
Usage: See source for all available options
OPENRC_PATH=/path/to/openrc.sh \\
SOURCE_IMAGE=UUID \\
NETWORK=UUID \\
$0
USAGE
}

TAG=${TAG:-latest}

# SOURCE_IMAGE=$(openstack image show Featured-Minimal-Ubuntu22 -f value -c id)
# NETWORK=${NETWORK:-$(openstack network show auto_allocated_network -f value -c id)}

if [[ -z "$SOURCE_IMAGE" ]]; then
  echo "!!! ERROR: Must provide a SOURCE_IMAGE"
  usage
  exit 1
fi
if [[ -z "$NETWORK" ]]; then
  echo "!!! ERROR: Must provide a NETWORK"
  usage
  exit 1
fi

FLAVOR=${FLAVOR:-m3.quad}

IMAGE_NAME_BASE=${IMAGE_NAME_BASE:-unidata-ubuntu-magnum}
TIMESTAMP=$(date +%Y%m%d_%H%M)
IMAGE_NAME_SUFFIX=${IMAGE_NAME_SUFFIX:-$TIMESTAMP}
# export necessary for container to inherit with a `docker run -e IMAGE_NAME`
export IMAGE_NAME=${IMAGE_NAME:-$IMAGE_NAME_BASE-$IMAGE_NAME_SUFFIX}

# If wanting to base off of something that isn't a featured ubuntu image, give ourselves a backdoor
SSH_USERNAME=${SSH_USERNAME:-ubuntu}

# The keypair name to use, as recognized by JS2/openstack
SSH_KEYPAIR_NAME=${SSH_KEYPAIR_NAME:-packer}

# Will be mounted via docker, so we need the full path
KEY_FILE=${KEY_FILE:-~/.ssh/id_ed25519_packer}
KEY_FILE=$(realpath $KEY_FILE)

# Ditto, but error out if one is not provided
if [[ -z "$OPENRC_PATH" ]]; then
  echo "!!! ERROR: Must provide an OPENRC_PATH !!!"
  usage
  exit 1
fi
OPENRC_PATH=$(realpath $OPENRC_FILE)

NODE_CUSTOM_ROLES_POST=${NODE_CUSTOM_ROLES_POST:-unidata-profile}

# Setup directories
LOG_DIR=$(pwd)/logs/$IMAGE_NAME
ROLES_DIR=$(pwd)/roles/$NODE_CUSTOM_ROLES_POST
mkdir -p $LOG_DIR

# Construct a packer var_file.json
VAR_FILE=$(cat <<VAR_FILE
{
  "source_image": "$SOURCE_IMAGE",
  "networks": "$NETWORK",
  "flavor": "$FLAVOR",
  "floating_ip_network": "",
  "use_floating_ip": "false",
  "image_name": "$IMAGE_NAME",
  "image_visibility": "private",
  "image_disk_format": "",
  "use_blockstorage_volume": "false",
  "volume_size": "",
  "volume_type": "",
  "security_groups": "image-builder",
  "ssh_username": "$SSH_USERNAME",
  "ssh_keypair_name": "$SSH_KEYPAIR_NAME",
  "ssh_private_key_file": "~/.ssh/id_ed25519_packer",
  "node_custom_roles_post": "$NODE_CUSTOM_ROLES_POST"
}
VAR_FILE
)
echo $VAR_FILE > $LOG_DIR/var_file.json

source $OPENRC_PATH

docker run -t \
  --name $IMAGE_NAME \
  -e IMAGE_NAME \
  -e PACKER_LOG=1 \
  -e PACKER_LOG_PATH=/image-builder-log/packer_debug.log \
  -e PACKER_VAR_FILES=/image-builder-log/var_file.json \
  -e OS_AUTH_TYPE \
  -e OS_AUTH_URL \
  -e OS_IDENTITY_API_VERSION \
  -e OS_REGION_NAME \
  -e OS_INTERFACE \
  -e OS_APPLICATION_CREDENTIAL_ID \
  -e OS_APPLICATION_CREDENTIAL_SECRET \
  -v $LOG_DIR:/image-builder-log \
  -v $ROLES_DIR:/home/openstack/image-builder/images/capi/ansible/roles/$NODE_CUSTOM_ROLES_POST \
  -v $KEY_FILE:/home/openstack/.ssh/id_ed25519_packer \
  unidata/image-builder:$TAG make build-openstack-ubuntu-2204
