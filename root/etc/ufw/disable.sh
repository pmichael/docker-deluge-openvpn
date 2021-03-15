#!/bin/bash

set -e

TIMESTAMP_FORMAT='%a %b %d %T %Y'
log() {
  echo "$(date +"${TIMESTAMP_FORMAT}") [ufw-disable] $*"
}
# Source our persisted env variables from container startup
. /etc/deluge/environment-variables.sh

ufw reset
ufw disable
ufw status