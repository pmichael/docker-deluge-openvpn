#!/bin/bash

set -e

TIMESTAMP_FORMAT='%a %b %d %T %Y'
log() {
  echo "$(date +"${TIMESTAMP_FORMAT}") [ufw-enable] $*"
}

# Source our persisted env variables from container startup
. /etc/deluge/environment-variables.sh

## If we use UFW or the LOCAL_NETWORK we need to grab network config info
if [[ "${ENABLE_UFW,,}" == "true" ]] || [[ -n "${LOCAL_NETWORK-}" ]]; then
  eval $(/sbin/ip route list match 0.0.0.0 | awk '{if($5!="tun0"){print "GW="$3"\nINT="$5; exit}}')
  ## IF we use UFW_ALLOW_GW_NET along with ENABLE_UFW we need to know what our netmask CIDR is
  if [[ "${ENABLE_UFW,,}" == "true" ]] && [[ "${UFW_ALLOW_GW_NET,,}" == "true" ]]; then
    eval $(/sbin/ip route list dev ${INT} | awk '{if($5=="link"){print "GW_CIDR="$1; exit}}')
  fi
fi

log "Got local network ${GW} and CIDR ${GW_CIDR} on interface ${INT}"

## Open port to any address
function ufwAllowPort {
  typeset -n portNum=${1} proto=${2}
  if [[ "${ENABLE_UFW,,}" == "true" ]] && [[ -n "${portNum-}" ]] && [[ -n "${proto-}" ]]; then
    echo "allowing ${portNum} through the firewall"
    ufw allow ${portNum} proto ${proto}
  fi
}

## Open port to specific address.
function ufwAllowPortLong {
  typeset -n portNum=${1} sourceAddress=${2}

  if [[ "${ENABLE_UFW,,}" == "true" ]] && [[ -n "${portNum-}" ]] && [[ -n "${sourceAddress-}" ]]; then
    echo "allowing ${sourceAddress} through the firewall to port ${portNum}"
    ufw allow from ${sourceAddress} to any port ${portNum}
  fi
}

log "Firewall script executed with $*"

if [[ "${ENABLE_UFW,,}" == "true" ]]; then
  if [[ "${UFW_DISABLE_IPTABLES_REJECT,,}" == "true" ]]; then
    # A horrible hack to ufw to prevent it detecting the ability to limit and REJECT traffic
    sed -i 's/return caps/return []/g' /usr/lib/python3/dist-packages/ufw/util.py
    # force a rewrite on the enable below
    echo "Disable and blank firewall"
    ufw disable
    echo "" > /etc/ufw/user.rules
  fi

  # Enable firewall
  log "enabling firewall"
  sed -i -e s/IPV6=yes/IPV6=no/ /etc/default/ufw
  ufw enable
  
  if [[ "${UFW_ALLOW_GW_NET,,}" == "true" ]]; then
    ufwAllowPortLong DELUGE_WEB_PORT GW_CIDR
    ufwAllowPortLong DELUGE_DEAMON_PORT GW_CIDR
  else
    ufwAllowPortLong DELUGE_WEB_PORT GW
    ufwAllowPortLong DELUGE_DEAMON_PORT GW
  fi

  if [[ -n "${UFW_EXTRA_PORTS-}"  ]]; then
    for port in ${UFW_EXTRA_PORTS//,/ }; do
      if [[ "${UFW_ALLOW_GW_NET,,}" == "true" ]]; then
        ufwAllowPortLong port GW_CIDR
      else
        ufwAllowPortLong port GW
      fi
    done
  fi
fi

if [[ -n "${LOCAL_NETWORK-}" ]]; then
  if [[ -n "${GW-}" ]] && [[ -n "${INT-}" ]]; then
    for localNet in ${LOCAL_NETWORK//,/ }; do
      echo "adding route to local network ${localNet} via ${GW} dev ${INT}"
      /sbin/ip route add "${localNet}" via "${GW}" dev "${INT}"
      if [[ "${ENABLE_UFW,,}" == "true" ]]; then
        ufwAllowPortLong DELUGE_WEB_PORT localNet
        ufwAllowPortLong DELUGE_DEAMON_PORT localNet
        if [[ -n "${UFW_EXTRA_PORTS-}" ]]; then
          for port in ${UFW_EXTRA_PORTS//,/ }; do
            ufwAllowPortLong port localNet
          done
        fi
      fi
    done
  fi
fi

ufw status