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
- [1.00 Proxmox Base OS Installation](#100-proxmox-base-os-installation)
- [2.00 Configure the Proxmox Hardware](#200-configure-the-proxmox-hardware)
	- [2.01 Update Proxmox OS and enable turnkeylinux templates](#201-update-proxmox-os-and-enable-turnkeylinux-templates)
	- [2.02 Create Disk Two - your shared storage](#202-create-disk-two---your-shared-storage)
- [3.00 Prepare your Network Hardware - Ready for Typhoon-01](#300-prepare-your-network-hardware---ready-for-typhoon-01)
	- [3.01 Configure your Network Switch](#301-configure-your-network-switch)
	- [3.02 Create Network Switch VLANs](#302-create-network-switch-vlans)
	- [3.03 Setup network switch ports](#303-setup-network-switch-ports)
	- [3.04 Setup network WiFi SSiDs for the VPN service](#304-setup-network-wifi-ssids-for-the-vpn-service)
	- [3.05 Edit your UniFi network firewall](#305-edit-your-unifi-network-firewall)
- [4.00 Easy Installation Option](#400-easy-installation-option)
	- [4.01 Script (A) - Qotom Mini PC model Q500G6-S05 build script](#401-script-a---qotom-mini-pc-model-q500g6-s05-build-script)
	- [4.02 Script (B) - Single NIC Hardware build script](#402-script-b---single-nic-hardware-build-script)
	- [4.03 Script (C) - Synology or NAS VM build script](#403-script-c---synology-or-nas-vm-build-script)
- [5.00 Basic Proxmox node configuration](#500-basic-proxmox-node-configuration)
	- [5.01  Create NFS mounts to NAS](#501--create-nfs-mounts-to-nas)
	- [5.02 Configure Proxmox bridge networking](#502-configure-proxmox-bridge-networking)
	- [5.03 Edit your Proxmox hosts file](#503-edit-your-proxmox-hosts-file)
	- [5.04 Create a new Proxmox user](#504-create-a-new-proxmox-user)
	- [5.05 Add SSH Keys](#505-add-ssh-keys)
	- [5.06 Edit Proxmox inotify limits](#506-edit-proxmox-inotify-limits)
- [6.00 Create a Proxmox pfSense VM on typhoon-01](#600-create-a-proxmox-pfsense-vm-on-typhoon-01)
	- [6.01 Download the latest pfSense ISO](#601-download-the-latest-pfsense-iso)
	- [6.02 Create the pfSense VM](#602-create-the-pfsense-vm)
	- [6.03 Install pfSense on the new VM](#603-install-pfsense-on-the-new-vm)
- [7.00 Create a pfSense Backup](#700-create-a-pfsense-backup)
- [8.00 Create a Cluster](#800-create-a-cluster)
	- [8.01 Create the Cluster](#801-create-the-cluster)
	- [8.02 Join the other Nodes to the New Cluster](#802-join-the-other-nodes-to-the-new-cluster)
	- [8.03 How to delete a existing cluster on a node](#803-how-to-delete-a-existing-cluster-on-a-node)
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


## 3.00 Configure your Proxmox Hardware
Configuration is done via the Proxmox web interface. Just point your browser to the IP address you set during the installation of Proxmox VE OS (https://your_nodes_ip_address:8006) and ignore the security warning by clicking `Advanced` then `Accept the Risk and Continue` -- this is the warning I get in Firefox.

Default login is "root" (realm PAM) and the root password you defined during the installation process.

### 3.01 Update Proxmox OS and enable turnkeylinux templates
Using the web interface `updates` > `refresh` search for all the latest required updates. You will get a few errors which ignore.

Next install the updates using the web interface `updates` > `_upgrade` - a pop up terminal will show the installation steps of all your required updates and it will prompt you to type `Y` so do so.

Next install turnkeylinux container templates by using the web interface CLI `shell` and type
`pveam update`

### 2.02 Rename Disk Label local-zfs to typhoon-share - IGNORE
~~During the installation of Proxmox OS you created a disk label `local-zfs`. For ease of identifying disks we want to relabel this disk to `typhoon-share`. `typhoon-share` is our storage for all VM's and LCX CT's.~~

U~~se the Proxmox web interface `typhoon-01` > `>_ Shell` and cut & paste the following into the CLI terminal window and press ENTER:~~
```
~~sed -i 's|zfspool: local-zfs|zfspool: typhoon-share|g' /etc/pve/storage.cfg~~
```

### 2.03 Optional - Create a Second Disk Two for typhoon-share
If for whatever reason you want to install a another disk for `typhoon-share` here are the instructions. 

Create the new disk using the web interface `Disks` > `ZFS` > `Create: ZFS` and configure each node as follows:

| Option | Node 1 Value | Node 2 Value | Node 3 Value |
| :---  | :---: | :---: | :---: |
| Name |`typhoon-share`|`typhoon-share`|`typhoon-share`
| RAID Level |`Single Disk`|`Single Disk`|`Single Disk`
| Compression |`on`|`on`|`on`
| ashift |`12`|`12`|`12`
| Device |`/dev/sdx`|`/dev/sdx`|`/dev/sdx`

**Note:** If your choose to use a ZFS Raid (2 or more disks) for storage redundancy change accordingly per node but you must retain the Name ID **typhoon-share**.

### 2.04 Optional - Create a NAS Share hosted on Proxmox
For those who want to build a NAS on `typhoon-01` you need to create a ZFS zpool with one disk or if you have multiple disks a Raid array of two or more disks. You may choose which raid level to use:

*  **RAID0** - Also called “striping”. The capacity of such volume is the sum of the capacities of all disks. But RAID0 does not add any redundancy, so the failure of a single drive makes the volume unusable.
*  **RAID1** - Also called “mirroring”. Data is written identically to all disks. This mode requires at least 2 disks with the same size. The resulting capacity is that of a single disk.
*  **RAID10** - A combination of RAID0 and RAID1. Requires at least 4 disks.
*  **RAIDZ-1** - A variation on RAID-5, single parity. Requires at least 3 disks.
*  **RAIDZ-2** - A variation on RAID-5, double parity. Requires at least 4 disks.
*  **RAIDZ-3** - A variation on RAID-5, triple parity. Requires at least 5 disks. 

Create the new NAS share using the web interface `Disks` > `ZFS` > `Create: ZFS` selecting one or more available disks to become members of your ZFS Raid. If your disks are not available read below. Configure as follows:

| Option | Node 1 Value | Notes
| :---  | :---: | :---
| Name |`tank`
| Add Storage | `☑`
| RAID Level |`i.e RAID10` | *Note: Choose from the above raid levels*
| Compression |`on`|`on`|`on`
| ashift |`12`|`12`|`12`
| Device |`/dev/sdx`| *Note: Select your disks. Only available disks show*
| |`/dev/sdx`| *Note: Select your disks. Only available disks show*
| |`/dev/sdx`| *Note: Select your disks. Only available disks show*
| |`/dev/sdx`| *Note: Select your disks. Only available disks show*

If any disks fail to show then the disks may need erasing/wiping. First step is to list all disks installed on your hardware. Use the Proxmox web interface `typhoon-01` > `>_ Shell` and type the command:
```
lsblk -f
```
You are looking for disks (sdx) which DO NOT belong to Proxmox OS install (i.e not disks /dev/sda or /dev/sdb). Note the size of the disk. Its fair to say NAS disks will be larger exceeding 1000.00G. You can also get more information with the CLI command ` fdisk -l`.

To wipe or erase the chosen disk type the following command replacing `/dev/sdx` with your disk identifier (i.e /dev/sdc) 
```
dd if=/dev/zero of=/dev/sdx bs=512 count=1 conv=notrunc &&
qm recsan --dryrun
```

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
>  **Build Type A** - 6x LAN 1Gb
*  2x LAN (LAG bonded)
*  2x VPN-egress (LAG bonded)
*  1x LAN-vpngate-local
*  1x LAN-vpngate-world

The network is configured to use VLANs in accordance to my network road map shown [here](https://github.com/ahuacate/network-roadmap).

Where our hosts have multiple NICs we can use NIC bonding (also called NIC teaming or Link Aggregation, LAG) which is a technique for binding multiple NIC’s to a single network device. By doing link aggregation, two NICs can appear as one logical interface, resulting in double speed. This is a native Linux kernel feature that is supported by most smart L2/L3 switches with IEEE 802.3ad support.

On the network switch appliance side we are going to use 802.3ad Dynamic link aggregation (802.3ad)(LACP) so your switch must be 802.3ad compliant. This creates aggregation groups of NICs which share the same speed and duplex settings as each other. A link aggregation group (LAG) combines a number of physical ports together to make a single high-bandwidth data path, so as to implement the traffic load sharing among the member ports in the group and to enhance the connection reliability.

### 3.01 Configure your Network Switch
These instructions are based on a UniFi US-24 port switch. Just transpose the settings to UniFi US-48 or whatever brand of Layer 2 switch you use. As a matter of practice I make the last switch ports 21-24 (on a UniFi US-24 port switch) a LAG Bond or Link Aggregation specically for the Synology NAS connection (referred to as 'balanced-TCP | Dynamic Link Aggregation IEEE 802.3ad' in the Synology network control panel) and always the first 6x ports are reserved for the Qotom (typhoon-01) hosting the pfSense OpenVPN Gateways.

For ease of port management I always use switch ports 1-4/6 for my primary Proxmox host (typhoon-01).

Configure your network switch LAG groups as per your **Build Type A** or **B**.

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

Note: The **Switch Port Profile / VLAN** must be preconfigured in your network switch (UniFi Controller). The above table, based on a UniFi US-24 model, shows port 1+2 are link agregated (LAG), port 3+4 are another LAG and ports 5 and 6 are not LAG'd. So ports 1 to 6 numbering on your switch correspond with the Qotom numbering for all 6 ports on the Qotom.

**Build Type A** - 4x LAN 1Gb

| UniFi US-24 | Port ID | Port ID |Port ID | Port ID |Port ID | Port ID | Port ID |Port ID | Port ID |Port ID | Port ID | Port ID |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
|**Port Number** | `1` | `3` |`5` | `7` |`9` | `11` | `13` | `15` |`17` | `19` |`21` | `23` |
|**Port Number** | `2` | `4` |`6` | `8` |`10` | `12` | `14` | `16` |`18` | `20` |`22` | `24` |
|**LAG Bond** | | | |  | |  |  |  |  |  | | |
|**Switch Port Profile / VLAN** | All : VPN-egress (2) | LAN-vpngate-world (30) : LAN-vpngate-local (40) |  |  |  |  |  |  |  | | |
|**LAN CAT6A cable connected to** | Port1 -> typhoon-01 (NIC1) : Port2 -> typhoon-01 (NIC2) | Port3 -> typhoon-01 (NIC3) : Port4 -> typhoon-01 (NIC4) |  |  |  |  |  |  |  |  |  |
||||||||||||
|**Proxmox Linux Bond** | | | |  | |  |  |  |  |  |  |  |
|**Proxmox Bridge** | `vmbr0` : `vmbr1` | `vmbr2 : vmbr3` |  | |  |  |  |  |  |  |  |
|**Proxmox Comment** | Proxmox LAN : VPN-egress | vpngate-world : vpngate-local |  | |  |  |  |  |  |  |  |

Note: The **Switch Port Profile / VLAN** must be preconfigured in your network switch (UniFi Controller).

**Build Type A** - 6x LAN 1Gb

| UniFi US-24 | Port ID | Port ID |Port ID | Port ID |Port ID | Port ID | Port ID |Port ID | Port ID |Port ID | Port ID | Port ID |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
|**Port Number** | `1` | `3` |`5` | `7` |`9` | `11` | `13` | `15` |`17` | `19` |`21` | `23` |
|**Port Number** | `2` | `4` |`6` | `8` |`10` | `12` | `14` | `16` |`18` | `20` |`22` | `24` |
|**LAG Bond** | LAG 1-2  | LAG 3-4 | |  | |  |  |  |  |  | | |
|**Switch Port Profile / VLAN** | All | VPN-egress (2) | LAN-vpngate-world (30) : LAN-vpngate-local (40) |  |  |  |  |  |  |  | All | All |
|**LAN CAT6A cable connected to** | Port1+2 -> typhoon-01 (NIC1+2) | Port3+4 -> typhoon-01 (NIC3+4) | Port5 -> typhoon-01 (NIC5) : Port6 -> typhoon-01 (NIC6) |  |  |  |  |  |  |  |  |  |
||||||||||||
|**Qotom NIC Ports** | Port 1+2 | Port 3+4 | Port 5+6 |  | |  |  |  |  |  |  |  |
|**Proxmox Linux Bond** | `bond0` | `bond1` | |  | |  |  |  |  |  |  |  |
|**Proxmox Bridge** | `vmbr0` | `vmbr1` | `vmbr2 : vmbr3` |  | |  |  |  |  |  |  |  |
|**Proxmox Comment** | Proxmox LAN Bond | VPN-egress Bond | vpngate-world : vpngate-local |  | |  |  |  |  |  |  |  |

Note: The **Switch Port Profile / VLAN** must be preconfigured in your network switch (UniFi Controller). The above table, based on a UniFi US-24 model, shows port 1+2 are link agregated (LAG), port 3+4 are another LAG and ports 5 and 6 are not LAG'd. So ports 1 to 6 numbering on your switch correspond with the Qotom numbering for all 6 ports on the Qotom.

![alt text](https://raw.githubusercontent.com/ahuacate/proxmox-node/master/images/qotom_6port.png)

Steps to configuring your network switch are as follows.

### 3.02 Create Network Switch VLANs
In this example three VLANs are created - 1x WAN/VPN-egress (VLAN2) | 1x LAN-vpngate-world (VLAN30) | 1x LAN-vpngate-local (VLAN40). The below instructions are for the UniFi controller `Settings` > `Networks` > `Create New Network`
*  Create a new network to be used for Egress of encypted traffic out of network to your VPN servers.

| Description | Value | Notes |
| :---  | :---: | :--- |
| Name |`VPN-egress`| *This network will be used as the WAN for Qotom pfSense OpenVPN clients (encrypted exit).* |
| Purpose |`Guest`| *Network Guest security policies.* |
| VLAN |`2`| *A dedicated VLAN for the WAN used by OpenVPN client(s) for network paths and firewall rules use Guest security policies.* |
| Gateway/Subnet |`192.168.2.5/28`| *Only 2 addresses on this subnet so /29 is ideal* |
| DHCP Server | `Enabled` | *Just use default range 192.168.2.1 -- 192.168.2.14* |
| Other Settings | *Just leave as Default* | |

* Create **two** new VLAN only networks to be used as gateways to connect to OpenVPN clients running on the Qotom and pfSense router.

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

| Description | Value | Notes |
| :---  | :---: | :--- |
| Name |**`Port 1 & 2`**|  |
| Switch Port Profile |`All`| *This is default* |
| **Profile Overrides**
| Operation | `☑` Aggregate
| Agregate Ports | `1-2`
| Link Speed | Autonegotiation
|||
| Name |**`Port 3 & 4`**|  |
| Switch Port Profile |`VPN-egress(2)`
| **Profile Overrides**
| Operation | `☑` Aggregate
| Agregate Ports | `3-4`
| Link Speed | Autonegotiation
|||
| Name |**`Port 5`**|  |
| Switch Port Profile |`LAN-vpngate-world (30)`| *This will put switch port 5 on VLAN30* |
| Profile Overrides | Leave Default
|||
| Name |**`Port 6`**|  |
| Switch Port Profile |`LAN-vpngate-local (40)`| *This will put switch port 6 on VLAN40* |
| Profile Overrides | Leave Default

![alt text](https://raw.githubusercontent.com/ahuacate/proxmox-node/master/images/unifi_ports_01.png)

### 3.04 Setup network WiFi SSiDs for the VPN service
In this example two VPN secure WiFI SSIDs are created. All traffic on these WiFi connections will exit to the internet via your preset VPN VLAN. The below instructions are for the UniFi controller `Settings` > `Wireless Networks` > `Create New Wireless Network` and fill out the form details as shown below:

| Description | Value | Notes |
| :---  | :---: | :--- |
| Name/SSID |**`hello-vpngate-world`**| *Call it whatever you like* |
| Enabled |`☑`| |
| Security | `WPA Personal` | *Wouldnt recommend anything less* |
| Security Key | password | *Your choosing* |
| VLAN |`30`| *Must be set as 30* |
| Other Settings | Leave as default| |
|||
| Name/SSID |**`hello-vpngate-local`**| *Call it whatever you like* |
| Enabled |`☑`| |
| Security | `WPA Personal` | *Wouldnt recommend anything less* |
| Security Key | password | *Your choosing* |
| VLAN |`40`| *Must be set as 40* |
| Other Settings | leave as default| |

### 3.05 Edit your UniFi network firewall
On your Proxmox Qotom build (typhoon-01) NIC ports enp3s0 & enp4s0 are bonded to create LAG `bond1`. You will then create in Proxmox a Linux Bridge using `bond1` called `vmbr2`. When you install pfSense VM on typhoon-01 the pfSense and HAProxy software will assign `vmbr2` (bond1) as its WAN interface NIC.

This WAN interface is VLAN2 and named in the UniFi controller software as `VPN-egress`. It's configured with network `Guest security policies` in the UniFi controller therefore it has no access to other network VLANs. The reason for this is explained build recipe for `VPN-egress` shown [HERE](https://github.com/ahuacate/proxmox-node#22-create-network-switch-vlans).

For HAProxy to work you must authorise VLAN2 (WAN in pfSense HAProxy) to have access to your Proxmox LXC server nodes with static IPv4 addresses on VLAN50.

The below instructions are for a UniFi controller `Settings` > `Guest Control`  and look under the `Access Control` section. Under `Pre-Authorization Access` click`**+** Add IPv4 Hostname or subnet` to add the following IPv4 addresses to authorise access for VLAN2 clients:fill out the form details as shown below:

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

As you've probably concluded you must add any new HAProxy backend server IPv4 address(s) to the Unifi Pre-Authorization Access list for HAProxy frontend to have access to those backend VLAN50 servers.

## 4.00 Easy Installation Option
If you have gotten this far and completed Steps 1.00 thru to 3.05 you can proceed to Step 4.0 to manually build your nodes or skip some steps by using CLI build bash scripts. But my bash scripts are written for the Qotom Mini PC model Q500G6-S05 (6x NIC variant) and single NIC hardware only. If you have different hardware, such as a 2x or 4x NIC Qotom or similiar hardware, then my scripts will not work and you best proceed to Step 4.0 and build manually.

I currently have the following CLI bash scripts available on GitHub to fastrack the build process:

Script (A) `typhoon-01-6x_NIC-setup-01.sh` which is for typhoon-01 (node-01), a Qotom Mini PC model Q500G6-S05 only. This script will perform the following tasks:
*  Steps 4.0 through to Step 5.2 performing the following tasks:
*  Create a New User **storm**
*  Create a new password for user **storm**
*  Create a new user group called **homelab**
*  Update/enable the Proxmox turnkey appliance list
*  Update and upgrade your Proxmox node
*  Install lm sensors SW
*  Create NFS mounts to your NAS
*  Update the hosts file
*  Download pfsense ISO to Proxmox templates
*  Create a pfSense Proxmox VM
*  Configure all 6x Proxmox NICS to LAGS/Bonds and network interface configurations

After executing this Script (A) you must continue manually to Step 6.0 to finish building typhoon-01.

Script (B) `typhoon-0X-Single_NIC-setup-01.sh` which is for typhoon-02/03 (node-02/03/04 etc), which MUST BE single NIC hardware only. The script will perform the following tasks:
*  Create a New User **storm**
*  Create a new password for user **storm**
*  Create a new user group called **homelab**
*  Update/enable the Proxmox turnkey appliance list
*  Update and upgrade your Proxmox node
*  Install lm sensors SW
*  Create NFS mounts to your NAS
*  Update the hosts file

Script (C) `typhoon-0X-VM-setup-01.sh` which is for typhoon-02/03 (node-02/03/04 etc), which **MUST BE Synology or NAS VM BUILD ONLY**. The script will perform the following tasks:
*  Create a New User **storm**
*  Create a new password for user **storm**
*  Create a new user group called **homelab**
*  Update/enable the Proxmox turnkey appliance list
*  Update and upgrade your Proxmox node
*  Create NFS mounts to your NAS
*  Update the hosts file

### 4.01 Script (A) - Qotom Mini PC model Q500G6-S05 build script
This script is for the Qotom Mini PC model Q500G6-S05 model ONLY. 

To execute the script use the Proxmox web interface `typhoon-01` > `>_ Shell` and cut & paste the following into the CLI terminal window and press ENTER:
```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/typhoon-01-6x_NIC-setup-01.sh)"
```
If successful you will see on your CLI terminal words **"Looking Good. Rebooting in 5 seconds ......"** and your typhoon-01 machine will reboot. You can now proceed to Step 6.0.

### 4.02 Script (B) - Single NIC Hardware build script
This script is for single NIC hardware ONLY (i.e Intel NUC etc). 

To execute the script use the Proxmox web interface `typhoon-02/03/04` > `>_ Shell` and cut & paste the following into the CLI terminal window and press ENTER:
```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/typhoon-0X-Single_NIC-setup-01.sh)"
```
If successful you will see on your CLI terminal words **"Looking Good. Rebooting in 5 seconds ......"** and your typhoon-01 machine will reboot. This hardware is now ready to deploy into a cluster assumming you have fully built typhoon-01.

### 4.03 Script (C) - Synology or NAS VM build script
This script is for a Proxmox VM build only (i.e Synology Virtual Machine Manager VM). 

To execute the script use the Proxmox web interface `typhoon-02/03/04` > `>_ Shell` and cut & paste the following into the CLI terminal window and press ENTER:
```
bash -c "$(wget -qLO - https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/typhoon-0X-VM-setup-01.sh)"
```
If successful you will see on your CLI terminal words **"Looking Good. Rebooting in 5 seconds ......"** and your typhoon-01 machine will reboot. This hardware is now ready to deploy into a cluster assumming you have fully built typhoon-01.

## 5.00 Basic Proxmox node configuration
Some of the basic Proxmox OS configuration tasks are common across all three nodes. The variable is with typhoon-01, the multi NIC device, which will alone have a guest pfSense VM installed to manage your networks OpenVPN Gateway services (no redundancy for OpenVPN services as its deemed non critical).

Configuration options are determined by hardware types:
   * Node 1 - typhoon-01 - Qotom Mini PC Q500G6-S05 is a 6x Gigabit NIC Router (6 LAN ports).
   * Node 2 - typhoon-02 - A single NIC x86 machine (1 LAN port).
   * Node 3 - typhoon-03 - Synology VM (1 Virtio LAN port)

### 5.01  Create NFS mounts to NAS
All three Proxmox nodes use NFS to mount data stored on a NAS so these instructions are applicable for all proxmox nodes. Your NFS server should be prepared and ready - Synology NFS Server instructions are available [HERE](https://github.com/ahuacate/synobuild#create-the-required-synology-shared-folders-and-nfs-shares).

The NFS mounts to be configured are: | `audio` | `backup` | `books` | `docker`| `music` | `cloudstorage` | `photo` | `public` | `transcode` | `video` |
Configuration is by the Proxmox web interface. Just point your browser to the IP address given during installation (https://yournodesipaddress:8006). Default login is "root" (realm PAM) and the root password you defined during the installation process.

Now using the web interface `Datacenter` > `Storage` > `Add` > `NFS` configure the NFS mounts as follows on all three nodes:

| Cyclone-01-audio | Value |
| :---  | :---: |
| ID |`cyclone-01-audio`|
| Server |`192.168.1.10`|
| Export |`/volume1/audio`|
| Content |`Disk image`|
| Nodes |leave as default|
| Enable |leave as default|
|||
| **Cyclone-01-backup** | **Value** |
| ID |`cyclone-01-backup`|
| Server |`192.168.1.10`|
| Export |`/volume1/proxmox/backup`|
| Content |`VZDump backup file`|
| Nodes |leave as default|
| Enable |leave as default|
| Max Backups | `3` |
|||
| **Cyclone-01-books** | **Value** |
| ID |`cyclone-01-books`|
| Server |`192.168.1.10`|
| Export |`/volume1/books`|
| Content |`Disk image`|
| Nodes |leave as default|
| Enable |leave as default|
|||
| **Cyclone-01-docker** | **Value** |
| ID |`cyclone-01-docker`|
| Server |`192.168.1.10`|
| Export |`/volume1/docker`|
| Content |`Disk image`|
| Nodes |leave as default|
| Enable |leave as default|
|||
| **Cyclone-01-music** | **Value** |
| ID |`cyclone-01-music`|
| Server |`192.168.1.10`|
| Export |`/volume1/music`|
| Content |`Disk image`|
| Nodes |leave as default|
| Enable |leave as default|
|||
| **Cyclone-01-cloudstorage** | **Value** |
| ID |`cyclone-01-cloudstorage`|
| Server |`192.168.1.10`|
| Export |`/volume1/cloudstorage`|
| Content |`Disk image`|
| Nodes |leave as default|
| Enable |leave as default|
|||
| **Cyclone-01-photo** | **Value** |
| ID |`cyclone-01-photo`|
| Server |`192.168.1.10`|
| Export |`/volume1/photo`|
| Content |`Disk image`|
| Nodes |leave as default|
| Enable |leave as default|
|||
| **Cyclone-01-public** | **Value** |
| ID |`cyclone-01-public`|
| Server |`192.168.1.10`|
| Export |`/volume1/public`|
| Content |`Disk image`|
| Nodes |leave as default|
| Enable |leave as default|
|||
| **Cyclone-01-transcode** | **Value** |
| ID |`cyclone-01-transcode`|
| Server |`192.168.1.10`|
| Export |`/volume1/video/transcode`|
| Content |`Disk image`|
| Nodes |leave as default|
| Enable |leave as default|
|||
| **Cyclone-01-video** | **Value** |
| ID |`cyclone-01-video`|
| Server |`192.168.1.10`|
| Export |`/volume1/video`|
| Content |`Disk image`|
| Nodes |leave as default|
| Enable |leave as default|

### 5.02 Configure Proxmox bridge networking
If you using a single NIC hardware or a Synology VM you can skip this step.

The Qotom Mini PC Q500G6-S05 has 6x Gigabit NICs. 

| Proxmox NIC ID | enp1s0 | enp2s0 |enp3s0 | enp4s0 |enp5s0 | enp6s0 |
| :--- | :---:  | :---: | :---:  | :---: | :---:  | :---: |
|**Proxmox Linux Bond** | `bond0` | `bond0` | `bond1` | `bond1` | |  |
|**Proxmox Linux Bridge** | `vmbr0` | `vmbr0` | `vmbr1` | `vmbr1` | `vmbr2` | `vmbr3` |

If you are using the Qotom 4x Gigabit NIC model version then you dont have enough NIC ports to create LAGS because we require 4x physical connection addresses. A Qotom 4x Gigabit NIC PC router configuration would be as follows.

| Proxmox NIC ID | enp1s0 | enp2s0 |enp3s0 | enp4s0 |
| :--- | :---:  | :---: | :---:  | :---: |
|**Proxmox Linux Bridge** | `vmbr0` | `vmbr1` | `vmbr2` | `vmbr3` |

The following recipes are for the 6x Gigabit NIC Qotom Mini PC Q500G6-S05 unit. Amend for other hardware.

Go to Proxmox web interface of your Qotom node (should be https://192.168.1.101:8006/ ) `typhoon-01` > `System` > `Network` > `Create` > `Linux Bond` and fill out the details as shown below (must be in order). Here we are going to create two LAGs/Bonds.

| Description | Value |
| :---  | :---: |
| Name |`bond0`|
| IP address |leave blank|
| Subnet mask |leave blank|
| Gateway |leave blank|
| IPv6 address |leave blank|
| Prefix length |leave blank|
| Gateway |leave blank|
| Autostart |`☑`|
| Slaves |`enp1s0 enp2s0`|
| Mode |`LACP (802.3ad)`|
| Hash policy |`layer2`|
| Comment |`Proxmox LAN Bond`|
|||
| Name |`bond1`|
| IP address |leave blank|
| Subnet mask |leave blank|
| Gateway |leave blank|
| IPv6 address |leave blank|
| Prefix length |leave blank|
| Gateway |leave blank|
| Autostart |`☑`|
| Slaves |`enp3s0 enp4s0`|
| Mode |`LACP (802.3ad)`|
| Hash policy |`layer2`|
| Comment |`VPN-egress Bond`|

Go to Proxmox web interface of your Qotom node (should be https://192.168.1.101:8006/ ) `typhoon-01` > `System` > `Network` > `Create` > `Linux Bridge` and fill out the details as shown below (must be in order) but note vmbr0 will be a edit, not create.

| Description | Value |
| :---  | :---: |
| Name |`vmbr0`|
| IP address |`192.168.1.101`|
| Subnet mask |`255.255.255.0`|
| Gateway |`192.168.1.5`|
| IPv6 address |leave blank|
| Prefix length |leave blank|
| Gateway |leave blank|
| Autostart |`☑`|
| VLAN aware |`☑`|
|Bridge ports |`bond0`|
| Comment |`Proxmox LAN Bridge/Bond`|
|||
| Name |`vmbr1`|
| IP address |leave blank|
| Subnet mask |leave blank|
| Gateway |leave blank|
| IPv6 address |leave blank|
| Prefix length |leave blank|
| Gateway |leave blank|
| Autostart |`☑`|
| VLAN aware |`☑`|
| Bridge ports |`bond1`|
| Comment |`VPN-egress Bridge/Bond`|
|||
| Name |`vmbr2`|
| IP address |leave blank|
| Subnet mask |leave blank|
| Gateway |leave blank|
| IPv6 address |leave blank|
| Prefix length |leave blank|
| Gateway |leave blank|
| Autostart |`☑`|
| VLAN aware |`☑`|
| Bridge ports |`enp5s0`|
| Comment |`vpngate-world`|
|||
| Name |`vmbr3`|
| IP address |leave blank|
| Subnet mask |leave blank|
| Gateway |leave blank|
| IPv6 address |leave blank|
| Prefix length |leave blank|
| Gateway |leave blank|
| Autostart |`☑`|
| VLAN aware |`☑`|
| Bridge ports |`enp6s0`|
| Comment |`vpngate-local`|

Note the bridge port corresponds to a physical interface identified above. The name for Linux Bridges must follow the format of vmbrX with ‘X’ being a number between 0 and 9999. Last but not least, `vmbr0` is the default Linux Bridge which wouldve been setup when first installing Proxmox and DOES NOT need to be created. Simply edit the existing `vmbr0` by changing `Bridge port ==> bond0`.

Reboot the Proxmox node to invoke the system changes.

### 5.03 Edit your Proxmox hosts file
I've stored my hosts file on GitHub for easy updating. You can view it [HERE](https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/hosts)

Go to Proxmox web interface of your node `typhoon-0X` > `>_Shell` and type the following to fully replace and update your hosts file:

```
hostsfile=$(wget https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/hosts -q -O -) &&
cat << EOF > /etc/hosts
$hostsfile
EOF
```

### 5.04 Create a new Proxmox user
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

### 5.05 Add SSH Keys
When adding `authorized_keys` to Proxmox you want to append your public key to `/etc/pve/priv/authorized_keys` NOT `~/.ssh/authorized_keys`.

First copy your public key (i.e id_rsa.pub or id_rsa.storm.pub) to your NAS shared folder called `public` (Proxmox needs access). Then go to Proxmox web interface of your node `typhoon-0X/01` > `>_Shell` and type the following to update your Proxmox authorized key file:

```
cat /mnt/pve/cyclone-01-public/id_rsa*.pub | cat >> /etc/pve/priv/authorized_keys &&
service sshd restart &&
rm /mnt/pve/cyclone-01-public/id_rsa*.pub
```

### 5.06 Edit Proxmox inotify limits
```
echo -e "fs.inotify.max_queued_events = 16384
fs.inotify.max_user_instances = 512
fs.inotify.max_user_watches = 8192" >> /etc/sysctl.conf
```

## 6.00 Create a Proxmox pfSense VM on typhoon-01
In this step you will create two OpenVPN Gateways for the whole network using pfSense. These two OpenVPN Gateways will be accessible by any connected devices, LAN or WiFi. The two OpenVPN Gateways are integated into separate VLAN networks:
   * `vpngate-world` - VLAN30 - This VPN client (used as a gateway) randomly connects to servers from a user determined safe list which should be outside of your country or union. A safer zone.
   * `vpngate-local` - VLAN40 - This VPN client (used as a gateway) connects to servers which are either local, incountry or within your union and should provide a faster connection speed. 

### 6.01 Download the latest pfSense ISO
Use the Proxmox web gui to add the Proxmox installation ISO which is available from [HERE](https://www.pfsense.org/download/) or use a Proxmox typhoon-01 cli `>Shell` and type the following:

For the Stable pfSense 2.4 (***Recommended - this is what I use***):
```
wget https://sgpfiles.pfsense.org/mirror/downloads/pfSense-CE-2.4.4-RELEASE-p3-amd64.iso.gz -P /var/lib/vz/template/iso && gzip -d /var/lib/vz/template/iso/pfSense-CE-2.4.4-RELEASE-p3-amd64.iso.gz
```
For the Development pfSense version 2.5:
```
wget https://snapshots.pfsense.org/amd64/pfSense_master/installer/pfSense-CE-2.5.0-DEVELOPMENT-amd64-latest.iso.gz -P /var/lib/vz/template/iso && gzip -d /var/lib/vz/template/iso/pfSense-CE-2.5.0-DEVELOPMENT-amd64-latest.iso.gz
```

### 6.02 Create the pfSense VM
You can create a pfSense VM by either using CLI or by the webgui.

For the webgui method go to Proxmox web interface of your Qotom node (should be https://192.168.1.101:8006/ ) `typhoon-01` > `Create VM` and fill out the details as shown below (whats not shown below leave as default)

| Description | Value |
| :---  | :---: |
| Node |`typhoon-01`|
| VM ID | `253` |
| Name | `pfsense` |
| Start at Boot | `Enabled` |
| Start/Shutdown order | `1` |
| Resource Pool | Leave blank |
| Use CD/DVD disc image file (ISO) | `pfSense-CE-2.4.4-RELEASE-p3-amd64.iso` |
| Guest OS | `Other` |
| Graphic card | `Default` |
| Qemu Agent | `Disabled` |
| SCSI Controller | `VirtIO SCSI` |
| BIOS | `Default (SeaBIOS)` |
| Machine | `Default (i440fx)` |
| Bus/Device | `VirtIO Block 0` |
| Storage | `typhoon-share` |
| Disk size (GiB) | `32` |
| Cache | `Default (No Cache)` |
| Sockers | `1` |
| Cores | `2` |
| Type | `host` |
| Memory (MiB) | `4096` |
| Minimum Memory (MiB) | `4096` |
| Ballooning Device | `Enabled` |
| Bridge | `vmbr0` |
| Model | `VirtIO (paravirtualized)` |
| Start after created | `Disabled` |

Now using the Proxmox web interface `typhoon-01` > `251 (pfsense)` > `Hardware` > `Add` > `Network Device` create the following additional network bridges as shown below:

| Description | Value |
| :---  | :---: |
| Bridge | **`vmbr1`** |
| VLAN Tag | `no VLAN` |
| Model | `VirtIO (paravirtualized)` |
|||
| Bridge | **`vmbr2`** |
| VLAN Tag | `no VLAN`|
| Model | `VirtIO (paravirtualized)` |
|||
| Bridge | **`vmbr3`** |
| VLAN Tag | `no VLAN` |
| Model | `VirtIO (paravirtualized)` |

Or if you prefer you can simply use Proxmox typhoon-01 cli `>Shell` and type the following to achieve the same thing (Note: the below script is for a Qotom Mini PC Q500G6-S05 with 6x Gigabit NICs ONLY):

For the Stable pfSense 2.4.4 (***Recommended - this is what I use***):
```
qm create 253 --bootdisk virtio0 --cores 2 --cpu host --ide2 local:iso/pfSense-CE-2.4.4-RELEASE-p3-amd64.iso,media=cdrom --memory 4096 --name pfsense --net0 virtio,bridge=vmbr0,firewall=1 --net1 virtio,bridge=vmbr1,firewall=1 --net2 virtio,bridge=vmbr2,firewall=1 --net3 virtio,bridge=vmbr3,firewall=1 --numa 0 --onboot 1 --ostype other --scsihw virtio-scsi-pci --sockets 1 --virtio0 typhoon-share:32 --startup order=1
```
For the Development pfSense version 2.5:
```
qm create 253 --bootdisk virtio0 --cores 2 --cpu host --ide2 local:iso/pfSense-CE-2.5.0-DEVELOPMENT-amd64-latest.iso,media=cdrom --memory 4096 --name pfsense --net0 virtio,bridge=vmbr0,firewall=1 --net1 virtio,bridge=vmbr1,firewall=1 --net2 virtio,bridge=vmbr2,firewall=1 --net3 virtio,bridge=vmbr3,firewall=1 --numa 0 --onboot 1 --ostype other --scsihw virtio-scsi-pci --sockets 1 --virtio0 typhoon-share:32 --startup order=1
```

### 6.03 Install pfSense on the new VM

The first step is to start the installation. Go to Proxmox web interface of your Qotom node (should be https://192.168.1.101:8006/ ) `typhoon-01` > `253 (pfsense)` > `Start`. When running click on the `>_Console tab` and you should see the installation script running. Follow the prompts and fill out the details as shown below:

| pfSense Installation Step | Value | Notes
| :--- | :--- | :---
| Copyright and distribution notice | `Accept` 	
| Welcome to pfSense / Install pfSense | `<OK>` 	
| Keymap Selection / >>> Continue with default keymap | `<Select>` 	
| Partitioning / Auto (UFS) - Guided Disk Setup | `<OK>`	
| Manual Configuration | `<No>` 	
| Complete | `<Reboot>` 	
| **The reboot phase**		
| Should VLANs be setup now? | `n` 	
| Enter the WAN interface name or 'a' for auto-detection | `vtnet1` | *This a 2Gb LAG WAN exit for pfSense*
| Enter the LAN interface name or 'a' for auto-detection | `vtnet0`	
| Enter the Optional 1 Interface name or 'a' for auto-detection | `vtnet2` | *This is Proxmox Linux Bridge vmbr2, VLAN30 - a 1Gb vpngate-world gateway connection*
| Enter the Optional 2 Interface name or 'a' for auto-detection | `vtnet3` | *This is Proxmox Linux Bridge vmbr3, VLAN40 - a 1Gb vpngate-local gateway connection*
| Do you want to proceed [y:n] |`y`	
| **Installation Phase**	
| Welcome to pfSense (amd64) on pfSense 
| pfSense boot screen has 16 options for further configuration
| Enter an option | `2` | *Type 2 to Set interface(s) IP address*
| Enter the number of the interface you wish to configure | `2` | *Type 2 to configure LAN (vtnet0 - static)*
| Enter the new LAN IPv4 address | `192.168.1.253` | *This will be the new pfSense webgui interface IP address*
| Enter the new LAN IPv4 subnet bit count | `24` 	
| For a WAN / For a LAN, press for none | `Press ENTER` | *Hit the key*
| Enter the new LAN IPv6 address, press for none | `Press ENTER` | *Hit the key*
| Do you want to enable the DHCP server on LAN? (y/n) | `n`	
| Do you want to revert to HTTP as the webConfigurator protocol? (y/n) | `y`	

You can now access the pfSense webConfigurator by opening the following URL in your web browser: http://192.168.1.253/

## 7.00 Create a pfSense Backup
If all is working its best to make a backup of your pfsense configuration. Also if you experiment around a lot, it’s an easy way to restore back to a working configuration. Also, do a backup each and every time before upgrading to a newer version of your firewall or pfSense OS. So in the event you have to rebuild pfSense you can skip Steps 7.0 onwards by using the backup restore feature which will save you a lot of time.

On your pfSense WebGUI navigate to `Diagnostics` > `Backup & Restore` then fill up the necessary fields as follows:

| Backup Configuration | Value | Notes
| :---  | :--- | :--- |
| Backup area | `All` | *Select All*
| Skip Packages | `[]` Do not backup package information | *Uncheck the box*
| Skip RRD data | `☑` Do not backup RRD data (NOTE: RRD Data can consume 4+ megabytes of config.xml space!)| *Check the box. RRD Data are your Graphs. Like the traffic Graph for example. I do not back them up because I do not need them*
| Encyption | `[]` Encrypt this configuration file. | *If you check this box a password value box will appear. Dont forget your password otherwise you are truly stuffed if you need to perform a restore*
| Password (optional box) | `xxxxxxxx` | *See above*

And then click the `Download configuration as XML` and `Save` the backup XML file to your NAS or a secure location. Note: If you are using the WebGUI on a Win10 PC the XML backup file will be saved in your users `Downloads` folder where you can then copy/move the file to a safer location. You should have a backup folder share on your NAS so why not store the XML file there `backup/pfsense/config-pfSense.localdomain-2019xxxxxxxxxx.xml`

## 8.00 Create a Cluster
At this stage you should have 3x fully built and ready Proxmox nodes on the same network - Typhoon-01, Typhoon-02 and Typhoon-03. You can need create a 3x node cluster.

### 8.01 Create the Cluster
Now using the pfSense web interface on node-01, Typhoon-01, go to `Datacenter` > `Cluster` > `Create Cluster` and fill out the fields as follows:

| Create Cluster | Value | Notes
| :---  | :--- | :--- |
| Cluster Name | `typhoon-cluster` |
| Ring 0 Address | Leave Blank |

And Click `Create`.

### 8.02 Join the other Nodes to the New Cluster
The first step in joining other nodes to your cluster, `typhoon-cluster`, is to copy typhoon-01 cluster manager fingerprint/join information into your clipboard.

**Step One:**

Now using the pfSense web interface on node-01, Typhoon-01, go to `Datacenter` > `Cluster` > `Join Information` and a new window will appear showing `Cluster Join Information` with the option to `Copy Information` into your clipboard. Click `Copy Information`.

**Step Two:**

Now using the pfSense web interface on the OTHER Nodes, Typhoon-02/03/04 etc, go to `Datacenter` > `Cluster` > `Join Cluster` and a new window will appear showing `Cluster Join` with the option to paste the `Cluster Join Information` into a `Infoprmation` field. Paste the information, enter your root password into the `Password` field and the other fields will automatically be filled.

And  Click `Join`. Repeat for on all nodes.

The result should be any configuration can now be done via a single Proxmox web interface. Just point your browser to the IP address given during installation (https://192.168.1.101:8006) and all 3x nodes should be shown below `Datacenter (typhoon-cluster)`. Or type `pvecm status` into any node `typhoon-01` > `>_Shell`:

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

### 8.03 How to delete a existing cluster on a node
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
