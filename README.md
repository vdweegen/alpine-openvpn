# Openvpn client in a container.

Openvpn is set up in a way that no direct connection is allowed from the container (we modify routes and set iptables). 

### Purpose

The purpose of this container is to be extended with layers that need access only via VPN.

### Configuration

Openvpn will search for config file in /ovpn/, if multiple are present the container will randomly select one. To provide this file, an external volume must be mapped with:

```-v </path/to/openvpn-configs>:/ovpn```

The final run command can be:

```docker run --privileged -it -v /path/to/openvpn-configs:/ovpn vdweegen/alpine-openvpn:latest```

### Limitations

* needs --privileged
* supports only tun devices

## Test external IP
```
wget -qO- http://ipecho.net/plain | xargs echo
```

## Make it work on Synology NAS
taken from https://github.com/oskarirauta/alpine-transmission-openvpn

**TODO: IMPROVE/VERIFY**

Here are the steps to run it on a Synology NAS (Tested on DSM 6) :

- Connect as _admin_ to your Synology SSH
- Switch to root with command `sudo su -`
- Enter your _admin_ password when prompted
- Create a TUN.sh file anywhere in your synology file system by typing `vim /volume1/foldername/TUN.sh`
replacing _foldername_ with any folder you created on your Synology
- Paste @timkelty 's script :
```
#!/bin/sh

# Create the necessary file structure for /dev/net/tun
if ( [ ! -c /dev/net/tun ] ); then
	if ( [ ! -d /dev/net ] ); then
		mkdir -m 755 /dev/net
	fi
	mknod /dev/net/tun c 10 200
fi

# Load the tun module if not already loaded
if ( !(lsmod | grep -q "^tun\s") ); then
	insmod /lib/modules/tun.ko
fi
```
- Save the file with [escape] + `:wq!`
- Go in the folder containing your script : `cd /volume1/foldername/`
- Check permission with `chmod 0755 TUN.sh`
- Run it with `./TUN.sh`
- Return to initial directory typing `cd`
- Create the DNS config file by typing `vim /volume1/foldername/resolv.conf`
- Paste the following lines :
```
nameserver 8.8.8.8
nameserver 8.8.4.4
```
- Save the file with [escape] + `:wq!`
- Create your docker container with a classic command like `docker run --privileged -d -v /volume1/foldername/resolv.conf:/etc/resolv.conf -v /volume1/yourpath/:/config -v /volume1/yourpath/:/data -e "OPENVPN_PROVIDER=PIA" -e "OPENVPN_CONFIG=Netherlands" -e "OPENVPN_USERNAME=XXXXX" -e "OPENVPN_PASSWORD=XXXXX" -p 9091:9091 --name "TransmissionVPN" oskarirauta/alpine-transmission-openvpn`
- To make it work after a nas restart, create an automated task in your synology web interface : go to **Settings Panel > Task Scheduler ** create a new task that run `/volume1/foldername/TUN.sh` as root (select '_root_' in 'user' selectbox). This task will start module that permit the container to run, you can make a task that run on startup. These kind of task doesn't work on my nas so I just made a task that run every minute.
