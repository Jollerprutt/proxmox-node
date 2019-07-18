#!/bin/bash

###################################################################
# This script is for Single LAN hardware.                         #
#                                                                 #
# Proxmox Version : 4.15.18-12-pve                                #
###################################################################

# Command to run script 
# wget -O - https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/typhoon-0X-Single_NIC-setup-01.sh | bash

# Q&A before proceeding to run script
read -r -p "Are you installing on Single NIC hardware [Y/n] " input
 
case $input in
    [yY][eE][sS]|[yY])
 echo "Yes"
 ;;
    [nN][oO]|[nN])
 echo "No"
       ;;
    *)
 echo "Invalid input..."
 exit 1
 ;;
esac

# Update turnkey appliance list
pveam update

# Update Proxmox Host
apt-get update
apt-get upgrade -y

# Install lm sensors (CPU Temp simple type 'sensors')
apt-get install lm-sensors -y

# Cyclone-01 NFS Mounts
echo -e "nfs: cyclone-01-backup
        export /volume1/proxmox/backup
        path /mnt/pve/cyclone-01-backup
        server 192.168.1.10
        content backup
        maxfiles 1
        options vers=3
nfs: cyclone-01-public
        export /volume1/public
        path /mnt/pve/cyclone-01-public
        server 192.168.1.10
        content images
        options vers=3
nfs: cyclone-01-docker
        export /volume1/docker
        path /mnt/pve/cyclone-01-docker
        server 192.168.1.10
        content images
        options vers=3
nfs: cyclone-01-video
        export /volume1/video
        path /mnt/pve/cyclone-01-video
        server 192.168.1.10
        content images
        options vers=3
        
nfs: cyclone-01-music
        export /volume1/music
        path /mnt/pve/cyclone-01-music
        server 192.168.1.10
        content images
        options vers=3        
        
nfs: cyclone-01-photo
        export /volume1/photo
        path /mnt/pve/cyclone-01-photo
        server 192.168.1.10
        content images
        options vers=3" >> /etc/pve/storage.cfg

# NFS mount all
pvesm status

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

# Create a PAM User Group
pveum groupadd homelab -comment 'Homelab User Group'
# Add PVEVMAdmin role (fully administer VMs) to group homelab
pveum aclmod / -group homelab -role PVEVMAdmin
# Create PAM User
pveum useradd storm@pam -comment 'User Storm'
pveum passwd storm@pam
# Add User to homelab group
pveum usermod storm@pam -group homelab

# Reboot the node
reboot
exit 0
