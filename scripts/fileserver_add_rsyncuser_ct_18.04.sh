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


# Set Temp Folder
if [ -z "${TEMP_DIR+x}" ]; then
  TEMP_DIR=$(mktemp -d)
  pushd $TEMP_DIR >/dev/null
else
  if [ $(pwd -P) != $TEMP_DIR ]; then
    cd $TEMP_DIR >/dev/null
  fi
fi


# Download external scripts
if [ ! -f $TEMP_DIR/fileserver_base_folder_setup ];then
  wget -qL https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/fileserver_base_folder_setup
fi
if [ ! -f $TEMP_DIR/fileserver_base_subfolder_setup ];then
  wget -qL https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/fileserver_base_subfolder_setup
fi


# Command to run script
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/fileserver_add_rsyncuser_ct_18.04.sh)"


# Setting Variables
CHROOT="/srv/$HOSTNAME/homes/chrootjail"
HOME_BASE="$CHROOT/homes/"
USER="kodi_rsync"
GROUP="chrootjail"


#### Creating File Server Jailed Users ####
if [ -z "${NEW_KODI_RSYNC_USER+x}" ] && [ -z "${PARENT_EXEC_NEW_KODI_RSYNC_USER+x}" ]; then
  section "File Server - Create Kodi_Rsync user account"
  echo
  box_out '#### PLEASE READ CAREFULLY - KODI_RSYNC USER ####' '' '"kodi_rsync" is a special user created for synchronising a portable or remote' 'media player with your File Server media library. Connection is by rssh rsync.' 'Its ideal for travellers or persons going away to a remote location with poor' 'or no internet access.' '' 'Our rsync script will securely connect to your File Server and;' '' '  --  rsync mirror your selected media library to your kodi player USB disk.' '  --  copy your latest media only to your kodi player USB disk.' '  --  remove the oldest media to fit newer media.' '  --  fill your USB disk to a limit set by you.' '' 'This is ideally suited for holiday homes, yachts or people on the move.' '' 'The first step involves creating a new user called "kodi_rsync" on your File Server' 'which has limited and restricted permissions granting rsync read access only' 'to your media libraries.' 'The second step, performed at a later stage, is setting up a CoreElec or' 'LibreElec player hardware with a USB hard disk and installing our' 'rsync scripts along with your File Server user "kodi_rsync" private ssh rsa key.'
  echo
  read -p "Create the user kodi_rsync on your File Server (NAS) [y/n]? " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    NEW_KODI_RSYNC_USER=0 >/dev/null
  else
    NEW_KODI_RSYNC_USER=1 >/dev/null
    info "You have chosen to skip this step."
    exit 0
  fi
fi


#### Checking Prerequisites ####
section "File Server CT - Checking Prerequisites."
# Checking SSHD status
msg "Checking SSHD status ..."
if [ "$(systemctl is-active --quiet sshd; echo $?) -eq 0" ]; then
  info "SSHD status: ${GREEN}active${NC}."
  SSHD_STATUS=0
  PRE_CHECK_01=0
else
  info "SSHD status: ${RED}inactive (dead).${NC}. Your intervention is required."
  SSHD_STATUS=1
  PRE_CHECK_01=1
fi
echo
# Checking for Chrootjail group
msg "Checking chrootjail group status..."
if [ "$(getent group chrootjail >/dev/null; echo $?) -ne 0" ]; then
  info "chrootjail status: ${GREEN}active${NC}."
  PRE_CHECK_02=0
else
  info "chrootjail status: ${RED}inactive - non existant${NC}."
  PRE_CHECK_02=1
fi
echo
# Checking for Chroot rsync
msg "Checking for chroot rsync component..."
if [ -f $CHROOT/usr/bin/rsync ]; then
  info "chrootjail rsync component: ${GREEN}active${NC}."
  PRE_CHECK_03=0
else
  info "chrootjail rsync component: ${RED}inactive - non existant${NC}.\nusr/bin/rsync is missing."
  PRE_CHECK_03=1
fi
echo
# Checking and Editing SSH server
msg "Checking and editing SSH server configuration file..."
if [ "$(systemctl is-active --quiet sshd; echo $?) -eq 0" ]; then
  sudo systemctl stop ssh 2>/dev/null
  sudo sed -i 's|#PubkeyAuthentication yes|PubkeyAuthentication yes|g' /etc/ssh/sshd_config
  sudo sed -i 's|#AuthorizedKeysFile.*|AuthorizedKeysFile     .ssh/authorized_keys|g' /etc/ssh/sshd_config
  sudo systemctl restart ssh.service 2>/dev/null
else
  sudo sed -i 's|#PubkeyAuthentication yes|PubkeyAuthentication yes|g' /etc/ssh/sshd_config
  sudo sed -i 's|#AuthorizedKeysFile.*|AuthorizedKeysFile     .ssh/authorized_keys|g' /etc/ssh/sshd_config
fi
info "SSH server options:\n  --  Public Key Authentication: ${GREEN}enabled.${NC}\n  --  Authorised Keys File:  ${GREEN}enabled.${NC}"
echo

# Check Results
msg "Prerequisites check status..."
if [ $PRE_CHECK_01 = 0 ] && [ $PRE_CHECK_02 = 0 ] && [ $PRE_CHECK_03 = 0 ]; then
  PRE_CHECK_INSTALL=1
  info "Prerequisite check status: ${GREEN}GOOD TO GO${NC}."
elif [ $PRE_CHECK_01 = 1 ] && [ $PRE_CHECK_02 = 0 ] && [ $PRE_CHECK_03 = 0 ]; then
  PRE_CHECK_INSTALL=0
  warn "User intervention required.\nYou can enable SSHD in the next steps.\n Proceeding with installation."
elif [ $PRE_CHECK_01 = 1 ] || [ $PRE_CHECK_01 = 0 ] && [ $PRE_CHECK_02 = 1 ] && [ $PRE_CHECK_03 = 0 ] || [ $PRE_CHECK_03 = 1 ]; then
  PRE_CHECK_INSTALL=1
  warn "User intervention required. Missing chrootjail user group.\nExiting installation script in 3 second."
  sleep 3
  exit 0
elif [ $PRE_CHECK_01 = 1 ] || [ $PRE_CHECK_01 = 0 ] && [ $PRE_CHECK_02 = 0 ] || [ $PRE_CHECK_02 = 1 ] && [ $PRE_CHECK_03 = 1 ]; then
  PRE_CHECK_INSTALL=1
  warn "User intervention required. Missing chroot components:\n  --  chroot rsync components.\nExiting installation script in 3 second."
  sleep 3
  exit 0
fi
echo


#### Installing Prerequisites ####
if [ $PRE_CHECK_INSTALL = 0 ]; then
  section "File Server CT - Installing Prerequisites."
  #### Configure SSH Server ####
  if [ $SSHD_STATUS = 1 ] && [ $PRE_CHECK_01 = 1 ]; then
    box_out '#### PLEASE READ CAREFULLY - ENABLE SSH SERVER ####' '' 'If you want to use kodi_rsync to connect to your File Server then' 'your SSH Server must be enabled. We also recommend you change the' 'default SSH port 22 for added security.'
    echo
    read -p "Enable SSH Server on your File Server (NAS) [y/n]? " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      SSHD_STATUS=0
      read -p "Confirm SSH Port number: " -e -i 22 SSH_PORT
      info "SSH Port is set: ${YELLOW}Port $SSH_PORT${NC}."
      sudo systemctl stop ssh 2>/dev/null
      sudo sed -i "s|#Port.*|Port $SSH_PORT|g" /etc/ssh/sshd_config
      sudo ufw allow ssh 2>/dev/null
      sudo systemctl restart ssh 2>/dev/null
      msg "Enabling SSHD server..."
      systemctl is-active sshd >/dev/null 2>&1 && info "OpenBSD Secure Shell server: ${GREEN}active (running).${NC}" || info "OpenBSD Secure Shell server: ${RED}inactive (dead).${NC}"
      echo
    else
      sudo systemctl stop ssh 2>/dev/null
      sudo systemctl disable ssh 2>/dev/null
      SSHD_STATUS=1
      msg "Disabling SSHD server..."
      systemctl is-active sshd >/dev/null 2>&1 && info "OpenBSD Secure Shell server: ${GREEN}active (running).${NC}" || info "OpenBSD Secure Shell server: ${RED}inactive (dead).${NC}"
      warn "You have chosen to disable SSH server. Cannot install kodi_rsync.\nExiting installation script in 3 second."
      sleep 3
      exit 0
    fi
  fi
fi
echo


#### Modify existing kodi_rsync user #####
if [ $(egrep "^${USER}" /etc/passwd > /dev/null; echo $?) -eq 0 ]; then
  section "File Server CT - Modify existing kodi_rsync user."
  msg "Checking for existing kodi_rsync..."
  info "kodi_sync user status: ${RED}active - old user exists${NC}."
  echo
  box_out '#### PLEASE READ CAREFULLY - DELETING OLD KODI_RSYNC USER ####' '' '"kodi_rsync" already exists. In the next step your choices are:' '' '  --  Delete old user "kodi_rsync" (Recommended - easy upgrade).' '      Your old SSH keys will be automatically backed up and you have the' '      option to re-use these same SSH keys with your newly created' '      "kodi_rsync" user.' '  --  Abort the script by typing "n".'
  echo
  read -p "Delete your existing kodi_rsync user (recommended) [y/n]? " -n 1 -r
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -f ${HOME_BASE}${USER}/.ssh/id_rsa* ]; then
      msg "Backing up your old user ${USER} SSH keys..."
      sudo mkdir -p /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)_old
      sudo chown -R root:privatelab /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)_old
      sudo chmod 0750 /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)_old
      sudo cp ${HOME_BASE}${USER}/.ssh/id_rsa* /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)_old/ 2>/dev/null
      info "Old ${USER} SSH keys backup complete."
    fi
    # Umount kodi_rsync bind mounts
    msg "Umount kodi_rsync bind mounts..."
    grep "/srv/$HOSTNAME/homes/chrootjail/kodi_rsync/share" /etc/fstab | awk '{print $2}' > kodi_rsync_umountlist
    echo
    while read dir; do
      if mount | grep $dir > /dev/null; then
        msg "Umounting bind mount: ${WHITE}$dir${NC}"
        sudo umount $dir 2>/dev/null
        info "Bind mount status: ${YELLOW}Disabled.${NC}"
      else
        msg "Umounting bind mount: ${WHITE}$dir${NC}"
        info "Bind mount status: ${YELLOW}Already Disabled.${NC}"
      fi
    done < kodi_rsync_umountlist # listing of bind mounts
    # Deleting old user
    msg "Deleting old user ${USER}..."
    sudo userdel -r ${USER} 2>/dev/null
    info "{$USER} has been deleted."
    msg "Deleting & cleaning old ${USER} home folder..."
    sudo rm -R ${HOME_BASE}${USER} 2>/dev/null
    info "Old ${USER} home folder deleted."
  else
    warn "You have chosen not to delete user kodi_rsync.\nCannot proceed. Nothing to do.\nExiting installation script in 3 second."
    sleep 3
    exit 0    
  fi
fi


#### Create & Setup kodi_rsync user #####
section "File Server CT - Create a new kodi_rsync user."
if [ $(id -u) -eq 0 ] && [ $NEW_KODI_RSYNC_USER = 0 ] && [ $SSHD_STATUS = 0 ]; then
  msg "Creating new user ${USER}..."
  useradd -g ${GROUP} -m -d ${HOME_BASE}${USER} -s /bin/bash ${USER}
  msg "Fixing ${USER} home folder location to ${GROUP} setup..."
  awk -v user="${USER}" -v path="/homes/${USER}" 'BEGIN{FS=OFS=":"}$1==user{$6=path}1' /etc/passwd > temp_file
  mv temp_file /etc/passwd
  msg "Copy ${USER} password to chrooted /etc/passwd..."
  cat /etc/passwd | grep ${USER} >> $CHROOT/etc/passwd
  msg "Creating authorised keys folders and settings for user ${USER}..."
  sudo mkdir -p ${HOME_BASE}${USER}/.ssh
  sudo touch ${HOME_BASE}${USER}/.ssh/authorized_keys
  sudo chmod -R 0700 ${HOME_BASE}${USER}
  info "User created: ${YELLOW}${USER}${NC} of group ${GROUP}"
  echo
  if [ -f /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)_old/id_rsa.pub ] && [ -f /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)_old/id_rsa ];then
    msg "A old set of your ${USER} SSH keys exists..."
    read -p "Re-add your old ${USER} SSH keys to your newly created ${USER} (Recommended) [y/n]? " -n 1 -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      msg "Adding your old SSH keys to your new ${USER}..."
      cat /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)_old/id_rsa.pub >> ${HOME_BASE}${USER}/.ssh/authorized_keys
      cp /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)_old/* ${HOME_BASE}${USER}/.ssh/ 2>/dev/null
      msg "Backing up your latest (old) ${USER} SSH keys..."
      sudo mkdir -p /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)
      sudo chown -R root:privatelab /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)
      sudo chmod 0750 /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)
      sudo cp ${HOME_BASE}${USER}/.ssh/id_rsa* /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)/
      sudo chown -R ${USER}:${GROUP} ${HOME_BASE}${USER}
      rm -R /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)_old 2>/dev/null
      info "User ${USER} SSH keys have been added to the system.\nA backup of your ${USER} SSH keys is stored in your sshkey folder." || warn "Failed adding user ${USER} SSH keys!"
    else
      info "You have chosen not to add your old ${USER} SSH keys.\nNew SSH keys will be generated for ${USER}."
      echo
    fi
  else
    msg "Creating new SSH keys for user ${USER}..." 
    sudo ssh-keygen -q -t rsa -b 4096 -f ${HOME_BASE}${USER}/.ssh/id_rsa -N ""
    cat ${HOME_BASE}${USER}/.ssh/id_rsa.pub >> ${HOME_BASE}${USER}/.ssh/authorized_keys
    msg "Backing up your latest ${USER} SSH keys..."
    sudo mkdir -p /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)
    sudo chown -R root:privatelab /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)
    sudo chmod 0750 /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)
    sudo cp ${HOME_BASE}${USER}/.ssh/id_rsa* /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)/
    sudo chown -R ${USER}:${GROUP} ${HOME_BASE}${USER}
    info "User ${USER} SSH keys have been added to the system.\nA backup of your ${USER} SSH keys is stored in your sshkey folder." || warn "Failed adding user ${USER} SSH keys!"
    echo
  fi
fi


#### Setting Access Permissions ####
section "File Server CT - Access Permissions."

if [ $NEW_KODI_RSYNC_USER = 0 ] && [ $SSHD_STATUS = 0 ]; then
  ls /srv/$HOSTNAME | grep -i '^[a-z]*$' | sed '/homes/d;/photo/d;/video/d;/music/d' | sed 's/^/\/srv\/'$HOSTNAME'\//' > kodi_rsync_acl_blocklist_input
  msg " Setting ACL restrictions for ${USER} to block..."
  while read -r dir; do
    setfacl -m u:kodi_rsync:000 "${dir}" >/dev/null
    info "ACL permissions set to blocked: ${WHITE}"${dir}"${NC}."
  done < kodi_rsync_acl_blocklist_input
  echo
fi

if [ $NEW_KODI_RSYNC_USER = 0 ] && [ $SSHD_STATUS = 0 ]; then
  cat fileserver_base_folder_setup | sed '/^#/d' | sed '/^$/d' | cut -d' ' -f1,4- | sed -n '/chrootjail:rwx/p' | sed 's/^/\/srv\/'$HOSTNAME'\//' | cut -d' ' -f1 >/dev/null > kodi_rsync_acl_rx_restriction_input
  echo -e "$(eval "echo -e \"`<fileserver_base_subfolder_setup`\"")" | sed '/^#/d' | sed '/^$/d' | cut -d' ' -f1,4- | sed -n '/chrootjail:rwx/p' | cut -d' ' -f1 >/dev/null >> kodi_rsync_acl_rx_restriction_input
  msg " Setting ACL permissions for ${USER} to rx..."
  while read -r dir; do
    setfacl -m u:kodi_rsync:rx "${dir}" >/dev/null
    info "ACL permissions set to rx: ${WHITE}"${dir}"${NC}."
  done < kodi_rsync_acl_rx_restriction_input
  echo
fi


#### Creating Bind Mounts ####
section "File Server CT - Creating Bind Mounts."

box_out '#### PLEASE READ CAREFULLY - PRIVATE MEDIA LIBRARIES ####' '' 'File Server user accounts have the option of sharing their personal photo' 'and home video media with other users. "kodi_rsync" can read' 'and rsync this media too if you want.' '' '  --  /srv/"hostname"/photo/"user_photo"' '  --  /srv/"hostname"/video/homevideo/"user_homevideo"' '' 'If you DO NOT want "kodi_rsync" to read and rsync these folders type "n" in' 'the next step.'
echo
read -p "Grant kodi_rsync access to your personal photos and videos [y/n]? " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  PRIVATE_LIBRARY=0
  setfacl -x u:${USER} /srv/$HOSTNAME/photo
  setfacl -x u:${USER} /srv/$HOSTNAME/video/homevideo
  info "Private media library rsync status: ${YELLOW}Access Granted.${NC}."
else
  PRIVATE_LIBRARY=1
  setfacl -Rm u:${USER}:000 /srv/$HOSTNAME/photo
  setfacl -Rm u:${USER}:000 /srv/$HOSTNAME/video/homevideo
  info "Private media library rsync status: ${YELLOW}Access Denied.${NC}."
fi
echo

box_out '#### PLEASE READ CAREFULLY - PRON MEDIA ####' '' '"kodi_rsync" can read and rsync your pron media library if you want.' '' '  --  /srv/"hostname"/video/"pron"' '' 'But if you DO NOT want "kodi_rsync" to read and rsync your pron media' 'type "n" in the next step to block "kodi_rsync" access.'
echo
read -p "Grant kodi_rsync access to pron media [y/n]? " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  PRON_LIBRARY=0
  setfacl -x u:${USER} /srv/$HOSTNAME/video/pron
  info "Pron media library rsync status: ${YELLOW}Access Granted.${NC}."
else
  PRON_LIBRARY=1
  setfacl -Rm u:${USER}:000 /srv/$HOSTNAME/video/pron
  info "Pron media library rsync status: ${YELLOW}Access Denied.${NC}."
fi
echo


# Create default home folders
msg "Creating ${USER} default home folders..."
sudo mkdir -p ${HOME_BASE}${USER}/{music,video}
if [ $PRIVATE_LIBRARY = 0 ]; then
  sudo mkdir -p ${HOME_BASE}${USER}/photo
fi
sudo chown -R ${USER}:${GROUP} ${HOME_BASE}${USER}
sudo chmod -R 0700 ${HOME_BASE}${USER}
info "${USER} default home folders: ${YELLOW}Success.${NC}"
echo

# Create shared music bind mount
if [ -d /srv/$HOSTNAME/music ] && [ $(grep -qs ${HOME_BASE}${USER}/music /proc/mounts > /dev/null; echo $?) = 1 ]; then
  msg "Creating /srv/$HOSTNAME/music bind mount..."
  echo "/srv/$HOSTNAME/music ${HOME_BASE}${USER}/music none bind,ro,xattr,acl 0 0" >> /etc/fstab
  mount ${HOME_BASE}${USER}/music
  info "Bind mount status: ${YELLOW}Success.${NC}"
  echo
elif [ -d /srv/$HOSTNAME/music ] && [ $(grep -qs ${HOME_BASE}${USER}/music /proc/mounts > /dev/null; echo $?) = 0 ]; then
  msg "Creating /srv/$HOSTNAME/music bind mount..."
  info "Bind mount status: ${YELLOW}Success. Previous mount exists.${NC}\nUsing existing mount."
  echo
elif [ ! -d /srv/$HOSTNAME/music ] && [ $(grep -qs ${HOME_BASE}${USER}/music /proc/mounts > /dev/null; echo $?) = 1 ]; then
  msg "Creating /srv/$HOSTNAME/music bind mount..."
  warn "Bind mount status: ${RED}Failed.${NC}\n Mount point /srv/$HOSTNAME/music does not exist.\nSkipping this mount point."
  echo
fi

# Create shared photo bind mount
if [ -d /srv/$HOSTNAME/photo ] && [ $PRIVATE_LIBRARY = 0 ] && [ $(grep -qs ${HOME_BASE}${USER}/photo /proc/mounts > /dev/null; echo $?) = 1 ]; then
  msg "Creating /srv/$HOSTNAME/photo bind mount..."
  echo "/srv/$HOSTNAME/photo ${HOME_BASE}${USER}/photo none bind,rw,xattr,acl 0 0" >> /etc/fstab
  mount ${HOME_BASE}${USER}/photo
  info "Bind mount status: ${YELLOW}Success.${NC}"
  echo
elif [ -d /srv/$HOSTNAME/photo ] && [ $PRIVATE_LIBRARY = 0 ] && [ $(grep -qs ${HOME_BASE}${USER}/photo /proc/mounts > /dev/null; echo $?) = 0 ]; then
  msg "Creating /srv/$HOSTNAME/photo bind mount..."
  info "Bind mount status: ${YELLOW}Success. Previous mount exists.${NC}\nUsing existing mount."
  echo
elif [ ! -d /srv/$HOSTNAME/photo ] && [ $PRIVATE_LIBRARY = 0 ] && [ $(grep -qs ${HOME_BASE}${USER}/photo /proc/mounts > /dev/null; echo $?) = 1 ]; then
  msg "Creating /srv/$HOSTNAME/photo bind mount..."
  warn "Bind mount status: ${RED}Failed.${NC}\n Mount point /srv/$HOSTNAME/photo does not exist.\nSkipping this mount point."
  echo
fi
 
# Create shared video bind mount
if [ -d /srv/$HOSTNAME/video ] && [ $(grep -qs ${HOME_BASE}${USER}/video /proc/mounts > /dev/null; echo $?) = 1 ]; then
  msg "Creating /srv/$HOSTNAME/video bind mount..."
  echo "/srv/$HOSTNAME/video ${HOME_BASE}${USER}/video none bind,rw,xattr,acl 0 0" >> /etc/fstab
  mount ${HOME_BASE}${USER}/video
  info "Bind mount status: ${YELLOW}Success.${NC}"
  echo
elif [ -d /srv/$HOSTNAME/video ] && [ $(grep -qs ${HOME_BASE}${USER}/video /proc/mounts > /dev/null; echo $?) = 0 ]; then
  msg "Creating /srv/$HOSTNAME/video bind mount..."
  info "Bind mount status: ${YELLOW}Success. Previous mount exists.${NC}\nUsing existing mount."
  echo
elif [ ! -d /srv/$HOSTNAME/video ] && [ $(grep -qs ${HOME_BASE}${USER}/video /proc/mounts > /dev/null; echo $?) = 1 ]; then
  msg "Creating /srv/$HOSTNAME/video bind mount..."
  warn "Bind mount status: ${RED}Failed.${NC}\nMount point /srv/$HOSTNAME/video does not exist.\nSkipping this mount point."
  echo
fi
echo
   
   
#### Finish ####
section "File Server CT - Completion Status."

echo
msg "${WHITE}Success.${NC}"
sleep 3

# Cleanup
if [ -z ${PARENT_EXEC_NEW_KODI_RSYNC_USER+x} ]; then
  cleanup
fi
