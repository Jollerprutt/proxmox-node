# Proxmox Node Setup
The purpose of this guide is to document a working Proxmox VE setup which runs on the following hardware types:

>  **Build Type A - Proxmox File Server** - Primary Host
>
>  *  Supermicro Mainboard - X11SSH-F (2x 1Gb LAN) or X11SSH-LN4F (4x 1Gb LAN)
>  *  PCIe Intel I350-T4 (4x LAN) (optional)
>  *  10Gbe Intel NIC (optional)
>  *  Support for Intel AES-NI
>  *  32Gb of ECC RAM (Minimum)
>  *  240Gb Samsung SM/PM883 x2 (Enterprise Grade SSD is a must)
>  *  8-10TB Rotational Disks
>
>  **Build Type B - Qotom Mini PC Q500G6-S05** - Primary Host
>
>  *  Qotom Mini PC Q500G6-S05 - I5 Intel
>  *  6x LAN Intel NIC
>  *  Support for Intel AES-NI (16Gb is max for Qotom)
>  *  16Gb of RAM
>  *  240Gb Samsung PM883 x1 (Enterprise Grade SSD is a must)
>
>  **Build Type C - Cluster Node Hardware** - Secondary Host
>
>  *  Any X86 hardware to complete a 3x host Proxmox cluster
>  *  Hardware example: Intel i3/i5/i7 NUC models with 16Gb RAM and 1x LAN NIC
>
>  **Network Appliances**
>  *  Ubiquiti UniFi Network Switches (Gen2 preferably).
>
>  **Optional Stuff**
>  * NAS Storage - Synology DiskStation, FreeNAS, QNAP, File Server - Not required for **Build A**.

In my opinion **Build Type A** is the best long term solution. Because with quality components you can obtain a better value to performance mark over and above most OEM NAS hardware, retain the flexibility to always be able upgrade any component at any time, such as LAN (10Gbe), RAM, CPU and expand storage capacity when needed. But I recommend when possible select or install install genuine Intel NICs, use ECC Ram and install enterprise grade SSD drives for the Proxmox VE OS and cache.

Whether you choose **Build Type A** or **Build Type B** you can create a Proxmox cluster by adding two low wattage **Build Type C** hosts. A minimum of three Proxmox hosts is needed to form a quorum in the event a host fails.

For my network hardware I use Ubiquiti UniFi products.

Network prerequisites are:
- [x] Layer 2 Network Switches
- [x] Network Gateway is `192.168.1.5`
- [x] Network DNS server is `192.168.1.5` (Note: your Gateway hardware should enable you to a configure DNS server(s), like a UniFi USG Gateway, so set the following: primary DNS `192.168.1.254` which will be your PiHole server IP address; and, secondary DNS `1.1.1.1` which is a backup Cloudfare DNS server in the event your PiHole server 192.168.1.254 fails or is down)
- [x] Network DHCP server is `192.168.1.5`
- [x] A DDNS service is fully configured and enabled (I recommend you use the free Synology DDNS service)
- [x] A ExpressVPN account (or any preferred VPN provider) is valid and its smart DNS feature is working (public IP registration is working with your DDNS provider)

Other optional Prerequisites are (if using Build Type B);
- [x] Synology NAS is `192.168.1.10`
- [x] Synology NAS is installed with Synology Virtual Machine Manager
- [x] Synology NAS is configured, including NFS, as per [synobuild](https://github.com/ahuacate/synobuild)

Tasks to be performed are:
- [1.00 Hardware Specifications](#100-hardware-specifications)
	- [1.01 Hardware Specifications - Build Type A](#101-hardware-specifications---build-type-a)
- [2.00 Proxmox OS Install](#200-proxmox-os-install)
	- [2.01 Proxmox VE OS Install - Build Type A](#201-proxmox-ve-os-install---build-type-a)
	- [2.02 Proxmox VE OS Install - Build Type B](#202-proxmox-ve-os-install---build-type-b)
	- [2.03 Proxmox VE OS Install - Build Type C](#203-proxmox-ve-os-install---build-type-c)
	- [2.04 Proxmox VE OS Install - Final Steps](#204-proxmox-ve-os-install---final-steps)
- [3.00 Prepare your Network Hardware - Ready for Typhoon-01](#300-prepare-your-network-hardware---ready-for-typhoon-01)
	- [3.01 Configure your Network Switch](#301-configure-your-network-switch)
	- [3.02 Create Network Switch VLANs](#302-create-network-switch-vlans)
	- [3.03 Setup network switch ports](#303-setup-network-switch-ports)
	- [3.04 Setup network WiFi SSiDs for the VPN service](#304-setup-network-wifi-ssids-for-the-vpn-service)
	- [3.05 Edit your UniFi network firewall](#305-edit-your-unifi-network-firewall)
- [4.00 Configure your Proxmox Host - Easy Script Method](#400-configure-your-proxmox-host---easy-script-method)
	- [4.01 Build Type A - 4x LAN 1Gb PLUS 10Gbe](#401-build-type-a---4x-lan-1gb-plus-10gbe)
	- [4.02 Build Type A - 4x LAN 1Gb](#402-build-type-a---4x-lan-1gb)
	- [4.03 Build Type B - Qotom Mini PC model Q500G6-S05 build script](#403-build-type-b---qotom-mini-pc-model-q500g6-s05-build-script)
	- [4.04 Build Type C - Single NIC Hardware build script](#404-build-type-c---single-nic-hardware-build-script)
	- [4.05 Build Type C - Synology or NAS VM build script](#405-build-type-c---synology-or-nas-vm-build-script)
- [5.00 Manual Configuration - Basic setup of your Proxmox Hosts](#500-manual-configuration---basic-setup-of-your-proxmox-hosts)
	- [5.01 Manual Configuration - Update Proxmox OS and enable turnkeylinux templates](#501-manual-configuration---update-proxmox-os-and-enable-turnkeylinux-templates)
	- [5.02 Manual Configuration - Edit your Proxmox hosts file](#502-manual-configuration---edit-your-proxmox-hosts-file)
	- [5.03 Manual Configuration - Edit Proxmox inotify limits](#503-manual-configuration---edit-proxmox-inotify-limits)
	- [5.04 Manual Configuration - Configure Proxmox bridge & bond networking](#504-manual-configuration---configure-proxmox-bridge--bond-networking)
		- [Build Type A - 4x LAN 1Gb plus 10Gbe](#build-type-a---4x-lan-1gb-plus-10gbe)
		- [Build Type A - 4x LAN 1Gb](#build-type-a---4x-lan-1gb)
		- [Build Type B - 6x LAN 1Gb](#build-type-b---6x-lan-1gb)
- [6.00 Manual Configuration - Create a File Server](#600-manual-configuration---create-a-file-server)
	- [6.01 Create a File Server on Build Type A](#601-create-a-file-server-on-build-type-a)
- [7.00 Manual Configuration - Network Storage Access](#700-manual-configuration---network-storage-access)
	- [7.01 Build Type A - Local Mount points](#701-build-type-a---local-mount-points)
	- [7.02 Build Type B & C](#702-build-type-b--c)
- [8.00 Manual Configuration - Add SSH Keys](#800-manual-configuration---add-ssh-keys)
- [9.00 Manual Configuration - Create a new Proxmox user](#900-manual-configuration---create-a-new-proxmox-user)
- [10.00 Create a Proxmox VE Cluster](#1000-create-a-proxmox-ve-cluster)
	- [10.01 Create a Cluster](#1001-create-a-cluster)
	- [10.02 Join the other Nodes to the New Cluster](#1002-join-the-other-nodes-to-the-new-cluster)
	- [10.03 How to delete a existing cluster on a node](#1003-how-to-delete-a-existing-cluster-on-a-node)
- [00.00 Patches and Fixes](#0000-patches-and-fixes)
	- [00.01 pfSense – disable firewall with pfctl -d](#0001-pfsense--disable-firewall-with-pfctl--d)
	- [00.02 Proxmox Backup Error - Permissions](#0002-proxmox-backup-error---permissions)
	- [00.03 Simple bash script to APT update all LXC containers which are stopped or running status](#0003-simple-bash-script-to-apt-update-all-lxc-containers-which-are-stopped-or-running-status)

## 1.00 Hardware Specifications
Hardware specifications for Build Types.

### 1.01 Hardware Specifications - Build Type A
| Component | Part Description | Part Number | Units | Notes
| :---  | :---: | :---: |  :---: | :---
| Mainboard | Supermicro X11SSH-F | MBD-X11SSH-F
| CPU | 
| PCIe Network Card (1Gbe)
| PCIe Network Card (10Gbe)
| IPMI LAN
| RAM
| PSU
| PVE SSD
| PCIe NVMe Card
| Storage Drives
| Server Case


## 2.00 Proxmox OS Install
This chapter is about how to install Proxmox VE on your host type.

It is highly recommended you install server grade SSD drives for your Proxmox OS. I use the Samsung SM883 and PM883 240Gb models.

In all build types always use the ZFS disk format.

Within these instructions we refer to SCSi and SATA controller devices designated disk names such as sda, sdb, sdc and so on, a generic linux naming convention, as `sdx` only. Ideally sda (and sdb in respect to Build Type A) should be your Proxmox OS SSD devices.

But Proxmox VE OS SSDs devices in some hardware builds may not be sda because the drive is not installed on a SCSi and SATA controller. For example, NVMe drives show as /dev/nvme0(n1..). 

Nevertheless, its most important to check your hardware device schematics and note which device type is designated to which type of hard drive you have installed. 

Now go to the Proxmox site and [download](https://www.proxmox.com/en/downloads) the latest ISO and burn to USB stick. Instructions are [here](https://pve.proxmox.com/wiki/Prepare_Installation_Media).

### 2.01 Proxmox VE OS Install - Build Type A

Install two 240Gb SSD's in your host. Proxmox VE OS is installed in a ZFS Raid 1 configuration using both SSDs on this host. Boot from the Proxmox installation USB stick and configure Proxmox VE as follows:

1.  **Proxmox Virtualisation Environment (PVE)** - At this stage you must select your Proxmox VE OS installation drives, Raid type and partition sizes. Click 'options' and complete as follows:

| Option | Value | Notes |
| :---  | :---: | :---
| Filesystem | `zfs (RAID1)`
| **Disk Setup - SATA**
| Harddisk 0 | /dev/sdx ||
| Harddisk 1 | /dev/sdx ||
| **Disk Setup - PCIe NVMe**
| Harddisk 0 || /dev/nvmeXn1 |
| Harddisk 1 || /dev/nvmeXn1 |
| **Advanced Options**
| ashift | `12` | *4K sector size. For 8K sectors use `13`*
| compress | `on`
| checksum | `on`
| copies | `1`
| size - 240GB | `148` ||| *Size for 240GB SSD*
| size - 120GB | `38` ||| *Size for 120GB SSD*

The above PVE partition `size` is calculated in the following table. The unallocated space is required for later partitioning for ZFS Logs and Cache.  

| Option | Value 240GB SSD | Value 120GB SSD | Notes |
| :---  | :---: | :---: | :---
| Actual Capacity | 220GB | 110GB | *This is a estimate of the actual usable space available.*
| PVE size | 148 | 38 | 
| **Unallocated space**
| ZFS Logs size | 8 | 8 | 
| ZFS Cache size | 64 | 64 |


### 2.02 Proxmox VE OS Install - Build Type B

Despite Qotom hardware having two internal SATA slots they are of different types. This is a problem because device /dev/sdb is mSATA. So I only use /dev/sda installed with a single 2,5" form factor SSD.

Proxmox VE OS is installed in a ZFS Raid0 configuration (Raid0 with 1x SSD is okay). Boot from the Proxmox installation USB stick and configure Proxmox VE as follows:

1.  **Proxmox Virtualisation Environment (PVE)** - At this stage you must select your Proxmox VE OS installation drive, and Raid type. Click 'options' and complete as follows:

| Option | Value | Notes |
| :---  | :---: | :---
| Filesystem | `zfs (RAID0)`
| **Disk Setup - SATA**
| Harddisk 0 | /dev/sda ||
| Harddisk 1 | --do not use-- ||
| **Advanced Options**
| ashift | `12` | *4K sector size. For 8K sectors use `13`*
| compress | `on`
| checksum | `on`
| copies | `1`
| size - 240GB | `240` ||| *Max the size*
| size - 120GB | `120` ||| *Max the size*

### 2.03 Proxmox VE OS Install - Build Type C

Build Type C can be any x86 hardware of your choosing. Its main role is for creating a cluster so I use low wattage Intel NUC's. If you have a Synology NAS with a Intel CPU you can save on hardware costs by creating a Synology Virtual Machine Proxmox VM build with these instructions [HERE](https://github.com/ahuacate/synobuild/blob/master/README.md#install--configure-synology-virtual-machine-manager).

Proxmox VE OS is installed in a ZFS Raid0 configuration (Raid0 with 1x SSD is okay). Boot from the Proxmox installation USB stick and configure Proxmox VE as follows:

1.  **Proxmox Virtualisation Environment (PVE)** - At this stage you must select your Proxmox VE OS installation drive, and Raid type. Click 'options' and complete as follows:

| Option | Value | Notes |
| :---  | :---: | :---
| Filesystem | `zfs (RAID0)`
| **Disk Setup - SATA**
| Harddisk 0 | /dev/sda ||
| Harddisk 1 | --do not use-- ||
| **Advanced Options**
| ashift | `12` | *4K sector size. For 8K sectors use `13`*
| compress | `on`
| checksum | `on`
| copies | `1`
| size - 240GB | `240` ||| *Max the size*
| size - 120GB | `120` ||| *Max the size*

### 2.04 Proxmox VE OS Install - Final Steps

The remaining steps in installing Proxmox VE are self explanatory. 

Configure each host as follows:

| Option | Build Type A - Value | Build Type B - Value | Build Type C - Value | Build Type C - Value | Notes |
| :---  | :---: | :---: | :---: | :---: | :--- |
| Country |Type your Country|Type your Country|Type your Country|Type your Country
| Timezone |Select|Select|Select|Select
| Keymap |`en-us`|`en-us`|`en-us`|`en-us`
| Password | Enter your new password | Enter your new password | Enter your new password | Enter your new password | *Same root password on all nodes*
| E-mail |Enter your Email|Enter your Email|Enter your Email|Enter your Email | *If you dont want to enter a valid email type mail@example.com*
| Management interface |Leave Default|Leave Default|Leave Default|Leave Default
| Hostname |`typhoon-01.localdomain`|`typhoon-01.localdomain`|`typhoon-02.localdomain`|`typhoon-03.local.domain`
|IP Address |`192.168.1.101`|`192.168.1.101`|`192.168.1.102`|`192.168.1.103`
| Netmask |`255.255.255.0`|`255.255.255.0`|`255.255.255.0`|`255.255.255.0`
| Gateway |`192.168.1.5`|`192.168.1.5`|`192.168.1.5`|`192.168.1.5`
| DNS Server |`192.168.1.5`|`192.168.1.5`|`192.168.1.5`|`192.168.1.5`

**Note:** Build Type A or B must be your Primary Host, assigned hostname `typhoon-01.localdomain` and IP `192.168.1.101`, and if your want to create a OpenVPN Gateway for your network clients then you must have 4x LAN available (i.e PCIe Intel I350-T4 card installed). Qotom models are available with 4x or 6x Intel LAN ports.


## 3.00 Prepare your Network Hardware - Ready for Typhoon-01
For our primary Proxmox host, typhoon-01, we use Build Type A or B hardware. The host should have a minimum of 4x LAN 1Gb and preferably 1x LAN 10Gbe. 

Build Type C hardware such as a Intel Nuc, or any other single network NIC host (including Synology Virtual Machines) only requires 1x LAN NIC.

In the setup for **Build Type A** or **B** you have the following options depending on your network components (ranked best first):

>  **Build Type A** - 4x LAN 1Gb PLUS 10Gbe
*  1x LAN 10Gbe
*  2x VPN-egress (LAG Bonded)
*  1x LAN-vpngate-local
*  1x LAN-vpngate-world
>  **Build Type A** - 4x LAN 1Gb
*  1x LAN
*  1x VPN-egress
*  1x LAN-vpngate-local
*  1x LAN-vpngate-world
>  **Build Type B** - 6x LAN 1Gb
*  2x LAN (LAG bonded)
*  2x VPN-egress (LAG bonded)
*  1x LAN-vpngate-local
*  1x LAN-vpngate-world

The network is configured to use VLANs in accordance to the network road map shown [here](https://github.com/ahuacate/network-roadmap).

Where the hosts have multiple NICs you can use NIC bonding (also called NIC teaming or Link Aggregation, LAG) which is a technique for binding multiple NIC’s to a single network device. By doing link aggregation, two NICs can appear as one logical interface, resulting in double speed. This is a native Linux kernel feature that is supported by most smart L2/L3 switches with IEEE 802.3ad support.

On the network switch appliance side you are going to use 802.3ad Dynamic link aggregation (802.3ad)(LACP) so your switch must be 802.3ad compliant. This creates aggregation groups of NICs which share the same speed and duplex settings as each other. A link aggregation group (LAG) combines a number of physical ports together to make a single high-bandwidth data path, so as to implement the traffic load sharing among the member ports in the group and to enhance the connection reliability.

### 3.01 Configure your Network Switch
These instructions are based on a UniFi US-24 port switch. Just transpose the settings to UniFi US-48 or whatever brand of Layer 2 switch you use.

For ease of port management I always use switch ports 1-4/6 for my primary Proxmox host (typhoon-01). Configure your network switch port profiles and LAG groups as follows:

**Build Type A** - 4x LAN 1Gb PLUS 10Gbe

| UniFi US-24 Gen2 | SFP+ Port ID | Port ID | Port ID | Port ID
| :--- | :---: | :---: | :---: | :---: 
|**Port Number** | `25` | `1` | `3` |`5`
|**Port Number** | `26` | `2` | `4` |`6`
|**LAG Bond** | | LAG 1-2  
|**Switch Port Profile / VLAN** | All | VPN-egress (2) | LAN-vpngate-world (30) : LAN-vpngate-local (40)
|**LAN CAT6A cable connected to** | N/A | Port1+2 -> typhoon-01 (NIC1+2) | Port3 -> typhoon-01 (NIC3) : Port4 -> typhoon-01 (NIC4)
|**LAN SFP+ cable connected to** | Port 25 > typhoon-01 (SFP+)
||
|**Host NIC Ports** | SFP+ | Port 1+2 | Port 3+4
|**Proxmox Linux Bond** | | `bond0`
|**Proxmox Bridge** | `vmbr0` | `vmbr1` | `vmbr2 : vmbr3`
|**Proxmox Comment** | Proxmox LAN SFP+ | VPN-egress Bond | vpngate-world : vpngate-local

Note: The **Switch Port Profile / VLAN** must be preconfigured in your network switch (UniFi Controller).

**Build Type A** - 4x LAN 1Gb

| UniFi US-24 | Port ID | Port ID |Port ID
| :--- | :---: | :---: | :---:
|**Port Number** | `1` | `3` | `5`
|**Port Number** | `2` | `4` | `6`
|**LAG Bond** |
|**Switch Port Profile / VLAN** | All : VPN-egress (2) | LAN-vpngate-world (30) : LAN-vpngate-local (40)
|**LAN CAT6A cable connected to** | Port1 -> typhoon-01 (NIC1) : Port2 -> typhoon-01 (NIC2) | Port3 -> typhoon-01 (NIC3) : Port4 -> typhoon-01 (NIC4)
||
|**Proxmox Linux Bond** |
|**Proxmox Bridge** | `vmbr0` : `vmbr1` | `vmbr2 : vmbr3`
|**Proxmox Comment** | Proxmox LAN : VPN-egress | vpngate-world : vpngate-local

Note: The **Switch Port Profile / VLAN** must be preconfigured in your network switch (UniFi Controller).

**Build Type B** - 6x LAN 1Gb (i.e Qotom Hardware)

| UniFi US-24 | Port ID | Port ID | Port ID
| :--- | :---: | :---: | :---:
|**Port Number** | `1` | `3` | `5`
|**Port Number** | `2` | `4` | `6`
|**LAG Bond** | LAG 1-2 | LAG 3-4
|**Switch Port Profile / VLAN** | All | VPN-egress (2) | LAN-vpngate-world (30) : LAN-vpngate-local (40)
|**LAN CAT6A cable connected to** | Port1+2 -> typhoon-01 (NIC1+2) | Port3+4 -> typhoon-01 (NIC3+4) | Port5 -> typhoon-01 (NIC5) : Port6 -> typhoon-01 (NIC6)
||
|**Qotom NIC Ports** | Port 1+2 | Port 3+4 | Port 5+6
|**Proxmox Linux Bond** | `bond0` | `bond1`
|**Proxmox Bridge** | `vmbr0` | `vmbr1` | `vmbr2 : vmbr3` |
|**Proxmox Comment** | Proxmox LAN Bond | VPN-egress Bond | vpngate-world : vpngate-local

Note: The **Switch Port Profile / VLAN** must be preconfigured in your network switch (UniFi Controller). The above table, based on a UniFi US-24 model, shows port 1+2 are link agregated (LAG), port 3+4 are another LAG and ports 5 and 6 are not LAG'd. So ports 1 to 6 numbering on your switch correspond with the Qotom numbering for all 6 ports on the Qotom.

![alt text](https://raw.githubusercontent.com/ahuacate/proxmox-node/master/images/qotom_6port.png)


### 3.02 Create Network Switch VLANs
Three VLANs are created - 1x WAN/VPN-egress (VLAN2) | 1x LAN-vpngate-world (VLAN30) | 1x LAN-vpngate-local (VLAN40). The instructions are specifically for UniFi controller `Settings` > `Networks` > `Create New Network`.

*  Create a new network to be used for Egress of encrypted traffic out of network to your VPN servers.

| Description | Value | Notes |
| :---  | :---: | :--- |
| Name |`VPN-egress`| *This network will be used as the WAN for pfSense OpenVPN clients (encrypted exit).* |
| Purpose |`Guest`| *Network Guest security policies.* |
| VLAN |`2`| *A dedicated VLAN for the WAN used by OpenVPN client(s) for network paths and firewall rules use Guest security policies.* |
| Gateway/Subnet |`192.168.2.5/28`| *Only 2 addresses on this subnet so /29 is ideal* |
| DHCP Server | `Enabled` | *Just use default range 192.168.2.1 -- 192.168.2.14* |
| Other Settings | *Just leave as Default* | |

* Create **two** new VLAN only networks to be used as VPN gateways by OpenVPN clients in pfSense.

| Description | Value | Notes |
| :---  | :---: | :--- |
| Name |**`LAN-vpngate-world`**| *This is the network where LAN clients will be restricted to the vpngate-world server* |
| Purpose |`VLAN Only`| This is critical. *We don't want the UniFi USG to do anything with any client on this VLAN other than be sure that they can get to their gateway.* |
| VLAN |`30`|  |
| IGMP Snooping |`Disabled`|  |
| DHCP Guarding |`192.168.30.5`|  |
|||
| Name |**`LAN-vpngate-local`**| *This is the network where LAN clients will be restricted to the vpngate-world server* |
| Purpose |`VLAN Only`| *This is critical. We don't want the UniFi USG to do anything with any client on this VLAN other than be sure that they can get to their gateway.* |
| VLAN |`40`|  |
| IGMP Snooping |`Disabled`|  |
| DHCP Guarding |`192.168.40.5`|  |

### 3.03 Setup network switch ports
Here we need to configure the network switch ports.

The instructions are for the UniFi controller `Devices` > `Select device - i.e UniFi Switch 24/48` > `Ports`  and select your port and `edit` and `apply` as follows:

| Description | Build Type A - 4x LAN 1Gb & SFP+ | Build Type A - 4x LAN 1Gb | Build Type B - 6x LAN 1Gb
| :---  | :---: | :---: | :---:
| Name |**`Port 25`**|**`Port 1`**|**`Port 1 & 2`**
| Switch Port Profile |`All`|`All`|`All`
| **Profile Overrides**
| Operation |`☐` Aggregate|`☐` Aggregate|`☑` Aggregate
| Agregate Ports |N/A|N/A|`1-2`
| Link Speed |Autonegotiation|Autonegotiation|Autonegotiation
|||
| Name |**`Port 1 & 2`**|**`Port 2`**|**`Port 3 & 4`**
| Switch Port Profile |`VPN-egress(2)`|`VPN-egress(2)`|`VPN-egress(2)`
| **Profile Overrides**
| Operation |`☑` Aggregate| `☐` Aggregate | `☑` Aggregate
| Agregate Ports |`1-2`| N/A | `3-4`
| Link Speed | Autonegotiation | Autonegotiation | Autonegotiation
|||
| Name |**`Port 3`**|**`Port 3`**|**`Port 5`**
| Switch Port Profile |`LAN-vpngate-world (30)`|`LAN-vpngate-world (30)`|`LAN-vpngate-world (30)`
| Profile Overrides |Leave Default|Leave Default|Leave Default
|||
| Name |**`Port 4`**|**`Port 4`**|**`Port 6`**
| Switch Port Profile |`LAN-vpngate-local (40)`|`LAN-vpngate-local (40)`|`LAN-vpngate-local (40)`
| Profile Overrides |Leave Default|Leave Default|Leave Default

Shown below is a sample of **Build Type B** - 6x LAN 1Gb.
![alt text](https://raw.githubusercontent.com/ahuacate/proxmox-node/master/images/unifi_ports_01.png)

### 3.04 Setup network WiFi SSiDs for the VPN service
Because we have two VPN VLAN's we can create two VPN WiFI SSIDs. All traffic on these WiFi connections will exit to the internet via your preset VPN VLAN (30 or 40). The following instructions are for the UniFi controller `Settings` > `Wireless Networks` > `Create New Wireless Network` and fill out the form details as shown below:

| Description | Value | Notes |
| :---  | :---: | :--- |
| Name/SSID |**`hello-vpngate-world`**| *Call it whatever you want.* |
| Enabled |`☑`| |
| Security | `WPA Personal` | *Wouldn't recommend anything less.* |
| Security Key | password | *Your choosing.* |
| VLAN |`30`| *Must be set as 30.* |
| Other Settings | Leave as default| |
|||
| Name/SSID |**`hello-vpngate-local`**| *Call it whatever you want.* |
| Enabled |`☑`| |
| Security | `WPA Personal` | *Wouldn't recommend anything less.* |
| Security Key | password | *Your choosing.* |
| VLAN |`40`| *Must be set as 40.* |
| Other Settings | leave as default| |

### 3.05 Edit your UniFi network firewall
When you install pfSense on host typhoon-01 both pfSense and HAProxy software must be assigned a WAN interface NIC. This WAN interface will correspond to a Proxmox Linux Bridge of your choosing (i.e vmbrX).

pfSense WAN interface must be VLAN2 which is labelled in your UniFi controller as `VPN-egress`. Because it's configured with network `Guest security policies` in the UniFi controller it has no access to other network VLANs. The reason for this is explained build recipe for `VPN-egress` shown [here](https://github.com/ahuacate/proxmox-node#32-create-network-switch-vlans).

On your Proxmox host (typhoon-01) the corresponding Proxmox Linux Bridges piped to pfSense WAN interface are as follows:

| pfSense WAN | Build Type A - 4x LAN 1Gb & SFP+ | Build Type A - 4x LAN 1Gb | Build Type B - 6x LAN 1Gb
| :---  | :---: | :---: | :---:
| Proxmox Bridge |`vmbr0` (bond0)|`vmbr1`|`vmbr1` (bond1)

So when you install pfSense VM on typhoon-01 the pfSense/HAProxy software must be assigned the above Proxmox Bridge ID as its WAN interface NIC. Use the Proxmox virtio MAC address to match vmbr(x) up with pfSense vtnet(x) assignments.

For HAProxy to work you must authorise UniFi VLAN2 (WAN in pfSense HAProxy) to have access to your Proxmox LXC & CT static IPv4 addresses. These instructions are for a UniFi controller `Settings` > `Guest Control`  and look under the `Access Control` section. Under `Pre-Authorization Access` click`**+** Add IPv4 Hostname or subnet` to add the following IPv4 addresses to authorise access for VLAN2 clients:fill out the form details as shown below:

| + Add IPv4 Hostname or subnet | Value | Notes
| :---  | :---: | :---
| IPv4 | 192.168.50.111 | *Jellyfin Server*
| IPv4 | 192.168.30.112 | *Nzbget Server*
| IPv4 | 192.168.30.113 | *Deluge Server*
| IPv4 | 192.168.50.114 | *flexget Server*
| IPv4 | 192.168.50.115 | *Sonarr Server*
| IPv4 | 192.168.50.116 | *RadarrServer*
| IPv4 | 192.168.50.117 | *Lidarr Server*
| IPv4 | 192.168.50.118 | *Lazylibrarian Server*
| IPv4 | 192.168.50.119 | *Ombi Server*
| IPv4 | 192.168.80.122 | *Syncthing Server*

And click `Apply Changes`.

As you've probably concluded you must add any new HAProxy backend server IPv4 address(s) to the Unifi Pre-Authorization Access list for HAProxy frontend to have access to these servers.

## 4.00 Configure your Proxmox Host - Easy Script Method
If you have completed Steps 1.00 thru to 3.05 you can proceed to build your Proxmox by using pre-configured bash scripts. The scripts should work for:

*  **Build Type A** - 4x LAN 1Gb PLUS 10Gbe
*  **Build Type A** - 4x LAN 1Gb
*  **Build Type B** - 6x LAN 1Gb (*Qotom Mini PC model Q500G6-S05*)
*  **Build Type C** - 1x LAN 1Gb

If your hardware doesn't match the above specifications then my Easy Scripts may not work. You best proceed to Step 5.0 and build manually.

### 4.01 Build Type A - 4x LAN 1Gb PLUS 10Gbe
This script is for the Build Type A only. This script will perform the following tasks:
*  Create a New User **storm**
*  Create a new password for user **storm**
*  Create a new user group called **homelab**
*  Update/enable the Proxmox turnkey appliance list
*  Update and upgrade your Proxmox host
*  Install lm sensors SW
*  Update the hosts file
*  Download pfsense ISO to Proxmox templates
*  Create a pfSense Proxmox VM
*  Configure all 4x Proxmox NICS to LAGS/Bonds and network interface configurations
*  Configure 1x SFP+ network interface configuration

To execute the script SSH into `typhoon-01`(ssh root@192.168.1.101) or use the Proxmox web interface CLI shell `typhoon-01` > `>_ Shell` and cut & paste the following into the CLI terminal window and press ENTER:
```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/typhoon-01-sfp_4x_NIC-setup-01.sh)"
```
If successful you will see on your CLI terminal words **"Looking Good. Rebooting in 5 seconds ......"** and your typhoon-01 machine will reboot. You can now proceed to Step 6.0.

### 4.02 Build Type A - 4x LAN 1Gb
This script is for the Build Type A only. This script will perform the following tasks:
*  Create a New User **storm**
*  Create a new password for user **storm**
*  Create a new user group called **homelab**
*  Update/enable the Proxmox turnkey appliance list
*  Update and upgrade your Proxmox host
*  Install lm sensors SW
*  Update the hosts file
*  Download pfsense ISO to Proxmox templates
*  Create a pfSense Proxmox VM
*  Configure all 4x Proxmox NICS to LAGS/Bonds and network interface configurations
*  Configure 1x SFP+ network interface configuration

To execute the script SSH into `typhoon-01`(ssh root@192.168.1.101) or use the Proxmox web interface CLI shell `typhoon-01` > `>_ Shell` and cut & paste the following into the CLI terminal window and press ENTER:
```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/typhoon-01-4x_NIC-setup-01.sh)"
```
If successful you will see on your CLI terminal words **"Looking Good. Rebooting in 5 seconds ......"** and your typhoon-01 machine will reboot. You can now proceed to Step 6.0.

### 4.03 Build Type B - Qotom Mini PC model Q500G6-S05 build script
This script is for the Qotom Mini PC model Q500G6-S05 model ONLY. This script will perform the following tasks:
*  Create a New User **storm**
*  Create a new password for user **storm**
*  Create a new user group called **homelab**
*  Update/enable the Proxmox turnkey appliance list
*  Update and upgrade your Proxmox host
*  Install lm sensors SW
*  Create NFS mounts to your NAS
*  Update the hosts file
*  Download pfsense ISO to Proxmox templates
*  Create a pfSense Proxmox VM
*  Configure all 6x Proxmox NICS to LAGS/Bonds and network interface configurations

To execute the script SSH into `typhoon-01`(ssh root@192.168.1.101) or use the Proxmox web interface CLI shell `typhoon-01` > `>_ Shell` and cut & paste the following into the CLI terminal window and press ENTER:
```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/typhoon-01-6x_NIC-setup-01.sh)"
```
If successful you will see on your CLI terminal words **"Looking Good. Rebooting in 5 seconds ......"** and your typhoon-01 machine will reboot. You can now proceed to Step 6.0.

### 4.04 Build Type C - Single NIC Hardware build script
This script is for single NIC hardware ONLY (i.e Intel NUC etc). The script will perform the following tasks:
*  Create a New User **storm**
*  Create a new password for user **storm**
*  Create a new user group called **homelab**
*  Update/enable the Proxmox turnkey appliance list
*  Update and upgrade your Proxmox host
*  Create NFS mounts to your NAS
*  Update the hosts file

To execute the script SSH into `typhoon-0X`(ssh root@192.168.1.10X) or use the Proxmox web interface CLI shell `typhoon-02/03/04` > `>_ Shell` and cut & paste the following into the CLI terminal window and press ENTER:
```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/typhoon-0X-Single_NIC-setup-01.sh)"
```
If successful you will see on your CLI terminal words **"Looking Good. Rebooting in 5 seconds ......"** and your typhoon-0X machine will reboot. This hardware is now ready to deploy into a cluster assumming you have fully built typhoon-0X.

### 4.05 Build Type C - Synology or NAS VM build script
This script is for a Proxmox VM build only (i.e Synology Virtual Machine Manager VM). The script will perform the following tasks:
*  Create a New User **storm**
*  Create a new password for user **storm**
*  Create a new user group called **homelab**
*  Update/enable the Proxmox turnkey appliance list
*  Update and upgrade your Proxmox host
*  Create NFS mounts to your NAS
*  Update the hosts file

To execute the script SSH into `typhoon-0X`(ssh root@192.168.1.10X) or use the Proxmox web interface CLI shell `typhoon-02/03/04` > `>_ Shell` and cut & paste the following into the CLI terminal window and press ENTER:
```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/typhoon-0X-VM-setup-01.sh)"
```
If successful you will see on your CLI terminal words **"Looking Good. Rebooting in 5 seconds ......"** and your typhoon-0X machine will reboot. This hardware is now ready to deploy into a cluster assumming you have fully built typhoon-0X.


## 5.00 Manual Configuration - Basic setup of your Proxmox Hosts
Configuration is done via the Proxmox web interface. Just point your browser to the IP address you set during the installation of Proxmox VE OS (https://your_nodes_ip_address:8006) and ignore the security warning by clicking `Advanced` then `Accept the Risk and Continue` -- this is the warning I get in Firefox.

Default login is "root" (realm PAM) and the root password you defined during the installation process.

### 5.01 Manual Configuration - Update Proxmox OS and enable turnkeylinux templates
Using the web interface `updates` > `refresh` search for all the latest required updates. You will get a few errors which ignore.

Next install the updates using the web interface `updates` > `_upgrade` - a pop up terminal will show the installation steps of all your required updates and it will prompt you to type `Y` so do so.

Next install turnkeylinux container templates by using the web interface CLI `shell` and type
`pveam update`

### 5.02 Manual Configuration - Edit your Proxmox hosts file
I've stored my hosts file on GitHub for easy updating. You can view it [HERE](https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/hosts)

Go to Proxmox web interface of your node `typhoon-0X` > `>_Shell` and type the following to fully replace and update your hosts file:

```
hostsfile=$(wget https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/hosts -q -O -) &&
cat << EOF > /etc/hosts
$hostsfile
EOF
```

### 5.03 Manual Configuration - Edit Proxmox inotify limits
Go to Proxmox web interface of your node `typhoon-0X` > `>_Shell` and type the following to fully replace and update your hosts file:
```
echo -e "fs.inotify.max_queued_events = 16384
fs.inotify.max_user_instances = 512
fs.inotify.max_user_watches = 8192" >> /etc/sysctl.conf
```

### 5.04 Manual Configuration - Configure Proxmox bridge & bond networking
This section is for **Build Type A** or **B** - hosts with multiple LAN NIC's. If you configuring **Build Type C**, a single NIC host or a Synology VM then you can skip this step.

####  Build Type A - 4x LAN 1Gb plus 10Gbe
A 4x LAN 1Gb plus 10Gbe configuration is as follows.

| Proxmox NIC ID | enp1s0 (SPF+) | enp2s0 |enp3s0 | enp4s0 | enp5s0
| :--- | :---:  | :---: | :---:  | :---: | :---: |
| **Proxmox Linux Bond** || `bond0` | `bond0`
| **Proxmox Linux Bridge** | `vmbr0` | `vmbr1` | `vmbr1` | `vmbr2` | `vmbr3`

####  Build Type A - 4x LAN 1Gb
A 4x LAN 1Gb configuration is as follows.

| Proxmox NIC ID | enp1s0 | enp2s0 |enp3s0 | enp4s0 |
| :--- | :---:  | :---: | :---:  | :---: |
|**Proxmox Linux Bridge** | `vmbr0` | `vmbr1` | `vmbr2` | `vmbr3` |

####  Build Type B - 6x LAN 1Gb
A 6x LAN 1Gb configuration (Qotom Mini PC Q500G6-S05) is as follows.

| Proxmox NIC ID | enp1s0 | enp2s0 |enp3s0 | enp4s0 |enp5s0 | enp6s0 |
| :--- | :---:  | :---: | :---:  | :---: | :---:  | :---: |
|**Proxmox Linux Bond** | `bond0` | `bond0` | `bond1` | `bond1`
|**Proxmox Linux Bridge** | `vmbr0` | `vmbr0` | `vmbr1` | `vmbr1` | `vmbr2` | `vmbr3` |

This next step only applies to **Build Type A - 4x LAN 1Gb & SFP+** and **Build Type B - 6x LAN 1Gb**. Go to Proxmox web interface of your host (should be https://192.168.1.101:8006/ ) `typhoon-01` > `System` > `Network` > `Create` > `Linux Bond` and fill out the details as shown below (must be in order).

| Description | Build Type A - 4x LAN 1Gb & SFP+ | Build Type A - 4x LAN 1Gb | Build Type B - 6x LAN 1Gb
| :---  | :---: | :---: | :---: |
| Name |`bond0`|-|`bond0`|
| IP address |-|-|-|
| Subnet mask |-|-|-|
| Gateway |-|-|-|
| IPv6 address |-|-|-|
| Prefix length |-|-|-|
| Gateway |-|-|-|
| Autostart |`☑`|-|`☑`|
| Slaves |`enp2s0 : enp3s0`||`enp1s0 : enp2s0`|
| Mode |`LACP (802.3ad)`|-|`LACP (802.3ad)`|
| Hash policy |`layer2`|-|`layer2`|
| Comment |`VPN-egress Bond`|-|`Proxmox LAN Bond`|
|||
| Name |-|-|`bond1`|
| IP address |-|-|-|
| Subnet mask |-|-|-|
| Gateway |-|-|-|
| IPv6 address |-|-|-|
| Prefix length |-|-|-|
| Gateway |-|-|-|
| Autostart |-|-|`☑`|
| Slaves |-|-|`enp3s0 enp4s0`|
| Mode |-|-|`LACP (802.3ad)`|
| Hash policy |-|-|`layer2`|
| Comment |-|-|`VPN-egress Bond`|

Go to Proxmox web interface of host typhoon-01 (should be https://192.168.1.101:8006/ ) `typhoon-01` > `System` > `Network` > `Create` > `Linux Bridge` and fill out the details as shown below (must be in order) but note vmbr0 will be a edit, not create.

| Description | Build Type A - 4x LAN 1Gb & SFP+ | Build Type A - 4x LAN 1Gb | Build Type B - 6x LAN 1Gb
| :---  | :---: | :---: | :---: |
| Name |`vmbr0`|`vmbr0`|`vmbr0`|
| IP address |`192.168.1.101`|`192.168.1.101`|`192.168.1.101`|
| Subnet mask |`255.255.255.0`|`255.255.255.0`|`255.255.255.0`|
| Gateway |`192.168.1.5`|`192.168.1.5`|`192.168.1.5`|
| IPv6 address |-|-|-|
| Prefix length |-|-|-|
| Gateway |-|-|-|
| Autostart |`☑`|`☑`|`☑`|
| VLAN aware |`☑`|`☑`|`☑`|
| Bridge ports |`enp1s0`|`enp1s0`|`bond0`|
| Comment |`Proxmox LAN Bridge`|`Proxmox LAN Bridge`|`Proxmox LAN Bridge/Bond`|
|||
| Name |`vmbr1`|`vmbr1`|`vmbr1`|
| IP address |-|-|-|
| Subnet mask |-|-|-|
| Gateway |-|-|-|
| IPv6 address |-|-|-|
| Prefix length |-|-|-|
| Gateway |-|-|-|
| Autostart |`☑`|`☑`|`☑`|
| VLAN aware |`☑`|`☑`|`☑`|
| Bridge ports |`bond0`|`enp2s0`|`bond1`|
| Comment |`VPN-egress Bridge/Bond`|`VPN-egress Bridge`|`VPN-egress Bridge/Bond`|
|||
| Name |`vmbr2`|`vmbr2`|`vmbr2`|
| IP address |-|-|-|
| Subnet mask |-|-|-|
| Gateway |-|-|-|
| IPv6 address |-|-|-|
| Prefix length |-|-|-|
| Gateway |-|-|-|
| Autostart|`☑`|`☑`|`☑`| 
| VLAN aware |`☑`|`☑`|`☑`|
| Bridge ports |`enp4s0`|`enp3s0`|`enp5s0`|
| Comment |`vpngate-world`|`vpngate-world`|`vpngate-world`|
|||
| Name |`vmbr3`|`vmbr3`|`vmbr3`|
| IP address |-|-|-|
| Subnet mask |-|-|-|
| Gateway |-|-|-|
| IPv6 address |-|-|-|
| Prefix length |-|-|-|
| Gateway |-|-|-|
| Autostart |`☑`|`☑`|`☑`| 
| VLAN aware|`☑`|`☑`|`☑`| 
| Bridge ports |`enp5s0`|`enp4s0`|`enp6s0`|
| Comment |`vpngate-local`|`vpngate-local`|`vpngate-local`|

Note the bridge port corresponds to a physical interface identified above. The name for Linux Bridges must follow the format of vmbrX with ‘X’ being a number between 0 and 9999. Last but not least, `vmbr0` is the default Linux Bridge which would've been setup when first installing Proxmox and DOES NOT need to be created. Simply edit the existing `vmbr0` by changing `Bridge port ==> bond0` for **Build Type B** - 6x LAN 1Gb.

Reboot the Proxmox host to invoke the system changes.


## 6.00 Manual Configuration - Create a File Server
These instructions apply to **Build Type A** only.

There are two options for NAS file serving. They are:

1.  **Build Type A** - Proxmox ZFS Raid pool hosted on typhoon-01. Data is served by a Proxmox Ubuntu 18.04 CT (cyclone-01) on typhoon-01 running NFS and Samba network servers; *or,*
2.  **Existing NAS Hardware** - An existing NAS, Synology, Qnap, FreeNAS etc, is available on the network om IPv4 192.168.1.10. The NAS or File Server must be configured with Samba and NFSv4.1 network servers.

If you have **Existing NAS Hardware** proceed to step 7.

### 6.01 Create a File Server on Build Type A
These instructions apply to **Build Type A** only.

To create a ZFS storage pool and a Proxmox CT File Server use our bash script. Simply follow the prompts and the script will perform the following tasks:

*  Create a ZFS raid storage pool
*  Create a default set of ZFS folder shares
*  Create a Proxmox Ubuntu 18.04 File Server CT
*  Setup Users and Groups Medialab, Homelab and Privatelab
*  Setup NFS4.1 and Samba networking protocols
*  Setup NFS exports and Samba shares
*  Create USB passthrough to access USB hardware directly from your File Server CT
*  Install Webmin for easy File Server management.

To execute the script SSH into `typhoon-01`(ssh root@192.168.1.101) or use the Proxmox web interface CLI shell `typhoon-01` > `>_ Shell` and cut & paste the following into the CLI terminal window and press ENTER:
```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/fileserver_create_ct_18.04.sh)"
```
If successful you will see on your CLI terminal words **"Looking Good. Rebooting in 5 seconds ......"** and your typhoon-01 machine will reboot..

## 7.00 Manual Configuration - Network Storage Access
If you intend to create a Proxmox cluster then you must have some form of network storage. The easiest solution is to use NFS.

If you have chosen the **Build Type A** route then your File Server is Proxmox host typhoon-01. On this host Proxmox VE VM's and CT's can access your ZFS storage using LXC mountpoints. But VM's and CT's running on other cluster hosts need access to the same ZFS storage data but use NFS mountpoints to cyclone-01 IP address 192.168.1.10.

### 7.01 Build Type A - Local Mount points
These instructions apply to **Build Type A** only.

### 7.02 Build Type B & C
These instructions apply to **Build Type A** and **C** only.

Your NFS server should be prepared and ready with shares - Synology NFS Server instructions are available [here](https://github.com/ahuacate/synobuild#create-the-required-synology-shared-folders-and-nfs-shares).

The NFS mounts to be configured are: | `audio` | `backup` | `books` | `docker`| `music` | `cloudstorage` | `photo` | `public` | `transcode` | `video` |
Configuration is by the Proxmox web interface. Just point your browser to the IP address given during installation (https://yournodesipaddress:8006). Default login is "root" (realm PAM) and the root password you defined during the installation process.

Now using the web interface `Datacenter` > `Storage` > `Add` > `NFS` configure the NFS mounts as follows. :

| Cyclone-01-audio | Value |
| :---  | :---: |
| ID |`cyclone-01-audio`|
| Server |`192.168.1.10`|
| Export |`/--list--/audio` |
| Content |`Disk image`|
| Nodes |leave as default|
| Enable |leave as default|
|||
| **Cyclone-01-backup** | **Value** |
| ID |`cyclone-01-backup`|
| Server |`192.168.1.10`|
| Export |`/--list--/proxmox/backup`|
| Content |`VZDump backup file`|
| Nodes |leave as default|
| Enable |leave as default|
| Max Backups | `3` |
|||
| **Cyclone-01-books** | **Value** |
| ID |`cyclone-01-books`|
| Server |`192.168.1.10`|
| Export |`/--list--/books`|
| Content |`Disk image`|
| Nodes |leave as default|
| Enable |leave as default|
|||
| **Cyclone-01-docker** | **Value** |
| ID |`cyclone-01-docker`|
| Server |`192.168.1.10`|
| Export |`/--list--/docker`|
| Content |`Disk image`|
| Nodes |leave as default|
| Enable |leave as default|
|||
| **Cyclone-01-music** | **Value** |
| ID |`cyclone-01-music`|
| Server |`192.168.1.10`|
| Export |`/--list--/music`|
| Content |`Disk image`|
| Nodes |leave as default|
| Enable |leave as default|
|||
| **Cyclone-01-cloudstorage** | **Value** |
| ID |`cyclone-01-cloudstorage`|
| Server |`192.168.1.10`|
| Export |`/--list--/cloudstorage`|
| Content |`Disk image`|
| Nodes |leave as default|
| Enable |leave as default|
|||
| **Cyclone-01-photo** | **Value** |
| ID |`cyclone-01-photo`|
| Server |`192.168.1.10`|
| Export |`/--list--/photo`|
| Content |`Disk image`|
| Nodes |leave as default|
| Enable |leave as default|
|||
| **Cyclone-01-public** | **Value** |
| ID |`cyclone-01-public`|
| Server |`192.168.1.10`|
| Export |`/--list--/public`|
| Content |`Disk image`|
| Nodes |leave as default|
| Enable |leave as default|
|||
| **Cyclone-01-transcode** | **Value** |
| ID |`cyclone-01-transcode`|
| Server |`192.168.1.10`|
| Export |`/--list--/video/transcode`|
| Content |`Disk image`|
| Nodes |leave as default|
| Enable |leave as default|
|||
| **Cyclone-01-video** | **Value** |
| ID |`cyclone-01-video`|
| Server |`192.168.1.10`|
| Export |`/--list--/video`|
| Content |`Disk image`|
| Nodes |leave as default|
| Enable |leave as default|


## 8.00 Manual Configuration - Add SSH Keys
When adding `authorized_keys` to Proxmox you want to append your public key to `/etc/pve/priv/authorized_keys` NOT `~/.ssh/authorized_keys`.

First copy your public key (i.e id_rsa.pub or id_rsa.storm.pub) to your NAS shared folder called `public` (Proxmox needs access). Then go to Proxmox web interface of your node `typhoon-0X/01` > `>_Shell` and type the following to update your Proxmox authorized key file:

```
cat /mnt/pve/cyclone-01-public/id_rsa*.pub | cat >> /etc/pve/priv/authorized_keys &&
service sshd restart &&
rm /mnt/pve/cyclone-01-public/id_rsa*.pub
```

## 9.00 Manual Configuration - Create a new Proxmox user
For ease of management I have created a specific user and group explicitly for Proxmox and Virtual Machines in my cluster with a username storm and group called homelab. You only have to complete this task on typhoon-01 because Proxmox PVE users (not PAM users) are deployed across the cluster.

To create a new group go to Proxmox web interface of your node (should be https://192.168.1.101:8006/ ) `Datacenter` > `Permissions` > `Groups` > `Create` and complete the form fields as follows:

| Create: Group | Value |
| :---  | :---: |
| `Name` | homelab |
| `Comment` | Homelab User Group |

And click `Create`.

Next create the new user so go to Proxmox web interface of your node (should be https://192.168.1.101:8006/ ) `Datacenter` > `Permissions` > `Users` > `Add` and complete the form fields as follows:

| Add: User | Value |
| :---  | :---: |
| User Name | `storm` |
| Realm | `Proxmox VE Authentication Server` |
| Password | Type your password |
| Confirm password | Type your password |
| Group | `homelab` |
| Expire | Leave Default |
| Enabled | `☑` |
| Comment | `User Storm` |
| First Name | Leave Blank |
| Last Name | Leave Blank |
| E-Mail | Leave blank |

And click `Add`.

## 10.00 Create a Proxmox VE Cluster
You need to have a minimum of three fully built and ready Proxmox VE hosts on the same network - Typhoon-01, Typhoon-02 and Typhoon-03.

### 10.01 Create a Cluster
Now using the Proxmox VE web interface on host typhoon-01, go to `Datacenter` > `Cluster` > `Create Cluster` and fill out the fields as follows:

| Create Cluster | Value | Notes
| :---  | :--- | :--- |
| Cluster Name | `typhoon-cluster` |
| Ring 0 Address | Leave Blank |

And Click `Create`.

### 10.02 Join the other Nodes to the New Cluster
The first step in joining other nodes to your cluster, `typhoon-cluster`, is to copy typhoon-01 cluster manager fingerprint/join information into your clipboard.

**Step One:**

Now using the Proxmox VE web interface on host typhoon-01, go to `Datacenter` > `Cluster` > `Join Information` and a new window will appear showing `Cluster Join Information` with the option to `Copy Information` into your clipboard. Click `Copy Information`.

**Step Two:**

Now using the Proxmox VE web interface on the OTHER hosts, typhoon-02/03/04 etc, go to `Datacenter` > `Cluster` > `Join Cluster` and a new window will appear showing `Cluster Join` with the option to paste the `Cluster Join Information` into a `Infoprmation` field. Paste the information, enter your root password into the `Password` field and the other fields will automatically be filled.

And  Click `Join`. Repeat for on all nodes.

The result should be any configuration can now be done via a single Proxmox VE web interface. Just point your browser to the IP address given during installation (https://192.168.1.101:8006) and all added cluster hosts should be shown below `Datacenter (typhoon-cluster)`. Or type `pvecm status` into any host `typhoon-01` > `>_Shell`:

```
pvecm status

# Results ...
Quorum information
------------------
Date:             Mon Jul 22 13:44:10 2019
Quorum provider:  corosync_votequorum
Nodes:            3
Node ID:          0x00000001
Ring ID:          1/348
Quorate:          Yes

Votequorum information
----------------------
Expected votes:   3
Highest expected: 3
Total votes:      3
Quorum:           2  
Flags:            Quorate 

Membership information
----------------------
    Nodeid      Votes Name
0x00000001          1 192.168.1.101 (local)
0x00000002          1 192.168.1.102
0x00000003          1 192.168.1.103
```

### 10.03 How to delete a existing cluster on a node
I made an error when creating the cluster name and it was headache to delete the cluster. But if you paste the following into a CLI terminal your cluster settings should be reset to default.

```
systemctl stop pve-cluster &&
pmxcfs -l &&
rm -f /etc/pve/cluster.conf /etc/pve/corosync.conf &&
rm -f /etc/cluster/cluster.conf /etc/corosync/corosync.conf &&
systemctl stop pve-cluster &&
rm /var/lib/pve-cluster/.pmxcfs.lockfile &&
rm -f /etc/corosync/authkey &&
systemctl start pve-cluster &&
systemctl restart pvedaemon &&
systemctl restart pveproxy &&
systemctl restart pvestatd &&
reboot
```

---

## 00.00 Patches and Fixes

### 00.01 pfSense – disable firewall with pfctl -d
If for whatever reason you have lost access to the pfSense web management console then go to the Proxmox web interface `typhoon-01` > `251 (pfsense)` > `>_ Console` and `Enter an option` numerical `8` to open a shell.

Then type and execute `pfctl -d` where the -d will temporally disable the firewall (you should see the confirmation in the shell `pf disabled`, where pf is the packet filter = FIREWALL)

Now you can log into the WAN side IP address (192.168.2.1) and govern the pfsense again to fix the problem causing pfSense web management console to sease working on 192.168.1.253.

### 00.02 Proxmox Backup Error - Permissions
If you get this error:
```
INFO: tar:  '/mnt/pve/cyclone-01-backup/dump/vzdump-lxc-111-2017_01_27-16_54_45.tmp: Cannot open: Permission denied
```
Fix is go to Proxmox `typhoon-01` > `>_Shell` and type the following:
```
chmod 755 /mnt/pve/cyclone-01-backup/dump
```

### 00.03 Simple bash script to APT update all LXC containers which are stopped or running status
The script will start stopped containers, update them and then shut them down in the background before moving on to next container.

To run script:
```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/update_all_containers.sh)"
```
