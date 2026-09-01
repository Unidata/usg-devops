# run.sh
# Run image builder
# Ensure kube_version property is set in resulting image
# Create a new cluster template

set -e
set -o pipefail

# log function
RUN_LOG_DIR="/image-builder-log"
log () {
  tee -a $RUN_LOG_DIR/run.log
}

# print date
info () {
  echo "[ INFO ] $(date "+%Y-%m-%d %H:%M") -- $@"
}

source /home/openstack/openrc.sh

############### Run image builder ###############

info "Running image builder" | log

# Get UUIDs for the SOURCE_IMAGE and NETWORK
SOURCE_IMAGE_UUID=$(openstack image show $SOURCE_IMAGE -f value -c id)
NETWORK_UUID=$(openstack network show $NETWORK -f value -c id)
info "SOURCE_IMAGE_UUID=$SOURCE_IMAGE_UUID" | log
info "NETWORK_UUID=$NETWORK_UUID" | log

# Ensure $FLAVOR and $KEYPAIR exist and are available to your openstack user
info "Ensuring flavor $FLAVOR is a valid openstack flavor" | log
openstack flavor show $FLAVOR -c name 2>&1 | log

info "Ensuring keypair $SSH_KEYPAIR_NAME is a valid openstack keypair" | log
openstack keypair show $SSH_KEYPAIR_NAME 2>&1 | log

# Construct a packer var_file.json
info "Creating $RUN_LOG_DIR/var_file.json" | log
VAR_FILE=$(cat <<VAR_FILE
{
  "source_image": "$SOURCE_IMAGE_UUID",
  "networks": "$NETWORK_UUID",
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
echo $VAR_FILE > $RUN_LOG_DIR/var_file.json

# Build the image
info "Building new CAPI image"
info "See $RUN_LOG_DIR/run.log"
make build-openstack-ubuntu-2204 | log
