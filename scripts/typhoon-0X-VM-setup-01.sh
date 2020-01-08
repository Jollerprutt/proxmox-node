#!/bin/bash

###################################################################
# This script is for VM Installations Only.                       #
#                                                                 #
# Tested on Proxmox Version : 4.15.18-12-pve                      #
###################################################################

# Command to run script
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/typhoon-0X-VM-setup-01.sh)"


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

# Update turnkey appliance list (not for VMs
# pveam update

# Update Proxmox Host
apt-get update
apt-get upgrade -y

# Increase the inotify limits
echo -e "fs.inotify.max_queued_events = 16384
fs.inotify.max_user_instances = 512
fs.inotify.max_user_watches = 8192" >> /etc/sysctl.conf

# Install lm sensors (CPU Temp simple type 'sensors')
#apt-get install lm-sensors -y

# Cyclone-01 NFS Mounts
pvesm add nfs cyclone-01-audio --path /mnt/pve/cyclone-01-audio --server 192.168.1.10 --export /volume1/audio --content images --options vers=4.1
pvesm add nfs cyclone-01-backup --path /mnt/pve/cyclone-01-backup --server 192.168.1.10 --export /volume1/proxmox/backup --content backup --options vers=4.1 --maxfiles 3
pvesm add nfs cyclone-01-books --path /mnt/pve/cyclone-01-books --server 192.168.1.10 --export /volume1/books --content images --options vers=4.1
pvesm add nfs cyclone-01-cloudstorage --path /mnt/pve/cyclone-01-cloudstorage --server 192.168.1.10 --export /volume1/cloudstorage --content images --options vers=4.1
pvesm add nfs cyclone-01-docker --path /mnt/pve/cyclone-01-docker --server 192.168.1.10 --export /volume1/docker --content images --options vers=4.1
pvesm add nfs cyclone-01-downloads --path /mnt/pve/cyclone-01-downloads --server 192.168.1.10 --export /volume1/downloads --content images --options vers=4.1
pvesm add nfs cyclone-01-music --path /mnt/pve/cyclone-01-music --server 192.168.1.10 --export /volume1/music --content images --options vers=4.1
pvesm add nfs cyclone-01-photo --path /mnt/pve/cyclone-01-photo --server 192.168.1.10 --export /volume1/photo --content images --options vers=4.1
pvesm add nfs cyclone-01-public --path /mnt/pve/cyclone-01-public --server 192.168.1.10 --export /volume1/public --content images --options vers=4.1
pvesm add nfs cyclone-01-transcode --path /mnt/pve/cyclone-01-transcode --server 192.168.1.10 --export /volume1/video/transcode --content images --options vers=4.1
pvesm add nfs cyclone-01-video --path /mnt/pve/cyclone-01-video --server 192.168.1.10 --export /volume1/video --content images --options vers=4.1

# Edit Proxmox host file
hostsfile=$(wget https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/hosts -q -O -)
cat << EOF > /etc/hosts
$hostsfile
EOF

# Reboot the node
clear
echo "Looking Good. Rebooting in 5 seconds ......"
sleep 5 ; reboot
