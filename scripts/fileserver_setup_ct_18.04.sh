#!/usr/bin/env bash

function info() {
  local REASON="$1"
  local FLAG="\e[36m[INFO]\e[39m"
  msg "$FLAG $REASON"
}
function msg() {
  local TEXT="$1"
  echo -e "$TEXT"
}
function section() {
  local REASON="  \e[97m$1\e[37m"
  printf -- '-%.0s' {1..100}; echo ""
  msg "$REASON"
  printf -- '-%.0s' {1..100}; echo ""
  echo
}
function box_out() {
  set +u
  local s=("$@") b w
  for l in "${s[@]}"; do
	((w<${#l})) && { b="$l"; w="${#l}"; }
  done
  tput setaf 3
  echo " -${b//?/-}-
| ${b//?/ } |"
  for l in "${s[@]}"; do
	printf '| %s%*s%s |\n' "$(tput setaf 7)" "-$w" "$l" "$(tput setaf 3)"
  done
  echo "| ${b//?/ } |
 -${b//?/-}-"
  tput sgr 0
  set -u
}

# Colour
RED=$'\033[0;31m'
YELLOW=$'\033[1;33m'
GREEN=$'\033[0;32m'
WHITE=$'\033[1;37m'
NC=$'\033[0m'


# Download external scripts
wget -qL https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/proxmox_setup_sharedfolderlist

#### Creating File Server Users and Groups ####
section "Creating File Server Users and Groups."


# Create users and groups
msg "Creating CT default user groups..."
# Create Groups
getent group medialab >/dev/null
if [ $? -ne 0 ]; then
	groupadd -g 65605 medialab
  info "Default user group created: ${YELLOW}medialab${NC}"
fi
getent group homelab >/dev/null
if [ $? -ne 0 ]; then
	groupadd -g 65606 homelab
  info "Default user group created: ${YELLOW}homelab${NC}"
fi
getent group privatelab >/dev/null
if [ $? -ne 0 ]; then
	groupadd -g 65607 privatelab
  info "Default user group created: ${YELLOW}privatelab${NC}"
fi
echo


# Create Base Users
msg "Creating CT default users..."
id -u media >/dev/null
if [ $? -ne 0 ]; then
	useradd -m -d /srv/$HOSTNAME/homes/media -u 1605 -g medialab -s /bin/bash media >/dev/null
  info "Default user created: ${YELLOW}media${NC} of group medialab"
fi
id -u storm >/dev/null
if [ $? -ne 0 ]; then
	useradd -m -d /srv/$HOSTNAME/homes/storm -u 1606 -g homelab -G medialab -s /bin/bash storm >/dev/null
  info "Default user created: ${YELLOW}storm${NC} of groups medialab, homelab"
fi
id -u typhoon >/dev/null
if [ $? -ne 0 ]; then
	useradd -m -d /srv/$HOSTNAME/homes/typhoon -u 1607 -g privatelab -G medialab,homelab -s /bin/bash typhoon >/dev/null
  info "Default user created: ${YELLOW}typhoon${NC} of groups medialab, homelab and privatelab"
fi
echo


# Create New users
echo
box_out '#### PLEASE READ CAREFULLY - NEW USER ACCOUNTS ####' '' 'Network servers and computing clients need to securely access and store data' 'on your File Server (NAS). By default your File Server is configured with a' 'list of users and user groups which are created automatically in this build:' '' '  --  GROUP NAME     -- USER NAME' '  --  "medialab"     -- /srv/CT_HOSTNAME/homes/"media"' '  --  "homelab"      -- /srv/CT_HOSTNAME/homes/"storm"' '  --  "privatelab"   -- /srv/CT_HOSTNAME/homes/"typhoon"' '' 'You have the option to create new user accounts on this File Server. Each' 'new user will automatically create its own Personal Home Folder. By default' 'all new users are members of the privatelab group. Privatelab group has' 'access rights to all default shared folders on the File Server. The folder' 'name of a Personal Home Folder is the same as the user account.' '' 'You can access a Personal Home Folder via CIFS/Samba and NFS.'
echo
read -p "Create new personal user accounts on your File Server (NAS) [y/n]? " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
	NEW_NAS_USER=0 >/dev/null
else
	NEW_NAS_USER=1 >/dev/null
	info "You have chosen to skip this step."
fi
echo

while [[ "$REPLY" != "no" ]] && [ "$NEW_NAS_USER" = 0 ]; do
read -p "Enter new username you want to create : " username
echo
msg "Choose your new user's group permissions."
GRP01="Homelab - Standard User - Personal Home Folder & Public Folder only." >/dev/null
GRP02="Privatelab - Admin User - Full access to all data." >/dev/null
PS3="Select your new users group permission rights (entering numeric) : "
echo
select grp_type in "$GRP01" "$GRP02"
do
echo
info "You have selected: $grp_type ..."
echo
break
done
if [ "$grp_type" = "$GRP01" ]; then
	USERGRP="homelab"
elif [ "$grp_type" = "$GRP02" ]; then
	USERGRP="privatelab -G medialab,homelab"
fi
while true; do
	read -s -p "Enter Password: " password
	echo
	read -s -p "Enter Password (again): " password2
	echo
	[ "$password" = "$password2" ] && echo "$username $password $USERGRP" >> usersfile.txt && break
	warn "Passwords do not match. Please try again."
done
echo
  read -p "Do you want to create another new user account (type yes/no)?"
done

if [ $(id -u) -eq 0 ] && [ "$NEW_NAS_USER" = 0 ]; then
NEW_USERS=usersfile.txt
HOME_BASE="/srv/$HOSTNAME/homes/"
cat ${NEW_USERS} |
while read USER PASSWORD GROUP
do
pass=$(perl -e 'print crypt($ARGV[0], 'password')' $PASSWORD)
egrep “^$USER[0]” /etc/passwd > /dev/null
if [ $? -eq 0 ]; then
warn “User $USER exists!”
exit 1
else
useradd -g ${GROUP} -p ${pass} -m -d ${HOME_BASE}${USER} -s /bin/bash ${USER}
sudo -iu ${USER} xdg-user-dirs-update
(echo ${PASSWORD}; echo ${PASSWORD} ) | smbpasswd -s -a ${USER}
[ $? -eq 0 ] && info “User $USER has been added to the system” || warn “Failed adding user $USER!”
fi
done
fi


# Create kodi_rsync user
box_out '#### PLEASE READ CAREFULLY - KODI_RSYNC USER ####' '' 'Do you want to make a CoreElec Kodi player portable for use in remote' 'locations? Like homes with no internet or LAN network.' '''This is achieved by attaching a USB3 hard disk to your CoreElec hardware and' 'running Linux native RSYNC to synchronise your selected File Server media' 'library to the attached USB3 hard disk.'
echo
read -p "Create the user kodi_rsync on your File Server (NAS)[yes/no]?: " -r
if [[ "$REPLY" == "y" || "$REPLY" == "Y" || "$REPLY" == "yes" || "$REPLY" == "Yes" ]]; then
  msg "Creating user kodi_rsync..."
  KODI_RSYNC=0
  id -u kodi_rsync >/dev/null
  if [ $? -ne 0 ]; then
    useradd -m -d /srv/$HOSTNAME/homes/kodi_rsync -g medialab -s /bin/bash kodi_rsync >/dev/null
    info "User created: ${YELLOW}kodi_rsync${NC} of group medialab"
  else
    info "User ${YELLOW}kodi_rsync${NC} already exists. Skipping this step."
    KODI_RSYNC=1
  fi
else
  KODI_RSYNC=1
  info "Skipping this step."
  echo
fi
if [ $KODI_RSYNC == 0 ]; then
  msg "Editing SSH server configuration file..."
  sudo sed -i 's|#PubkeyAuthentication yes|PubkeyAuthentication yes|g' /etc/ssh/sshd_config
  sudo sed -i 's|#AuthorizedKeysFile.*|AuthorizedKeysFile     .ssh/authorized_keys|g' /etc/ssh/sshd_config
  msg "Creating authorised keys folders for user kodi_rsync..."
  mkdir /srv/$HOSTNAME/homes/kodi_rsync/.ssh
  chmod 700 /srv/$HOSTNAME/homes/kodi_rsync/.ssh
  touch /srv/$HOSTNAME/homes/kodi_rsync/.ssh/authorized_keys
  chmod 600 /srv/$HOSTNAME/homes/kodi_rsync/.ssh/authorized_keys
  chmod 700 /srv/$HOSTNAME/homes/kodi_rsync
  msg "Restarting SSH service..."
  sudo synoservicectl --reload sshd
  echo
fi


#### Setting Folder Permissions ####
section "Setting File Server Folder Permissions."


# Set Medialab Folder Permissions
msg "Setting medialab folder share permissions..."
echo
cat proxmox_setup_sharedfolderlist | awk '$2 ~ "medialab" { print $1 }' > proxmox_setup_sharedfolderlist-medialab
schemaExtractDir="/srv/$HOSTNAME"
while read dir; do
  dir="$schemaExtractDir/$dir"
  if [ -d "$dir" ]; then
    info "$dir exists, setting medialab group permissions for this folder."
	chgrp -R medialab "${dir}"
	chmod g+rwx -R "${dir}"
	echo
  else
    warn "$dir does not exist: skipping ..."
	echo
  fi
done < proxmox_setup_sharedfolderlist-medialab # file listing of medialab folders to modify

# Set Homelab Folder Permissions
msg "Setting homelab folder share permissions..."
echo
cat proxmox_setup_sharedfolderlist | awk '$2 ~ "homelab" { print $1 }' > proxmox_setup_sharedfolderlist-homelab
schemaExtractDir="/srv/$HOSTNAME"
while read dir; do
  dir="$schemaExtractDir/$dir"
  if [ -d "$dir" ]; then
    info "$dir exists, setting homelab group permissions for this folder."
	chgrp -R homelab "${dir}"
	chmod g+rwx -R "${dir}"
	echo
  else
    warn "$dir does not exist: skipping ..."
	echo
  fi
done < proxmox_setup_sharedfolderlist-homelab # file listing of homelab folders to modify

# Set Privatelab Folder Permissions
msg "Setting privatelab folder share permissions..."
echo
cat proxmox_setup_sharedfolderlist | awk '$2 ~ "privatelab" { print $1 }' > proxmox_setup_sharedfolderlist-privatelab
schemaExtractDir="/srv/$HOSTNAME"
while read dir; do
  dir="$schemaExtractDir/$dir"
  if [ -d "$dir" ]; then
    info "$dir exists, setting privatelab group permissions for this folder."
	chgrp -R privatelab "${dir}"
	chmod g+rwx -R "${dir}"
	echo
  else
    warn "$dir does not exist: skipping ..."
	echo
  fi
done < proxmox_setup_sharedfolderlist-privatelab # file listing of privatelab folders to modify

# Set Public Folder Permissions
msg "Setting public folder share permissions..."
echo
cat proxmox_setup_sharedfolderlist | awk '$2 ~ "public" { print $1 }' > proxmox_setup_sharedfolderlist-public
schemaExtractDir="/srv/$HOSTNAME"
while read dir; do
  dir="$schemaExtractDir/$dir"
  if [ -d "$dir" ]; then
    info "$dir exists, setting public group permissions for this folder."
	chmod -R a+rwx "${dir}"
	echo
  else
    warn "$dir does not exist: skipping ..."
	echo
  fi
done < proxmox_setup_sharedfolderlist-public # file listing of privatelab folders to modify


#### Install and Configure Samba ####
section "Installing and configuring Samba."


# Install Samba
msg "Installing Samba..."
apt update >/dev/null
apt install -y samba >/dev/null

# Configure Samba Basics
msg "Configuring Samba..."
service smbd stop
cat << EOF > /etc/samba/smb.conf
[global]
	workgroup = WORKGROUP
	server string = $HOSTNAME
	server role = standalone server
	disable netbios = yes
	dns proxy = no
	interfaces = 127.0.0.0/8 eth0
	bind interfaces only = yes
	log file = /var/log/samba/log.%m
	max log size = 1000
	syslog = 0
	panic action = /usr/share/samba/panic-action %d
	passdb backend = tdbsam
	obey pam restrictions = yes
	unix password sync = yes
	passwd program = /usr/bin/passwd %u
	passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
	pam password change = yes
	map to guest = bad user
	usershare allow guests = yes

[homes]
	comment = home directories
	browseable = yes
	read only = no
	create mask = 0775
	directory mask = 0775
	valid users = %S

[public]
	comment = public anonymous access
	path = /srv/$HOSTNAME/public
	browsable =yes
	public = yes
	read only = no
	force user = nobody
	guest ok = yes
EOF

# Create your Default and Custom Samba Shares 
msg "Creating default and custom Samba folder shares..."
echo
cat proxmox_setup_sharedfolderlist | awk '{ print $1 }' | sed '/homes/d;/public/d' > proxmox_setup_sharedfolderlist-samba_dir
schemaExtractDir="/srv/$HOSTNAME"
while read dir; do
  dir01="$schemaExtractDir/$dir"
  if [ -d "$dir01" ]; then
    dirgrp=$(cat proxmox_setup_sharedfolderlist | grep -i $dir | awk '{ print $2}') || true >/dev/null
	eval "cat <<-EOF >> /etc/samba/smb.conf

	[$dir]
		comment = $dir folder access
		path = ${dir01}
		browsable =yes
		read only = no
		create mask = 0775
		directory mask = 0775
		valid users = %S,@$dirgrp
	EOF"
  else
	info "${dir01} does not exist: skipping."
	echo
  fi
done < proxmox_setup_sharedfolderlist-samba_dir # file listing of folders to create
service smbd start # Restart Samba


#### Install and Configure NFS ####
section "Installing and configuring NFS Server."


# Install nfs
msg "Installing NFS Server..."
apt update >/dev/null
apt install -y nfs-kernel-server >/dev/null

# Edit Exports
msg "Modifying /etc/exports file..."
echo
if [ "$XTRA_SHARES" = 0 ]; then
	echo
	box_out '#### PLEASE READ CAREFULLY - ADDITIONAL NFS SHARED FOLDERS ####' '' 'In a previous step you created additional shared folders.' '' 'You can choose to select which additional folders are to be made available as NFS shares.'
	echo
	read -p "Do you want to create NFS shares for your additional shared folders [y/n]? " -n 1 -r
	echo
fi

if [ "$XTRA_SHARES" = 0 ] && [[ $REPLY =~ ^[Yy]$ ]]
then
	NFS_XTRA_SHARES=0 >/dev/null
else
	NFS_XTRA_SHARES=1 >/dev/null
	info "Your additional shared folders will not be available as NFS shares (default shared folders only) ..."
	echo
fi

if [ "$NFS_XTRA_SHARES" = 0 ] && [ "$XTRA_SHARES" = 0 ]; then
echo "Please select which additional folders are to be made available as NFS shares."
menu() {
    echo "Avaliable options:"
    for i in ${!options[@]}; do 
        printf "%3d%s) %s\n" $((i+1)) "${choices[i]:- }" "${options[i]}"
    done
    if [[ "$msg" ]]; then echo "$msg"; fi
}
options=( $(cat proxmox_setup_sharedfolderlist-xtra | awk '{ print $1 }' | sed -e 's/^/"/g' -e 's/$/"/g' | tr '\n' ' ' | sed -e 's/^\|$//g' | sed 's/\s*$//') )
prompt="Check an option (again to uncheck, ENTER when done): "
while menu && read -rp "$prompt" num && [[ "$num" ]]; do
    [[ "$num" != *[![:digit:]]* ]] &&
    (( num > 0 && num <= ${#options[@]} )) ||
    { msg="Invalid option: $num"; continue; }
    ((num--)); msg="${options[num]} was ${choices[num]:+un}checked"
    [[ "${choices[num]}" ]] && choices[num]="" || choices[num]="+"
done
fi
printf "You selected"; msg=" nothing"
for i in ${!options[@]}; do 
	[[ "${choices[i]}" ]] && { printf " %s" "${options[i]}"; msg=""; } && echo $({ printf " %s" "${options[i]}"; msg=""; }) | sed 's/\"//g' >> nfs_xtra_choices
done
echo "$msg"

# Create Input lists to create NFS Exports
grep -v -Ff nfs_xtra_choices proxmox_setup_sharedfolderlist-xtra > rejected_folders-default_dir # rejected NFS choice folders
grep -Ff nfs_xtra_choices proxmox_setup_sharedfolderlist | sed '/medialab/!d' >> rejected_folders-default_dir # rejected NFS choice folders including any new custom medialab folders

grep -Ff nfs_xtra_choices proxmox_setup_sharedfolderlist | sed '/medialab/!d' > included_folders-media_dir # included new custom medialab NFS choice folders

# Create Default NFS exports
grep -vxFf rejected_folders-all proxmox_setup_sharedfolderlist | sed '/backup/d;/git/d;/homes/d;/openvpn/d;/sshkey/d' | sed '/music/d;/photo/d;/video/d' | awk '{ print $1 }' > proxmox_setup_sharedfolderlist-nfs_default_dir
schemaExtractDir="/srv/$HOSTNAME"
while read dir; do
  dir01="$schemaExtractDir/$dir"
  if [ -d "$dir01" ]; then
	eval "cat <<-EOF >> exports

	# $dir export
	/srv/$HOSTNAME/$dir 192.168.1.101(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100) 192.168.1.102(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100) 192.168.1.103(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100) 192.168.1.104(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100)
	EOF"
  else
	info "${dir01} does not exist: skipping..."
	echo
  fi
done < proxmox_setup_sharedfolderlist-nfs_default_dir # file listing of folders to create
# Create Media NFS exports
cat proxmox_setup_sharedfolderlist | grep -i 'music\|photo\|\video' | sed '$r included_folders-media_dir' | awk '{ print $1 }' > proxmox_setup_sharedfolderlist-nfs_media_dir 
schemaExtractDir="/srv/$HOSTNAME"
while read dir; do
  dir01="$schemaExtractDir/$dir"
  if [ -d "$dir01" ]; then
	eval "cat <<-EOF >> exports

	# $dir export
	/srv/$HOSTNAME/$dir 192.168.1.101(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100) 192.168.1.102(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100) 192.168.1.103(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100) 192.168.1.104(rw,async,no_wdelay,no_root_squash,insecure_locks,sec=sys,anonuid=1025,anongid=100) 192.168.50.0/24(rw,async,no_wdelay,crossmnt,insecure,all_squash,insecure_locks,sec=sys,anonuid=1024,anongid=100)
	EOF"
  else
	info "${dir01} does not exist: skipping..."
	echo
  fi
done < proxmox_setup_sharedfolderlist-nfs_media_dir # file listing of folders to create


# NFS Server Restart
msg "Restarting NFS Server..."
service nfs-kernel-server restart
if [ "$(systemctl is-active --quiet nfs-kernel-server; echo $?) -eq 0" ]; then
	info "NFS is active (running)."
	echo
elif [ "$(systemctl is-active --quiet nfs-kernel-server; echo $?) -eq 3" ]; then
	warn "NFS is inactive (dead). Your intervention is required."
	echo
fi


#### Install and Configure Webmin ####
section "Installing and configuring Webmin."


# Install Webmin Prerequisites
msg "Installing Webmin prerequisites..."
apt-get install -y gnupg2 >/dev/null
bash -c 'echo "deb http://download.webmin.com/download/repository sarge contrib" >> /etc/apt/sources.list' >/dev/null
wget -qL http://www.webmin.com/jcameron-key.asc
apt-key add jcameron-key.asc
apt-get update >/dev/null

# Install Webmin
msg "Installing Webmin..."
apt-get install -y webmin >/dev/null
if [ "$(systemctl is-active --quiet webmin; echo $?) -eq 0" ]; then
	info "Webmin is active (running)..."
	echo
elif [ "$(systemctl is-active --quiet webmin; echo $?) -eq 3" ]; then
	warn "Webmin is inactive (dead). Your intervention is required..."
	echo
fi
