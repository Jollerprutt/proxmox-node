#!/usr/bin/env bash

# Append your public key to /etc/pve/priv/authorized_keys
RSA_FILE=/mnt/pve/cyclone-01-public/id_rsa*.pub
echo
box_out '#### ADDING YOUR OWN SSH PUBLIC KEY - MUST READ ####' '' 'To append your own SSH Public Key to your hosts authorized keys you SHOULD FIRST COPY your SSH Public Key' 'into your shared /volume1/public folder on your NAS server.' '' 'If you do not have access to your shared /volume1/public folder' 'on your NAS server then you will be prompted to PASTE your SSH Public Key into this terminal.' 'Use your right-click to paste into the terminal window.' 
echo
sleep 1
read -p "Do you want to add your own SSH Public Key to host $NEW_HOSTNAME [y/n]? " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
	info "Preparing to add your SSH Public Key..."
	RSA_KEY_INSTALL=0
	sleep 1
	echo
else
	RSA_KEY_INSTALL=1
	echo
fi
# Check if RSA key is present and available on NAS
if [ "$RSA_KEY_INSTALL" = "0" ] && [ -f $RSA_FILE ]; then
	info "Found a SSH Public Key filename $(echo `basename /mnt/pve/cyclone-01-public/id_rsa*.pub`) in your NAS shared /volume1/public folder."
	NAS_RSA_AVAIL=0
	echo
elif [ "$RSA_KEY_INSTALL" = "0" ] && [ "$(-f $RSA_FILE; echo "$?")" = "1" ]; then
	warn "No SSH Public Key exists in your NAS shared /volume1/public folder. Using terminal input method"
	NAS_RSA_AVAIL=1
	echo
fi
# Check if NAS SSH key already exists on host
if [ "$RSA_KEY_INSTALL" = "0" ]  && [ "$NAS_RSA_AVAIL" = "0" ] && [ "$(grep -q "$(cat $RSA_FILE)" /root/.ssh/authorized_keys; echo "$?")" = "0" ]; then
	info "Matching SSH Public Key filename $(echo `basename /mnt/pve/cyclone-01-public/id_rsa*.pub`) found on host $NEW_HOSTNAME. Already installed. Not proceeding."
	CHECK_NAS_RSA=0
	echo
else
	CHECK_NAS_RSA=1
fi
# Copy NAS RSA key to host
if [ "$RSA_KEY_INSTALL" = "0" ] && [ "$NAS_RSA_AVAIL" = "0" ] && [ "$CHECK_NAS_RSA" = "1" ]; then
	cat <<-EOF >> /root/.ssh/authorized_keys
	$(cat $RSA_FILE)
	EOF
	info "Your SSH Public Key has been added to host $NEW_HOSTNAME authorized_keys..."
	service sshd restart >/dev/null
	info "Restarting sshd service..."
	echo
fi
# Use terminal to add SSH Public Key
if [ "$RSA_KEY_INSTALL" = "0" ] && [ "$NAS_RSA_AVAIL" = "1" ]; then
	read -r -p "Please paste your SSH Public Key at the prompt then press ENTER: `echo $'\n> '`" INPUTLINE_RSA
	INPUTLINE_RSA_AVAIL=0
	echo
else
	INPUTLINE_RSA_AVAIL=1
fi
# Check if INPUTLINE SSH key already exists on host
if [ "$RSA_KEY_INSTALL" = "0" ] && [ "$INPUTLINE_RSA_AVAIL" = "0" ] && [ "$(grep -q "$(echo $INPUTLINE_RSA)" /root/.ssh/authorized_keys; echo "$?")" = "0" ]; then
	info "Matching SSH Public Key found on host $NEW_HOSTNAME. Already installed. Not proceeding."
	CHECK_INPUTLINE_RSA=0
	echo
else
	CHECK_INPUTLINE_RSA=1
fi

# Copy INPUTLINE RSA key to host
if [ "$RSA_KEY_INSTALL" = "0" ] && [ "$INPUTLINE_RSA_AVAIL" = "0" ] && [ "$CHECK_INPUTLINE_RSA" = "1" ]; then
	cat <<-EOF >> /root/.ssh/authorized_keys
	$(echo $INPUTLINE_RSA)
	EOF
	info "Your SSH Public Key has been added to host $NEW_HOSTNAME authorized_keys..."
	service sshd restart >/dev/null
	info "Restarting sshd service..."
	echo
fi
