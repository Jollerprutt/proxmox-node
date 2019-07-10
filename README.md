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
Qotom hardware is unlike a Intel Nuc or any other single network NIC host (including Synology Virtual Machines) because a Qotom has multiple network NICs. In the following setup we use a Qotom Mini PC model Q500G6-S05, a 6x port Gigabit NIC PC router.

If you are using a Qotom 4x Gigabit NIC model then you cannot create LAGS/Bonds because you do not have enough ports. So configure Proxmox bridges only.

In order to create VLANs within a Virtual Machine (VM) for clients like Docker or a LXC container, you need to have a Linux Bridge. Because we use a Qotom and have 6x Gigabit NICs we can use NIC bonding (also called NIC teaming or Link Aggregation, LAG) which is a technique for binding multiple NIC’s to a single network device. By doing link aggregation, two NICs can appear as one logical interface, resulting in double speed. This is a native Linux kernel feature that is supported by most smart L2/L3 switches with IEEE 802.3ad.

We are going to use 802.3ad Dynamic link aggregation (802.3ad)(LACP) so your switch must be 802.3ad compliant. This creates aggregation groups of NICs which share the same speed and duplex settings as each other. A link aggregation group (LAG) combines a number of physical ports together to make a single high-bandwidth data path, so as to implement the traffic load sharing among the member ports in the group and to enhance the connection reliability.

The next steps will setup your network switch and Qotom Hardware.

### 1. Configure your Network Switch
This example is based on UniFi US-24 port switch. Just transpose the settings to UniFi US-48 or whatever brand of Layer 2 switch you use. As a matter of practice I make the last switch ports 21-24 a LAG Bond or Link Aggregation for the Synology NAS connection (referred to as 'balanced-TCP | Dynamic Link Aggregation IEEE 802.3ad' in the Synology network control panel) and the preceding 6x ports are reserved for the Qotom and pfSense OpenVPN Gateways. Configure your network switch LAG groups as per following table.

| 24 Port Switch | Port ID | Port ID |Port ID | Port ID |Port ID | Port ID | Port ID |Port ID | Port ID |Port ID | Port ID | Port ID |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
|**Port Number** | `1` | `3` |`5` | `7` |`9` | `11` | `13` | `15` |`17` | `19` |`21` | `23` |
|**Port Number** | `2` | `4` |`6` | `8` |`10` | `12` | `14` | `16` |`18` | `20` |`22` | `24` |
|**LAG Bond** |  |  | |  | |  |  | LAG 15-16 | LAG 17-18 |  | LAG 21-24 | LAG 21-24 |
|**Switch Port Profile / VLAN** |  |  | |  | |  |  | All | VPN-egress (VLAN2) |  | All | All |
||||||||||||
|**Qotom NIC Ports** |  |  | |  | |  |  | Port 1+2 | Port 3+4 | Port 5+6 |  |  |
|**Proxmox Linux Bond** |  |  | |  | |  |  | `bond0` | `bond1` |  |  |  |
|**Proxmox Bridge** |  |  | |  | |  |  | `vmbr0` | `vmbr1` | `vmbr2/vmbr3` |  |  |
|**Proxmox Comment** |  |  | |  | |  |  | Proxmox LAN Bond | VPN-egress Bond | vpngate-world/vpngate-local|  |  |

Note the **Switch Port Profile / VLAN** must be preconfigured in your network switch. The above table, based on a UniFi US-24 model, shows port 15+16 are link agreegated (LAG), port 17+18 are another LAG and ports 19 and 20 are not LAG'd. So ports 15 to 20, a total of 6 ports are use the Qotom.

Steps to configuring your network switch:
#### 1.1 Create VLANs
In this example three VLANs are created - 1x WAN/VPN-egress (VLAN2) | 1x LAN-vpngate-world (VLAN30) | 1x LAN-vpngate-local (VLAN40). The below instructions are for the UniFi controller `Settings` > `Networks` > `Create New Network`
*  Create a new network to be used for Egress of encypted traffic out of network to your VPN servers.

| Description | Value | Notes |
| :---  | :---: | :--- |
| `Name` |VPN-egress| This network will be used as the WAN for Qotom pfSense OpenVPN clients (encrypted exit). |
| `Purpose` |Guest|  Network Guest security policies. |
| `VLAN` |2| A dedicated VLAN for the WAN used by OpenVPN client(s) for network paths and firewall rules use Guest security policies. |
| `Gateway/Subnet` |192.168.2.1/28| Only 2 addresses on this subnet so /29 is ideal |
| `DHCP Server` | Enabled | Just use default range 192.168.2.2 -- 192.168.2.14 |
| `Other Settings` | Just leave as Default | |

* Create **two** new VLAN only networks to be used as gateways to connect to OpenVPN clients running on the Qotom and pfSense router.

| Description | Value | Notes |
| :---  | :---: | :--- |
| `Name` |**LAN-vpngate-world**| This is the network where LAN clients will be restricted to the vpngate-world server |
| `Purpose` |VLAN Only| This is critical. We don't want the UniFi USG to do anything with any client on this VLAN other than be sure that they can get to their gateway. |
| `VLAN` |30|  |
| `IGMP Snooping` |Disabled|  |
| `DHCP Guarding` |Disabled|  |
|
| `Name` |**LAN-vpngate-local**| This is the network where LAN clients will be restricted to the vpngate-world server |
| `Purpose` |VLAN Only| This is critical. We don't want the UniFi USG to do anything with any client on this VLAN other than be sure that they can get to their gateway. |
| `VLAN` |40|  |
| `IGMP Snooping` |Disabled|  |
| `DHCP Guarding` |Disabled|  |

#### 1.2 Setup network switch ports
In this example network switch ingress port 19 is associated with vpngate-world and ingress port 20 is associted with vpngate-local. The below instructions are for the UniFi controller `Devices` > `Select device - i.e UniFi Switch 24/48` > `Ports`  and select port 19 or 20 and edit and `apply` as follows:

| Description | Value | Notes |
| :---  | :---: | :--- |
| `Name` |**Port 19**|  |
| `Switch Port Profile` |LAN-vpngate-world (30)| This will put switch port 19 on VLAN30 |
|
| `Name` |**Port 20**|  |
| `Switch Port Profile` |LAN-vpngate-local (40)| This will put switch port 20 on VLAN30 |

#### 1.3 Setup secure VPN WiFi SSiDs
In this example two VPN secure WiFI SSIDs are created. and all traffic on these WiFi connections will exit to the internet via VPN. The below instructions are for the UniFi controller `Settings` > `Wireless Networks` > `Create New Wireless Network`  as follows:

| Description | Value | Notes |
| :---  | :---: | :--- |
| `Name/SSID` |**hello-vpngate-world**| Call it whatever you like |
| `Enabled` |[x]| |
| `Security` | WPA Personal | Wouldnt recommend anything less |
| `Security Key` | password | Your choosing |
| `VLAN` |30| Must be set as 30 |
| `Other Settings` | Just leave as default| |
|
| `Name/SSID` |**hello-vpngate-local**| Call it whatever you like |
| `Enabled` |[x]| |
| `Security` | WPA Personal | Wouldnt recommend anything less |
| `Security Key` | password | Your choosing |
| `VLAN` |40| Must be set as 40 |
| `Other Settings` | Just leave as default| |

### 2. Configure Proxmox node typhoon-01 (Qotom)
The Qotom Mini PC Q500G6-S05 has 6x Gigabit NICs. 

| Proxmox NIC ID | enp1s0 | enp2s0 |enp3s0 | enp4s0 |enp5s0 | enp6s0 |
| :--- | :---:  | :---: | :---:  | :---: | :---:  | :---: |
|**Proxmox Linux Bond** | `bond0` | `bond0` | `bond1` | `bond1` | |  |
|**Proxmox Linux Bridge** | `vmbr0` | `vmbr0` | `vmbr1` | `vmbr1` | `vmbr2` | `vmbr3` |

If you are using the Qotom 4x Gigabit NIC model version then you dont have enough NIC ports to create LAGS because we require 4x connection addresses. A Qotom 4x Gigabit NIC PC router configuration would be as follows.

| Proxmox NIC ID | enp1s0 | enp2s0 |enp3s0 | enp4s0 |
| :--- | :---:  | :---: | :---:  | :---: |
|**Proxmox Linux Bridge** | `vmbr0` | `vmbr1` | `vmbr2` | `vmbr3` |

The following recipes are for the Qotom Mini PC Q500G6-S05 unit. Amend for other hardware.

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
| `Name` |bond1|
| `IP address` |leave blank|
| `Subnet mask` |leave blank|
| `Gateway` |leave blank|
| `IPv6 address` |leave blank|
| `Prefix length` |leave blank|
| `Gateway` |leave blank|
| `Autostart` |[x]|
| `Slaves` |enp3s0 enp4s0|
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

Note the bridge port corresponds to a physical interface identified above. The name for Linux Bridges must follow the format of vmbrX with ‘X’ being a number between 0 and 9999. Last but not least, `vmbr0` is the default Linux Bridge which wouldve been setup when first installing Proxmox and DOES NOT need to be created. Simply edit the existing `vmbr0` by changing `Bridge port ==> bond0`.

Reboot the Proxmox node to invoke the system changes.

### 3. Install pfsense
In this step you will create two OpenVPN Gateways for the whole network using pfSense. These two OpenVPN Gateways will be accessible by connected devices, LAN and WiFi. The two OpenVPN Gateways are integated into separate VLAN networks:
   * `vpngate-world` - VLAN30 - This VPN client (used as a gateway) randomly connects to servers from a user determined safe list which should be outside of your country or nation. A safer zone.
   * `vpngate-local` - VLAN40 - This VPN client (used as a gateway) connects to servers which are either local, incountry or within your selected region and should provide a faster connection speed. 


# Download ISO Template images
wget https://snapshots.pfsense.org/amd64/pfSense_master/installer/pfSense-CE-2.5.0-DEVELOPMENT-amd64-latest.iso.gz -P /var/lib/vz/template/iso
gzip -d pfSense-CE-2.5.0-DEVELOPMENT-amd64-latest.iso.gz

qm create 251 --bootdisk virtio0 --cores 2 --cpu host --ide2 local:iso/pfSense-CE-2.5.0-DEVELOPMENT-amd64-latest.iso,media=cdrom --memory 2048 --name pfsense --net0 virtio=AA:EE:88:D4:26:E4,bridge=vmbr0,firewall=1 --net1 virtio=6E:C1:23:F4:1A:7D,bridge=vmbr1,firewall=1 --net2 virtio=92:10:6F:1E:B8:BD,bridge=vmbr2,firewall=1,tag=30 --net3 virtio=72:E8:93:32:7B:D3,bridge=vmbr3,firewall=1,tag=40 --numa 0 --onboot 1 --ostype other --scsihw virtio-scsi-pci --smbios1 uuid=a386d1df-b3ab-4694-9f1c-e002e7eb30c5 --sockets 1 --virtio0 local-lvm:vm-251-disk-0,size=32G --vmgenid 3cc5ea9e-670e-4571-b45c-7c97f0a27ade


Copyright and distribution notice | Accept
Welcome to pfSense / Install pfSense | <OK>
Keymap Selection / >>> Continue with default keymap | <Select>
Partitioning / Auto (UFS) - Guided Disk Setup | <OK>
Manual Configuration | <No>
Complete | <Reboot>
The reboot phase
Should VLANs be setup now? | n
Enter the WAN interface name or 'a' for auto-detection: vtnet1
Enter the LAN interface name or 'a' for auto-detection: vtnet0
Enter the Optional 1 Interface name or 'a' for auto-detection: vtnet2
Enter the Optional 2 Interface name or 'a' for auto-detection: vtnet3
Do you want to proceed [y:n] | y


