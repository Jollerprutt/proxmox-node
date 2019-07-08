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
We have two configuration options subject to hardware types:
   * Node 2 & 3 - Various single NIC machines including Vm's.
   * Node 1 - Qotom Mini PC Q500G6-S05 is a 6x Gigabit NIC Router (6 LAN ports). This node will also host OPENVPN Gateways.
You have two options to configure a Proxmox node - use a automated recipe script or manually.

### 1. Automated Recipe Scripts
You have two options to configure a Proxmox node - automated script or manually.

### 2. Manual Configuration
1.  NFS mounts to NAS
Every Proxmox node must use NFS to mount data stored on your NAS. Your Synology NFS instructions are available [HERE}(https://github.com/ahuacate/synobuild#create-the-required-synology-shared-folders-and-nfs-shares). The nfs mounts are: | `backup` | `docker`| `music` | `photo` | `public` | `video` | 
Configuration is by the Proxmox web interface. Just point your browser to the IP address given during installation (https://yournodesipaddress:8006). Default login is "root" (realm PAM) and the root password you defined during the installation process.
Using the web interface `Datacenter` > `Storage` > `Add` > `NFS` configure as follows:

| Cyclone-01-backup | Value |
| :---  | :---: |
| `ID` |cyclone-01-backup|
| `Server` |192.168.1.10|
| `Export` |/volume1/proxmox/backup|
| `Content` |VZDump backup file|
| `Nodes` |leave as default|
| `Enable` |leave as default|
|||
| **Cyclone-01-docker** | **Value** |
| `ID` |cyclone-01-docker|
| `Server` |192.168.1.10|
| `Export` |/volume1/docker|
| `Content` |Disk image|
| `Nodes` |leave as default|
| `Enable` |leave as default|
|||
| **Cyclone-01-music** | **Value** |
| `ID` |cyclone-01-music|
| `Server` |192.168.1.10|
| `Export` |/volume1/music|
| `Content` |Disk image|
| `Nodes` |leave as default|
| `Enable` |leave as default|
|||
| **Cyclone-01-photo** | **Value** |
| `ID` |cyclone-01-photo|
| `Server` |192.168.1.10|
| `Export` |/volume1/photo|
| `Content` |Disk image|
| `Nodes` |leave as default|
| `Enable` |leave as default|
|||
| **Cyclone-01-public** | **Value** |
| `ID` |cyclone-01-public|
| `Server` |192.168.1.10|
| `Export` |/volume1/public|
| `Content` |Disk image|
| `Nodes` |leave as default|
| `Enable` |leave as default|
|||
| **Cyclone-01-video** | **Value** |
| `ID` |cyclone-01-video|
| `Server` |192.168.1.10|
| `Export` |/volume1/video|
| `Content` |Disk image|
| `Nodes` |leave as default|
| `Enable` |leave as default|

## Qotom Build
A proxmox configuration on Qotom hardware is unlike other hardware such as a Intel Nuc or any other single network NIC host (including Synology Virtual Machines) because Qotom hardware has multiple network NICs. In the following setup we use a Qotom Mini PC Q500G6-S05 a 6x Gigabit NIC PC router.

If you are using the Qotom 4x Gigabit NIC model then you cannot create LAGS/Bonds. Simply configure straight forward Proxmox bridges.

In order to create VLANs within a Virtual Machine (VM) for Docker or a LXC container, you need to have a Linux bridge. Because we have 6x Gigabit NICs we can use NIC bonding (also called NIC teaming or Link Aggregation, LAG) which is a technique for binding multiple NIC’s to a single network device. By doing link aggregation, two NICs can appear as one logical interface, resulting in double speed. This is a native Linux kernel feature that is supported by most smart L2/L3 switches.

We are going to use 802.3ad Dynamic link aggregation (802.3ad)(LACP) so your switch must be 802.3ad compliant. This creates aggregation groups of NICs which share the same speed and duplex settings as each other. A link aggregation group (LAG) combines a number of physical ports together to make a single high-bandwidth data path, so as to implement the traffic load sharing among the member ports in the group and to enhance the connection reliability.

The first step is to setup your switch and Qotom Hardware.

### 1. Configure your switch
This example is based on UniFi US-24 port switch. Just transpose the settings to UniFi US-48 or whatever brand of Layer 2 switch you use. As a matter of practice I make the last switch ports 21-24 a LAG Bond or Link Aggregation for the Synology NAS connection (referred to as 'balanced-TCP | Dynamic Link Aggregation IEEE 802.3ad' in the Synology network control panel) and the preceding 6x ports are reserved for the Qotom. Configure your switch LAGs as per following table.

| 24 Port Switch | Port ID | Port ID |Port ID | Port ID |Port ID | Port ID | Port ID |Port ID | Port ID |Port ID | Port ID | Port ID |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
|**Port Number** | `1` | `3` |`5` | `7` |`9` | `11` | `13` | `15` |`17` | `19` |`21` | `23` |
|**Port Number** | `2` | `4` |`6` | `8` |`10` | `12` | `14` | `16` |`18` | `20` |`22` | `24` |
|**LAG Bond** |  |  | |  | |  |  | LAG 15-16 | LAG 17-18 |  | LAG 21-24 | LAG 21-24 |
|
|**Qotom NIC Ports** |  |  | |  | |  |  | Port 1+2 | Port 3+4 | Port 5+6 |  |  |
|**Proxmox Linux Bond** |  |  | |  | |  |  | bond0 | bond1 |  |  |  |
|**Proxmox Bridge** |  |  | |  | |  |  | vmbr0 | vmbr1 | vmbr2/vmbr3|  |  |
|**Proxmox Comment** |  |  | |  | |  |  | Proxmox LAN Bond | VPN-egress Bond | vpngate-world/vpngate-local|  |  |

### 2. Configure Proxmox node (qotom)
The Qotom Mini PC Q500G6-S05 has 6x Gigabit NICs. If you are using the 4x Gigabit NIC model then you cannot create LAGS - not enough NICs.

| Proxmox NIC ID | enp1s0 | enp2s0 |enp3s0 | enp4s0 |enp5s0 | enp6s0 |
| :--- | :---:  | :---: | :---:  | :---: | :---:  | :---: |
|**Proxmox Linux Bond** | `bond0` | `bond0` | `bond1` | `bond1` | |  |
|**Proxmox Linux Bridge** | `vmbr0` | `vmbr0` | `vmbr1` | `vmbr1` | `vmbr2` | `vmbr3` |

Go to Proxmox web interface of your Qotom node (should be https://192.168.1.101:8006/ ) `typhoon-01` > `System` > `Network` > `Create` > `Linux Bond` and fill out the details as shown below (must be in order). Here we are going to create two LAGs/Bonds.

| Description | Value |
| :---  | :---: |
| `Name` |bond0|
| `IP address` |leave blank|
| `Subnet mask` |leave blank|
| `Gateway` |leave blank|
| `IPv6 address` |leave blank|
| `Prefix length` |leave blank|
| `Gateway` |leave blank|
| `Autostart` |[x]|
| `Slaves` |enp1s0 enp2s0|
| `Mode` |LACP (802.3ad)|
| `Hash policy` |layer2|
| `Comment` |Proxmox LAN Bond|
|||
| `Name` |bond0|
| `IP address` |leave blank|
| `Subnet mask` |leave blank|
| `Gateway` |leave blank|
| `IPv6 address` |leave blank|
| `Prefix length` |leave blank|
| `Gateway` |leave blank|
| `Autostart` |[x]|
| `Slaves` |enp13s0 enp4s0|
| `Mode` |LACP (802.3ad)|
| `Hash policy` |layer2|
| `Comment` |VPN-egress Bond|

Go to Proxmox web interface of your Qotom node (should be https://192.168.1.101:8006/ ) `typhoon-01` > `System` > `Network` > `Create` > `Linux Bridge` and fill out the details as shown below (must be in order) but note vmbr0 will be a edit, not create.

| Description | Value |
| :---  | :---: |
| `Name` |vmbr0|
| `IP address` |192.168.1.101|
| `Subnet mask` |255.255.255.0|
| `Gateway` |192.168.1.5|
| `IPv6 address` |leave blank|
| `Prefix length` |leave blank|
| `Gateway` |leave blank|
| `Autostart` |[x]|
| `VLAN aware` |[x]|
| `Bridge ports` |bond0|
| `Comment` |Proxmox LAN Bridge/Bond|
|||
| `Name` |vmbr1|
| `IP address` |leave blank|
| `Subnet mask` |leave blank|
| `Gateway` |leave blank|
| `IPv6 address` |leave blank|
| `Prefix length` |leave blank|
| `Gateway` |leave blank|
| `Autostart` |[x]|
| `VLAN aware` |[x]|
| `Bridge ports` |bond1|
| `Comment` |VPN-egress Bridge/Bond|
|||
| `Name` |vmbr2|
| `IP address` |leave blank|
| `Subnet mask` |leave blank|
| `Gateway` |leave blank|
| `IPv6 address` |leave blank|
| `Prefix length` |leave blank|
| `Gateway` |leave blank|
| `Autostart` |[x]|
| `VLAN aware` |[x]|
| `Bridge ports` |enp5s0|
| `Comment` |vpngate-world|
|||
| `Name` |vmbr3|
| `IP address` |leave blank|
| `Subnet mask` |leave blank|
| `Gateway` |leave blank|
| `IPv6 address` |leave blank|
| `Prefix length` |leave blank|
| `Gateway` |leave blank|
| `Autostart` |[x]|
| `VLAN aware` |[x]|
| `Bridge ports` |enp6s0|
| `Comment` |vpngate-local|

Note the bridge port corresponds to a physical interface identified above. The name for bridges must follow the format of vmbrX with ‘X’ being a number between 0 and 9999. I chose to have the bridge number the same as the physical interface number to help maintain my sanity. Last but not least, you also need to click ‘VLAN aware’ on the bridge. 
