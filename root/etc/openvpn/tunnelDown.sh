#!/bin/bash

if [ "${PEER_DNS}" != "no" ]; then
    if [ -e /etc/resolv.conf-"${dev}".sv ] ; then
        cp /etc/resolv.conf-"${dev}".sv /etc/resolv.conf
    fi
    chmod 644 /etc/resolv.conf
fi

/etc/deluge/stop.sh "$@"
