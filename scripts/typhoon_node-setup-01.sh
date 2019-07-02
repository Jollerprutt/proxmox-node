# Edit Proxmox host file
echo -e "127.0.0.1 localhost.localdomain localhost
192.168.1.101 typhoon-01.localdomain.com typhoon-01
192.168.1.102 typhoon-02.localdomain.com typhoon-02
192.168.1.103 typhoon-03.localdomain.com typhoon-03
192.168.1.104 typhoon-04.localdomain.com typhoon-04

# The follow are network machines
192.168.1.10 cyclone-01 cyclone-01.localdomain.com cyclone-01

# The following lines are desirable for IPv6 capable hosts

::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts"  >  /etc/hosts

# Create a PAM User Group
pveum groupadd homelab -comment 'Homelab User Group'
# Add PVEVMAdmin role (fully administer VMs) to group homelab
pveum aclmod / -group homelab -role PVEVMAdmin
# Create PAM User
pveum useradd storm@pam -comment 'User Storm'
pveum passwd storm@pam
# Add User to homelab group
pveum usermod storm@pam -group homelab

cat /home/james/.ssh/id_rsa.pub | ssh [USER]@[SERVER] "cat >> ~/.ssh/authorized_keys"

/etc/pve/storage.cfg

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
        options vers=4
PVEVMAdmin
