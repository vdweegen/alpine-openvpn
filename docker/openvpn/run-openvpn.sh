#!/bin/sh

set -e

# prepare vpn
mkdir -p /dev/net
if [ ! -c /dev/net/tun ]; then
	mknod /dev/net/tun c 10 200
fi

OVPNCONF=$(find /ovpn -type f -name '*.ovpn' | shuf -n 1)
[ -z $OVPNCONF ] && {
	echo Couldn\'t select openvpn config file
	exit 1;
}
echo Selecting config file: $OVPNCONF

[ -f $OVPNCONF ] || {
	echo /etc/openvpn_host/openvpnconfig.conf is missing please provide the volume with the file  > /dev/stderr; 
	exit 1; 
}

[ -f /ovpn/credentials ] || {
        echo /ovpn/credentials is missing please provide the volume with the file  > /dev/stderr;
        exit 1;
}

REMOTE=`grep '^remote\s' $OVPNCONF | awk '{print $2}'`
REMOTEIP=`dig +short $REMOTE | shuf -n 1`
DEFAULTGW=`ip ro ls | grep default | awk '{print $3}'`

[ -n "$REMOTE" ] || { 
	echo no remote in /etc/openvpn_host/openvpnconfig.conf > /dev/stderr; 
	exit 1; 
}
[ -n "$REMOTEIP" ] || {
        echo Could not determine IP for $REMOTE > /dev/stderr;
        exit 1;
}
[ -n "$DEFAULTGW" ] || { 
	echo could not determine default gateway > /dev/stderr; 
	exit 1; 
}

echo "============================"
echo Default Gateway: $DEFAULTGW
echo Remote: $REMOTE
echo Remote IP: $REMOTEIP
echo "============================"

MATCHES_HOST="$(grep -n $REMOTE /etc/hosts | cut -f1 -d:)"
HOST_ENTRY="${REMOTEIP} ${REMOTE}"

if [ ! -z "$MATCHES_HOST" ]
then
    echo "Updating existing hosts entry."
    # iterate over the line numbers on which matches were found
    while read -r LINE_NO; do
        # replace the text of each line with the desired host entry
        sed -i '' "${LINE_NO}s/.*/${HOST_ENTRY} /" /etc/hosts
    done < "$MATCHES_HOST"
else
    echo "Adding new hosts entry."
    echo "$HOST_ENTRY" | tee -a /etc/hosts > /dev/null
fi

# flush and set policies
iptables -P INPUT DROP
iptables -P OUTPUT DROP

# set lo
iptables -A INPUT  -i lo
iptables -A OUTPUT -o lo

# allow returning packets for all interfaces
iptables -A INPUT -p tcp  -m state --state RELATED,ESTABLISHED -j ACCEPT 
iptables -A INPUT -p udp  -m state --state RELATED,ESTABLISHED -j ACCEPT 
iptables -A INPUT -p icmp -m state --state RELATED,ESTABLISHED -j ACCEPT 

# vpn server
iptables -A OUTPUT -o eth0 -d $REMOTEIP -j ACCEPT

# allow output on tun0
iptables -A OUTPUT -o tun0 -j ACCEPT

# make sure default route is deleted forever
ip ro del default

# add a route only for the VPN server
ip ro add $REMOTEIP via $DEFAULTGW dev eth0

/usr/sbin/openvpn --script-security 2 --up /usr/local/bin/openvpn-up.sh \
	--status /ovpn/openvpnconfig.status 10 --redirect-gateway local \
	--cd /ovpn --config $OVPNCONF --auth-user-pass /ovpn/credentials

# if openvpn exits, take the whole container with us
echo openvpn died
kill 1 # kill the supervisor so the container dies
