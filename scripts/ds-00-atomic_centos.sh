#!/bin/ash

#### proxmox ds-00 vm node build script ####

# Command to run script on atomic centos vm node

# Prefer docker-latest
systemctl disable docker --now
systemctl enable docker-latest --now
sed -i '/DOCKERBINARY/s/^#//g' /etc/sysconfig/docker

# Permit connectivity between VMs
sed -i '/^COMMIT/i #Allow all inter-node communication\n-A INPUT -s 192.168.1.0/24 -j ACCEPT' /etc/sysconfig/iptables

# Enable Host resolution
echo -e "# Proxmox Hosts
192.168.1.101 typhoon-01.localdomain typhoon-01
192.168.1.102 typhoon-02.localdomain typhoon-02
192.168.1.103 typhoon-03.localdomain typhoon-03
192.168.1.104 typhoon-04.localdomain typhoon-04
# NAS Storage
192.168.1.10 cyclone-01.localdomain cyclone-01
192.168.1.11 cyclone-02.localdomain cyclone-02
# Docker Nodes
192.168.1.111 ds-01.localdomain ds-01
192.168.1.112 ds-02.localdomain ds-02
192.168.1.113 ds-03.localdomain ds-03
192.168.1.114 ds-04.localdomain ds-04
192.168.1.115 ds-05.localdomain ds-05
192.168.1.116 ds-06.localdomain ds-06
192.168.1.117 ds-07.localdomain ds-07
192.168.1.118 ds-08.localdomain ds-08
192.168.1.119 ds-09.localdomain ds-09
# LXC Nodes
192.168.1.254 pihole.localdomain pihole
192.168.1.20 unifi.localdomain unifi
192.168.1.121 jellyfin.localdomain jellyfin
192.168.1.122 safevpn.localdomain safevpn" >> /etc/hosts

# Set timezone
ln -sf /usr/share/zoneinfo/Asia/Bangkok /etc/localtime
# ln -sf /usr/share/zoneinfo/Australia/Melbourne /etc/localtime

# Create NFS Mount Folders
mkdir -p /mnt/nas/{docker,typhoon,openvpn,photo,video,music,download}

# Add nfs mounts to fstab
echo -e "# NAS Cyclone-01 Mounts
192.168.1.10:/volume1/docker /mnt/nas/docker nfs4 auto 0 0
192.168.1.10:/volume1/typhoon /mnt/nas/typhoon nfs4 auto 0 0
192.168.1.10:/volume1/openvpn /mnt/nas/openvpn nfs4 auto 0 0
192.168.1.10:/volume1/photo /mnt/nas/photo nfs4 auto 0 0
192.168.1.10:/volume1/video /mnt/nas/video nfs4 auto 0 0
192.168.1.10:/volume1/music /mnt/nas/music nfs4 auto 0 0
192.168.1.10:/volume2/download /mnt/nas/download nfs4 auto 0 0" >> /etc/fstab

# Immediate nfs mount
mount -a

# Create docker config folders on nas
mkdir -p /mnt/nas/docker/{portainer,duplicity,owntracks,config/{traefik,docker-cleanup,shepherd,registry,duplicity}}
mkdir -p /mnt/nas/docker/autopirate/{lazylibrarian,mylar,ombi,lidarr,sonarr,radarr,nzbhydra,sabnzbd,nzbget,rtorrent,deluge,jackett}
# HA
mkdir -p /mnt/nas/docker/homeassistant/{homeassistant,grafana,influxdb-backup}
mkdir -p /mnt/nas/docker/runtime/homeassistant/influxdb
# Nextcloud
mkdir -p /mnt/nas/docker/nextcloud/{html,apps,config,data,database-dump}
mkdir -p /mnt/nas/docker/runtime/nextcloud/{db,redis}


# Prepare the host for traefik
mkdir ~/dockersock
cd ~/dockersock
curl -O https://raw.githubusercontent.com/dpw/\
selinux-dockersock/master/Makefile
curl -O https://raw.githubusercontent.com/dpw/\
selinux-dockersock/master/dockersock.te
make && semodule -i dockersock.pp

# Enable IPVS module
echo "modprobe ip_vs" >> /etc/rc.local
modprobe ip_vs

# Tweaks
# Handy bash auto-completion for docker
cd /etc/bash_completion.d/
curl -O https://raw.githubusercontent.com/docker/cli/b75596e1e4d5295ac69b9934d1bd8aff691a0de8/contrib/completion/bash/docker
# Install some useful bash aliases on (each) host
cd ~
curl -O https://raw.githubusercontent.com/funkypenguin/geek-cookbook/master/examples/scripts/gcb-aliases.sh
echo 'source ~/gcb-aliases.sh' >> ~/.bash_profile


# Update & Reboot
atomic host upgrade
systemctl reboot
