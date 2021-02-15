#!/bin/bash

##
# Get some initial setup out of the way.
##

TIMESTAMP_FORMAT='%a %b %d %T %Y'
log() {
  echo "$(date +"${TIMESTAMP_FORMAT}") [tunnel-up] $*"
}

if [[ -n "$REVISION" ]]; then
  log "Starting container with revision: $REVISION"
fi

[[ "${DEBUG}" == "true" ]] && set -x

log "[info] System information $(uname -a)"

export PUID=$(echo "${PUID}" | sed -e 's/^[ \t]*//')
if [[ ! -z "${PUID}" ]]; then
  log "[info] PUID defined as '${PUID}'"
else
  log "[warn] PUID not defined (via -e PUID), defaulting to '99'"
  export PUID="99"
fi

# set user nobody to specified user id (non unique)
usermod -o -u "${PUID}" abc &>/dev/null

export PGID=$(echo "${PGID}" | sed -e 's/^[ \t]*//')
if [[ ! -z "${PGID}" ]]; then
  log "[info] PGID defined as '${PGID}'"
else
  log "[warn] PGID not defined (via -e PGID), defaulting to '100'"
  export PGID="100"
fi

# set group nobody to specified group id (non unique)
groupmod -o -g "${PGID}" abc &>/dev/null

# check for presence of perms file, if it exists then skip setting
# permissions, otherwise recursively set on volume mappings for host
if [[ ! -f "/config/perms.txt" ]]; then
  log "[info] Setting permissions recursively on volume mappings..."

  if [[ -d "/downloads" ]]; then
    volumes=("/config" "/downloads")
  else
    volumes=("/config")
  fi

  set +e
  chown -R "${PUID}":"${PGID}" "${volumes[@]}"
  exit_code_chown=$?
  chmod -R 775 "${volumes[@]}"
  exit_code_chmod=$?
  set -e

  if ((${exit_code_chown} != 0 || ${exit_code_chmod} != 0)); then
    log "[warn] Unable to chown/chmod ${volumes}, assuming NFS/SMB mountpoint"
  fi

  echo "This file prevents permissions from being applied/re-applied to /config, if you want to reset permissions then please delete this file and restart the container." >/config/perms.txt
else
  log "[info] Permissions already set for volume mappings"
fi

log "[info] Setting permissions on files/folders inside container..."
chown -R "${PUID}":"${PGID}" /usr/bin/deluged /usr/bin/deluge-web
chmod -R 775 /usr/bin/deluged /usr/bin/deluge-web

# if config file doesnt exist (wont exist until user changes a setting) then copy default config file
if [[ ! -f /config/core.conf ]]; then
  log "[info] Deluge config file doesn't exist, copying default..."
  cp /etc/config/core.conf /config/
else
  log "[info] Deluge config file already exists, skipping copy"
fi

# if config file doesnt exist then copy stock config file
if [[ ! -f /config/web.conf ]]; then
  log "[info] Deluge webui config file doesn't exist, copying default..."
  cp /etc/config/web.conf /config/
else
  log "[info] Deluge webui config file already exists, skipping copy"
fi

# If openvpn-pre-start.sh exists, run it
if [[ -x /config/openvpn-pre-start.sh ]]; then
  log "Executing /config/openvpn-pre-start.sh"
  /config/openvpn-pre-start.sh "$@"
  log "/config/openvpn-pre-start.sh returned $?"
fi

# Allow for overriding the DNS used directly in the /etc/resolv.conf
if compgen -e | grep -q "OVERRIDE_DNS"; then
  log "One or more OVERRIDE_DNS addresses found. Will use them to overwrite /etc/resolv.conf"
  log "" >/etc/resolv.conf
  for var in $(compgen -e | grep "OVERRIDE_DNS"); do
    log "nameserver $(printenv "$var")" >>/etc/resolv.conf
  done
fi

# If create_tun_device is set, create /dev/net/tun
if [[ "${CREATE_TUN_DEVICE,,}" == "true" ]]; then
  mkdir -p /dev/net
  mknod /dev/net/tun c 10 200
  chmod 600 /dev/net/tun
fi

##
# Configure OpenVPN.
# This basically means to figure out the config file to use as well as username/password
##

# If no OPENVPN_PROVIDER is given, we default to "custom" provider.
VPN_PROVIDER="${OPENVPN_PROVIDER:-custom}"
VPN_PROVIDER="${VPN_PROVIDER,,}" # to lowercase
VPN_PROVIDER_HOME="/etc/openvpn/${VPN_PROVIDER}"
if [[ ! -d $VPN_PROVIDER_HOME ]]; then
  echo "Creating $VPN_PROVIDER_HOME"
  mkdir -p "$VPN_PROVIDER_HOME"
fi

# Make sure that we have enough information to start OpenVPN
if [[ -z $OPENVPN_CONFIG_URL ]] && [[ "${OPENVPN_PROVIDER}" == "**None**" ]] || [[ -z "${OPENVPN_PROVIDER-}" ]]; then
  log "ERROR: Cannot determine where to find your OpenVPN config. Both OPENVPN_CONFIG_URL and OPENVPN_PROVIDER is unset."
  log "You have to either provide a URL to the config you want to use, or set a configured provider that will download one for you."
  log "Exiting..." && exit 1
fi
log "Using OpenVPN provider: ${VPN_PROVIDER^^}"

if [[ -n $OPENVPN_CONFIG_URL ]]; then
  log "Found URL to OpenVPN config, will download it."
  CHOSEN_OPENVPN_CONFIG=$VPN_PROVIDER_HOME/downloaded_config.ovpn
  curl -o "$CHOSEN_OPENVPN_CONFIG" -sSL "$OPENVPN_CONFIG_URL"
  # shellcheck source=openvpn/modify-openvpn-config.sh
  /etc/openvpn/modify-openvpn-config.sh "$CHOSEN_OPENVPN_CONFIG"
elif [[ -x $VPN_PROVIDER_HOME/configure-openvpn.sh ]]; then
  log "Provider $OPENVPN_PROVIDER has a custom startup script, executing it"
  # shellcheck source=/dev/null
  . "$VPN_PROVIDER_HOME"/configure-openvpn.sh
fi

if [[ -z ${CHOSEN_OPENVPN_CONFIG} ]]; then
  # We still don't have a config. The user might have set a config in OPENVPN_CONFIG.
  if [[ -n "${OPENVPN_CONFIG-}" ]]; then
    readarray -t OPENVPN_CONFIG_ARRAY <<<"${OPENVPN_CONFIG//,/$'\n'}"

    ## Trim leading and trailing spaces from all entries. Inefficient as all heck, but works like a champ.
    for i in "${!OPENVPN_CONFIG_ARRAY[@]}"; do
      OPENVPN_CONFIG_ARRAY[${i}]="${OPENVPN_CONFIG_ARRAY[${i}]#"${OPENVPN_CONFIG_ARRAY[${i}]%%[![:space:]]*}"}"
      OPENVPN_CONFIG_ARRAY[${i}]="${OPENVPN_CONFIG_ARRAY[${i}]%"${OPENVPN_CONFIG_ARRAY[${i}]##*[![:space:]]}"}"
    done

    # If there were multiple configs (comma separated), select one of them
    if ((${#OPENVPN_CONFIG_ARRAY[@]} > 1)); then
      OPENVPN_CONFIG_RANDOM=$((RANDOM % ${#OPENVPN_CONFIG_ARRAY[@]}))
      log "${#OPENVPN_CONFIG_ARRAY[@]} servers found in OPENVPN_CONFIG, ${OPENVPN_CONFIG_ARRAY[${OPENVPN_CONFIG_RANDOM}]} chosen randomly"
      OPENVPN_CONFIG="${OPENVPN_CONFIG_ARRAY[${OPENVPN_CONFIG_RANDOM}]}"
    fi

    # Check that the chosen config exists.
    if [[ -f "${VPN_PROVIDER_HOME}/${OPENVPN_CONFIG}.ovpn" ]]; then
      log "Starting OpenVPN using config ${OPENVPN_CONFIG}.ovpn"
      CHOSEN_OPENVPN_CONFIG="${VPN_PROVIDER_HOME}/${OPENVPN_CONFIG}.ovpn"
    else
      log "Supplied config ${OPENVPN_CONFIG}.ovpn could not be found."
      log "Your options for this provider are:"
      ls "${VPN_PROVIDER_HOME}" | grep .ovpn
      log "NB: Remember to not specify .ovpn as part of the config name."
      exit 1 # No longer fall back to default. The user chose a specific config - we should use it or fail.
    fi
  else
    log "No VPN configuration provided. Using default."
    CHOSEN_OPENVPN_CONFIG="${VPN_PROVIDER_HOME}/default.ovpn"
  fi
fi

# add OpenVPN user/pass
if [[ "${OPENVPN_USERNAME}" == "**None**" ]] || [[ "${OPENVPN_PASSWORD}" == "**None**" ]]; then
  if [[ ! -f /config/openvpn-credentials.txt ]]; then
    log "OpenVPN credentials not set. Exiting."
    exit 1
  fi
  log "Found existing OPENVPN credentials at /config/openvpn-credentials.txt"
else
  log "Setting OpenVPN credentials..."
  echo "${OPENVPN_USERNAME}" >/config/openvpn-credentials.txt
  echo "${OPENVPN_PASSWORD}" >>/config/openvpn-credentials.txt
  chmod 600 /config/openvpn-credentials.txt
fi

# Persist transmission settings for use by transmission-daemon
python3 /etc/openvpn/persistEnvironment.py /etc/deluge/environment-variables.sh

# Setting up kill switch
if [[ "true" = "${ENABLE_UFW}" ]]; then
  /etc/ufw/enable.sh tun0 ${CHOSEN_OPENVPN_CONFIG}
fi

DELUGE_CONTROL_OPTS="--script-security 2 --up-delay --up /etc/openvpn/tunnelUp.sh --down /etc/openvpn/tunnelDown.sh"

# shellcheck disable=SC2086
log "Starting openvpn"
exec openvpn ${DELUGE_CONTROL_OPTS} ${OPENVPN_OPTS} --config "${CHOSEN_OPENVPN_CONFIG}"