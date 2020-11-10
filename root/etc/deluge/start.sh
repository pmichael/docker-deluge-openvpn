#!/bin/bash

TIMESTAMP_FORMAT='%a %b %d %T %Y'
log() {
  echo "$(date +"${TIMESTAMP_FORMAT}") [tunnel-up] $*"
}

# Source our persisted env variables from container startup
. /etc/deluge/environment-variables.sh

# This script will be called with tun/tap device name as parameter 1, and local IP as parameter 4
# See https://openvpn.net/index.php/open-source/documentation/manuals/65-openvpn-20x-manpage.html (--up cmd)
log "Up script executed with $*"
if [[ "$4" = "" ]]; then
  log "ERROR, unable to obtain tunnel address"
  log "killing $PPID"
  kill -9 $PPID
  exit 1
fi

# If deluge-pre-start.sh exists, run it
if [[ -x /config/deluge-pre-start.sh ]]; then
  log "Executing /config/deluge-pre-start.sh"
  /config/deluge-pre-start.sh "$@"
  log "/config/deluge-pre-start.sh returned $?"
fi

if [[ ! -e "/dev/random" ]]; then
  # Avoid "Fatal: no entropy gathering module detected" error
  log "INFO: /dev/random not found - symlink to /dev/urandom"
  ln -s /dev/urandom /dev/random
fi

log "Using ip of interface $1: $4"
export DELUGE_BIND_ADDRESS_IPV4=$4

if [ -e /config/core.conf ]; then
  log "Updating Deluge conf file: listen_interface=$DELUGE_BIND_ADDRESS_IPV4"
  sed -i -e "s/\"listen_interface\": \".*\"/\"listen_interface\": \"$DELUGE_BIND_ADDRESS_IPV4\"/" /config/core.conf
fi

if [[ "true" = "$DROP_DEFAULT_ROUTE" ]]; then
  log "DROPPING DEFAULT ROUTE"
  ip r del default || exit 1
fi

## If we use UFW or the LOCAL_NETWORK we need to grab network config info
if [[ "${ENABLE_UFW,,}" == "true" ]] || [[ -n "${LOCAL_NETWORK-}" ]]; then
  eval $(/sbin/ip r l | awk '{if($5!="tun0"){print "GW="$3"\nINT="$5; exit}}')
  ## IF we use UFW_ALLOW_GW_NET along with ENABLE_UFW we need to know what our netmask CIDR is
  if [[ "${ENABLE_UFW,,}" == "true" ]] && [[ "${UFW_ALLOW_GW_NET,,}" == "true" ]]; then
    eval $(ip r l dev ${INT} | awk '{if($5=="link"){print "GW_CIDR="$1; exit}}')
  fi
fi

if [[ "${UFW_ALLOW_GW_NET,,}" == "true" ]]; then
  log "Allow in and out from ${GW_CIDR}"
  ufw allow in to ${GW_CIDR}
  ufw allow out to ${GW_CIDR}
fi

if [[ -n "${LOCAL_NETWORK-}" ]]; then
  if [[ -n "${GW-}" ]] && [[ -n "${INT-}" ]]; then
    for localNet in ${LOCAL_NETWORK//,/ }; do
      log "Adding route to local network ${localNet} via ${GW} dev ${INT}"
      /sbin/ip r a "${localNet}" via "${GW}" dev "${INT}"
    done
  fi
fi

log "Starting Deluge"
exec su --preserve-environment abc -s /bin/bash -c "/usr/bin/deluged -d -c /config -L info -l /config/deluged.log" &

# wait for deluge daemon process to start (listen for port)
while [[ $(netstat -lnt | awk '$6 == "LISTEN" && $4 ~ ".58846"') == "" ]]; do
  sleep 0.1
done

log "Starting Deluge webui..."
exec su --preserve-environment abc -s /bin/bash -c "/usr/bin/deluge-web -d -c /config -L info -l /config/web.log" &

# Configure port forwarding if applicable
if [[ -x /etc/openvpn/${OPENVPN_PROVIDER,,}/update-port.sh && -z $DISABLE_PORT_UPDATER ]]; then
  log "Provider ${OPENVPN_PROVIDER^^} has a script for automatic port forwarding. Will run it now."
  log "If you want to disable this, set environment variable DISABLE_PORT_UPDATER=yes"
  log /etc/openvpn/${OPENVPN_PROVIDER,,}/update-port.sh &
fi

# If deluge-post-start.sh exists, run it
if [[ -x /config/deluge-post-start.sh ]]; then
  log "Executing /config/deluge-post-start.sh"
  /config/deluge-post-start.sh "$@"
  log "/config/deluge-post-start.sh returned $?"
fi

log "Deluge startup script complete."
