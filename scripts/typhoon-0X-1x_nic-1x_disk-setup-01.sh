#!/usr/bin/env bash

set -Eeuo pipefail
shopt -s expand_aliases
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR
trap cleanup EXIT
function error_exit() {
  trap - ERR
  local DEFAULT='Unknown failure occured.'
  local REASON="\e[97m${1:-$DEFAULT}\e[39m"
  local FLAG="\e[91m[ERROR] \e[93m$EXIT@$LINE"
  msg "$FLAG $REASON"
  [ ! -z ${CTID-} ] && cleanup_failed
  exit $EXIT
  
TEMP_DIR=$(mktemp -d)
pushd $TEMP_DIR >/dev/null

###################################################################
# This script is for 1x NIC hardware Only.                        #
#                                                                 #
# Tested on Proxmox Version : 4.15.18-12-pve                      #
###################################################################

# Command to run script
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/typhoon-0X-1x_nic-1x_disk-setup-01.sh)"

# Intro
echo -e "In the next steps you must enter your desired Proxmox host settings. \nOr simply press 'ENTER' to accept our defaults."
echo

# Set Proxmox Machine hostname
read -p "Enter your Proxmox machine hostname: " -e -i $HOSTNAME NEW_HOSTNAME
info "Your Proxmox hostname is $NEW_HOSTNAME."
echo

# Set Proxmox host IP address
read -p "Enter $HNAME IPv4 address: " -e -i `hostname -i`/24 NEW_IPV4
info "Your $NEW_HOSTNAME IPv4 address is $NEW_IPV4."
echo

# Set Proxmox host Gateway IP address
read -p "Enter $HNAME IPv4 address: " -e -i `ip route | grep default | cut -d\  -f3` NEW_GATEWAY
info "Your $NEW_HOSTNAME gateway IPv4 address is $NEW_GATEWAY."
echo


# Update turnkey appliance list
msg "Updating turnkey appliance list..."
pveam update >/dev/null

# Update Proxmox OS
msg "Updating Proxmox OS..."
apt-get update >/dev/null
apt-get -qqy upgrade >/dev/null

# Increase the inotify limits
msg "Increasing inotify limits..."
echo -e "fs.inotify.max_queued_events = 16384
fs.inotify.max_user_instances = 512
fs.inotify.max_user_watches = 8192" >> /etc/sysctl.conf

# Install lm sensors (CPU Temp simple type 'sensors')
msg "Installing lm sensors..."
apt-get install -y lm-sensors >/dev/null

# Install VAINFO
msg "Installing VAINFO..."
apt install -y vainfo >/dev/null

# Rename ZFS disk label
msg "Renaming local-zfs disk label to typhoon-share..."
sed -i 's|zfspool: local-zfs|zfspool: typhoon-share|g' /etc/pve/storage.cfg

# Cyclone-01 NFS Mounts
msg "Creating NFS mounts..."
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
read -p "Overwrite your system hosts file to Ahuacates latest release? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
    hostsfile=$(wget https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/hosts -q -O -)
    cat << EOF > /etc/hosts
    $hostsfile
    EOF
fi

# Append your public key to /etc/pve/priv/authorized_keys
echo -e "To append your public SSH key to `hostname` you MUST COPY your public SSH key into your shared 'public folder' on your NAS.\nYour NAS public folder should be NFS mounted by `hostname`."
read -p  "If you have copied your public SSH key into your 'public folder' on your NAS OR want to continue without adding a public SSH key to `hostname` simply press 'ENTER'..."
RSA_KEY=/mnt/pve/cyclone-01-public/id_rsa*.pub
if [ -f "$RSA_KEY" ]; then
    echo "A public RSA key exists in folder $RSA_KEY"
    read -p "Do you want to add this public SSH key to `hostname` authorized_keys? " -n 1 -r
    echo    # (optional) move to a new line
    if [[ $REPLY =~ ^[Yy]$ ]]
    then
        cat /mnt/pve/cyclone-01-public/id_rsa*.pub | cat >> /etc/pve/priv/authorized_keys >/dev/null
        echo "Your public SSH key has been added to `hostname` authorized_keys..."
        service sshd restart >/dev/null
        echo "Restarting sshd service..."
else 
    echo -e "No public SSH key was found in folder $RSA_KEY.\nNo public SSH key has been added to `hostname` authorized_keys."
fi


# Basic Details
echo "All passwords must have a minimum of 5 characters"
read -p "Please Enter a NEW password for user storm: " stormpasswd

# Create a New User called 'storm'
groupadd --system homelab -g 65606
adduser --system --no-create-home --uid 1606 --gid 65606 storm
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

lspci | egrep -i --color 'network|ethernet'
lspci | grep -i ethernet | wc -l
lspci | grep -i 'Ethernet' | grep -i 'Intel Corporation I350' | wc -l


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

iface enp1s0f0 inet manual

iface enp1s0f1 inet manual

iface enp1s0f2 inet manual

iface enp1s0f3 inet manual

iface enp5s0 inet manual

iface enp6s0 inet manual


auto vmbr0
iface vmbr0 inet static
        address  192.168.1.104
        netmask  255.255.255.0
        gateway  192.168.1.5
        bridge-ports enp1s0f0
        bridge-stp off
        bridge-fd 0
        bridge-vlan-aware yes
        bridge-vids 2-4094
#Proxmox LAN Bridge

auto vmbr1
iface vmbr1 inet manual
        bridge-ports enp1s0f1
        bridge-stp off
        bridge-fd 0
        bridge-vlan-aware yes
        bridge-vids 2-4094
#VPN-egress Bridge

auto vmbr2
iface vmbr2 inet manual
        bridge-ports enp1s0f2
        bridge-stp off
        bridge-fd 0
        bridge-vlan-aware yes
        bridge-vids 2-4094
#vpngate-world

auto vmbr3
iface vmbr3 inet manual
        bridge-ports enp1s0f3
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
