#!/bin/bash
set -euo pipefail

USERNAME="openstack"
USER_ID=${OPENSTACK_USER_ID:-1000}
GROUP_ID=${OPENSTACK_GROUP_ID:-1000}

case "$USER_ID" in
    (''|*[!0-9]*)
        echo "ERROR: OPENSTACK_USER_ID must be numeric, got '$USER_ID'" >&2;
                  exit 1;;
esac
case "$GROUP_ID" in
    (''|*[!0-9]*)
        echo "ERROR: OPENSTACK_GROUP_ID must be numeric, got '$GROUP_ID'" >&2;
                  exit 1;;
esac
if [ "$USER_ID" -eq 0 ] || [ "$GROUP_ID" -eq 0 ]; then
   echo "ERROR: OPENSTACK_USER_ID and OPENSTACK_GROUP_ID must be non-root" >&2
   exit 1
fi

if ! getent group "$USERNAME" >/dev/null; then
    groupadd -r "$USERNAME" -g "$GROUP_ID"
fi

if ! id -u "$USERNAME" >/dev/null 2>&1; then
    useradd -u "$USER_ID" -g "$USERNAME" -s /bin/bash -c "Openstack user" "$USERNAME" 2>/dev/null
fi

HOME_DIR=$(getent passwd "$USERNAME" | cut -d: -f6)
chown -R "$USER_ID:$GROUP_ID" "$HOME_DIR"

exec gosu "$USERNAME" "$@"
