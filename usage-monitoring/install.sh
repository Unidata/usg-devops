# /usr/bin/env /usr/bin/bash

set -x

INSTALL_PATH=$HOME/.local/bin/
CONFIG_PATH=$HOME/.config/usage-monitoring/

mkdir -p $INSTALL_PATH $CONFIG_PATH

ln -s ./usage_monitoring.py $INSTALL_PATH
ln -s ./usage_monitoring_config.py $CONFIG_PATH
