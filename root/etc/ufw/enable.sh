#!/bin/bash

set -e

TIMESTAMP_FORMAT='%a %b %d %T %Y'
log() {
  echo "$(date +"${TIMESTAMP_FORMAT}") [tunnel-up] $*"
}
# Source our persisted env variables from container startup
. /etc/deluge/environment-variables.sh

log "Firewall script executed with $*"

# Enable firewall
log "enabling firewall"
sed -i -e s/IPV6=yes/IPV6=no/ /etc/default/ufw

# Block all outgoing
log "Deny all outgoing traffic"
ufw default deny outgoing
# Block all incoming
# log "Deny all incoming traffic"
# ufw default deny incoming
# Allow all incoming
log "Allow all incoming traffic"
ufw default allow incoming

# Allow LOCAL_NETWORK
if [[ -n "${LOCAL_NETWORK-}" ]]; then
  for localNet in ${LOCAL_NETWORK//,/ }; do
    log "Allow in and out from ${localNet}"
    ufw allow in to ${localNet}
    ufw allow out to ${localNet}
  done
fi

# Allow outgoing traffic on the vpn interface ${1} in principle tun0
log "Allow outgoing traffic on ${1}"
ufw allow out on ${1} from any to any

# Allow connection to the VPN IP server
log "Getting server and port from ${2}"
VPN_SERVER_IP=$(cat ${2} | grep -H "remote" | head -1 | cut -d " " -f 3)
VPN_PORT=$(cat ${2} | grep -H "remote" | head -1 | cut -d " " -f 4)
log "Got IP ${VPN_SERVER_IP} and port ${VPN_PORT}"

PROTOCOL="udp"
if [[ -n ${NORDVPN_PROTOCOL} ]]; then
  PROTOCOL=${NORDVPN_PROTOCOL}
fi

log "Allow to connect to ${VPN_SERVER_IP} on port ${VPN_PORT} using ${PROTOCOL}"
ufw allow out to ${VPN_SERVER_IP} port ${VPN_PORT} proto ${PROTOCOL}

ufw enable
ufw status