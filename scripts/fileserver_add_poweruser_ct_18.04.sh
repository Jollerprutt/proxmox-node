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
function warn() {
  local REASON="\e[97m$1\e[39m"
  local FLAG="\e[93m[WARNING]\e[39m"
  msg "$FLAG $REASON"
}
function section() {
  local REASON="  \e[97m$1\e[37m"
  printf -- '-%.0s' {1..100}; echo ""
  msg "$REASON"
  printf -- '-%.0s' {1..100}; echo ""
  echo
}
function cleanup() {
  popd >/dev/null
  rm -rf $TEMP_DIR
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

# Command to run script
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/fileserver_add_poweruser_ct_18.04.sh)"


#### Create New Power User Accounts ####
if [ -z "${NEW_POWER_USER+x}" ]; then
  section "File Server - Create New Power User Accounts"

  echo
  box_out '#### PLEASE READ CAREFULLY - CREATING POWER USER ACCOUNTS ####' '' 'Power Users are trusted persons with privileged access to data and application' 'resources hosted on your File Server. Power Users are NOT standard users!' 'Standard users are added at a later stage.' '' 'Each new Power Users security permissions are controlled by linux groups.' 'Group security permission levels are as follows:' '' '  --  GROUP NAME    -- PERMISSIONS' '  --  "medialab"    -- Everything to do with media (i.e movies, TV and music)' '  --  "homelab"     -- Everything to do with a smart home including "medialab"' '  --  "privatelab"  -- Private storage including "medialab" & "homelab" rights' '' 'A Personal Home Folder will be created for each new user. The folder name is' 'the users name. You can access Personal Home Folders and other shares' 'via CIFS/Samba and NFS.' '' 'Remember your File Server is also pre-configured with user names' 'specifically tasked for running hosted applications (i.e Proxmox LXC,CT,VM).' 'These application users names are as follows:' '' '  --  GROUP NAME    -- USER NAME' '  --  "medialab"    -- /srv/CT_HOSTNAME/homes/"media"' '  --  "homelab"     -- /srv/CT_HOSTNAME/homes/"storm"' '  --  "privatelab"  -- /srv/CT_HOSTNAME/homes/"typhoon"'
  echo
  read -p "Create new power user accounts on your File Server (NAS) [y/n]? " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    NEW_POWER_USER=0 >/dev/null
    TEMP_DIR=$(mktemp -d)
    pushd $TEMP_DIR >/dev/null
  else
    NEW_POWER_USER=1 >/dev/null
    info "You have chosen to skip this step."
    exit 0
  fi
  echo
fi
while [[ "$REPLY" != "no" ]] && [ "$NEW_POWER_USER" = 0 ]; do
  read -p "Enter new username you want to create : " username
  echo
  msg "Choose your new user's group permissions."
  GRP01="Medialab - Everything to do with media (i.e movies, TV and music)." >/dev/null
  GRP02="Homelab - Everything to do with a smart home including medialab." >/dev/null
  GRP03="Privatelab - Private storage including medialab & homelab rights." >/dev/null
  PS3="Select your new users group permission rights level (entering numeric) : "
  echo
  select grp_type in "$GRP01" "$GRP02" "$GRP03"
  do
  echo
  info "You have selected: $grp_type"
  echo
  break
  done
  if [ "$grp_type" = "$GRP01" ]; then
    usergrp="medialab"
  elif [ "$grp_type" = "$GRP02" ]; then
    usergrp="homelab -G medialab"
  elif [ "$grp_type" = "$GRP03" ]; then
    usergrp="privatelab -G medialab,homelab"
  fi
  while true; do
    read -s -p "Enter Password: " password
    echo
    read -s -p "Enter Password (again): " password2
    echo
    [ "$password" = "$password2" ] && echo "$username $password $usergrp" >> usersfile.txt && break
    warn "Passwords do not match. Please try again."
  done
  echo
    read -p "Do you want to create another new user account [yes/no]?"
done
if [ $(id -u) -eq 0 ] && [ "$NEW_POWER_USER" = 0 ]; then
  NEW_USERS=usersfile.txt
  HOME_BASE="/srv/$HOSTNAME/homes/"
  cat ${NEW_USERS} | while read USER PASSWORD GROUP USERMOD
  do
  pass=$(perl -e 'print crypt($ARGV[0], 'password')' $PASSWORD)
  if [ $(egrep "^$USER[0]" /etc/passwd > /dev/null; echo $?) = 0 ]; then USER_EXISTS=0; else USER_EXISTS=1; fi
  if [ -d "${HOME_BASE}${USER}" ]; then USER_DIR_EXISTS=0; else USER_DIR_EXISTS=1; fi
  if [ $USER_EXISTS = 0 ]; then
    warn "User $USER exists!"
    echo
    exit 1
  elif [ $USER_EXISTS = 1 ] && [ $USER_DIR_EXISTS = 0 ]; then
    msg "Creating new user ${USER}..."
    useradd -g ${GROUP} -p ${pass} ${USERMOD} -m -d ${HOME_BASE}${USER} -s /bin/bash ${USER}
    msg "Creating SSH folder and authorised keys file for user ${USER}..."
    sudo mkdir -p /srv/$HOSTNAME/homes/${USER}/.ssh
    sudo touch /srv/$HOSTNAME/homes/${USER}/.ssh/authorized_keys
    sudo mkdir -p /srv/$HOSTNAME/homes/${USER}/.sftp
    sudo touch /srv/$HOSTNAME/homes/${USER}/.sftp/authorized_keys
    sudo chmod -R 0700 /srv/$HOSTNAME/homes/${USER}
    sudo chown -R ${USER}:${GROUP} /srv/$HOSTNAME/homes/${USER}
    sudo ssh-keygen -q -t rsa -b 4096 -f /srv/$HOSTNAME/homes/${USER}/.ssh/id_${USER,,}_rsa -N ""
    cat /srv/$HOSTNAME/homes/${USER}/.ssh/id_${USER,,}_rsa.pub >> /srv/$HOSTNAME/homes/${USER}/.ssh/authorized_keys
    # Create sftp public keygen
    msg "Adding your new ${USER} SSH keys to SSH sftp authorized_keys file..."
    ssh-keygen -e -f /srv/$HOSTNAME/homes/${USER}/.ssh/id_${USER,,}_rsa.pub > /srv/$HOSTNAME/homes/${USER}/.sftp/authorized_keys
    msg "Creating ${USER} smb account..."
    (echo ${PASSWORD}; echo ${PASSWORD} ) | smbpasswd -s -a ${USER}
    info "User $USER has been added to the system. Existing home folder found.\nUsing existing home folder."
    echo
  else
    msg "Creating new user ${USER}..."
    useradd -g ${GROUP} -p ${pass} ${USERMOD} -m -d ${HOME_BASE}${USER} -s /bin/bash ${USER}
    msg "Creating default home folders (xdg-user-dirs-update)..."
    sudo -iu ${USER} xdg-user-dirs-update
    msg "Creating SSH folder and authorised keys file for user ${USER}..."
    sudo mkdir -p /srv/$HOSTNAME/homes/${USER}/.ssh
    sudo touch /srv/$HOSTNAME/homes/${USER}/.ssh/authorized_keys
    sudo mkdir -p /srv/$HOSTNAME/homes/${USER}/.sftp
    sudo touch /srv/$HOSTNAME/homes/${USER}/.sftp/authorized_keys
    sudo chmod -R 0700 /srv/$HOSTNAME/homes/${USER}
    sudo chown -R ${USER}:${GROUP} /srv/$HOSTNAME/homes/${USER}
    sudo ssh-keygen -q -t rsa -b 4096 -f /srv/$HOSTNAME/homes/${USER}/.ssh/id_${USER,,}_rsa -N ""
    cat /srv/$HOSTNAME/homes/${USER}/.ssh/id_${USER,,}_rsa.pub >> /srv/$HOSTNAME/homes/${USER}/.ssh/authorized_keys
    # Create sftp public keygen
    msg "Adding your new ${USER} SSH keys to SSH sftp authorized_keys file..."
    ssh-keygen -e -f /srv/$HOSTNAME/homes/${USER}/.ssh/id_${USER,,}_rsa.pub > /srv/$HOSTNAME/homes/${USER}/.sftp/authorized_keys
    msg "Creating ${USER} smb account..."
    (echo ${PASSWORD}; echo ${PASSWORD} ) | smbpasswd -s -a ${USER}
    [ $USER_EXISTS = 1 ] && info "User $USER has been added to the system." || warn "Failed adding user $USER!"
    echo
  fi
  done
fi

