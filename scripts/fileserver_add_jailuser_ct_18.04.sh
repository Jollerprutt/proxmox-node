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
if [ -z ${TEMP_DIR+x} ]; then
  TEMP_DIR=$(mktemp -d)
  pushd $TEMP_DIR >/dev/null
else
  if [ $(pwd -P) != $TEMP_DIR ]; then
    cd $TEMP_DIR >/dev/null
  fi
fi

# Download external scripts

# Command to run script
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/fileserver_add_jailuser_ct_18.04.sh)"


# Setting Variables
CHROOT="/srv/$HOSTNAME/homes/chrootjail"
HOME_BASE="$CHROOT/homes/"
GROUP="chrootjail"


#### Creating File Server Jailed Users ####
if [ -z ${NEW_JAIL_USER+x} ] && [ -z ${PARENT_EXEC_NEW_JAIL_USER+x} ]; then
  section "File Server - Create Restricted and Jailed User Accounts"
  echo
box_out '#### PLEASE READ CAREFULLY - RESTRICTED & JAILED USER ACCOUNTS ####' '' 'Every new user is restricted or jailed within their own home folder. In Linux' 'this is called a chroot jail. But you can select the level of restrictions which' 'are applied to each newly created user. This technique can be quite useful if' 'you want a particular user to be provided with a limited system environment,' 'limited folder access and at the same time keep them separate from your' 'main server system and other personal data.' '' 'The chroot technique will automatically jail selected users belonging' 'to the "chrootjail" user group upon ssh or ftp login.' '' 'An example of a jailed user is a person who has remote access to your' 'File Server but is restricted to your video library (TV, movies, documentary),' 'public folders and their home folder for cloud storage only.' 'Remote access to your File Server is restricted to sftp, ssh and rsync' 'using private SSH RSA encrypted keys.' '' 'Default "chrootjail" group permission options are:' '' 
'  --  GROUP NAME     -- USER NAME' 
'      "chrootjail"   -- /srv/hostname/homes/chrootjail/"username_injail"' '' 
'Selectable jail folder permission levels for each new user:' '' 
'  --  LEVEL 1        -- FOLDER' 
'      -rwx------     -- /srv/hostname/homes/chrootjail/"username_injail"' 
'                     -- Bind Mounts - mounted at ~/public folder' 
'      -rwxrwxrw-     -- /srv/hostname/homes/chrootjail/"username_injail"/public' '' 
'  --  LEVEL 2        -- FOLDER' 
'      -rwx------     -- /srv/hostname/homes/chrootjail/"username_injail"' 
'                     -- Bind Mounts - mounted at ~/share folder' 
'      -rwxrwxrw-     -- /srv/hostname/downloads/user/"username_downloads"' 
'      -rwxrwxrw-     -- /srv/hostname/photo/"username_photo"' 
'      -rwxrwxrw-     -- /srv/hostname/public' 
'      -rwxrwxrw-     -- /srv/hostname/video/homevideo/"username_homevideo"' 
'      -rwxr-----     -- /srv/hostname/video/movies' 
'      -rwxr-----     -- /srv/hostname/video/tv' 
'      -rwxr-----     -- /srv/hostname/video/documentary' '' 
'  --  LEVEL 3        -- FOLDER' 
'      -rwx------     -- /srv/"hostname"/homes/chrootjail/"username_injail"' 
'                     -- Bind Mounts - mounted at ~/share folder' 
'      -rwxr-----     -- /srv/hostname/audio' 
'      -rwxr-----     -- /srv/hostname/books' 
'      -rwxrwxrw-     -- /srv/hostname/downloads/user/"username_downloads"' 
'      -rwxr-----     -- /srv/hostname/music' 
'      -rwxrwxrw-     -- /srv/hostname/photo/"username_photo"' 
'      -rwxrwxrw-     -- /srv/hostname/public' 
'      -rwxrwxrw-     -- /srv/hostname/video/homevideo/"username_homevideo"' 
'      -rwxr-----     -- /srv/hostname/video (All)' '' 

'All Home folders are automatically suffixed: "username_injail".'
  echo
  read -p "Create restricted jailed user accounts on your File Server (NAS) [y/n]? " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    NEW_JAIL_USER=0 >/dev/null
  else
    NEW_JAIL_USER=1 >/dev/null
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
    box_out '#### PLEASE READ CAREFULLY - ENABLE SSH SERVER ####' '' 'If you want to use SSH (Rsync/SFTP) to connect to your File Server then' 'your SSH Server must be enabled. You need SSH to perform any' 'of the following tasks:' '' '  --  Secure SSH Connection to the File Server.' '  --  Perform a secure RSync Backup to the File Server.' '' 'We also recommend you change the default SSH port 22 for added security.' '' 'For added security we restrict all SSH, RSYNC and SFTP access for all' 'chrootjail users to their given home folder only.'
    echo
    read -p "Enable SSH Server on your File Server (NAS) [yes/no]?: " -r
    if [[ "$REPLY" == "y" || "$REPLY" == "Y" || "$REPLY" == "yes" || "$REPLY" == "Yes" ]]; then
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


#### Create & Setup new users #####
section "File Server CT - Create new users."
REPLY=yes
while [[ "$REPLY" != "no" ]] && [ "$NEW_JAIL_USER" = 0 ]; do
  while true; do
    read -p "Enter a new jailed username you want to create : " jail_username
    jail_username=${jail_username,,}_injail
    info "All jailed usernames are automatically suffixed: ${YELLOW}$jail_username${NC}"
    echo
    msg "Checking username availability..."
    [ "$(id -u $jail_username >/dev/null; echo $?)" -ne 0 ] && msg "Username status: ${YELLOW}Available${NC}." && break
    warn "$jail_username already exists. Please try again."
  done
  echo
  msg "Every new jailed user has a private Home folder and a optional level of access\nto other File Server shared folders. Choosing the level of shared folder access\ndepends restrictions you want to apply to the new user. Now select your new\njailed user level of access to shared folders level."
  LEVEL01="Home + Shared Public folder only." >/dev/null
  LEVEL02="Home + Shared Public, Photo, Video (Movies, TV, Documentary, Homevideo) folders." >/dev/null
  LEVEL03="Home + Shared Public, Photo, Video (all), Music, Audio & Books folders." >/dev/null
  PS3="Select your new users folder access rights (entering numeric) : "
  echo
  select level_type in "$LEVEL01" "$LEVEL02" "$LEVEL03"
  do
  echo
  info "You have selected: $level_type ..."
  echo
  break
  done
  if [ "$level_type" = "$LEVEL01" ]; then
    jail_type="level01"
  elif [ "$level_type" = "$LEVEL02" ]; then
    jail_type="level02"
  elif [ "$level_type" = "$LEVEL03" ]; then
    jail_type="level03"
  fi
  while true; do
    read -s -p "Enter Password: " jail_password
    echo
    read -s -p "Enter Password (again): " jail_password2
    echo
    [ "$jail_password" = "$jail_password2" ] && echo "$jail_username $jail_password $GROUP $jail_type" >> jailed_usersfile.txt && break
    warn "Passwords do not match. Please try again."
  done
  echo
    read -p "Do you want to create another new jailed user account (type yes/no)?"
done

if [ $(id -u) -eq 0 ] && [ $NEW_JAIL_USER = 0 ]; then
  NEW_USERS=jailed_usersfile.txt
  cat ${NEW_USERS} | while read USER PASSWORD GROUP JAIL_TYPE
  do
  pass=$(perl -e 'print crypt($ARGV[0], 'password')' $PASSWORD)
  # Check for Existing User name
  if [ $(egrep "^$USER[0]" /etc/passwd > /dev/null; echo $?) = 0 ]; then USER_EXISTS=0; else USER_EXISTS=1; fi
  # Check for Existing Home folder
  if [ -d "${HOME_BASE}${USER}" ]; then USER_DIR_EXISTS=0; else USER_DIR_EXISTS=1; fi

  #### Managing existing user SSH keys ####
  if [ $USER_EXISTS = 0 ]; then
    warn "User $USER exists!"
    echo
    exit 1
  elif [ $USER_EXISTS = 1 ] && [ $USER_DIR_EXISTS = 0 ] && [ -f ${HOME_BASE}${USER}/.ssh/id_${USER,,}_rsa*  ]; then
    box_out '#### PLEASE READ CAREFULLY - FOUND OLDER USER SSH KEYS ####' '' 'A old copy of the users SSH keys already exist. Your choices are:' '' '  --  Generate new SSH keys.' '  --  Re-use your old user SSH keys.' '' 'A copy of your old SSH keys is stored in your /srv/"hostname"/sshkey folder'.
    echo
    msg "Backing up your old user ${USER} SSH keys..."
    sudo mkdir -p /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)_old
    sudo chown -R root:privatelab /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)_old
    sudo chmod 0750 /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)_old
    sudo cp ${HOME_BASE}${USER}/.ssh/id_${USER,,}_rsa* /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)_old/ 2>/dev/null
    info "Old ${USER} SSH keys backup complete."
    echo
    msg "Deleting old ${USER} SSH folder..."
    sudo rm -R ${HOME_BASE}${USER}/.ssh 2>/dev/null
    info "Old ${USER} SSH folder deleted."
    echo
  fi


  #### Creating new user accounts ####
  msg "Creating new user ${USER}..."
  useradd -g ${GROUP} -p ${pass} -m -d ${HOME_BASE}${USER} -s /bin/bash ${USER}
  msg "Fixing ${USER} home folder location to ${GROUP} setup..."
  awk -v user="${USER}" -v path="/homes/${USER}" 'BEGIN{FS=OFS=":"}$1==user{$6=path}1' /etc/passwd > temp_file
  mv temp_file /etc/passwd
  msg "Copy ${USER} password to chrooted /etc/passwd..."
  cat /etc/passwd | grep ${USER} >> $CHROOT/etc/passwd
  msg "Creating SSH folder and authorised keys file for user ${USER}..."
  sudo mkdir -p ${HOME_BASE}${USER}/.ssh
  sudo touch ${HOME_BASE}${USER}/.ssh/authorized_keys
  sudo mkdir -p ${HOME_BASE}${USER}/.sftp
  sudo touch ${HOME_BASE}${USER}/.sftp/authorized_keys 
  sudo chmod -R 0700 ${HOME_BASE}${USER}
  info "User created: ${YELLOW}${USER}${NC} of group ${GROUP}"
  echo
  if [ -f /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)_old/id_${USER,,}_rsa.pub ] && [ -f /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)_old/id_${USER,,}_rsa ];then
    msg "A old copy of your ${USER} SSH keys exists..."
    read -p "Re-add your old ${USER} SSH keys to your newly created ${USER} (Recommended) [y/n]? " -n 1 -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      msg "Adding your old SSH keys to your new ${USER}..."
      cat /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)_old/id_${USER,,}_rsa.pub >> ${HOME_BASE}${USER}/.ssh/authorized_keys
      cp /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)_old/* ${HOME_BASE}${USER}/.ssh/ 2>/dev/null
      # Create sftp public keygen
      msg "Adding your old ${USER} SSH keys to SSH sftp authorized_keys file..."
      ssh-keygen -e -f /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)_old/id_${USER,,}_rsa.pub > ${HOME_BASE}${USER}/.sftp/authorized_keys
      msg "Backing up ${USER} latest SSH keys..."
      sudo mkdir -p /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)
      sudo chown -R root:privatelab /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)
      sudo chmod 0750 /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)
      sudo cp ${HOME_BASE}${USER}/.ssh/id_${USER,,}_rsa* /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)/
      sudo rm -R /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)_old 2>/dev/null
      info "User ${USER} SSH keys have been added to the system.\nA backup of ${USER} SSH keys is stored in your servers sshkey folder." || warn "Failed adding user ${USER} SSH keys!"
    else
      info "You have chosen not to add your old ${USER} SSH keys.\nNew SSH keys will be generated for ${USER}."
      echo
    fi
  else
    msg "Creating new SSH keys for user ${USER}..." 
    sudo ssh-keygen -q -t rsa -b 4096 -f ${HOME_BASE}${USER}/.ssh/id_${USER,,}_rsa -N ""
    cat ${HOME_BASE}${USER}/.ssh/id_${USER,,}_rsa.pub >> ${HOME_BASE}${USER}/.ssh/authorized_keys
    # Create sftp public keygen
    msg "Adding your new ${USER} SSH keys to SSH sftp authorized_keys file..."
    ssh-keygen -e -f ${HOME_BASE}${USER}/.ssh/id_${USER,,}_rsa.pub > ${HOME_BASE}${USER}/.sftp/authorized_keys
    msg "Backing up ${USER} latest SSH keys..."
    sudo mkdir -p /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)
    sudo chown -R root:privatelab /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)
    sudo chmod 0750 /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)
    sudo cp ${HOME_BASE}${USER}/.ssh/id_${USER,,}_rsa* /srv/$HOSTNAME/sshkey/${USER,,}_$(date +%Y%m%d)/
    sudo chown -R ${USER}:${GROUP} ${HOME_BASE}${USER}
    info "User ${USER} SSH keys have been added to the system.\nA backup of your ${USER} SSH keys is stored in your sshkey folder." || warn "Failed adding user ${USER} SSH keys!"
    echo
  fi

  #### Setting Bind Mounts ####
  section "File Server CT - Bind Mounts."
  msg "Creating ${USER} default home folders..."
  sudo mkdir -p ${HOME_BASE}${USER}/{backup,backup/{mobile,pc},documents,music,photo,video} 
  sudo chmod 0750 ${HOME_BASE}${USER}/{backup,backup/{mobile,pc},documents,music,photo,video}
  sudo chown -R ${USER}:${GROUP} ${HOME_BASE}${USER}
  info "${USER} default home folders: ${YELLOW}Success.${NC}"
  echo

  #Level 01 Bind mounts
  if [ ${JAIL_TYPE} = "level01" ]; then
    sudo mkdir -p ${HOME_BASE}${USER}/public
    sudo chmod 0750 ${HOME_BASE}${USER}/public
    sudo chown -R ${USER}:${GROUP} ${HOME_BASE}${USER}/public
    # Create shared public bind mount
    if [ -d /srv/$HOSTNAME/public ] && [ $(grep -qs ${HOME_BASE}${USER}/public /proc/mounts > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/public bind mount..."
      echo "/srv/$HOSTNAME/public ${HOME_BASE}${USER}/public none bind,rw,xattr,acl 0 0" >> /etc/fstab
      mount ${HOME_BASE}${USER}/public
      info "Bind mount status: ${YELLOW}Success.${NC}"
    elif [ -d /srv/$HOSTNAME/public ] && [ $(grep -qs ${HOME_BASE}${USER}/public /proc/mounts > /dev/null; echo $?) = 0 ]; then
      msg "Creating /srv/$HOSTNAME/public bind mount..."
      info "Bind mount status: ${YELLOW}Success. Previous mount exists.${NC}\nUsing existing mount."
    elif [ ! -d /srv/$HOSTNAME/public ] && [ $(grep -qs ${HOME_BASE}${USER}/public /proc/mounts > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/public bind mount..."
      warn "Bind mount status: ${RED}Failed.${NC}\n Mount point /srv/$HOSTNAME/public does not exist.\nSkipping this mount point."
    fi

  #Level 02 Bind mounts
  elif [ ${JAIL_TYPE} = "level02" ]; then
    msg "Creating ${USER} share mount point folders..."
    sudo mkdir -p ${HOME_BASE}${USER}/share
    sudo mkdir -p ${HOME_BASE}${USER}/share/{downloads,photo,public,video}
    sudo chown -R ${USER}:${GROUP} ${HOME_BASE}${USER}/share
    sudo chmod -R 0750 ${HOME_BASE}${USER}/share
    # Create shared downloads bind mount
    if [ -d /srv/$HOSTNAME/downloads ] && [ $(grep -qs ${HOME_BASE}${USER}/share/downloads/user/$(echo ${USER} | awk -F '_' '{print $1}')_downloads /proc/mounts > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/downloads bind mount..."
      sudo mkdir -p /srv/$HOSTNAME/downloads/{user,user/$(echo ${USER} | awk -F '_' '{print $1}')_downloads}
      sudo chown -R ${USER}:${GROUP} /srv/$HOSTNAME/downloads/user/$(echo ${USER} | awk -F '_' '{print $1}')_downloads
      sudo chmod 0750 /srv/$HOSTNAME/downloads/user/$(echo ${USER} | awk -F '_' '{print $1}')_downloads
      setfacl -Rm d:u:${USER}:rwx,g:${GROUP}:000,g:medialab:rwx,g:privatelab:rwx /srv/$HOSTNAME/downloads/user/$(echo ${USER} | awk -F '_' '{print $1}')_downloads
      echo "/srv/$HOSTNAME/downloads/user/$(echo ${USER} | awk -F '_' '{print $1}')_downloads ${HOME_BASE}${USER}/share/downloads none bind,rw,xattr,acl 0 0" >> /etc/fstab
      mount ${HOME_BASE}${USER}/share/downloads
      info "Bind mount status: ${YELLOW}Success.${NC}"
    elif [ -d /srv/$HOSTNAME/downloads ] && [ $(grep -qs ${HOME_BASE}${USER}/share/downloads/user/$(echo ${USER} | awk -F '_' '{print $1}')_downloads /proc/mounts > /dev/null; echo $?) = 0 ]; then
      msg "Creating /srv/$HOSTNAME/downloads bind mount..."
      info "Bind mount status: ${YELLOW}Success. Previous mount exists.${NC}\nUsing existing mount."
    elif [ ! -d /srv/$HOSTNAME/downloads ] && [ $(grep -qs ${HOME_BASE}${USER}/share/downloads/user/$(echo ${USER} | awk -F '_' '{print $1}')_downloads > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/downloads bind mount..."
      warn "Bind mount status: ${RED}Failed.${NC}\n Mount point /srv/$HOSTNAME/downloads does not exist.\nSkipping this mount point."
    fi
    # Create shared public bind mount
    if [ -d /srv/$HOSTNAME/public ] && [ $(grep -qs ${HOME_BASE}${USER}/share/public /proc/mounts > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/public bind mount..."
      echo "/srv/$HOSTNAME/public ${HOME_BASE}${USER}/share/public none bind,rw,xattr,acl 0 0" >> /etc/fstab
      mount ${HOME_BASE}${USER}/share/public
      info "Bind mount status: ${YELLOW}Success.${NC}"
    elif [ -d /srv/$HOSTNAME/public ] && [ $(grep -qs ${HOME_BASE}${USER}/share/public /proc/mounts > /dev/null; echo $?) = 0 ]; then
      msg "Creating /srv/$HOSTNAME/public bind mount..."
      info "Bind mount status: ${YELLOW}Success. Previous mount exists.${NC}\nUsing existing mount."
    elif [ ! -d /srv/$HOSTNAME/public ] && [ $(grep -qs ${HOME_BASE}${USER}/share/public /proc/mounts > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/public bind mount..."
      warn "Bind mount status: ${RED}Failed.${NC}\n Mount point /srv/$HOSTNAME/public does not exist.\nSkipping this mount point."
    fi
    # Create shared photo bind mount
    if [ -d /srv/$HOSTNAME/photo ] && [ $(grep -qs ${HOME_BASE}${USER}/share/photo /proc/mounts > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/photo bind mount..."
      sudo mkdir -p /srv/$HOSTNAME/photo/$(echo ${USER} | awk -F '_' '{print $1}')_photo
      sudo chown -R ${USER}:${GROUP} /srv/$HOSTNAME/photo/$(echo ${USER} | awk -F '_' '{print $1}')_photo
      sudo chmod 1750 /srv/$HOSTNAME/photo/$(echo ${USER} | awk -F '_' '{print $1}')_photo
      setfacl -Rm g:${GROUP}:rx,g:medialab:rx,g:privatelab:rwx,d:u:${USER}:rwx /srv/$HOSTNAME/photo/$(echo ${USER} | awk -F '_' '{print $1}')_photo
      echo "/srv/$HOSTNAME/photo ${HOME_BASE}${USER}/share/photo none bind,rw,xattr,acl 0 0" >> /etc/fstab
      mount ${HOME_BASE}${USER}/share/photo
      info "Bind mount status: ${YELLOW}Success.${NC}"
    elif [ -d /srv/$HOSTNAME/photo ] && [ $(grep -qs ${HOME_BASE}${USER}/share/photo /proc/mounts > /dev/null; echo $?) = 0 ]; then
      msg "Creating /srv/$HOSTNAME/photo bind mount..."
      info "Bind mount status: ${YELLOW}Success. Previous mount exists.${NC}\nUsing existing mount."
    elif [ ! -d /srv/$HOSTNAME/photo ] && [ $(grep -qs ${HOME_BASE}${USER}/share/photo /proc/mounts > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/photo bind mount..."
      warn "Bind mount status: ${RED}Failed.${NC}\n Mount point /srv/$HOSTNAME/photo does not exist.\nSkipping this mount point."
    fi
    # Create shared video bind mount
    if [ -d /srv/$HOSTNAME/video ] && [ $(grep -qs ${HOME_BASE}${USER}/share/video /proc/mounts > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/video bind mount..."
      sudo mkdir -p /srv/$HOSTNAME/video/homevideo/$(echo ${USER} | awk -F '_' '{print $1}')_homevideo
      sudo chown -R ${USER}:${GROUP} /srv/$HOSTNAME/video/homevideo/$(echo ${USER} | awk -F '_' '{print $1}')_homevideo
      sudo chmod -R 1750 /srv/$HOSTNAME/video/homevideo/$(echo ${USER} | awk -F '_' '{print $1}')_homevideo
      setfacl -Rm g:${GROUP}:rx,g:medialab:rx,g:privatelab:rwx,d:u:${USER}:rwx /srv/$HOSTNAME/video/homevideo/$(echo ${USER} | awk -F '_' '{print $1}')_homevideo
      if [ -d /srv/$HOSTNAME/video/pron ]; then
        setfacl -Rm u:${USER}:000 /srv/$HOSTNAME/video/pron
      fi
      echo "/srv/$HOSTNAME/video ${HOME_BASE}${USER}/share/video none bind,rw,xattr,acl 0 0" >> /etc/fstab
      mount ${HOME_BASE}${USER}/share/video
      "Bind mount status: ${YELLOW}Success.${NC}"
    elif [ -d /srv/$HOSTNAME/video ] && [ $(grep -qs ${HOME_BASE}${USER}/share/video /proc/mounts > /dev/null; echo $?) = 0 ]; then
      msg "Creating /srv/$HOSTNAME/video bind mount..."
      if [ -d /srv/$HOSTNAME/video/pron ]; then
        setfacl -Rm u:${USER}:000 /srv/$HOSTNAME/video/pron
      fi
      info "Bind mount status: ${YELLOW}Success. Previous mount exists.${NC}\nUsing existing mount."
    elif [ ! -d /srv/$HOSTNAME/video ] && [ $(grep -qs ${HOME_BASE}${USER}/share/video /proc/mounts > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/video bind mount..."
      warn "Bind mount status: ${RED}Failed.${NC}\n Mount point /srv/$HOSTNAME/video does not exist.\nSkipping this mount point."
    fi

  #Level 03 Bind mounts
  elif [ ${JAIL_TYPE} = "level03" ]; then
    msg "Creating ${USER} share mount point folders..."
    sudo mkdir -p ${HOME_BASE}${USER}/share
    sudo mkdir -p ${HOME_BASE}${USER}/share/{audio,books,downloads,music,photo,public,video}
    sudo chown -R ${USER}:${GROUP} ${HOME_BASE}${USER}/share
    sudo chmod -R 0750 ${HOME_BASE}${USER}/share
    # Create shared audio bind mount
    if [ -d /srv/$HOSTNAME/audio ] && [ $(grep -qs ${HOME_BASE}${USER}/share/audio /proc/mounts > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/audio bind mount..."
      echo "/srv/$HOSTNAME/audio ${HOME_BASE}${USER}/share/audio none bind,ro,xattr,acl 0 0" >> /etc/fstab
      mount ${HOME_BASE}${USER}/share/audio
      "Bind mount status: ${YELLOW}Success.${NC}"
    elif [ -d /srv/$HOSTNAME/audio ] && [ $(grep -qs ${HOME_BASE}${USER}/share/audio /proc/mounts > /dev/null; echo $?) = 0 ]; then
      msg "Creating /srv/$HOSTNAME/audio bind mount..."
      info "Bind mount status: ${YELLOW}Success. Previous mount exists.${NC}\nUsing existing mount."
    elif [ ! -d /srv/$HOSTNAME/audio ] && [ $(grep -qs ${HOME_BASE}${USER}/share/audio /proc/mounts > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/audio bind mount..."
      warn "Bind mount status: ${RED}Failed.${NC}\n Mount point /srv/$HOSTNAME/audio does not exist.\nSkipping this mount point."
    fi
    # Create shared books bind mount
    if [ -d /srv/$HOSTNAME/books ] && [ $(grep -qs ${HOME_BASE}${USER}/share/books /proc/mounts > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/books bind mount..."
      echo "/srv/$HOSTNAME/books ${HOME_BASE}${USER}/share/books none bind,ro,xattr,acl 0 0" >> /etc/fstab
      mount ${HOME_BASE}${USER}/share/books
      "Bind mount status: ${YELLOW}Success.${NC}"
    elif [ -d /srv/$HOSTNAME/books ] && [ $(grep -qs ${HOME_BASE}${USER}/share/books /proc/mounts > /dev/null; echo $?) = 0 ]; then
      msg "Creating /srv/$HOSTNAME/books bind mount..."
      info "Bind mount status: ${YELLOW}Success. Previous mount exists.${NC}\nUsing existing mount."
    elif [ ! -d /srv/$HOSTNAME/books ] && [ $(grep -qs ${HOME_BASE}${USER}/share/books /proc/mounts > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/books bind mount..."
      warn "Bind mount status: ${RED}Failed.${NC}\n Mount point /srv/$HOSTNAME/books does not exist.\nSkipping this mount point."
    fi
    # Create shared downloads bind mount
    if [ -d /srv/$HOSTNAME/downloads ] && [ $(grep -qs ${HOME_BASE}${USER}/share/downloads/user/$(echo ${USER} | awk -F '_' '{print $1}')_downloads /proc/mounts > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/downloads bind mount..."
      sudo mkdir -p /srv/$HOSTNAME/downloads/{user,user/$(echo ${USER} | awk -F '_' '{print $1}')_downloads}
      sudo chown -R ${USER}:${GROUP} /srv/$HOSTNAME/downloads/user/$(echo ${USER} | awk -F '_' '{print $1}')_downloads
      sudo chmod 0750 /srv/$HOSTNAME/downloads/user/$(echo ${USER} | awk -F '_' '{print $1}')_downloads
      setfacl -Rm d:u:${USER}:rwx,g:${GROUP}:000,g:medialab:rwx,g:privatelab:rwx /srv/$HOSTNAME/downloads/user/$(echo ${USER} | awk -F '_' '{print $1}')_downloads
      echo "/srv/$HOSTNAME/downloads/user/$(echo ${USER} | awk -F '_' '{print $1}')_downloads ${HOME_BASE}${USER}/share/downloads none bind,rw,xattr,acl 0 0" >> /etc/fstab
      mount ${HOME_BASE}${USER}/share/downloads
      info "Bind mount status: ${YELLOW}Success.${NC}"
    elif [ -d /srv/$HOSTNAME/downloads ] && [ $(grep -qs ${HOME_BASE}${USER}/share/downloads/user/$(echo ${USER} | awk -F '_' '{print $1}')_downloads /proc/mounts > /dev/null; echo $?) = 0 ]; then
      msg "Creating /srv/$HOSTNAME/downloads bind mount..."
      info "Bind mount status: ${YELLOW}Success. Previous mount exists.${NC}\nUsing existing mount."
    elif [ ! -d /srv/$HOSTNAME/downloads ] && [ $(grep -qs ${HOME_BASE}${USER}/share/downloads/user/$(echo ${USER} | awk -F '_' '{print $1}')_downloads > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/downloads bind mount..."
      warn "Bind mount status: ${RED}Failed.${NC}\n Mount point /srv/$HOSTNAME/downloads does not exist.\nSkipping this mount point."
    fi
    # Create shared music bind mount
    if [ -d /srv/$HOSTNAME/music ] && [ $(grep -qs ${HOME_BASE}${USER}/share/music /proc/mounts > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/music bind mount..."
      echo "/srv/$HOSTNAME/music ${HOME_BASE}${USER}/share/music none bind,ro,xattr,acl 0 0" >> /etc/fstab
      mount ${HOME_BASE}${USER}/share/music
      "Bind mount status: ${YELLOW}Success.${NC}"
    elif [ -d /srv/$HOSTNAME/music ] && [ $(grep -qs ${HOME_BASE}${USER}/share/music /proc/mounts > /dev/null; echo $?) = 0 ]; then
      msg "Creating /srv/$HOSTNAME/music bind mount..."
      info "Bind mount status: ${YELLOW}Success. Previous mount exists.${NC}\nUsing existing mount."
    elif [ ! -d /srv/$HOSTNAME/music ] && [ $(grep -qs ${HOME_BASE}${USER}/share/music /proc/mounts > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/music bind mount..."
      warn "Bind mount status: ${RED}Failed.${NC}\n Mount point /srv/$HOSTNAME/music does not exist.\nSkipping this mount point."
    fi
    # Create shared public bind mount
    if [ -d /srv/$HOSTNAME/public ] && [ $(grep -qs ${HOME_BASE}${USER}/share/public /proc/mounts > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/public bind mount..."
      echo "/srv/$HOSTNAME/public ${HOME_BASE}${USER}/share/public none bind,rw,xattr,acl 0 0" >> /etc/fstab
      mount ${HOME_BASE}${USER}/share/public
      info "Bind mount status: ${YELLOW}Success.${NC}"
    elif [ -d /srv/$HOSTNAME/public ] && [ $(grep -qs ${HOME_BASE}${USER}/share/public /proc/mounts > /dev/null; echo $?) = 0 ]; then
      msg "Creating /srv/$HOSTNAME/public bind mount..."
      info "Bind mount status: ${YELLOW}Success. Previous mount exists.${NC}\nUsing existing mount."
    elif [ ! -d /srv/$HOSTNAME/public ] && [ $(grep -qs ${HOME_BASE}${USER}/share/public /proc/mounts > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/public bind mount..."
      warn "Bind mount status: ${RED}Failed.${NC}\n Mount point /srv/$HOSTNAME/public does not exist.\nSkipping this mount point."
    fi
    # Create shared photo bind mount
    if [ -d /srv/$HOSTNAME/photo ] && [ $(grep -qs ${HOME_BASE}${USER}/share/photo /proc/mounts > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/photo bind mount..."
      sudo mkdir -p /srv/$HOSTNAME/photo/$(echo ${USER} | awk -F '_' '{print $1}')_photo
      sudo chown -R ${USER}:${GROUP} /srv/$HOSTNAME/photo/$(echo ${USER} | awk -F '_' '{print $1}')_photo
      sudo chmod 1750 /srv/$HOSTNAME/photo/$(echo ${USER} | awk -F '_' '{print $1}')_photo
      setfacl -Rm g:${GROUP}:rx,g:medialab:rx,g:privatelab:rwx,d:u:${USER}:rwx /srv/$HOSTNAME/photo/$(echo ${USER} | awk -F '_' '{print $1}')_photo
      echo "/srv/$HOSTNAME/photo ${HOME_BASE}${USER}/share/photo none bind,rw,xattr,acl 0 0" >> /etc/fstab
      mount ${HOME_BASE}${USER}/share/photo
      info "Bind mount status: ${YELLOW}Success.${NC}"
    elif [ -d /srv/$HOSTNAME/photo ] && [ $(grep -qs ${HOME_BASE}${USER}/share/photo /proc/mounts > /dev/null; echo $?) = 0 ]; then
      msg "Creating /srv/$HOSTNAME/photo bind mount..."
      info "Bind mount status: ${YELLOW}Success. Previous mount exists.${NC}\nUsing existing mount."
    elif [ ! -d /srv/$HOSTNAME/photo ] && [ $(grep -qs ${HOME_BASE}${USER}/share/photo /proc/mounts > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/photo bind mount..."
      warn "Bind mount status: ${RED}Failed.${NC}\n Mount point /srv/$HOSTNAME/photo does not exist.\nSkipping this mount point."
    fi
    # Create shared video bind mount
    if [ -d /srv/$HOSTNAME/video ] && [ $(grep -qs ${HOME_BASE}${USER}/share/video /proc/mounts > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/video bind mount..."
      sudo mkdir -p /srv/$HOSTNAME/video/homevideo/$(echo ${USER} | awk -F '_' '{print $1}')_homevideo
      sudo chown -R ${USER}:${GROUP} /srv/$HOSTNAME/video/homevideo/$(echo ${USER} | awk -F '_' '{print $1}')_homevideo
      sudo chmod -R 1750 /srv/$HOSTNAME/video/homevideo/$(echo ${USER} | awk -F '_' '{print $1}')_homevideo
      setfacl -Rm g:${GROUP}:rx,g:medialab:rx,g:privatelab:rwx,d:u:${USER}:rwx /srv/$HOSTNAME/video/homevideo/$(echo ${USER} | awk -F '_' '{print $1}')_homevideo
      echo "/srv/$HOSTNAME/video ${HOME_BASE}${USER}/share/video none bind,rw,xattr,acl 0 0" >> /etc/fstab
      mount ${HOME_BASE}${USER}/share/video
      "Bind mount status: ${YELLOW}Success.${NC}"
    elif [ -d /srv/$HOSTNAME/video ] && [ $(grep -qs ${HOME_BASE}${USER}/share/video /proc/mounts > /dev/null; echo $?) = 0 ]; then
      msg "Creating /srv/$HOSTNAME/video bind mount..."
      info "Bind mount status: ${YELLOW}Success. Previous mount exists.${NC}\nUsing existing mount."
    elif [ ! -d /srv/$HOSTNAME/video ] && [ $(grep -qs ${HOME_BASE}${USER}/share/video /proc/mounts > /dev/null; echo $?) = 1 ]; then
      msg "Creating /srv/$HOSTNAME/video bind mount..."
      warn "Bind mount status: ${RED}Failed.${NC}\n Mount point /srv/$HOSTNAME/video does not exist.\nSkipping this mount point."
    fi
   echo
  fi 
  done
fi
echo

#### Finish ####
section "File Server CT - Completion Status."

clear
echo
msg "${WHITE}Success.${NC}"
sleep 3

# Cleanup
if [ -z ${PARENT_EXEC_NEW_JAIL_USER+x} ]; then
  cleanup
fi
