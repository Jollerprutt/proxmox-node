#!/bin/bash

###################################################################
# This script is for Qotom 6 NIC hardware Only.                   #
#                                                                 #
# Tested on Proxmox Version : 4.15.18-12-pve                      #
###################################################################

# Command to run script 
# wget https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/typhoon-01-6x_NIC-setup-01.sh -P /tmp && chmod +x /tmp/typhoon-01-6x_NIC-setup-01.sh && bash /tmp/typhoon-01-6x_NIC-setup-01.sh; rm -rf /tmp/typhoon-01-6x_NIC-setup-01.sh

# Basic Details
echo "All passwords must have a minimum of 5 characters"
read -p "Please Enter a NEW password for user storm: " stormpasswd

# Create a New User called 'storm'
groupadd --system homelab -g 1005
adduser --system --no-create-home --uid 1005 --gid 1005 storm
# Create a New PVE User Group
pveum groupadd homelab -comment 'Homelab User Group'
# Add PVEVMAdmin role (fully administer VMs) to group homelab
pveum aclmod / -group homelab -role PVEVMAdmin
# Create PVE User
pveum useradd storm@pve -comment 'User Storm'
# Save storm password
echo -e "$stormpasswd\n$stormpasswd" | pveum passwd storm@pve
# Add User to homelab group
pveum usermod storm@pve -group homelab

# Update turnkey appliance list
pveam update

# Update Proxmox Host
apt-get update
apt-get upgrade -y

# Increase the inotify limits
sysctl fs.inotify.max_user_instances=512

# Install lm sensors (CPU Temp simple type 'sensors')
apt-get install lm-sensors -y

# Install VAINFO
apt install vainfo -y

# Cyclone-01 NFS Mounts
pvesm add nfs cyclone-01-audio --path /mnt/pve/cyclone-01-audio --server 192.168.1.10 --export /volume1/audio --content images --options vers=4.1
pvesm add nfs cyclone-01-backup --path /mnt/pve/cyclone-01-backup --server 192.168.1.10 --export /volume1/proxmox/backup --content backup --options vers=4.1 --maxfiles 1
pvesm add nfs cyclone-01-books --path /mnt/pve/cyclone-01-books --server 192.168.1.10 --export /volume1/books --content images --options vers=4.1
pvesm add nfs cyclone-01-public --path /mnt/pve/cyclone-01-public --server 192.168.1.10 --export /volume1/public --content images --options vers=4.1
pvesm add nfs cyclone-01-docker --path /mnt/pve/cyclone-01-docker --server 192.168.1.10 --export /volume1/docker --content images --options vers=4.1
pvesm add nfs cyclone-01-video --path /mnt/pve/cyclone-01-video --server 192.168.1.10 --export /volume1/video --content images --options vers=4.1
pvesm add nfs cyclone-01-music --path /mnt/pve/cyclone-01-music --server 192.168.1.10 --export /volume1/music --content images --options vers=4.1
pvesm add nfs cyclone-01-cloudstorage --path /mnt/pve/cyclone-01-cloudstorage --server 192.168.1.10 --export /volume1/cloudstorage --content images --options vers=4.1
pvesm add nfs cyclone-01-photo --path /mnt/pve/cyclone-01-photo --server 192.168.1.10 --export /volume1/photo --content images --options vers=4.1
pvesm add nfs cyclone-01-transcode --path /mnt/pve/cyclone-01-transcode --server 192.168.1.10 --export /volume1/video/transcode --content images --options vers=4.1

# Edit Proxmox host file
echo -e "127.0.0.1 localhost.localdomain localhost

# Proxmox Hosts
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

# VM Machines
192.168.1.253 pfsense.localdomain pfsense

# LXC Machines
192.168.1.6 unifi.localdomain unifi
192.168.1.254 pihole.localdomain pihole
192.168.50.20 jellyfin.localdomain jellyfin

# The following lines are desirable for IPv6 capable hosts

::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts"  >  /etc/hosts

#### Here on is particular to Typhoon-01 and 6-NIC Hardware ####

# Download pfSense VM into templates and for typhoon-01 only
if [ "$HOSTNAME" = typhoon-01 ]; then
   wget https://sgpfiles.pfsense.org/mirror/downloads/pfSense-CE-2.4.4-RELEASE-p3-amd64.iso.gz -P /var/lib/vz/template/iso && gzip -d /var/lib/vz/template/iso/pfSense-CE-2.4.4-RELEASE-p3-amd64.iso.gz
else
   printf '%s\n' "This is not typhoon-01 so I am not downloading"
fi

# Create pfSense VM
if [ "$HOSTNAME" = typhoon-01 ]; then
   qm create 253 --bootdisk virtio0 --cores 2 --cpu host --ide2 local:iso/pfSense-CE-2.4.4-RELEASE-p3-amd64.iso,media=cdrom --memory 4096 --name pfsense --net0 virtio,bridge=vmbr0,firewall=1 --net1 virtio,bridge=vmbr1,firewall=1 --net2 virtio,bridge=vmbr2,firewall=1 --net3 virtio,bridge=vmbr3,firewall=1 --numa 0 --onboot 1 --ostype other --scsihw virtio-scsi-pci --sockets 1 --virtio0 local-lvm:32 --startup order=1
else
   printf '%s\n' "This is not typhoon-01 so I am not installing pfSense"
fi


# Proxmox Networking - Qotom 6x Nic Version
if [ "$HOSTNAME" = typhoon-01 ]; then
   echo -e "# network interface settings; autogenerated
# Please do NOT modify this file directly, unless you know what
# you're doing.
#
# If you want to manage parts of the network configuration manually,
# please utilize the 'source' or 'source-directory' directives to do
# so.
# PVE will preserve these directives, but will NOT read its network
# configuration from sourced files, so do not attempt to move any of
# the PVE managed interfaces into external files!

auto lo
iface lo inet loopback

iface enp1s0 inet manual

iface enp2s0 inet manual

iface enp3s0 inet manual

iface enp4s0 inet manual

iface enp5s0 inet manual

iface enp6s0 inet manual

auto bond0
iface bond0 inet manual
        bond-slaves enp1s0 enp2s0
        bond-miimon 100
        bond-mode 802.3ad
        bond-xmit-hash-policy layer2
#Proxmox LAN Bond

auto bond1
iface bond1 inet manual
        bond-slaves enp3s0 enp4s0
        bond-miimon 100
        bond-mode 802.3ad
        bond-xmit-hash-policy layer2
#VPN-egress Bond

auto vmbr0
iface vmbr0 inet static
        address  192.168.1.101
        netmask  255.255.255.0
        gateway  192.168.1.5
        bridge-ports bond0
        bridge-stp off
        bridge-fd 0
        bridge-vlan-aware yes
        bridge-vids 2-4094
#Proxmox LAN Bridge/Bond

auto vmbr1
iface vmbr1 inet manual
        bridge-ports bond1
        bridge-stp off
        bridge-fd 0
        bridge-vlan-aware yes
        bridge-vids 2-4094
#VPN-egress Bridge/Bond

auto vmbr2
iface vmbr2 inet manual
        bridge-ports enp5s0
        bridge-stp off
        bridge-fd 0
        bridge-vlan-aware yes
        bridge-vids 2-4094
#vpngate-world

auto vmbr3
iface vmbr3 inet manual
        bridge-ports enp6s0
        bridge-stp off
        bridge-fd 0
        bridge-vlan-aware yes
        bridge-vids 2-4094
#vpngate-local"  >  /etc/network/interfaces.new
else
   printf '%s\n' "This is not typhoon-01 so I am not configuring your NIC Interfaces"
fi

# Reboot the node
clear
echo "Looking Good. Rebooting in 5 seconds ......"
sleep 5 ; reboot
