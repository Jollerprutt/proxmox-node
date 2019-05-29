# Your Proxmox Build
The following is for a hard metal proxmox node(s) build. Modify accordingly for your own NAS or NFS server setup.
Network Prerequisites are:
- [x] Network Gateway is `192.168.1.5`
- [x] Network DNS server is `192.168.1.5`
- [x] Network DHCP server is `192.168.1.5`

Other Prerequisites are:
- [x] Synology NAS, including NFS, is fully configured as per [synobuild](https://github.com/ahuacate/synobuild)

Tasks to be performed are:
- [ ] Create the required Synology shared folders and NFS shares
- [ ] Create a new user group `homelab`
- [ ] Create two new Synology users;
  * first user named: `storm`
  * second user named: `gituser`
- [ ] Configure Synology NAS SSH Key-based authentication for the above users.

## Proxmox Installation
For each proxmox node each installation requires two hard disks.
Disk one (sda) is the for proxmox OS so a small 30Gb disk is adequate. Use a sata or USB dom if you like.
Disk two (sdb) I recommend a 250Gb SSD as minimum - preferably 500Gb.
Create your proxmox installation USB media (instructions [here](https://pve.proxmox.com/wiki/Install_from_USB_Stick)), set your nodes bios boot order to USB first (so you can boot off your proxmox installation USB media), and install proxmox. Remember to remove your USB media on reboot. Configure each node as follows:

| Option | Node 1 Value | Node 2 Value | Node 3 Value |
| :---  | :---: | :---: | :---: |
| `Filesystem` |ext4 |ext4|ext4
| `Disk(s)` |sda|sda|sda
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

## Configure your Proxmox server
Further configuration is done via the Proxmox web interface. Just point your browser to the IP address given during installation (https://youripaddress:8006). Default login is "root" (realm PAM) and the root password was defined during the installation process.

### 1. Update the Proxmox OS and turnkeylinux templates
Using the web interface `updates` > `refresh` to search for all the latest required updates.
Next install the updates using the web interface `updates` > `_upgrade` and a pop up terminal will show installing all your required updates.

Next install turnkeylinux container templates use the web interface CLI `shell` and type
`pveam update`

### 2. Create Disk Two
Create Disk Two using the web interface `Disks` > `ZFS` > `Create: ZFS` and configure each node as follows:

| Option | Node 1 Value | Node 2 Value | Node 3 Value |
| :---  | :---: | :---: | :---: |
| `Name` |typhoon-share-01|typhoon-share-02|typhoon-share-03
| `RAID Level` |Single Disk|Single Disk|Single Disk
| `Compression` |on|on|on
| `ashift` |12|12|12
| `Device` |/dev/sdb|/dev/sdb|/dev/sdb

Note: If your choose to use a ZFS Raid change accordingly per node but retain the `Name` ID

## LXC Installs
### 1. PiHole LXC Container - CentOS7
Deploy an LXC container with the CentOS7 template image:

| Option | Node 1 Value |
| :---  | :---: |
| `Hostname` |pihole|
| `Unprivileged container` | ☑ |
| `Template` |centos-7-default_****_amd|
| `Storage` |typhoon-share-01|
| `Disk Size` |8 GiB|
| `CPU Cores` |2|
| `Memory (MiB)` |1024|
| `Swap (MiB)` |512|
| `IPv4/CIDR` |192.168.1.253/24|
| `Gateway` |192.168.1.5|

When at the console for the CentOS7 LXC instance:
Install pihole..
curl -sSL https://install.pi-hole.net | bash

Open VPN Gateway


