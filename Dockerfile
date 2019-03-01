FROM alpine:3.9
MAINTAINER vdweegen

RUN apk add --update iptables ip6tables supervisor openvpn bind-tools && \
    rm -rf /tmp/* /var/cache/apk/*i && \
    mkdir -p /ovpn

ADD docker/supervisord.conf /etc/

ADD docker/supervisord-openvpn.conf /etc/supervisor/conf.d/

ADD docker/openvpn /usr/local/bin/

ENTRYPOINT ["supervisord", "--nodaemon", "--configuration", "/etc/supervisord.conf"]
