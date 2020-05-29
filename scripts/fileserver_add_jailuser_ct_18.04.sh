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
wget -qL https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/fileserver_chroot_programs_ct_18.04


#### Creating File Server Jailed Users ####
if [ -z $NEW_JAIL_USER ]; then
  section "File Server CT - Creating Users and Groups."
  echo
  box_out '#### PLEASE READ CAREFULLY - RESTRICTED & JAILED USER ACCOUNTS ####' '' 'In this step you can create restricted jailed users with limited remote' 'access to a select group of folders only. A jailed user should be created' 'for people who need remote access to your File Server data like your' 'video library (TV, movies, documentary), public folder or for' 'private cloud data storage only.' 'Remote access to your File Server is restricted to SFTP and SSH RSync only' 'using a jailed users private SSH RSA encrypted keys.' 'Default jailgroup access rights are:' '' '  --  GROUP NAME     -- USER NAME' '  --  "jailgroup"    -- /srv/"hostname"/homes/jails/chroot/"jailed_username"' '' '  --  PERMISSIONS    -- FOLDER' '  --  -rwx------     -- /srv/"hostname"/homes/jails/chroot/"jailed_username"' '  --  -rwxr-----     -- /srv/CT_HOSTNAME/video/movies' '  --  -rwxr-----     -- /srv/CT_HOSTNAME/video/tv' '  --  -rwxr-----     -- /srv/CT_HOSTNAME/video/documentary' '  --  -rwxr-----     -- /srv/CT_HOSTNAME/public' '' 'By default all new jailed users are members of the "jailgroup". A jailed' 'users Home Folder is the same as the jailed user account (jailed_username).' '' 'No passwords are used - only SSH RSA encrypted keys.'
  echo
  read -p "Create restricted jailed user accounts on your File Server (NAS) [y/n]? " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    NEW_JAIL_USER=0 >/dev/null
  else
    NEW_JAIL_USER=1 >/dev/null
    info "You have chosen to skip this step."
    exit 0
    echo
  fi
fi

echo TEST DONE
