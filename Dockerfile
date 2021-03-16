FROM ubuntu:18.04

ARG DEBIAN_FRONTEND="noninteractive"

RUN set -ex; \
    apt-get update && \
    apt-get -y install gnupg apt-utils && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys C5E6A5ED249AD24C && \
    echo "deb http://ppa.launchpad.net/deluge-team/stable/ubuntu bionic main" >> \
	/etc/apt/sources.list.d/deluge.list && \
    echo "deb-src http://ppa.launchpad.net/deluge-team/stable/ubuntu bionic main" >> \
	/etc/apt/sources.list.d/deluge.list && \
    echo "**** install packages ****" && \
    apt-get update && \
    apt-get -y install dumb-init iputils-ping dnsutils bash jq net-tools openvpn curl ufw deluged deluge-console deluge-web python3-future python3-requests p7zip-full unrar unzip && \
    echo "Cleanup"; \
    rm -rf /tmp/* /var/lib/apt/lists/* /var/tmp/* && \
    echo "Adding user"; \
    groupadd -g 911 abc && \
	useradd -u 911 -g 911 -s /bin/false -m abc && \
    usermod -G users abc

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
    HEALTH_CHECK_HOST=google.com \
    LANG='en_US.UTF-8' \
    LANGUAGE='en_US.UTF-8' \ 
    TERM='xterm' \
    LOCAL_NETWORK= \
    PEER_DNS= \
    DISABLE_PORT_UPDATER=

HEALTHCHECK --interval=1m CMD /etc/scripts/healthcheck.sh

VOLUME /downloads
VOLUME /config

EXPOSE 8112 58846 58946 58946/udp

CMD ["dumb-init", "/etc/openvpn/init.sh"]