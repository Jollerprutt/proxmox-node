#!/usr/bin/env bash

# info function
function info() {
  local REASON="$1"
  local FLAG="\e[36m[INFO]\e[39m"
  msg "$FLAG $REASON"
}
# Warning function
function warn() {
  local REASON="\e[97m$1\e[39m"
  local FLAG="\e[93m[WARNING]\e[39m"
  msg "$FLAG $REASON"
}
# Msg function
function msg() {
  local TEXT="$1"
  echo -e "$TEXT"
}
# Echo output in a box
function box_out() {
  local s=("$@") b w
  for l in "${s[@]}"; do
    ((w<${#l})) && { b="$l"; w="${#l}"; }
  done
  tput setaf 3
  echo " -${b//?/-}-
| ${b//?/ } |"
  for l in "${s[@]}"; do
    printf '| %s%*s%s |\n' "$(tput setaf 4)" "-$w" "$l" "$(tput setaf 3)"
  done
  echo "| ${b//?/ } |
 -${b//?/-}-"
  tput sgr 0
}


#########################################################################################
# This script is for setting up your Proxmox Hosts.               						#
#                                                                 						#
# Tested on Proxmox Version : pve-manager/6.1-3/37248ce6 (running kernel: 5.3.10-1-pve) #
#########################################################################################

# Command to run script
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/typhoon-0X-1x_nic-1x_disk-setup-01.sh)"
# pvesm add nfs cyclone-01-public --path /mnt/pve/cyclone-01-public --server 192.168.1.10 --export /volume1/public --content images --options vers=4.1
# /mnt/pve/cyclone-01-public/test.sh
# chmod +x /mnt/pve/cyclone-01-public/test.sh
# bash -c /mnt/pve/cyclone-01-public/test.sh

# Introduction
clear
echo
box_out '#### PLEASE READ CAREFULLY ####' '' 'This script will help you configure your Proxmox host. User input is required.' 'The script will create, edit and/or change system files on your Proxmox host' 'When an optional default setting is provided you may accept the default by pressing ENTER on your keyboard.'
sleep 1
echo

read -p "Do you want to continue (y/n)? " -n 1 -r &&
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
	info "Excellent. Starting now..."
	sleep 1
	echo
else
	warn "Cancelled by user. Now exiting..."
	exit
fi

# Choose your Ethernet Controller Type
TYPE01="Qotom 6x LAN Ports" >/dev/null
TYPE02="Qotom 4x LAN Ports" >/dev/null
TYPE03="Qotom 2x LAN Ports" >/dev/null
TYPE04="Installed PCIe Intel I350-T4 4x Port LAN Card" >/dev/null
TYPE05="Installed PCIe Intel I350-T2 2x Port LAN Card" >/dev/null
TYPE06="Installed PCIe 4x Port LAN Card (i.e Any Brand)" >/dev/null
TYPE07="Installed PCIe 2x Port LAN Card (i.e Any Brand)" >/dev/null
TYPE08="Standard 1x LAN Port" >/dev/null
TYPE09="None of the above. I do not want to configure networking" >/dev/null
PS3="Enter your hardware or ethernet controller type to configure (entering numeric) : "
echo
select brand in "$TYPE01" "$TYPE02" "$TYPE03" "$TYPE04" "$TYPE05" "$TYPE06" "$TYPE07" "$TYPE08" "$TYPE09"
do
echo
info "You have chosen $brand to configure..."
break
done
echo

# Set Proxmox Machine hostname
read -p "Enter your Proxmox machine hostname or press ENTER to accept default: " -e -i $HOSTNAME NEW_HOSTNAME
info "Your Proxmox hostname is $NEW_HOSTNAME."
echo

# Set Proxmox host IP address
read -p "Enter $NEW_HOSTNAME IPv4 address or press ENTER to accept default: " -e -i `hostname -i` NEW_IPV4
info "Your $NEW_HOSTNAME IPv4 address is $NEW_IPV4."
echo

# Set Proxmox host Gateway IP address
read -p "Enter $NEW_HOSTNAME Gateway IPv4 address or press ENTER to accept default: " -e -i `ip route | grep default | cut -d\  -f3` NEW_GATEWAY
info "Your $NEW_HOSTNAME gateway IPv4 address is $NEW_GATEWAY."
echo

# Set IP address for NAS
read -p "Enter your Network Attached Storage (NAS) IPv4 address or press ENTER to accept default: " -e -i 192.168.1.10 NAS_IPV4
info "Your Network Attached Storage (NAS) IPv4 address is $NAS_IPV4."
echo

# Set NAS Machine hostname
read -p "Provide your NAS machine hostname or press ENTER to accept default: " -e -i cyclone-01 NAS_HOSTNAME
info "Your NAS hostname is $NAS_HOSTNAME."
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
grep -q '^fs.inotify.max_queued_events =.*' /etc/sysctl.conf && sed -i 's/^fs.inotify.max_queued_events =.*/fs.inotify.max_queued_events = 16384/' /etc/sysctl.conf || echo 'fs.inotify.max_queued_events = 16384' >> /etc/sysctl.conf
grep -q '^fs.inotify.max_user_instances =.*' /etc/sysctl.conf && sed -i 's/^fs.inotify.max_user_instances =.*/fs.inotify.max_user_instances = 512/' /etc/sysctl.conf || echo 'fs.inotify.max_user_instances = 512' >> /etc/sysctl.conf
grep -q '^fs.inotify.max_user_watches =.*' /etc/sysctl.conf && sed -i 's/^fs.inotify.max_user_watches =.*/fs.inotify.max_user_watches = 8192/' /etc/sysctl.conf || echo 'fs.inotify.max_user_watches = 8192' >> /etc/sysctl.conf

# Install lm sensors (CPU Temp simple type 'sensors')
msg "Installing lm sensors..."
apt-get install -y lm-sensors >/dev/null

# Install VAINFO
msg "Installing VAINFO..."
apt-get install -y vainfo >/dev/null

# Edit Proxmox host file
echo
read -p "Overwrite your system hosts file with Ahuacates latest release [y/n]? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
	hostsfile=$(wget https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/hosts -q -O -)
	cat <<-EOF > /etc/hosts
	$hostsfile
	EOF
	info "$NEW_HOSTNAME hosts file has been updated..."
	echo
fi

# # Intel Nic Model Count
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
	info "Configuring network for a Intel Corporation I350-T4 Gigabit Network Ethernet Controller - "$I350"x Nics..."
	eval "cat <<-EOF > /etc/network/interfaces.new
	$intel_i350_t4
	EOF"
# Proxmox Networking - Intel I350-T2 Nic Version
elif [ "$I350" = 2 ] && [ "$brand" = "$TYPE05" ]; then
	info "Configuring network for a Intel Corporation I350-T2 Gigabit Network Ethernet Controller - "$I350"x Nics..."
	cat <<-EOF > /etc/network/interfaces.new
	$intel_i350_t2
	EOF
# Proxmox Networking - Qotom 6x LAN Ports Version
elif [ "$I211" = 6 ] && [ "$brand" = "$TYPE01" ]; then
	info "Configuring network for a Intel Corporation I211-T6 Gigabit Network Ethernet Controller - "$I211"x Nics..."
	cat <<-EOF > /etc/network/interfaces.new
	$intel_i211_t6
	EOF
# Proxmox Networking - Qotom 4x LAN Ports Version
elif [ "$I211" = 4 ] && [ "$brand" = "$TYPE02" ]; then
	info "Configuring network for a Intel Corporation I211-T4 Gigabit Network Ethernet Controller - "$I211"x Nics..."
	cat <<-EOF > /etc/network/interfaces.new
	$intel_i211_t4
	EOF
# Proxmox Networking - Qotom 2x LAN Ports Version
elif [ "$I211" = 2 ] && [ "$brand" = "$TYPE03" ]; then
	info "Configuring network for a Intel Corporation I211-T2 Gigabit Network Ethernet Controller - "$I211"x Nics..."
	cat <<-EOF > /etc/network/interfaces.new
	$intel_i211_t2
	EOF
# Proxmox Networking - PCIe 4x Port LAN Card Generic Version
elif [ "$brand" = "$TYPE06" ]; then
	info "Configuring network for a Generic PCIe 4x Port LAN Card Network Ethernet Controller - 4x Nics..."
	cat <<-EOF > /etc/network/interfaces.new
	$generic_t4
	EOF
# Proxmox Networking - PCIe 2x Port LAN Card Generic Version
elif [ "$brand" = "$TYPE07" ]; then
	info "Configuring network for a Generic PCIe 2x Port LAN Card Network Ethernet Controller - 2x Nics..."
	cat <<-EOF > /etc/network/interfaces.new
	$generic_t2
	EOF
# Proxmox Networking - PCIe 1x Port LAN Card Generic Version
elif [ "$brand" = "$TYPE08" ]; then
	printf '%s\n' "Configuring network for a Generic PCIe 1x Port LAN Card Network Ethernet Controller - 1x Nics..."
	sed -i "s|address.*|address  $NEW_IPV4|g" /etc/network/interfaces >/dev/null
	sed -i "s|gateway.*|gateway  $NEW_GATEWAY|g" /etc/network/interfaces >/dev/null
	sed -i '/bridge-fd/a \
	\tbridge-vlan-aware yes \
	\tbridge-vids 2-4094' /etc/network/interfaces >/dev/null
# Proxmox Networking - None
elif [ "$brand" = "$TYPE09" ]; then
	info "Skipping configuring any network..."
fi


# Cyclone-01 NFS Mounts
echo
NFS_MOUNT_POINTS=$(showmount -d $NAS_IPV4 | grep -E "/audio|/books|/docker|/cloudstorage|/downloads|/music|/photo|/proxmox/backup|/public|/video|/video/transcode")
rpcinfo -t $NAS_IPV4 nfs 4 > /dev/null 2>&1
read NFS4_TRUE < <(echo $?)
rpcinfo -t $NAS_IPV4 nfs 3 > /dev/null 2>&1
read NFS3_TRUE < <(echo $?)
if [ "$NFS4_TRUE" -eq "0" ]; then
	info  "Remote NFS Version 4 shares are available on NFS server $NAS_IPV4."
	box_out `showmount -d $NAS_IPV4 | grep -E --color=auto "/volume1/audio|/volume1/audio|/volume1/books|/volume1/docker|/volume1/downloads|/volume1/music|/volume1/photo|/volume1/proxmox/backup|/volume1/public|/volume1/video|/volume1/video/transcode"`
	echo
	info "NFS mounts SHOULD ONLY be created on your primary Proxmox host node (i.e typhoon-01)."
	echo
	read -p "Create NFS mounts on host $NEW_HOSTNAME [y/n]? " -n 1 -r
	if [[ $REPLY =~ ^[Yy]$ ]]
then
	NFS_TRUE=0 >/dev/null
	VERS=4.1 >/dev/null
	echo
	fi
fi
rpcinfo -t $NAS_IPV4 nfs 3 > /dev/null 2>&1
read NFS3_TRUE < <(echo $?)
if [ "$NFS4_TRUE" -ne "0" ] && [ "$NFS3_TRUE" -eq "0" ]; then
	echo  "Remote NFS Version 3 shares are available on NFS server $NAS_IPV4."
	box_out `showmount -d $NAS_IPV4 | grep -E --color=auto "/volume1/audio|/volume1/audio|/volume1/books|/cloudstorage|/volume1/docker|/volume1/downloads|/volume1/music|/volume1/photo|/volume1/proxmox/backup|/volume1/public|/volume1/video|/volume1/video/transcode"`
	echo
	info "You should upgrade your NFS server $NAS_HOSTNAME $$NAS_IPV4 to NFSv4.1 before creating NFS mounts.
	NFS mounts SHOULD ONLY be created on your primary Proxmox host node (i.e typhoon-01)."
	echo
	read -p "Create NFS version 3.0 mounts anyway on host $NEW_HOSTNAME [y/n]? " -n 1 -r
	if [[ $REPLY =~ ^[Yy]$ ]]
then
	NFS_TRUE=0 >/dev/null
	VERS=3 >/dev/null
	echo
	fi
fi
# Cyclone-01 NFS Mounts - cyclone-01-audio
NFS_MOUNT_AUDIO=$(showmount -d $NAS_IPV4 | grep -E "/audio" || echo "/no mount available/")
if [ $(echo "$NFS_MOUNT_POINTS" | grep -q "$NFS_MOUNT_AUDIO"; echo $?) -eq 0 ] && [ $(cat /etc/pve/storage.cfg | grep -q "$NAS_HOSTNAME-audio"; echo $?) -eq 1 ] && [ "$NFS_TRUE" = 0 ]; then
	pvesm add nfs "$NAS_HOSTNAME"-audio --path /mnt/pve/"$NAS_HOSTNAME"-audio --server $NAS_IPV4 --export $NFS_MOUNT_AUDIO --content images --options vers=$VERS
	info "Created NFSv$VERS mount $NFS_MOUNT_AUDIO..."
	sleep 2
	echo
elif [ $(echo "$NFS_MOUNT_POINTS" | grep -q "$NFS_MOUNT_AUDIO"; echo $?) -ne 0 ] && [ "$NFS_TRUE" = 0 ]; then
	warn "Unable to connect to NFS Server: NFS mount $NAS_IPV4:$NFS_MOUNT_AUDIO fail!"
	echo
elif [ $(cat /etc/pve/storage.cfg | grep -q "$NAS_HOSTNAME-audio"; echo $?) -eq 0 ] && [ "$NFS_TRUE" = 0 ]; then
	warn "NFS mount $NAS_IPV4:$NFS_MOUNT_AUDIO already exists. Skipping action!"
	echo
fi
# Cyclone-01 NFS Mounts - cyclone-01-backup
NFS_MOUNT_BACKUP=$(showmount -d $NAS_IPV4 | grep -E "/proxmox/backup" || echo "/no mount available/")
if [ $(echo "$NFS_MOUNT_POINTS" | grep -q "$NFS_MOUNT_BACKUP"; echo $?) -eq 0 ] && [ $(cat /etc/pve/storage.cfg | grep -q "$NAS_HOSTNAME-backup"; echo $?) -eq 1 ] && [ "$NFS_TRUE" = 0 ]; then
	pvesm add nfs "$NAS_HOSTNAME"-backup --path /mnt/pve/"$NAS_HOSTNAME"-backup --server $NAS_IPV4 --export $NFS_MOUNT_BACKUP --content images --options vers=$VERS
	info "Created NFSv$VERS mount $NFS_MOUNT_BACKUP..."
	sleep 2
	echo
elif [ $(echo "$NFS_MOUNT_POINTS" | grep -q "$NFS_MOUNT_BACKUP"; echo $?) -ne 0 ] && [ "$NFS_TRUE" = 0 ]; then
	warn "Unable to connect to NFS Server: NFS mount $NAS_IPV4:$NFS_MOUNT_BACKUP fail!"
	echo
elif [ $(cat /etc/pve/storage.cfg | grep -q "$NAS_HOSTNAME-backup"; echo $?) -eq 0 ] && [ "$NFS_TRUE" = 0 ]; then
	warn "NFS mount $NAS_IPV4:$NFS_MOUNT_BACKUP already exists. Skipping action!"
	echo
fi
# Cyclone-01 NFS Mounts - cyclone-01-books
NFS_MOUNT_BOOKS=$(showmount -d $NAS_IPV4 | grep -E "/books" || echo "/no mount available/")
if [ $(echo "$NFS_MOUNT_POINTS" | grep -q "$NFS_MOUNT_BOOKS"; echo $?) -eq 0 ] && [ $(cat /etc/pve/storage.cfg | grep -q "$NAS_HOSTNAME-books"; echo $?) -eq 1 ] && [ "$NFS_TRUE" = 0 ]; then
	pvesm add nfs "$NAS_HOSTNAME"-books --path /mnt/pve/"$NAS_HOSTNAME"-books --server $NAS_IPV4 --export $NFS_MOUNT_BOOKS --content images --options vers=$VERS
	info "Created NFSv$VERS mount $NFS_MOUNT_BOOKS..."
	sleep 2
	echo
elif [ $(echo "$NFS_MOUNT_POINTS" | grep -q "$NFS_MOUNT_BOOKS"; echo $?) -ne 0 ] && [ "$NFS_TRUE" = 0 ]; then
	warn "Unable to connect to NFS Server: NFS mount $NAS_IPV4:$NFS_MOUNT_BOOKS fail!"
	echo
elif [ $(cat /etc/pve/storage.cfg | grep -q "$NAS_HOSTNAME-books"; echo $?) -eq 0 ] && [ "$NFS_TRUE" = 0 ]; then
	warn "NFS mount $NAS_IPV4:$NFS_MOUNT_BOOKS already exists. Skipping action!"
	echo
fi
# Cyclone-01 NFS Mounts - cyclone-01-cloudstorage
NFS_MOUNT_CLOUDSTORAGE=$(showmount -d $NAS_IPV4 | grep -E "/cloudstorage" || echo "/no mount available/")
if [ $(echo "$NFS_MOUNT_POINTS" | grep -q "$NFS_MOUNT_CLOUDSTORAGE"; echo $?) -eq 0 ] && [ $(cat /etc/pve/storage.cfg | grep -q "$NAS_HOSTNAME-cloudstorage"; echo $?) -eq 1 ] && [ "$NFS_TRUE" = 0 ]; then
	pvesm add nfs "$NAS_HOSTNAME"-cloudstorage --path /mnt/pve/"$NAS_HOSTNAME"-cloudstorage --server $NAS_IPV4 --export $NFS_MOUNT_CLOUDSTORAGE --content images --options vers=$VERS
	info "Created NFSv$VERS mount $NFS_MOUNT_CLOUDSTORAGE..."
	sleep 2
	echo
elif [ $(echo "$NFS_MOUNT_POINTS" | grep -q "$NFS_MOUNT_CLOUDSTORAGE"; echo $?) -ne 0 ] && [ "$NFS_TRUE" = 0 ]; then
	warn "Unable to connect to NFS Server: NFS mount $NAS_IPV4:$NFS_MOUNT_CLOUDSTORAGE fail!"
	echo
elif [ $(cat /etc/pve/storage.cfg | grep -q "$NAS_HOSTNAME-cloudstorage"; echo $?) -eq 0 ] && [ "$NFS_TRUE" = 0 ]; then
	warn "NFS mount $NAS_IPV4:$NFS_MOUNT_CLOUDSTORAGE already exists. Skipping action!"
	echo
fi
# Cyclone-01 NFS Mounts - cyclone-01-docker
NFS_MOUNT_DOCKER=$(showmount -d $NAS_IPV4 | grep -E "/docker" || echo "/no mount available/")
if [ $(echo "$NFS_MOUNT_POINTS" | grep -q "$NFS_MOUNT_DOCKER"; echo $?) -eq 0 ] && [ $(cat /etc/pve/storage.cfg | grep -q "$NAS_HOSTNAME-docker"; echo $?) -eq 1 ] && [ "$NFS_TRUE" = 0 ]; then
	pvesm add nfs "$NAS_HOSTNAME"-docker --path /mnt/pve/"$NAS_HOSTNAME"-docker --server $NAS_IPV4 --export $NFS_MOUNT_DOCKER --content images --options vers=$VERS
	info "Created NFSv$VERS mount $NFS_MOUNT_DOCKER..."
	sleep 2
	echo
elif [ $(echo "$NFS_MOUNT_POINTS" | grep -q "$NFS_MOUNT_DOCKER"; echo $?) -ne 0 ] && [ "$NFS_TRUE" = 0 ]; then
	warn "Unable to connect to NFS Server: NFS mount $NAS_IPV4:$NFS_MOUNT_DOCKER fail!"
	echo
elif [ $(cat /etc/pve/storage.cfg | grep -q "$NAS_HOSTNAME-docker"; echo $?) -eq 0 ] && [ "$NFS_TRUE" = 0 ]; then
	warn "NFS mount $NAS_IPV4:$NFS_MOUNT_DOCKER already exists. Skipping action!"
	echo
fi
# Cyclone-01 NFS Mounts - cyclone-01-downloads
NFS_MOUNT_DOWNLOADS=$(showmount -d $NAS_IPV4 | grep -E "/downloads" || echo "/no mount available/")
if [ $(echo "$NFS_MOUNT_POINTS" | grep -q "$NFS_MOUNT_DOWNLOADS"; echo $?) -eq 0 ] && [ $(cat /etc/pve/storage.cfg | grep -q "$NAS_HOSTNAME-downloads"; echo $?) -eq 1 ] && [ "$NFS_TRUE" = 0 ]; then
	pvesm add nfs "$NAS_HOSTNAME"-downloads --path /mnt/pve/"$NAS_HOSTNAME"-downloads --server $NAS_IPV4 --export $NFS_MOUNT_DOWNLOADS --content images --options vers=$VERS
	info "Created NFSv$VERS mount $NFS_MOUNT_DOWNLOADS..."
	sleep 2
	echo
elif [ $(echo "$NFS_MOUNT_POINTS" | grep -q "$NFS_MOUNT_DOWNLOADS"; echo $?) -ne 0 ] && [ "$NFS_TRUE" = 0 ]; then
	warn "Unable to connect to NFS Server: NFS mount $NAS_IPV4:$NFS_MOUNT_DOWNLOADS fail!"
	echo
elif [ $(cat /etc/pve/storage.cfg | grep -q "$NAS_HOSTNAME-downloads"; echo $?) -eq 0 ] && [ "$NFS_TRUE" = 0 ]; then
	warn "NFS mount $NAS_IPV4:$NFS_MOUNT_DOWNLOADS already exists. Skipping action!"
	echo
fi
# Cyclone-01 NFS Mounts - cyclone-01-music
NFS_MOUNT_MUSIC=$(showmount -d $NAS_IPV4 | grep -E "/music" || echo "/no mount available/")
if [ $(echo "$NFS_MOUNT_POINTS" | grep -q "$NFS_MOUNT_MUSIC"; echo $?) -eq 0 ] && [ $(cat /etc/pve/storage.cfg | grep -q "$NAS_HOSTNAME-music"; echo $?) -eq 1 ] && [ "$NFS_TRUE" = 0 ]; then
	pvesm add nfs "$NAS_HOSTNAME"-music --path /mnt/pve/"$NAS_HOSTNAME"-music --server $NAS_IPV4 --export $NFS_MOUNT_MUSIC --content images --options vers=$VERS
	info "Created NFSv$VERS mount $NFS_MOUNT_MUSIC..."
	sleep 2
	echo
elif [ $(echo "$NFS_MOUNT_POINTS" | grep -q "$NFS_MOUNT_MUSIC"; echo $?) -ne 0 ] && [ "$NFS_TRUE" = 0 ]; then
	warn "Unable to connect to NFS Server: NFS mount $NAS_IPV4:$NFS_MOUNT_MUSIC fail!"
	echo
elif [ $(cat /etc/pve/storage.cfg | grep -q "$NAS_HOSTNAME-music"; echo $?) -eq 0 ] && [ "$NFS_TRUE" = 0 ]; then
	warn "NFS mount $NAS_IPV4:$NFS_MOUNT_MUSIC already exists. Skipping action!"
	echo
fi
# Cyclone-01 NFS Mounts - cyclone-01-photo
NFS_MOUNT_PHOTO=$(showmount -d $NAS_IPV4 | grep -E "/photo" || echo "/no mount available/")
if [ $(echo "$NFS_MOUNT_POINTS" | grep -q "$NFS_MOUNT_PHOTO"; echo $?) -eq 0 ] && [ $(cat /etc/pve/storage.cfg | grep -q "$NAS_HOSTNAME-photo"; echo $?) -eq 1 ] && [ "$NFS_TRUE" = 0 ]; then
	pvesm add nfs "$NAS_HOSTNAME"-photo --path /mnt/pve/"$NAS_HOSTNAME"-photo --server $NAS_IPV4 --export $NFS_MOUNT_PHOTO --content images --options vers=$VERS
	info "Created NFSv$VERS mount $NFS_MOUNT_PHOTO..."
	sleep 2
	echo
elif [ $(echo "$NFS_MOUNT_POINTS" | grep -q "$NFS_MOUNT_PHOTO"; echo $?) -ne 0 ] && [ "$NFS_TRUE" = 0 ]; then
	warn "Unable to connect to NFS Server: NFS mount $NAS_IPV4:$NFS_MOUNT_PHOTO fail!"
	echo
elif [ $(cat /etc/pve/storage.cfg | grep -q "$NAS_HOSTNAME-photo"; echo $?) -eq 0 ] && [ "$NFS_TRUE" = 0 ]; then
	warn "NFS mount $NAS_IPV4:$NFS_MOUNT_PHOTO already exists. Skipping action!"
	echo
fi
# Cyclone-01 NFS Mounts - cyclone-01-public
NFS_MOUNT_PUBLIC=$(showmount -d $NAS_IPV4 | grep -E "/public" || echo "/no mount available/")
if [ $(echo "$NFS_MOUNT_POINTS" | grep -q "$NFS_MOUNT_PUBLIC"; echo $?) -eq 0 ] && [ $(cat /etc/pve/storage.cfg | grep -q "$NAS_HOSTNAME-public"; echo $?) -eq 1 ] && [ "$NFS_TRUE" = 0 ]; then
	pvesm add nfs "$NAS_HOSTNAME"-public --path /mnt/pve/"$NAS_HOSTNAME"-public --server $NAS_IPV4 --export $NFS_MOUNT_PUBLIC --content images --options vers=$VERS
	info "Created NFSv$VERS mount $NFS_MOUNT_PUBLIC..."
	sleep 2
	echo
elif [ $(echo "$NFS_MOUNT_POINTS" | grep -q "$NFS_MOUNT_PUBLIC"; echo $?) -ne 0 ] && [ "$NFS_TRUE" = 0 ]; then
	warn "Unable to connect to NFS Server: NFS mount $NAS_IPV4:$NFS_MOUNT_PUBLIC fail!"
	echo
elif [ $(cat /etc/pve/storage.cfg | grep -q "$NAS_HOSTNAME-public"; echo $?) -eq 0 ] && [ "$NFS_TRUE" = 0 ]; then
	warn "NFS mount $NAS_IPV4:$NFS_MOUNT_PUBLIC already exists. Skipping action!"
	echo
fi
# Cyclone-01 NFS Mounts - cyclone-01-transcode
NFS_MOUNT_TRANSCODE=$(showmount -d $NAS_IPV4 | grep -E "/video/transcode" || echo "/no mount available/")
if [ $(echo "$NFS_MOUNT_POINTS" | grep -q "$NFS_MOUNT_TRANSCODE"; echo $?) -eq 0 ] && [ $(cat /etc/pve/storage.cfg | grep -q "$NAS_HOSTNAME-transcode"; echo $?) -eq 1 ] && [ "$NFS_TRUE" = 0 ]; then
	pvesm add nfs "$NAS_HOSTNAME"-transcode --path /mnt/pve/"$NAS_HOSTNAME"-transcode --server $NAS_IPV4 --export $NFS_MOUNT_TRANSCODE --content images --options vers=$VERS
	info "Created NFSv$VERS mount $NFS_MOUNT_TRANSCODE..."
	sleep 2
	echo
elif [ $(echo "$NFS_MOUNT_POINTS" | grep -q "$NFS_MOUNT_TRANSCODE"; echo $?) -ne 0 ] && [ "$NFS_TRUE" = 0 ]; then
	warn "Unable to connect to NFS Server: NFS mount $NAS_IPV4:$NFS_MOUNT_TRANSCODE fail!"
	echo
elif [ $(cat /etc/pve/storage.cfg | grep -q "$NAS_HOSTNAME-transcode"; echo $?) -eq 0 ] && [ "$NFS_TRUE" = 0 ]; then
	warn "NFS mount $NAS_IPV4:$NFS_MOUNT_TRANSCODE already exists. Skipping action!"
	echo
fi
# Cyclone-01 NFS Mounts - cyclone-01-video
NFS_MOUNT_VIDEO=$(showmount -d $NAS_IPV4 | grep -E "/video" | grep -v "/video/transcode" || echo "/no mount available/")
if [ $(echo "$NFS_MOUNT_POINTS" | grep -q "$NFS_MOUNT_VIDEO"; echo $?) -eq 0 ] && [ $(cat /etc/pve/storage.cfg | grep -q "$NAS_HOSTNAME-video"; echo $?) -eq 1 ] && [ "$NFS_TRUE" = 0 ]; then
	pvesm add nfs "$NAS_HOSTNAME"-video --path /mnt/pve/"$NAS_HOSTNAME"-video --server $NAS_IPV4 --export $NFS_MOUNT_VIDEO --content images --options vers=$VERS
	info "Created NFSv$VERS mount $NFS_MOUNT_VIDEO..."
	sleep 2
	echo
elif [ $(echo "$NFS_MOUNT_POINTS" | grep -q "$NFS_MOUNT_VIDEO"; echo $?) -ne 0 ] && [ "$NFS_TRUE" = 0 ]; then
	warn "Unable to connect to NFS Server: NFS mount $NAS_IPV4:$NFS_MOUNT_VIDEO fail!"
	echo
elif [ $(cat /etc/pve/storage.cfg | grep -q "$NAS_HOSTNAME-video"; echo $?) -eq 0 ] && [ "$NFS_TRUE" = 0 ]; then
	warn "NFS mount $NAS_IPV4:$NFS_MOUNT_VIDEO already exists. Skipping action!"
	echo
fi


# Append your public key to /etc/pve/priv/authorized_keys
RSA_KEY=/mnt/pve/cyclone-01-public/id_rsa*.pub
echo
box_out '#### ADDING YOUR OWN SSH PUBLIC KEY - MUST READ ####' '' 'To append your own SSH Public Key to your hosts authorized keys you MUST FIRST COPY your SSH Public Key' 'into your shared /volume1/public folder on your NAS server.'
echo
sleep 1
read -p "Do you want to copy your own SSH Public Key to host $NEW_HOSTNAME [y/n]? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
	RSA_KEY_INSTALL=0 >/dev/null
	info "Preparing to copy your SSH Public Key..."
	sleep 1
	echo
else
	RSA_KEY_INSTALL=1 >/dev/null
	echo
fi
# Test NFS mount access
if [ "$(grep -qs /mnt/pve/cyclone-01-public /proc/mounts; echo $?)" -eq "0" ] && [ "$RSA_KEY_INSTALL" = "0" ]; then
    info "Your NAS shared /volume1/public folder is mounted and accessible."
	echo
	NFS_PUBLIC_TRUE=0 >/dev/null
elif [ "$(grep -qs /mnt/pve/cyclone-01-public /proc/mounts; echo $?)" -ne "0" ] && [ "$RSA_KEY_INSTALL" = "0" ]; then
    warn "Your NAS shared /volume1/public folder is NOT accessible. Cannot append your SSH Public Key at this stage."
	echo
	NFS_PUBLIC_TRUE=1 >/dev/null
fi
# Check if RSA key is present and available on NAS
if [ -f $RSA_KEY ]; then
	RSA_AVAIL=0
else
	RSA_AVAIL=1
fi
if [ "$RSA_AVAIL" = "0" ] && [ "$NFS_PUBLIC_TRUE" = "0" ] && [ "$RSA_KEY_INSTALL" = "0" ]; then
	info "Found a SSH Public Key filename $(echo `basename "/mnt/pve/cyclone-01-public/id_rsa*.pub"`) in your NAS shared /volume1/public folder."
	echo
	RSA_KEY_TRUE=0 >/dev/null
elif [ "$RSA_AVAIL" = "1" ] && [ "$NFS_PUBLIC_TRUE" = "0" ] && [ "$RSA_KEY_INSTALL" = "0" ]; then
	warn "No SSH Public Key exists in your NAS shared /volume1/public folder. Cannot append your SSH Public Key to host $NEW_HOSTNAME at this stage."
	echo
	RSA_KEY_TRUE=1 >/dev/null
fi
# Check if SSH key already exists on host
if [ "grep -q $RSA_KEY ~/.ssh/authorized_keys" = "0" ] && [ "$RSA_KEY_TRUE" = "0" ] && [ "$RSA_KEY_INSTALL" = "0" ]; then
	info "Matching SSH Public Key filename $(echo `basename "/mnt/pve/cyclone-01-public/id_rsa*.pub"`) found on host $NEW_HOSTNAME. Not proceeding."
	echo
	RSA_KEY_EXISTS=0 >/dev/null
else
	RSA_KEY_EXISTS=1 >/dev/null
fi
# Copy RSA key to host
if [ "$RSA_KEY_EXISTS" = "1" ] && [ "$RSA_KEY_TRUE" = "0" ] && [ "$NFS_PUBLIC_TRUE" = "0" ] && [ "$RSA_KEY_INSTALL" = "0" ]; then
	cat <<-EOF >> ~/.ssh/authorized_keys
	$(cat $RSA_KEY)
	EOF
	info "Your SSH Public Key has been added to host $NEW_HOSTNAME authorized_keys..."
	service sshd restart >/dev/null
	info "Restarting sshd service..."
	echo
fi


# Install Fail2ban
echo
box_out '#### INSTALL FAIL2BAN - RECOMMENDED INSTALLATION ####' '' 'Fail2Ban is an intrusion prevention software framework that protects computer servers from brute-force attacks.' 'But DO NOT forget your Proxmox password'
echo
sleep 3
read -p "Do you want to install Fail2ban intrusion prevention software on $NEW_HOSTNAME [y/n]? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
	FAIL2BAN=0 >/dev/null
else
	FAIL2BAN=1 >/dev/null
fi
if [ "$FAIL2BAN" = "0" ] && [ "$(dpkg -s fail2ban &> /dev/null; echo $?)" -ne "0" ]; then
	info "Installing Fail2ban..."
elif [ "$FAIL2BAN" = "0" ] && [ "$(dpkg -s fail2ban &> /dev/null; echo $?)" -eq "0" ]; then
	warn "Fail2ban already exists (installed). Not re-installing Fail2ban..."	
elif [ "$FAIL2BAN" = "1" ] && [ "$(dpkg -s fail2ban &> /dev/null; echo $?)" -eq "0" ]; then
	info "Cancelled. FYI Fail2ban already installed..."
elif [ "$FAIL2BAN" = "1" ] && [ "$(dpkg -s fail2ban &> /dev/null; echo $?)" -ne "0" ]; then
	info "Cancelled. Not installing Fail2ban..."
fi
# Install Fail2ban Software
if [ "$FAIL2BAN" = "0" ]; then
	info "Installing Fail2ban software..."
	apt-get update >/dev/null
	apt-get install -y fail2ban >/dev/null
	FAIL2BAN_INSTALL=0
fi
# Create file /etc/fail2ban/jail.local
if [ "$FAIL2BAN" = "0" ] && [ "$FAIL2BAN_INSTALL" = "0" ]; then
	cat <<-EOF >  /etc/fail2ban/jail.local
	[proxmox]
	enabled = true
	port = https,http,8006
	filter = proxmox
	logpath = /var/log/daemon.log
	maxretry = 3
	# 1 hour
	bantime = 3600
	EOF
	info "Fail2ban file jail.local has been created..."
	JAIL_LOCAL=0
	echo
fi
# Create file /etc/fail2ban/filter.d/proxmox.conf 
if [ "$FAIL2BAN" = "0" ] && [ "$FAIL2BAN_INSTALL" = "0" ]; then
	cat <<-EOF >  /etc/fail2ban/filter.d/proxmox.conf 
	[Definition]
	failregex = pvedaemon\[.*authentication failure; rhost=<HOST> user=.* msg=.*
	ignoreregex =
	EOF
	info "Fail2ban file proxmox.conf has been created..."
	PROXMOX_CONF=0
	echo
fi
# Start Fail2ban
if [ "$FAIL2BAN" = "0" ] && [ "$FAIL2BAN_INSTALL" = "0" ] && [ "$JAIL_LOCAL" = "0" ] && [ "$PROXMOX_CONF" = "0" ]; then
	systemctl restart fail2ban >/dev/null
	sleep 2
fi
# Fail2ban systemctl status
if [ "$FAIL2BAN" = "0" ] && [ "$(systemctl is-active --quiet fail2ban; echo $?) -eq 0" ]; then
	info "Fail2ban is active (running)..."
elif [ "$FAIL2BAN" = "0" ] && [ "$(systemctl is-active --quiet fail2ban; echo $?) -eq 3" ]; then
	warn "Fail2ban is inactive (dead). Your intervention is required..."
fi


# Rename ZFS disk label
if grep local-zfs /etc/pve/storage.cfg >/dev/null; then
	read -p "Rename your local-zfs disk label to typhoon-share [y/n]? " -n 1 -r
	echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
	info "Renaming local-zfs disk label to typhoon-share..."
	sed -i 's|zfspool: local-zfs|zfspool: typhoon-share|g' /etc/pve/storage.cfg
	echo
fi
fi


# Reboot Host
info "Success. Configuration complete..."
echo
read -p "Do you want to reboot host $NEW_HOSTNAME - it's recommended! [y/n]? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
	info "Rebooting in 3 seconds..."
	sleep 3
	reboot 
else
	info "Exiting the script..."
	exit
fi
