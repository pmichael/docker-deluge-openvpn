IMAGE=192.168.10.26:5000/deluge-openvpn

.PHONY: build
build:
	sh build.sh "$(IMAGE)"

.PHONY: push
push:
	sh push.sh "$(IMAGE)"