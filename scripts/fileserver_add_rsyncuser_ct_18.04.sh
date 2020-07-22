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

# Command to run script
# bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/fileserver_add_jailuser_ct_18.04.sh)"


# Setting Variables
CHROOT="/srv/$HOSTNAME/homes/chrootjail"
HOME_BASE="$CHROOT/homes/"
GROUP="chrootjail"


#### Creating File Server Jailed Users ####
if [ -z "${NEW_JAIL_USER+x}" ] && [ -z "${PARENT_EXEC_NEW_JAIL_USER+x}" ]; then
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
