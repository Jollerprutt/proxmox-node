# Your Proxmox Node Build
The following is for a hard metal proxmox node(s) build. Modify accordingly for your own NAS or NFS server setup.
Network prerequisites are:
- [x] Network Gateway is `192.168.1.5`
- [x] Network DNS server is `192.168.1.5` (Note: on your DNS server 192.168.1.5, like a UniFi USG Gateway, set the following: primary DNS `192.168.1.254` which is your PiHole server IP address; secondary DNS `1.1.1.1` which is a Cloudfare DNS server)
- [x] Network DHCP server is `192.168.1.5`

Other Prerequisites are:
- [x] Synology NAS, Synology Virtual Machine Manager, including NFS, is fully configured as per [synobuild](https://github.com/ahuacate/synobuild)

Tasks to be performed are:
- [ ] Proxmox OS Installation
- [ ] Update Proxmox OS and enable turnkeylinux templates

## Proxmox Installation
Each proxmox node requires two hard disks.
SCSi and SATA controllers device file name is sda,sdb,sdc and so on. So disk one is often device sda but this is subject to types of hardware. So we refer to SATA disk devices as sdx. The Proxmox OS disk requires 120 Gb SSD disk. You can use a USB dom if you want to.
Disk two (sdx) I recommend a 500 Gb SSD which will be used as Proxmox ZFS shared storage disk for the cluster. But for my installation I use a 250 Gb SSD.
Create your Proxmox installation USB media (instructions [here](https://pve.proxmox.com/wiki/Install_from_USB_Stick)), set your nodes bios boot loader order to Hard Disk first / USB second (so you can boot from your proxmox installation USB media), and install proxmox.
For your Synology Virtual Machine Proxmox VM pre-setup follow the the instructions [HERE](https://github.com/ahuacate/synobuild#install--configure-synology-virtual-machine-manager). Remember to remove your USB media on reboot on the hard metal hardware. Configure each node as follows:

| Option | Node 1 Value | Node 2 Value | Node 3 Value |
| :---  | :---: | :---: | :---: |
| `Filesystem` |ext4 |ext4|ext4
| `Disk(s)` |sdx|sdx|sdx
| `Country` |"select"|"select"|"select"
| `Timezone` |"select"|"select"|"select"
| `Keymap` |en-us|en-us|en-us
| `E-mail` |"your email"|"your email"|"your email"
| `Management interface` |default|default|default
| `Hostname` |typhoon-01|typhoon-02|typhoon-03
|`IP` |192.168.1.101|192.168.1.102|192.168.1.103
| `Netmask` |255.255.255.0| 255.255.255.0| 255.255.255.0
| `Gateway` |192.168.1.5|192.168.1.5|192.168.1.5
| `DNS` |192.168.1.5|192.168.1.5|192.168.1.5
Please use your supplied password.

## Configure your Proxmox Hardware
Further configuration is done via the Proxmox web interface. Just point your browser to the IP address given during installation (https://yournodesipaddress:8006). Default login is "root" (realm PAM) and the root password you defined during the installation process.

### 1. Update Proxmox OS and enable turnkeylinux templates
Using the web interface `updates` > `refresh` search for all the latest required updates.
Next install the updates using the web interface `updates` > `_upgrade` - a pop up terminal will show the installation steps of all your required updates.

Next install turnkeylinux container templates by using the web interface CLI `shell` and type
`pveam update`

### 2. Create Disk Two
Create Disk Two using the web interface `Disks` > `ZFS` > `Create: ZFS` and configure each node as follows:

| Option | Node 1 Value | Node 2 Value | Node 3 Value |
| :---  | :---: | :---: | :---: |
| `Name` |typhoon-share|typhoon-share|typhoon-share
| `RAID Level` |Single Disk|Single Disk|Single Disk
| `Compression` |on|on|on
| `ashift` |12|12|12
| `Device` |/dev/sdx|/dev/sdx|/dev/sdx

Note: If your choose to use a ZFS Raid change accordingly per node but retain the `Name` ID

## Configure Proxmox OS
Here 
### 3. NFS mounts to NAS
Each Proxmox node will mount NFS shares on your NAS as per instructions available [HERE}(https://github.com/ahuacate/synobuild#create-the-required-synology-shared-folders-and-nfs-shares). The  NAS nfs shares are: `proxmox` | `video` | `music` | `docker` |
