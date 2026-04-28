# /usr/bin/env /usr/bin/bash

set -x

INSTALL_PATH=$HOME/.local/bin/
CONFIG_PATH=$HOME/.config/usage-monitoring/

mkdir -p $INSTALL_PATH $CONFIG_PATH

ln -s $PWD/usage_monitoring.py $INSTALL_PATH/usage_monitoring.py
ln -s $PWD/config.json $CONFIG_PATH/config.json
