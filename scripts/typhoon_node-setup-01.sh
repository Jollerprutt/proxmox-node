zfspool: typhoon-share
        pool typhoon-share
        content rootdir,images
        sparse 0

nfs: cyclone-01-backup
        export /volume1/proxmox/backup
        path /mnt/pve/cyclone-01-backup
        server 192.168.1.10
        content backup
        maxfiles 1
        options vers=3
