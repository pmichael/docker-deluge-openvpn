FROM alpine:edge

RUN echo "@edgecommunity http://nl.alpinelinux.org/alpine/edge/community" >> /etc/apk/repositories \
    && echo "@testing http://nl.alpinelinux.org/alpine/edge/testing" >> /etc/apk/repositories \
    && apk update \
    && apk add --upgrade apk-tools \
    && apk add bash dumb-init openvpn shadow curl jq tzdata openrc tinyproxy tinyproxy-openrc openssh unrar deluge@testing ufw@edgecommunity \
    && rm -rf /tmp/* /var/tmp/* \
    && groupadd -g 911 abc \
	&& useradd -u 911 -g 911 -s /bin/false -m abc \
    && usermod -G users abc

# Add configuration and scripts
COPY root/ /

ENV OPENVPN_USERNAME=**None** \
    OPENVPN_PASSWORD=**None** \
    OPENVPN_PROVIDER=**None** \
    CREATE_TUN_DEVICE=true \
    ENABLE_UFW=false \
    UFW_EXTRA_PORTS= \
    UFW_ALLOW_GW_NET=false \
    PUID= \
    PGID= \
    DROP_DEFAULT_ROUTE= \
    WEBPROXY_ENABLED=false \
    WEBPROXY_PORT=8888 \
    WEBPROXY_USERNAME= \
    WEBPROXY_PASSWORD= \
    HEALTH_CHECK_HOST=google.com \
    LANG='en_US.UTF-8' \
    LANGUAGE='en_US.UTF-8' \ 
    TERM='xterm' \
    LOCAL_NETWORK=

HEALTHCHECK --interval=1m CMD /etc/scripts/healthcheck.sh

# Compatability with https://hub.docker.com/r/willfarrell/autoheal/
LABEL autoheal=true

VOLUME /downloads
VOLUME /config

# Expose web ui port
EXPOSE 8112 

# expose port for deluge daemon
EXPOSE 58846

# expose port for incoming torrent data (tcp and udp)
EXPOSE 58946 
EXPOSE 58946/udp

CMD ["dumb-init", "/etc/openvpn/start.sh"]