#!/bin/bash

/etc/deluge/start.sh "$@"
[[ ! -f /opt/tinyproxy/start.sh ]] || /opt/tinyproxy/start.sh
