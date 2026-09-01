usage () {
cat <<USAGE
---------------------------------------------------------------------
Usage:
[ IMAGE_BUILDER_ENV="/path/to/env.sh" ] ./$0 \\
  --openrc-path                </path/to/openrc.sh> \\
  --source-image               <source-image-name-or-uuid> \\
  --network                    <network-name-or-uuid> \\
  [ --docker-image-tag ]       <image-tag> \\
  [ --source-image-flavor ]    <source-image-flavor> \\
  [ --image-name-base ]        <resulting-image-name-base> \\
  [ --image-name-suffix ]      <resulting-image-name-suffix> \\
  [ --ssh-username ]           <source-instance-ssh-username> \\
  [ --ssh-keypair-name ]       <openstack-keypair-name> \\
  [ --ssh-key-file ]           </path/to/private/key> \\
  [ --node-custom-roles-post ] <custom-role-name> \\
  [ --help ]
---------------------------------------------------------------------
Usage:
Alternatively, create an env.sh setting the environment variables as in the example below:
########### env.sh ##########
# Required arguments:
OPENRC_PATH=
SOURCE_IMAGE=
NETWORK=

# Optional arguments:
DOCKER_IMAGE_TAG=latest
SOURCE_IMAGE_FLAVOR=m3.quad
IMAGE_NAME_BASE=unidata-ubuntu-magnum
IMAGE_NAME_SUFFIX=$(date +%Y%m%d_%H%M)
SSH_USERNAME=ubuntu
SSH_KEYPAIR_NAME=packer
SSH_KEY_FILE=~/.ssh/id_ed25519_packer
NODE_CUSTOM_ROLES_POST=unidata-profile
########### env.sh ##########
Then:
[ IMAGE_BUILDER_ENV="/path/to/env.sh" ] ./$0 [ options ]

In this case, options override values from env.sh
USAGE
}

# First source environment file
IMAGE_BUILDER_ENV=${IMAGE_BUILDER_ENV:-"./env.sh"}
ls -1 &> /dev/null $IMAGE_BUILDER_ENV || { echo "[ ERROR ] $IMAGE_BUILDER_ENV not found! Exiting ..."; exit 1; }
source $IMAGE_BUILDER_ENV

# Parse script args
#   Override environment file vars with those parsed
while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    --openrc-path)
      OPENRC_PATH="$2"
      shift 2
      ;;
    --source-image)
      SOURCE_IMAGE="$2"
      shift 2
      ;;
    --network)
      NETWORK="$2"
      shift 2
      ;;
    --docker-image-tag)
      DOCKER_IMAGE_TAG="$2"
      shift 2
      ;;
    --source-image-flavor)
      SOURCE_IMAGE_FLAVOR="$2"
      shift 2
      ;;
    --image-name-base)
      IMAGE_NAME_BASE="$2"
      shift 2
      ;;
    --image-name-suffix)
      IMAGE_NAME_SUFFIX="$2"
      shift 2
      ;;
    --ssh-username)
      SSH_USERNAME="$2"
      shift 2
      ;;
    --ssh-keypair-name)
      SSH_KEYPAIR_NAME="$2"
      shift 2
      ;;
    --ssh-key-file)
      SSH_KEY_FILE="$2"
      shift 2
      ;;
    --node-custom-roles-post)
      NODE_CUSTOM_ROLES_POST="$2"
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      echo "[ ERROR ] Unknown option: $key"
      usage
      exit 1
      ;;
  esac
done

# Ensure required variables are set and ensure everythiing else is defaulted
if [[ -z "$OPENRC_PATH" ]]; then
  echo "!!! ERROR: Must provide an OPENRC_PATH"
  usage
  exit 1
fi
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
export SOURCE_IMAGE \
  NETWORK \
  DOCKER_IMAGE_TAG=${DOCKER_IMAGE_TAG:-"latest"} \
  SOURCE_IMAGE_FLAVOR=${SOURCE_IMAGE_FLAVOR:-"m3.quad"} \
  IMAGE_NAME_BASE=${IMAGE_NAME_BASE:-"unidata-ubuntu-magnum"} \
  IMAGE_NAME_SUFFIX=${IMAGE_NAME_SUFFIX:-"$(date +%Y%m%d_%H%M)"} \
  SSH_USERNAME=${SSH_USERNAME:-"ubuntu"} \
  SSH_KEYPAIR_NAME=${SSH_KEYPAIR_NAME:-"packer"} \
  NODE_CUSTOM_ROLES_POST=${NODE_CUSTOM_ROLES_POST:-"unidata-profile"}

# Ensure absolute paths are sent to the docker run command
export OPENRC_PATH=$(realpath $OPENRC_PATH) \
  SSH_KEY_FILE=$(realpath ${SSH_KEY_FILE:-~/.ssh/id_ed25519_packer})

# Export "derived" variables
# NOTE: If a NODE_CUSTOM_ROLES_POST isn't set, the resulting bind mount will mount an *empty or non-existent* $(pwd)/roles directory into the image-builder/images/capi/ansible/roles directory, breaking everything :)
# This must be fixed
export \
  IMAGE_NAME=${IMAGE_NAME:-"$IMAGE_NAME_BASE-$IMAGE_NAME_SUFFIX"} \
  ROLES_DIR=$(pwd)/roles/$NODE_CUSTOM_ROLES_POST
  LOG_DIR=$(pwd)/logs/$IMAGE_NAME

# Ensure base log dir exists
mkdir -p $LOG_DIR

# Run docker image
#   Bind mount log dir
#   Bind mount ssh key file
#   Bind mount roles dir
#   Set env vars with -e option to docker run
docker run -t \
  --name $IMAGE_NAME \
  -e PACKER_LOG=1 \
  -e PACKER_LOG_PATH=/image-builder-log/packer_debug.log \
  -e PACKER_VAR_FILES=/image-builder-log/var_file.json \
  -e SOURCE_IMAGE -e NETWORK -e SOURCE_IMAGE_FLAVOR \
  -e IMAGE_NAME -e SSH_USERNAME -e SSH_KEYPAIR_NAME \
  -e SSH_KEY_FILE \
  -u $(id -u) \
  -v $LOG_DIR:/image-builder-log \
  -v $ROLES_DIR:/home/openstack/image-builder/images/capi/ansible/roles/$NODE_CUSTOM_ROLES_POST \
  -v $SSH_KEY_FILE:/home/openstack/.ssh/id_ed25519_packer \
  -v $OPENRC_PATH:/home/openstack/openrc.sh \
  unidata/image-builder:${DOCKER_IMAGE_TAG}
