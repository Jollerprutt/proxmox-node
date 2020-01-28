#!/usr/bin/env bash

# Cyclone-01 NFS Mounts
echo
NFS_MOUNT_POINTS=$(showmount -d $NAS_IPV4 | grep -E "/audio|/books|/docker|/cloudstorage|/downloads|/music|/photo|/proxmox/backup|/public|/video|/video/transcode")
rpcinfo -t $NAS_IPV4 nfs 4 > /dev/null 2>&1
read NFS4_TRUE < <(echo $?)
rpcinfo -t $NAS_IPV4 nfs 3 > /dev/null 2>&1
read NFS3_TRUE < <(echo $?)
if [ "$NFS4_TRUE" -eq "0" ]; then
	info  "Remote NFS Version 4 shares are available on NFS server $NAS_IPV4."
	box_out `showmount -d $NAS_IPV4 | grep -E --color=auto "/audio|/books|/docker|/cloudstorage|/downloads|/music|/photo|/proxmox/backup|/public|/video|/video/transcode"`
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
	box_out `showmount -d $NAS_IPV4 | grep -E --color=auto "/audio|/books|/docker|/cloudstorage|/downloads|/music|/photo|/proxmox/backup|/public|/video|/video/transcode"`
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
