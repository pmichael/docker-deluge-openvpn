#!/bin/bash

set -e

TIMESTAMP_FORMAT='%a %b %d %T %Y'
log() {
  echo "$(date +"${TIMESTAMP_FORMAT}") [ufw-disable] $*"
}

log "Disabling ufw"
ufw disable