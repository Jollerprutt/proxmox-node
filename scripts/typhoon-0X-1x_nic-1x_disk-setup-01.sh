#!/usr/bin/env bash

set -Eeuo pipefail
shopt -s expand_aliases
alias die='EXIT=$? LINE=$LINENO error_exit'
trap die ERR
function error_exit() {
  trap - ERR
  local DEFAULT='Unknown failure occured.'
  local REASON="\e[97m${1:-$DEFAULT}\e[39m"
  local FLAG="\e[91m[ERROR:LXC] \e[93m$EXIT@$LINE"
  msg "$FLAG $REASON"
  exit $EXIT
}
function msg() {
  local TEXT="$1"
  echo -e "$TEXT"
}


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

# Choose your Ethernet Controller Type
TYPE01="Qotom 6x LAN Ports" >/dev/null
TYPE02="Qotom 4x LAN Ports" >/dev/null
TYPE03="Qotom 2x LAN Ports" >/dev/null
TYPE04="Installed PCIe Intel I350-T4 4x Port LAN Card" >/dev/null
TYPE05="Installed PCIe Intel I350-T2 2x Port LAN Card" >/dev/null
TYPE06="Installed PCIe 4x Port LAN Card (i.e Any Brand)" >/dev/null
TYPE07="Installed PCIe 2x Port LAN Card (i.e Any Brand)" >/dev/null
TYPE08="Standard 1x LAN Port" >/dev/null

echo -e "Select your hardware or ethernet controller type from the list below:"
select brand in "$TYPE01" "$TYPE02" "$TYPE03" "$TYPE04" "$TYPE05" "$TYPE06" "$TYPE07" "$TYPE08"
do
echo "You have chosen $brand..."
break
done
echo

# Set Proxmox Machine hostname
read -p "Enter your Proxmox machine hostname: " -e -i $HOSTNAME NEW_HOSTNAME
info "Your Proxmox hostname is $NEW_HOSTNAME."
echo

# Set Proxmox host IP address
read -p "Enter $NEW_HOSTNAME IPv4 address: " -e -i `hostname -i` NEW_IPV4
info "Your $NEW_HOSTNAME IPv4 address is $NEW_IPV4."
echo

# Set Proxmox host Gateway IP address
read -p "Enter $NEW_HOSTNAME IPv4 address: " -e -i `ip route | grep default | cut -d\  -f3` NEW_GATEWAY
info "Your $NEW_HOSTNAME gateway IPv4 address is $NEW_GATEWAY."
echo

# Set IP address for NAS
read -p "Enter your Network Attached Storage (NAS) IPv4 address: " -e -i 192.168.1.10 NAS_IPV4
info "Your Network Attached Storage (NAS) IPv4 address is $NAS_IPV4."
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
if [ "$NEW_HOSTNAME" = typhoon-04 ]; then
  echo
  echo "The device hostname is set to be $NEW_HOSTNAME which is your primary Proxmox device."
  echo "The following NFS mount points are available on your NFS server IPV4 $NAS_IPV4."
  showmount -d "$NAS_IPV4"
  echo
  read -p "Create all required NFS mounts to NFS server IPV4 $NAS_IPV4? " -n 1 -r
  echo    # (optional) move to a new line
  if [[ $REPLY =~ ^[Yy]$ ]]
  then
    msg "Creating NFS mounts..."
    pvesm add nfs cyclone-01-audio --path /mnt/pve/cyclone-01-audio --server $NAS_IPV4 --export /volume1/audio --content images --options vers=4.1
    pvesm add nfs cyclone-01-backup --path /mnt/pve/cyclone-01-backup --server $NAS_IPV4 --export /volume1/proxmox/backup --content backup --options vers=4.1 --maxfiles 3
    pvesm add nfs cyclone-01-books --path /mnt/pve/cyclone-01-books --server $NAS_IPV4 --export /volume1/books --content images --options vers=4.1
    pvesm add nfs cyclone-01-cloudstorage --path /mnt/pve/cyclone-01-cloudstorage --server $NAS_IPV4 --export /volume1/cloudstorage --content images --options vers=4.1
    pvesm add nfs cyclone-01-docker --path /mnt/pve/cyclone-01-docker --server $NAS_IPV4 --export /volume1/docker --content images --options vers=4.1
    pvesm add nfs cyclone-01-downloads --path /mnt/pve/cyclone-01-downloads --server $NAS_IPV4 --export /volume1/downloads --content images --options vers=4.1
    pvesm add nfs cyclone-01-music --path /mnt/pve/cyclone-01-music --server $NAS_IPV4 --export /volume1/music --content images --options vers=4.1
    pvesm add nfs cyclone-01-photo --path /mnt/pve/cyclone-01-photo --server $NAS_IPV4 --export /volume1/photo --content images --options vers=4.1
    pvesm add nfs cyclone-01-public --path /mnt/pve/cyclone-01-public --server $NAS_IPV4 --export /volume1/public --content images --options vers=4.1
    pvesm add nfs cyclone-01-transcode --path /mnt/pve/cyclone-01-transcode --server $NAS_IPV4 --export /volume1/video/transcode --content images --options vers=4.1
    pvesm add nfs cyclone-01-video --path /mnt/pve/cyclone-01-video --server $NAS_IPV4 --export /volume1/video --content images --options vers=4.1
fi

# Edit Proxmox host file
#read -p "Overwrite your system hosts file to Ahuacates latest release? " -n 1 -r
#echo    # (optional) move to a new line
#if [[ $REPLY =~ ^[Yy]$ ]]
#then
#  hostsfile=$(wget https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/hosts -q -O -)
#  cat << EOF > /etc/hosts
#  $hostsfile EOF
#fi

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

# Intel Nic Model Count
#lspci | egrep -i --color 'network|ethernet'
#lspci | grep -i ethernet | wc -l
I350=`lspci | grep -i 'Ethernet' | grep -i 'Intel Corporation I350' | wc -l` >/dev/null
I211=`lspci | grep -i 'Ethernet' | grep -i 'Intel Corporation I211' | wc -l` >/dev/null

# Setting files for /etc/network/interfaces.new
intel_i350_t4=$(wget -qO- https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/intel_i350-t4_interfaces)
intel_i350_t2=$(wget -qO- https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/intel_i350-t2_interfaces)
intel_i211_t6=$(wget -qO- https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/intel_i211_t6_interfaces)
intel_i211_t4=$(wget -qO- https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/intel_i211_t4_interfaces)
intel_i211_t2=$(wget -qO- https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/intel_i211_t2_interfaces)
generic_t4=$(wget -qO- https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/generic_t4_interfaces)
generic_t2=$(wget -qO- https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/generic_t2_interfaces)
generic_t1=$(wget -qO- https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/generic_t1_interfaces)

# Proxmox Networking - Intel I350-T4 Nic Version
if [ "$I350" = 4 ] && [ "$brand" = "$TYPE04" ]; then
printf '%s\n' "Configuring network for a Intel Corporation I350-T4 Gigabit Network Ethernet Controller - "$I350"x Nics..."
eval "cat << EOF > /etc/network/interfaces.new
$intel_i350_t4
EOF"
fi

# Proxmox Networking - Intel I350-T2 Nic Version
if [ "$I350" = 2 ] && [ "$brand" = "$TYPE05" ]; then
printf '%s\n' "Configuring network for a Intel Corporation I350-T2 Gigabit Network Ethernet Controller - "$I350"x Nics..."
eval "cat << EOF > /etc/network/interfaces.new
$intel_i350_t2
EOF"
fi

# Proxmox Networking - Qotom 6x LAN Ports Version
if [ "$I211" = 6 ] && [ "$brand" = "$TYPE01" ]; then
printf '%s\n' "Configuring network for a Intel Corporation I211-T6 Gigabit Network Ethernet Controller - "$I211"x Nics..."
eval "cat << EOF > /etc/network/interfaces.new
$intel_i211_t6
EOF"
fi

# Proxmox Networking - Qotom 4x LAN Ports Version
if [ "$I211" = 4 ] && [ "$brand" = "$TYPE02" ]; then
printf '%s\n' "Configuring network for a Intel Corporation I211-T4 Gigabit Network Ethernet Controller - "$I211"x Nics..."
eval "cat << EOF > /etc/network/interfaces.new
$intel_i211_t4
EOF"
fi

# Proxmox Networking - Qotom 2x LAN Ports Version
if [ "$I211" = 2 ] && [ "$brand" = "$TYPE03" ]; then
printf '%s\n' "Configuring network for a Intel Corporation I211-T2 Gigabit Network Ethernet Controller - "$I211"x Nics..."
eval "cat << EOF > /etc/network/interfaces.new
$intel_i211_t2
EOF"
fi

# Proxmox Networking - PCIe 4x Port LAN Card Generic Version
if [ "$brand" = "$TYPE06" ]; then
printf '%s\n' "Configuring network for a Generic PCIe 4x Port LAN Card Network Ethernet Controller - 4x Nics..."
eval "cat << EOF > /etc/network/interfaces.new
$generic_t4
EOF"
fi

# Proxmox Networking - PCIe 2x Port LAN Card Generic Version
if [ "$brand" = "$TYPE07" ]; then
printf '%s\n' "Configuring network for a Generic PCIe 2x Port LAN Card Network Ethernet Controller - 2x Nics..."
eval "cat << EOF > /etc/network/interfaces.new
$generic_t2
EOF"
fi

# Proxmox Networking - PCIe 1x Port LAN Card Generic Version
if [ "$brand" = "$TYPE08" ]; then
printf '%s\n' "Configuring network for a Generic PCIe 1x Port LAN Card Network Ethernet Controller - 1x Nics..."
sed -i "s|address.*|address  $NEW_IPV4|g" /etc/network/interfaces >/dev/null
sed -i "s|gateway.*|gateway  $NEW_GATEWAY|g" /etc/network/interfaces >/dev/null
sed -i '/bridge-fd/a \
\tbridge-vlan-aware yes \
\tbridge-vids 2-4094' /etc/network/interfaces >/dev/null
fi

# Reboot the node
#clear
#echo "Looking Good. Rebooting in 5 seconds ......"
#sleep 5 ; reboot

# Cleanup container
msg "Cleanup..."
