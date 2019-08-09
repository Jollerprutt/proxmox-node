# Proxmox Node Building
This recipe builds two physical hardware Proxmox nodes and one Synology VM Proxmox node. Such a group of nodes is called a cluster and has a central management WebGUI by a single URL/IP address. Because a cluster of 3x nodes can form a quorum we have High Availability in the event a node fails.

The hardware in this recipe uses:
>  *  1x Qotom Mini PC Q500G6-S05 with 6x Gigabit NICs;
>  *  1x Intel i3 NUC model nuc5i3ryh; 
>  *  1x Synology DS1515+ with 4x NICs; and,
>  *  Ubiquiti Network Switches.

Both the Qotom Mini PC Q500G6-S05 and Intel NUC model nuc5i3ryh are low wattage at 15W TDP, Intel CPU's are all 2x core / 4x thread Intel CPUs, support for Intel AES-NI instruction sets (for OpenVPN which is single threaded only), all have Intel NIC's, and all have at least 2x SATA 6.0 Gb/s Ports each to support SSD's. Each node is installed with a minimum of 16Gb of RAM. 

I also use Ubiquiti Network gear which is a dream to configure and maintain. 

Obviously you can modify these instructions to meet your own hardware requirements.

Network prerequisites are:
- [x] Layer 2 Network Switches
- [x] Network Gateway is `192.168.1.5`
- [x] Network DNS server is `192.168.1.5` (Note: your Gateway hardware should enable you to a configure DNS server(s), like a UniFi USG Gateway, so set the following: primary DNS `192.168.1.254` which will be your PiHole server IP address; and, secondary DNS `1.1.1.1` which is a backup Cloudfare DNS server in the event your PiHole server 192.168.1.254 fails or os down)
- [x] Network DHCP server is `192.168.1.5`
- [x] A DDNS service is fully configured and enabled (I recommend you use the free Synology DDNS service)
- [x] A ExpressVPN account (or any preferred VPN provider) is valid and its smart DNS feature is working (public IP registration is working with your DDNS provider)

Other Prerequisites are:
- [x] Synology NAS is `192.168.1.10`
- [x] Synology NAS is installed with Synology Virtual Machine Manager
- [x] Synology NAS is configured, including NFS, as per [synobuild](https://github.com/ahuacate/synobuild)

Tasks to be performed are:
- [ ] 1.0 Proxmox Base OS Installation
- [ ] 2.0 Prepare your Network Hardware - Ready for Typhoon-01
- [ ] 3.0 Easy Installation Option
- [ ] 4.0 Basic Proxmox node configuration
- [ ] 5.0 Create a Proxmox pfSense VM on typhoon-01
- [ ] 6.0 Install pfSense on the new VM
- [ ] 7.0 Setup pfSense
- [ ] 8.0 Install & Setup pfBlockerNG on pfSense
- [ ] 9.0 Create a pfSense Backup
- [ ] 10.0 Create a Cluster
- [ ] 11.0 pfSense – disable firewall with CLI pfctl -d

## 1.0 Proxmox Base OS Installation
Each Proxmox node requires two SSD hard disks. Basically one is for the Proxmox OS and the other disk is configured as a Proxmox ZFS shared storage disk.

In these instructions SCSi and SATA controller devices designate disk names such as sda,sdb,sdc and so on, a generic linux naming convention, are referred to as `sdx` only. This is because despite Disk 1 often being device sda in some hardware it may not be. So its best to first check your hardware and note which device is designated to which type of hard disk you have installed. This is important because the disk you have chosen to used as your Proxmox ZFS shared storage disk, a SSD size of at least 250 Gb,  should NOT have your OS installed on it. So for ease of writing and to avoid confusion all SATA disk devices are referred to as sdx.

Each Proxmox node requires a OS SSD disk, disk 1, minimum size of 60 Gb. But I recommend a 120 Gb SSD disk - the smallest these days. You could use a USB dom for the Proxmox OS but a generic consumer USB thumbdrive or SDcard is **NOT RECOMMENDED** because Proxmox has a fair amount of Read/Write activity.

For Disk 2 (sdx) I recommend a 500 Gb SSD which will be used as a Proxmox ZFS shared storage disk for the cluster. But my installation uses a 250 Gb SSD.

Create your Proxmox installation USB media (instructions [here](https://pve.proxmox.com/wiki/Install_from_USB_Stick)), set your nodes bios boot loader order to Hard Disk first / USB second (so you can boot from your proxmox installation USB media), and install proxmox.

For your Synology Virtual Machine Proxmox VM build follow the the instructions [HERE](https://github.com/ahuacate/synobuild/blob/master/README.md#install--configure-synology-virtual-machine-manager).

Remember to remove your USB media on reboot on the hard metal hardware.

Configure each node as follows:

| Option | Node 1 Value | Node 2 Value | Node 3 Value | Notes |
| :---  | :---: | :---: | :---: | :--- |
| **Hardware Type** | **Qotom - Multi NIC** | **Generic PC - Single NIC** | **Synology VM**
| Target Disk | Select `120Gb` | Select `120Gb` | Select `120Gb` | *Not the largest disk for shared storage*
| Target Disk - Options Filesystem |`ext4`|`ext4`|`ext4`| *Leave Default - ext4 etc*
| Country |Type your Country|Type your Country|Type your Country
| Timezone |Select |Select|Select
| Keymap |`en-us`|`en-us`|`en-us`
| Password | Enter your new password | 	Enter your new password |  	Enter your new password | *Same root password on all nodes*
| E-mail |Enter your Email|Enter your Email|Enter your Email | *If you dont want to enter a invalid email type mail@example.com*
| Management interface |Leave Default|Leave Default|Leave Default
| Hostname |`typhoon-01.localdomain`|`typhoon-02.localdomain`|`typhoon-03.local.domain`
|IP Address |`192.168.1.101`|`192.168.1.102`|`192.168.1.103`
| Netmask |`255.255.255.0`|`255.255.255.0`|`255.255.255.0`
| Gateway |`192.168.1.5`|`192.168.1.5`|`192.168.1.5`
| DNS Server |`192.168.1.5`|`192.168.1.5`|`192.168.1.5`

**Note:** Node 1 MUST BE your Qotom.

### 1.1 Configure the Proxmox Hardware
Further configuration is done via the Proxmox web interface. Just point your browser to the IP address given during installation (https://yournodesipaddress:8006) and ignore the security warning by clicking `Advanced` then `Accept the Risk and Continue` -- this is the warning I get in Firefox. Default login is "root" (realm PAM) and the root password you defined during the installation process.

### 1.2 Update Proxmox OS and enable turnkeylinux templates
Using the web interface `updates` > `refresh` search for all the latest required updates. You will get a few errors which ignore.
Next install the updates using the web interface `updates` > `_upgrade` - a pop up terminal will show the installation steps of all your required updates and it will prompt you to type `Y` so do so.

Next install turnkeylinux container templates by using the web interface CLI `shell` and type
`pveam update`

### 1.3 Create Disk Two - your shared storage
Create Disk 2 using the web interface `Disks` > `ZFS` > `Create: ZFS` and configure each node as follows:

| Option | Node 1 Value | Node 2 Value | Node 3 Value |
| :---  | :---: | :---: | :---: |
| Name |`typhoon-share`|`typhoon-share`|`typhoon-share`
| RAID Level |`Single Disk`|`Single Disk`|`Single Disk`
| Compression |`on`|`on`|`on`
| ashift |`12`|`12`|`12`
| Device |`/dev/sdx`|`/dev/sdx`|`/dev/sdx`

**Note:** If your choose to use a ZFS Raid (2 or more disks) for storage redundancy change accordingly per node but you must retain the Name ID **typhoon-share**.

## 2.0 Prepare your Network Hardware - Ready for Typhoon-01
For our primary Proxmox machine, typhoon-01, we use Qotom hardware because it has 2, 4 or 6 network 1Gb NICs depeniding on the model. Standard hardware, such as a  a Intel Nuc, or any other single network NIC host (including Synology Virtual Machines) has only 1 network NIC.

In the following setup we use a Qotom Mini PC model Q500G6-S0 which has 6x Gigabit LAN ports connected to our network switch.

In order to create VLANs within a Virtual Machine (VM) for containers like Docker or a LXC, you need to have a Linux Bridge. Because we use a Qotom with 6x Gigabit NICs we can use NIC bonding (also called NIC teaming or Link Aggregation, LAG) which is a technique for binding multiple NIC’s to a single network device. By doing link aggregation, two NICs can appear as one logical interface, resulting in double speed. This is a native Linux kernel feature that is supported by most smart L2/L3 switches with IEEE 802.3ad support.

If you are using a Qotom 4x Gigabit NIC model then you CANNOT create LAGS/Bonds because you do not have enough ports. So configure Proxmox bridges only.

We are going to use 802.3ad Dynamic link aggregation (802.3ad)(LACP) so your switch must be 802.3ad compliant. This creates aggregation groups of NICs which share the same speed and duplex settings as each other. A link aggregation group (LAG) combines a number of physical ports together to make a single high-bandwidth data path, so as to implement the traffic load sharing among the member ports in the group and to enhance the connection reliability.

### 2.1 Configure your Network Switch
These instructions are based on a UniFi US-24 port switch. Just transpose the settings to UniFi US-48 or whatever brand of Layer 2 switch you use. As a matter of practice I make the last switch ports 21-24 (on a UniFi US-24 port switch) a LAG Bond or Link Aggregation specically for the Synology NAS connection (referred to as 'balanced-TCP | Dynamic Link Aggregation IEEE 802.3ad' in the Synology network control panel) and the preceding 6x ports are reserved for the Qotom (typhoon-01) hosting the pfSense OpenVPN Gateways.

Configure your network switch LAG groups as per following table.

| 24 Port Switch | Port ID | Port ID |Port ID | Port ID |Port ID | Port ID | Port ID |Port ID | Port ID |Port ID | Port ID | Port ID |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
|**Port Number** | `1` | `3` |`5` | `7` |`9` | `11` | `13` | `15` |`17` | `19` |`21` | `23` |
|**Port Number** | `2` | `4` |`6` | `8` |`10` | `12` | `14` | `16` |`18` | `20` |`22` | `24` |
|**LAG Bond** |  |  | |  | |  |  | LAG 15-16 | LAG 17-18 |  | LAG 21-24 | LAG 21-24 |
|**Switch Port Profile / VLAN** |  |  | |  | |  |  | All | VPN-egress (2) | LAN-vpngate-world (30) / LAN-vpngate-local (40) | All | All |
|**LAN CAT6A cable connected to** |  |  | |  | |  | Port14 -> typhoon-02 | Port15+16 -> typhoon-01 (NIC1+2) | Port17+18 -> typhoon-01 (NIC3+4) | Port19 -> typhoon-01 (NIC5) : Port20 -> typhoon-01 (NIC6)  |  |  |
||||||||||||
|**Qotom NIC Ports** |  |  | |  | |  |  | Port 1+2 | Port 3+4 | Port 5+6 |  |  |
|**Proxmox Linux Bond** |  |  | |  | |  |  | `bond0` | `bond1` |  |  |  |
|**Proxmox Bridge** |  |  | |  | |  |  | `vmbr0` | `vmbr1` | `vmbr2/vmbr3` |  |  |
|**Proxmox Comment** |  |  | |  | |  |  | Proxmox LAN Bond | VPN-egress Bond | vpngate-world/vpngate-local|  |  |

Note the **Switch Port Profile / VLAN** must be preconfigured in your network switch (UniFi Controller). The above table, based on a UniFi US-24 model, shows port 15+16 are link agregated (LAG), port 17+18 are another LAG and ports 19 and 20 are not LAG'd. So ports 15 to 20, a total of 6 ports are used by the Qotom. The other LAG, ports 21-24 are used by the Synology.

Steps to configuring your network switch are as follows:
#### 2.2 Create Network Switch VLANs
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

#### 2.3 Setup network switch ports
In this example network switch ingress port 19 is associated with vpngate-world and ingress port 20 is associted with vpngate-local. The below instructions are for the UniFi controller `Devices` > `Select device - i.e UniFi Switch 24/48` > `Ports`  and select port 19 or 20 and `edit` and `apply` as follows:

| Description | Value | Notes |
| :---  | :---: | :--- |
| Name |**`Port 19`**|  |
| Switch Port Profile |`LAN-vpngate-world (30)`| *This will put switch port 19 on VLAN30* |
|||
| Name |**`Port 20`**|  |
| Switch Port Profile |`LAN-vpngate-local (40)`| *This will put switch port 20 on VLAN30* |

#### 2.4 Setup network WiFi SSiDs for the VPN service
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

#### 2.5 Edit your UniFi network firewall
On your Proxmox Qotom build (typhoon-01) NIC ports enp3s0 & enp4s0 are bonded to create LAG `bond1`. You will then create in Proxmox a Linux Bridge using `bond1` called `vmbr2`. When you install pfSense VM on typhoon-01 the pfSense and HAProxy software will assign `vmbr2` (bond1) as its WAN interface NIC.

This WAN interface is VLAN2 and named in the UniFi controller software as `VPN-egress`. It's configured with network `Guest security policies` in the UniFi controller therefore it has no access to other network VLANs. The reason for this is explained build recipe for `VPN-egress` shown [HERE](https://github.com/ahuacate/proxmox-node#22-create-network-switch-vlans).

For HAProxy to work you must authorise VLAN2 (WAN in pfSense HAProxy) to have access to your Proxmox LXC server nodes with static IPv4 addresses on VLAN50.

The below instructions are for a UniFi controller `Settings` > `Guest Control`  and look under the `Access Control` section. Under `Pre-Authorization Access` click`**+** Add IPv4 Hostname or subnet` to add the following IPv4 addresses to authorise access for VLAN2 clients:fill out the form details as shown below:

| + Add IPv4 Hostname or subnet | Value | Notes
| :---  | :---: | :---
| IPv4 | 192.168.50.111 | *Jellyfin Server*
| IPv4 | 192.168.50.112 | *Sonarr Server*
| IPv4 | 192.168.50.113 | *Radarr Server*
| IPv4 | 192.168.50.114 | *Sabnzbd Server*
| IPv4 | 192.168.50.115 | *Deluge Server*

And click `Apply Changes`.

As you've probably concluded you must add any new HAProxy backend server IPv4 address(s) to the Unifi Pre-Authorization Access list for HAProxy frontend to have access to those backend VLAN50 servers.

## 3.0 Easy Installation Option
If you have gotten this far and completed Steps 1.0 thru to 2.4 you can proceed to Step 4.0 to manually build your nodes or skip some steps by using CLI build bash scripts. But my bash scripts are written for the Qotom Mini PC model Q500G6-S05 (6x NIC variant) and single NIC hardware only. If you have different hardware, such as a 2x or 4x NIC Qotom or similiar hardware, then my scripts will not work and you best proceed to Step 4.0 and build manually.

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

### 3.1 Script (A) - Qotom Mini PC model Q500G6-S05 build script
This script is for the Qotom Mini PC model Q500G6-S05 model ONLY. 

To execute the script use the Proxmox web interface `typhoon-01` > `>_ Shell` and cut & paste the following into the CLI terminal window and press ENTER:
```
wget https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/typhoon-01-6x_NIC-setup-01.sh -P /tmp && chmod +x /tmp/typhoon-01-6x_NIC-setup-01.sh && bash /tmp/typhoon-01-6x_NIC-setup-01.sh; rm -rf /tmp/typhoon-01-6x_NIC-setup-01.sh
```
If successful you will see on your CLI terminal words **"Looking Good. Rebooting in 5 seconds ......"** and your typhoon-01 machine will reboot. You can now proceed to Step 6.0.

### 3.2 Script (B) - Single NIC Hardware build script
This script is for single NIC hardware ONLY (i.e Intel NUC etc). 

To execute the script use the Proxmox web interface `typhoon-02/03/04` > `>_ Shell` and cut & paste the following into the CLI terminal window and press ENTER:
```
wget https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/typhoon-0X-Single_NIC-setup-01.sh -P /tmp && chmod +x /tmp/typhoon-0X-Single_NIC-setup-01.sh && bash /tmp/typhoon-0X-Single_NIC-setup-01.sh; rm -rf /tmp/typhoon-0X-Single_NIC-setup-01.sh
```
If successful you will see on your CLI terminal words **"Looking Good. Rebooting in 5 seconds ......"** and your typhoon-01 machine will reboot. This hardware is now ready to deploy into a cluster assumming you have fully built typhoon-01.

### 3.3 Script (C) - Synology or NAS VM build script
This script is for a Proxmox VM build only (i.e Synology Virtual Machine Manager VM). 

To execute the script use the Proxmox web interface `typhoon-02/03/04` > `>_ Shell` and cut & paste the following into the CLI terminal window and press ENTER:
```
wget https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/typhoon-0X-VM-setup-01.sh -P /tmp && chmod +x /tmp/typhoon-0X-VM-setup-01.sh && bash /tmp/typhoon-0X-VM-setup-01.sh; rm -rf /tmp/typhoon-0X-VM-setup-01.sh
```
If successful you will see on your CLI terminal words **"Looking Good. Rebooting in 5 seconds ......"** and your typhoon-01 machine will reboot. This hardware is now ready to deploy into a cluster assumming you have fully built typhoon-01.

## 4.0 Basic Proxmox node configuration
Some of the basic Proxmox OS configuration tasks are common across all three nodes. The variable is with typhoon-01, the multi NIC device, which will alone have a guest pfSense VM installed to manage your networks OpenVPN Gateway services (no redundancy for OpenVPN services as its deemed non critical).

Configuration options are determined by hardware types:
   * Node 1 - typhoon-01 - Qotom Mini PC Q500G6-S05 is a 6x Gigabit NIC Router (6 LAN ports).
   * Node 2 - typhoon-02 - A single NIC x86 machine (1 LAN port).
   * Node 3 - typhoon-03 - Synology VM (1 Virtio LAN port)

### 4.1  Create NFS mounts to NAS
All three Proxmox nodes use NFS to mount data stored on a NAS so these instructions are applicable for all proxmox nodes. Your NFS server should be prepared and ready - Synology NFS Server instructions are available [HERE](https://github.com/ahuacate/synobuild#create-the-required-synology-shared-folders-and-nfs-shares).

The NFS mounts to be configured are: | `backup` | `docker`| `music` | `photo` | `public` | `video` | 
Configuration is by the Proxmox web interface. Just point your browser to the IP address given during installation (https://yournodesipaddress:8006). Default login is "root" (realm PAM) and the root password you defined during the installation process.

Now using the web interface `Datacenter` > `Storage` > `Add` > `NFS` configure the NFS mounts as follows on all three nodes:

| Cyclone-01-backup | Value |
| :---  | :---: |
| ID |`cyclone-01-backup`|
| Server |`192.168.1.10`|
| Export |`/volume1/proxmox/backup`|
| Content |`VZDump backup file`|
| Nodes |leave as default|
| Enable |leave as default|
|||
| **Cyclone-01-docker** | **Value** |
| ID |`cyclone-01-docke`r|
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

### 4.2 Configure Proxmox bridge networking
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

### 4.3 Edit your Proxmox hosts file
Go to Proxmox web interface of your node `typhoon-0X` > `System` > `Network` > `Hosts`  and replace the contents with the following:

```
127.0.0.1 localhost.localdomain localhost
# Proxmox Hosts
192.168.1.101 typhoon-01.localdomain typhoon-01
192.168.1.102 typhoon-02.localdomain typhoon-02
192.168.1.103 typhoon-03.localdomain typhoon-03
192.168.1.104 typhoon-04.localdomain typhoon-04
# NAS Storage
192.168.1.10 cyclone-01.localdomain cyclone-01
192.168.1.11 cyclone-02.localdomain cyclone-02
# Docker Nodes
192.168.1.111 ds-01.localdomain ds-01
192.168.1.112 ds-02.localdomain ds-02
192.168.1.113 ds-03.localdomain ds-03
192.168.1.114 ds-04.localdomain ds-04
192.168.1.115 ds-05.localdomain ds-05
192.168.1.116 ds-06.localdomain ds-06
192.168.1.117 ds-07.localdomain ds-07
192.168.1.118 ds-08.localdomain ds-08
192.168.1.119 ds-09.localdomain ds-09
# VM Machines
192.168.1.253 pfsense.localdomain pfsense
# LXC Machines
192.168.1.6 unifi.localdomain unifi
192.168.1.254 pihole.localdomain pihole
192.168.50.20 jellyfin.localdomain jellyfin
# The following lines are desirable for IPv6 capable hosts
::1     ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
```
Then click `Save`.

### 4.4 Create a new Proxmox user
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

## 5.0 Create a Proxmox pfSense VM on typhoon-01
In this step you will create two OpenVPN Gateways for the whole network using pfSense. These two OpenVPN Gateways will be accessible by any connected devices, LAN or WiFi. The two OpenVPN Gateways are integated into separate VLAN networks:
   * `vpngate-world` - VLAN30 - This VPN client (used as a gateway) randomly connects to servers from a user determined safe list which should be outside of your country or union. A safer zone.
   * `vpngate-local` - VLAN40 - This VPN client (used as a gateway) connects to servers which are either local, incountry or within your union and should provide a faster connection speed. 

### 5.1 Download the latest pfSense ISO
Use the Proxmox web gui to add the Proxmox installation ISO which is available from [HERE](https://www.pfsense.org/download/) or use a Proxmox typhoon-01 cli `>Shell` and type the following:

For the Stable pfSense 2.4 (***Recommended - this is what I use***):
```
wget https://sgpfiles.pfsense.org/mirror/downloads/pfSense-CE-2.4.4-RELEASE-p3-amd64.iso.gz -P /var/lib/vz/template/iso && gzip -d /var/lib/vz/template/iso/pfSense-CE-2.4.4-RELEASE-p3-amd64.iso.gz
```
For the Development pfSense version 2.5:
```
wget https://snapshots.pfsense.org/amd64/pfSense_master/installer/pfSense-CE-2.5.0-DEVELOPMENT-amd64-latest.iso.gz -P /var/lib/vz/template/iso && gzip -d /var/lib/vz/template/iso/pfSense-CE-2.5.0-DEVELOPMENT-amd64-latest.iso.gz
```

### 5.2 Create the pfSense VM
You can create a pfSense VM by either using CLI or by the webgui.

For the webgui method go to Proxmox web interface of your Qotom node (should be https://192.168.1.101:8006/ ) `typhoon-01` > `Create VM` and fill out the details as shown below (whats not shown below leave as default)

| Description | Value |
| :---  | :---: |
| Node |`typhoon-01`|
| VM ID | `251` |
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
| Storage | `local-lvm` |
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
qm create 253 --bootdisk virtio0 --cores 2 --cpu host --ide2 local:iso/pfSense-CE-2.4.4-RELEASE-p3-amd64.iso,media=cdrom --memory 4096 --name pfsense --net0 virtio,bridge=vmbr0,firewall=1 --net1 virtio,bridge=vmbr1,firewall=1 --net2 virtio,bridge=vmbr2,firewall=1 --net3 virtio,bridge=vmbr3,firewall=1 --numa 0 --onboot 1 --ostype other --scsihw virtio-scsi-pci --sockets 1 --virtio0 local-lvm:32 --startup order=1
```
For the Development pfSense version 2.5:
```
qm create 253 --bootdisk virtio0 --cores 2 --cpu host --ide2 local:iso/pfSense-CE-2.5.0-DEVELOPMENT-amd64-latest.iso,media=cdrom --memory 4096 --name pfsense --net0 virtio,bridge=vmbr0,firewall=1 --net1 virtio,bridge=vmbr1,firewall=1 --net2 virtio,bridge=vmbr2,firewall=1 --net3 virtio,bridge=vmbr3,firewall=1 --numa 0 --onboot 1 --ostype other --scsihw virtio-scsi-pci --sockets 1 --virtio0 local-lvm:32 --startup order=1
```

## 6.0 Install pfSense on the new VM
The first step is to start the installation. Go to Proxmox web interface of your Qotom node (should be https://192.168.1.101:8006/ ) `typhoon-01` > `251 (pfsense)` > `Start`. When running click on the  `>_Console` tab and you should see the installation script running. Follow the prompts and fill out the details as shown below:

| pfSense Installation Step | Value | Notes
| :---  | :---: | :--- |
Copyright and distribution notice | `Accept` |
Welcome to pfSense / Install pfSense | `<OK>` |
Keymap Selection / >>> Continue with default keymap | `<Select>` |
Partitioning / Auto (UFS) - Guided Disk Setup | `<OK>` |
Manual Configuration | `<No>` |
Complete | `<Reboot>` |
***The reboot phase*** |
Should VLANs be setup now? | `n` |
Enter the WAN interface name or 'a' for auto-detection | `vtnet1` | *This a 2Gb LAG WAN exit for pfSense*
Enter the LAN interface name or 'a' for auto-detection| `vtnet0` |
Enter the Optional 1 Interface name or 'a' for auto-detection| `vtnet2` | *This is Proxmox Linux Bridge vmbr2, VLAN30 - a 1Gb vpngate-world gateway connection*
Enter the Optional 2 Interface name or 'a' for auto-detection| `vtnet3` | *This is Proxmox Linux Bridge vmbr3, VLAN40 - a 1Gb vpngate-local gateway connection*
Do you want to proceed [y:n] |`y` |
***Installation Phase*** |
***Welcome to pfSense (amd64) on pfSense*** | | *pfSense boot screen has 16 options for further configuration*
Enter an option| `2` | *Type 2 to Set interface(s) IP address*
Enter the number of the interface you wish to configure| `2` | *Type 2 to configure LAN (vtnet0 - static)*
Enter the new LAN IPv4 address| `192.168.1.253` | *This will be the new pfSense webgui interface IP address*
Enter the new LAN IPv4 subnet bit count| `24` | 
For a WAN / For a LAN, press <ENTER> for none| `Press ENTER` | *Hit the <ENTER> key*
Enter the new LAN IPv6 address, press <ENTER> for none| `Press ENTER` | *Hit the <ENTER> key*
Do you want to enable the DHCP server on LAN? (y/n)| `n` 
Do you want to revert to HTTP as the webConfigurator protocol? (y/n)| `y`

You can now access the pfSense webConfigurator by opening the following URL in your web browser: http://192.168.1.253/

## 7.0 Setup pfSense
You can now access pfSense webConfigurator by opening the following URL in your web browser: http://192.168.1.253/ . In the pfSense webConfigurator we are going to setup two OpenVPN Gateways, namely vpngate-world and vpngate-local. Your default login details are User > admin | Pwd > pfsense

### 7.1 Change Your pfSense Password
Now using the pfSense web interface `System` > `User Manager` > `click on the admin pencil icon` and change your password to something more secure. Remember to hit the `Save` button at the bottom of the page.

### 7.2 Enable AES-NI 
If your CPU supports AES-NI CPU Crypto best enable it.

Now using the pfSense web interface `System` > `Advanced` > `Miscellaneous Tab` scroll down to the section `Cryptographic & Thermal Hardware` and change the details as shown below:

| Cryptographic & Thermal Hardware | Value | Notes
| :---  | :---: | :--- |
| Cryptographic Hardware | `AES-NI CPU-based Accelleration` | *This works for the Qotom Mini PC Q500G6-S05 series and modern hardware*
| Thermal Sensors | None/ACPI | *Will not work because Proxmox virtualization host will NOT forward CPU temperature data to it's pfSense guest*

Remember to hit the `Save` button at the bottom of the page.

### 7.3 Add DHCP Servers to OPT1 and OPT2 and fix a Static IPv4 to WAN
Now using the pfSense web interface `Interfaces` > `OPT1` to open a configuration form, then fill up the necessary fields as follows:

| Interfaces/OPT1 (vtnet2) | Value | Notes
| :---  | :---: | :--- |
| Enable | `☑` | *Check the box*
| Description | `OPT1`
| IPv4 Configuration Type | `Static IPv4`
| Ipv6 Configuration Type | `None`
| MAC Address | Leave blank
| MTU | Leave blank
| MSS | Leave blank
| Speed and  Duplex | `Default (no preference, typically autoselect)`
| **Static IPv4 Configuration**
| IPv4 Address | `192.168.30.5/24`
| IPv4 Upstream gateway | `None`
| **Reserved Networks**
| Block private networks and loopback addresses | `[ ]` | *Uncheck the box*
| Block bogon networks | `[]` | *Uncheck the box*

And click `Save`.

Now using the pfSense web interface `Interfaces` > `OPT2` to open a configuration form, then fill up the necessary fields as follows:

| Interfaces/OPT2 (vtnet3) | Value | Notes
| :---  | :---: | :--- |
| Enable | `☑` | *Check the box*
| Description | `OPT2`
| IPv4 Configuration Type | `Static IPv4`
| Ipv6 Configuration Type | `None`
| MAC Address | Leave blank
| MTU | Leave blank
| MSS | Leave blank
| Speed and  Duplex | `Default (no preference, typically autoselect)`
| **Static IPv4 Configuration**
| IPv4 Address | `192.168.40.5/24`
| IPv4 Upstream gateway | `None`
| **Reserved Networks**
| Block private networks and loopback addresses | `[]` | *Uncheck the box*
| Block bogon networks | `[]` | *Uncheck the box*

And click `Save`.

Now using the pfSense web interface `Interfaces` > `WAN` to open a configuration form, then edit the necessary fields to match the following:

| Interfaces/WAN (vtnet1) | Value | Notes
| :---  | :---: | :--- |
| Enable | `☑` | *Check the box*
| Description | `WAN`
| IPv4 Configuration Type | `Static IPv4`
| Ipv6 Configuration Type | `None`
| MAC Address | Leave blank
| MTU | Leave blank
| MSS | Leave blank
| Speed and  Duplex | `Default (no preference, typically autoselect)`
| **Static IPv4 Configuration**
| IPv4 Address | `192.168.2.1/28`
| IPv4 Upstream gateway | Click `Add a new Gateway` | `First create the new gateway, then select it`
| **NewIPv4 Gateway**
| Default | `☑` Default gateway
| Gateway Name |`WANGW`
| Gateway IPv4 | `192.168.2.5`
| Description | `WAN/VPN Egress Gateway` | *And click `Save` to create the new gateway*
| **Reserved Networks**
| Block private networks and loopback addresses | `[]` | *Uncheck the box*
| Block bogon networks | `[]` | *Uncheck the box*

And click `Save`.

### 7.4 Setup DHCP Servers for OPT1 and OPT2
Now using the pfSense web interface `Services` > `DHCP Server` > `OPT1 Tab` or `OPT2 Tab` to open a configuration form, then fill up the necessary fields as follows:

| General Options | OPT 1 Value | OPT2 Value | Notes |
| :---  | :---: | :---: | :---
| Enable | `☑` |  `☑` | *Opt1&2 Check the box*
| BOOTP | `[ ]` | `[ ]` | *Disable*
| Deny unknown clients | `[ ]` | `[ ]` | *Disable*
| Ignore denied clients | `[ ]` | `[ ]` | *Disable*
| Ignore client identifiers | `[ ]` | `[ ]` | *Disable*
| Subnet | 192.168.30.0 | 192.168.40.0 |
| Subnet mask |255.255.255.0 | 255.255.255.0 | 
| Available range | 192.168.30.1 - 192.168.30.254 | 192.168.40.1 - 192.168.40.254 |
| Range | `192.168.30.150 - 192.168.30.250` | `192.168.40.150 - 192.168.40.250` |
| **Servers**
| WINS servers | Leave blank
| DNS servers | Leave Blank | Leave Blank | *DNS Server 1-4: Must leave all blank. We are going to use DNS Resolver for DNS tasks. If you add DNS here then pFBlockerNG will not work.*
| **Other Options**
| Gateway | `192.168.30.5` | `192.168.40.51`
| Default Lease time | `86320` | `86320`
| Maximum lease time | `86400` | `86400`

Remember to hit the `Save` button at the bottom of the page.

### 7.5 Add your OpenVPN Client Server details
Here we going to create OpenVPN clients vpngate-world and vpngate-local. You will need your VPN account server username and password details and have your vpn server provider OVPN configuration file open in a text editor so you can copy various certificate and key details (cut & paste). Note the values for this form will vary between different VPN providers but there should be a tutorial showing your providers pfSense configuration settings on the internet somewhere. 

Now using the pfSense web interface `System` > `Cert. Manager` > `CAs` > `Add` to open a configuration form, then fill up the necessary fields as follows:

| Create/Edit CA | Value | Notes
| :---  | :---: | :--- |
| Descriptive name | `ExpressVPN` | *Or whatever your providers name is, ExpressVPN, PIA etc*
| Method | `Import an existing Certificate Authority`
| **Existing Certificate Authority**
| Certificate data | `Insert your key data` | *Open the OpenVPN configuration file that you downloaded and open it with your favorite text editor. Look for the text that is wrapped within the <ca> portion of the file. Copying the entire string from —–BEGIN CERTIFICATE—– to —–END CERTIFICATE—–* |
| Certificate Private Key (optional) | Leave this blank
| Serial for next certificate | Leave this blank

Click `Save`. Stay on this page and click `Certificates` at the top. Click `Add`enter the following:

| Add/Sign a New Certificate | Value | Notes
| :---  | :---: | :--- |
| Descriptive name | `ExpressVPN Cert` | *Or whatever your providers name is, PIA Cert etc*
| **Import Certificate**
| Certificate data | `Insert your key data` | *Open the OpenVPN configuration file that you downloaded and open it with your favorite text editor. Look for the text that is wrapped within the <cert> portion of the file. Copy the entire string from —–BEGIN CERTIFICATE—– to —–END CERTIFICATE—–*
| Private key data | `Insert your key data` | *With your text editor still open, look for the text that is wrapped within the <key> portion of the file. Copy the entire string from —–BEGIN RSA PRIVATE KEY—– to —-END RSA PRIVATE KEY—-*

Click `Save`.

Now using the pfSense web interface `VPN` > `OpenVPN` > `Clients Tab` > `Add` to open a configuration form, then fill up the necessary fields as follows (creating one each for vpngate-world and vpngate-local):

| General Information | Value | Notes
| :---  | :---: | :--- |
| Disabled | Leave this box unchecked
|Server Mode | `Peer to Peer (SSL/TLS)`
| Protocol | `UDP on IPv4 only`
| Device mode | `tun - Layer 3 Tunnel Mode`
| Interface | `WAN`
| Local port | Leave blank
| Server host or address : vpngate-world | `netherlands-amsterdam-ca-version-2.expressnetw.com`| *Open the OpenVPN configuration file that you downloaded and open it with your favorite text editor. Look for text that starts with remote, followed by a server name. Copy the server name string into this field (e.g., if you are in USA maybe you wnat to use servers outside of your jurisdiction like netherlands-amsterdam-ca-version-2.expressnetw.com )*
| Server host or address : vpngate-local | `thailand-ca-version-2.expressnetw.com` | *Open the OpenVPN configuration file that you downloaded and open it with your favorite text editor. Look for text that starts with remote, followed by a server name. Copy the server name string into this field (e.g., if you are in South East Asia maybe you wnat to use servers near your region like thailand-ca-version-2.expressnetw.com )*
| Server port | `1195`
| Proxy host or address | Leave blank
| Proxy port | Leave blank
| Proxy authentication… | leave default
| Server host name resolution | leave default (none)
| Description | `vpngate-world` or `vpngate-local` | *Simply type vpngate-world or vpngate-local for the connection service you are creating*
| **User Authentication Settings**
| Username | `insert your account username`
| Password | `insert your account password`
| Authentication Retry | Leave disabled/default
| **Cryptographic Settings**
| TLS Configuration | `☑ Use a TLS Key` | *Check the box*
| TLS Configuration | `[ ] Automatically generate a TLS Key.` | *Uncheck the box*
| TLS Key | `Insert your key data` | *Open the OpenVPN configuration file that you downloaded and open it with your favorite text editor. Look for text that is wrapped within the <tls-auth> portion of the file. Ignore the “2048 bit OpenVPN static key” entries and start copying from —–BEGIN OpenVPN Static key V1—– to —–END OpenVPN Static key V1—–*
| TLS Key Usage Mode | `TLS Authentication`
| Peer Certificate Authority | `ExpressVPN` | *Select the “ExpressVPN” entry that you created previously in the Cert. Manager steps*
| Client Certificate | `ExpressVPN Cert` | *Select the “ExpressVPN Cert” entry that you created previously in the Cert. Manager steps*
| Encryption Algorithm | `AES-256-CBC` | *Open the OpenVPN configuration file that you downloaded and open it with your favorite text editor. Look for the text cipher. In this example, the OpenVPN configuration is listed as “cipher AES-256-CBC,” so we will select “AES-256-CBC (256-bit key, 128-bit block) from the drop-down*
| Enable NCP | `[ ] Enable Negotiable Cryptographic Parameters` | *Uncheck the box*
| NCP Algorithms | `AES-256-CBC` | Only use/add AES-256-CBC
| Auth digest algorithm | `SHA512 (512-bit)`| *Open the OpenVPN configuration file that you downloaded and open it with your favorite text editor. Look for the text auth followed by the algorithm after. In this example, we saw “auth SHA512,” so we will select “SHA512 (512-bit)” from the dropdown*
| Hardware Crypto | `Intel RDRAND engine - RAND` | *Thats what shows on a Qotom Mini PC Q500G6-S05 which has a AES-NI ready Intel i5-7300U CPU*
| **Tunnel Settings**
| IPv4 Tunnel Network | Leave blank
| IPv6 Tunnel Network | Leave blank
| IPv4 Remote network(s) | Leave blank
| IPv6 Remote network(s) | Leave blank
| Limit outgoing bandwidth | Leave blank
| Compression | `Adaptive LZO Compression`
| Topology | `Leave the default` | *Subnet — One IP address per client in a common subnet*
| Type-of-Service |  [ ] Leave unchecked
| Don't pull routes | `☑`| *Check the box*
| Don't add/remove routes | `☑` | *Check the box*
| **Advanced Configuration**
| Custom options : vpngate-world| `route-nopull;fast-io;persist-key;persist-tun;remote sweden-2-ca-version-2.expressnetw.com 1195;remote singapore-cbd-ca-version-2.expressnetw.com 1195;remote germany-frankfurt-1-ca-version-2.expressnetw.com 1195;remote-random;pull;comp-lzo;tls-client;verify-x509-name Server name-prefix;remote-cert-tls server;key-direction 1;route-method exe;route-delay 2;tun-mtu 1500;fragment 1300;mssfix 1450;verb 3;sndbuf 524288;rcvbuf 524288` | *These options are derived from the OpenVPN configuration you have been referencing. We will be pulling out all custom options that we have not used previously. Note, the addition of `route-nopull`. Also, for redundancy we add other remote servers in the event the primary server fails*
| Custom options : vpngate-local| `route-nopull;fast-io;persist-key;persist-tun;remote-random;pull;comp-lzo;tls-client;verify-x509-name Server name-prefix;remote-cert-tls server;key-direction 1;route-method exe;route-delay 2;tun-mtu 1500;fragment 1300;mssfix 1450;verb 3;sndbuf 524288;rcvbuf 524288` | *These options are derived from the OpenVPN configuration you have been referencing. We will be pulling out all custom options that we have not used previously. Note, the addition of `route-nopull`.*
| UDP Fast I/O | `☑ Use fast I/O operations with UDP writes to tun/tap. Experimental.` | *Check the box*
| Send/Receive Buffer | `512`
| Gateway creation  | `IPv4 Only`
| Verbosity level | `3 (recommended)`

Click `Save`.

Then to check whether the connection works navigate `Status` > `OpenVPN` and Status field for vpngate-world and vpngate-local should show `up`. This means you are connected to your provider.

### 7.6 Add two new Gateways
Next we need to add an interface for each new OpenVPN connection and then a Gateway for each interface. Now using the pfSense web interface `Interfaces` > `Assignments` the configuration form will show two available network ports which can be added, ovpnc1 (vpngate-world) and ovpnc2 (vpngate-local). Now `Add` both and remember to click `Save`.

Then click on the corresponding `Interface` names one at a time, likely to be `OPT3` and `OPT4`,  and edit the necessary fields as follows (editing both OPT3 and OPT4):

The first edit will be `OPT3`:

| Interfaces/OPT3 (ovpnc1) | Value | Notes
| :---  | :---: | :--- |
| Enable | `☑` Enable interface | *Check the box*
| Description | `vpngateworld`
| IPv4/IPv6 Configuration | This interface type does not support manual address configuration on this page.
| MAC Address | `None`
| MTU | Leave blank
| MTU | Leave blank
| MSS | Leave blank
| **Reserved Networks**
| Block private networks and loopback addresses | `[]` | *Uncheck the box*
| Block bogon networks | `[]` | *Uncheck the box*

Now edit `OPT4`:

| Interfaces/OPT4 (ovpnc2) | Value | Notes
| :---  | :---: | :--- |
| Enable | `☑` Enable interface | *Check the box*
| Description | `vpngatelocal`
| IPv4/IPv6 Configuration | This interface type does not support manual address configuration on this page.
| MAC Address | `None`
| MTU | Leave blank
| MTU | Leave blank
| MSS | Leave blank
| **Reserved Networks**
| Block private networks and loopback addresses | `[]` | *Uncheck the box*
| Block bogon networks | `[]` | *Uncheck the box*

Click `Save`.

At this point you are ready to create the firewall rules. Now I would **highly recommend a reboot** here as this was the only thing that made the next few steps work. So do a reboot `Diagnostics` > `Reboot` and perform a `Reboot`. If you dont things might get not work in the steps ahead.

### 7.7 Adding NAT Rules
Next we need to add the NAT rules to allow for traffic to go out of the  VPN encrypted gateway(s), this is done from the `Firewall` > `NAT` > `Outbound Tab`. 

If you have Automatic NAT enabled you want to enable Manual Outbound NAT and click `Save`. Now you will see and be able to edit the NAT Mappings configuration form.

But first you must find any rules that allows the devices you wish to tunnel, with a `Source` value of `192.168.30.0/24` and `192.168.40.0/24` and delete them and click `Save` at the bottom right of the form page. **DO NOT DELETE** the `Mappings` with `Source` values like `127.0.0.0/8, ::1/128, 192.168.1.0/24`!

Now create new mappings by `Firewall` > `NAT` > `Outband Tab` > `Add` to open a new configuration form, then fill up the necessary fields as follows (creating one each for `VLAN30 to vpngate-world` and `VLAN40 to vpngate-local`):

| Edit Advanced Outbound NAT Entry | Value | Value
| :---  | :--- | :--- |
| Disabled | `[]` Disable this rule
| Do not NAT | `[]` Enabling this option will .....
| Interface | `VPNGATEWORLD`
|Address Family | `IPv4+IPv6`
| Protocol | `any`
| Source | `Network` | `192.168.30.0/24`
| Destination | `Any` | Leave blank
| **Translation**
| Address | `Interface Address`
| Port or Range | Leave blank
| **Misc**
| No XMLRPC Sync | `[]`
| Description | `VLAN30 to vpngate-world`

And click `Save`. 

Repeat the above steps for `VLAN40 to vpngate-local` changing to the values as follows:

| Edit Advanced Outbound NAT Entry | Value | Value
| :---  | :--- | :--- |
| Disabled | `[]` Disable this rule
| Do not NAT | `[]` Enabling this option will .....
| Interface | `VPNGATELOCAL`
|Address Family | `IPv4+IPv6`
| Protocol | `any`
| Source | `Network` | `192.168.40.0/24`
| Destination | `Any` | Leave blank
| **Translation**
| Address | `Interface Address`
| Port or Range | Leave blank
| **Misc**
| No XMLRPC Sync | `[]`
| Description | `VLAN40 to vpngate-local`

And click `Save`. 

Now your first two mappings for the new gateways show look like this:

| |Interface|Source|Source Port|Destination|Destination Port|NAT Address|NAT Port|Static Port|Description|
|:--- | :---  | :--- | :--- | :---  | :--- | :--- | :---  | :--- | :--- |
|[]|VPNGATEWORLD|192.168.30.0/24|*|*|*|VPNGATEWORLD address|*|:heavy_check_mark:|VLAN30 to vpngate-world
|[]|VPNGATELOCAL|192.168.40.0/24|*|*|*|VPNGATELOCAL address|*|:heavy_check_mark:|VLAN40 to vpngate-local

### 7.8 Adding the Firewall Rules
This is simple because we are going to send all the traffic in a subnet(s) (VLAN30 > vpngate-world / VLAN40 > vpngate-local) through the openVPN tunnel. 

So first lets do OPT1 / vpngate-world so go `Firewall` > `Rules` > `OPT1 tab` and `Add` a new rule:

| Edit Firewall Rule / OPT1 | Value | Notes|
| :---  | :--- | :--- |
| Action | `Pass`
| Disabled | `[]` disable this rule
| Interface | `OPT1`
| Addresss Family | `IPv4+IPv6`
| Protocol | `Any`
| **Extra Options**
| Log | `[]` Log packets that are handled by this rule
| Description | `VLAN30 Traffic to vpngate-world`
| Advanced Options | Click `Display Advanced` | *This is a important step. You only want to edit one value in `Advanced`!!!!
| **Advanced Options**
| Gateway | `VPNGATEWORLD_VPNV$-x.x.x.x-Interface VPNGATEWORLD_VPNV4 Gateway` | `MUST Change to this gateway!`

Click `Save`.

Now do OPT2 / vpngate-local so go `Firewall` > `Rules` > `OPT2 tab` and `Add` a new rule:

| Edit Firewall Rule / OPT2 | Value | Notes|
| :---  | :--- | :--- |
| Action | `Pass`
| Disabled | `[]` disable this rule
| Interface | `OPT2`
| Addresss Family | `IPv4+IPv6`
| Protocol | `Any`
| **Extra Options**
| Log | `[]` Log packets that are handled by this rule
| Description | `VLAN40 Traffic to vpngate-local`
| Advanced Options | Click `Display Advanced` | *This is a important step. You only want to edit one value in `Advanced`!!!!*
| **Advanced Options**
| Gateway | `VPNGATELOCAL_VPNV4-x.x.x.x-Interface VPNGATELOCAL_VPNV4 Gateway` | *MUST Change to this gateway!*

Click `Save` and `Apply`.

The above rules will send all the traffic on that interface into the VPN tunnel, you must ensure that the ‘gateway’ option is set to your VPN gateway and that this rule is above any other rule that allows hosts to go out to the internet. pfSense needs to be able to catch this rule before any others.

### 7.9 Setup pfSense DNS
Here will setup different DNS services for each OpenVPN WAN. I do not recommend setting one up for the non-OpenVPN WAN because it may cause DNS leaks when using a OpenVPN Gateway because of how pfSense DNS Resolver works.

Navigate to `System` > `General Settings` and under DNS servers add IP addresses for Cloudflare DNS servers and select your WAN gateway.

| DNS Server Settings | Value | Value | Notes
| :---  | :--- | :--- | :---
| DNS Servers | `85.203.37.1` | `VPNGATEWORLD_VPNV4-opt3-wan-xxxx`
| DNS Servers | `85.203.37.2` | `VPNGATELOCAL_VPNV4-opt4-wan-xxxx`
| **Below is Optional BUT not recommended**
| DNS Servers | `1.1.1.1` | `WAN_DHCP - wan-xxxx`

After entering the DNS IP addresses, scroll down to the bottom of the page and click `Save`. Your pfSense appliance is now configured for DNS servers.

**Note:** The problem with setting up DNS for WAN (non encrypted gateway) is in the event OpenDNS queries fail, it will likely use 127.0.0.1 (itself - host) as another available DNS server. But if you must, I recommend you use Cloudflare’s DNS service which is arguably the best DNS servers to use in pfSense and here we configure Cloudfare DNS over TLS for added security.

To configure the pfSense DNS resolver to send DNS queries over TLS, navigate to `Services` > `DNS Resolver` and on the tab `General Settings` scroll down to the `Display Custom Options` box. Enter the following lines (you should be able to simply copy / paste the section text block below):
```
server:
forward-zone:
name: "."
forward-ssl-upstream: yes
forward-addr: 1.1.1.1@853
forward-addr: 1.0.0.1@853
```
After entering the above code, scroll down to the bottom of the page and click `Save` and then to the top of the page click `Apply Changes`.

### 7.9.1 Set Up DNS Resolver
To configure the pfSense DNS resolver navigate to `Services` > `DNS Resolver` and on the tab `General Settings` fill up the necessary fields as follows:

| General Settings | Value | Notes
| :---  | :--- | :--- 
| Enable | `☑ Enable DNS resolver` | 
| Listen Port | Leave Default | 
| Enable SSL/TLS Service | `[]` | 
| SSL/TLS Certificate | Leave Default | 
| SSL/TLS Listen Port | Leave Default | 
| Network Interfaces | `OPT1` | *Select ONLY OPT1, OPT2 and Localhost - Use the Ctrl key to toggle selection*
||`OPT2`
||`Localhost`
| Outgoing Network Interfaces | `VPNGATEWORLD` |*Select ONLY VPNGATEWORLD and VPNGATELOCAL - Use the Ctrl key to toggle selection*
|| `VPNGATELOCAL`
| System Domain Local Zone Type | `Transparent` | 
| DNSSEC | `☑ Enable DNSSEC Support` | 
| DNS Query Forwarding | `[]` Enable Forwarding Mode | *Uncheck*
|| `[]` Use SSL/TLS for outgoing DNS Queries to Forwarding Servers | *Uncheck*
| DHCP Registration | `[]` Register DHCP leases in the DNS Resolver | *Uncheck*
| Static DHCP | `[]` Register DHCP static mappings in the DNS Resolver | *Uncheck*
| OpenVPN Clients | `[]` Register connected OpenVPN clients in the DNS Resolver | *Uncheck*
| **Below is Optional only if you want add TLS and Cloudfare DNS as shown in Step 7.9 - Not Recommended**
| Display Custom Options | Click `Display Custom Options` | 
| Custom options  | server:
||forward-zone:
||name: "."
||forward-ssl-upstream: yes
||forward-addr: 1.1.1.1@853
||forward-addr: 1.0.0.1@853
||server:include: /var/unbound/pfb_dnsbl.*conf | 

### 7.9.1 Finish Up
After all your rules are in place head over to `Diagnostics` > `States` > `Reset States Tab` > and tick `Reset the firewall state table` click `Reset`. After doing any firewall changes that involve a gateway change its best doing a state reset before checking if anything has worked (odds are it will not work if you dont). PfSense WebGUI may hang for period but dont despair because it will return in a few seconds for routing to come back and up to a minute, don’t panic.

And finally navigate to `Diagnostics` > `Reboot` and reboot your pfSense machine.

Once you’re done head over to any client PC on the network or mobile on the WiFi SSID on either `vpngate-world` VLAN30 or `vpngate-local` VLAN40 networks and use IP checker to if its all working https://wtfismyip.com

Success! (hopefully)

## 8.0 Install & Setup pfBlockerNG on pfSense
pfBlockerNG can add other security enhancements such as blocking known bad IP addresses with blocklists. For example, getting rid of adverts and pop-ups from websites. If you don’t already have a blocklist functionality in place on your pfSense (such as PiHole), I would strongly suggest adding pfBlockerNG Devel to your new OpenVPN Gateways (VPNGGATEWORLD and VPNGATELOCAL).

### 8.1 pfBlockerNG Installation
In the pfSense WebGUI go to `System` > `Package Manager` > `Available Packages` and type ‘pfblocker’ into the search criteria and then click `Search`.

Make sure you click `+ Install` on the version with ‘-devel’ (i.e pfBlockerNG-devel) at the end of it, and then `Confirm` on the next page. Installation may take a short while as it downloads and updates certain packages.  

At this point, you have already installed the package. Next, you will need to enable it from pfSense WebGUI `Firewall` > `pfBlockerNG` and the option to exit out of the wizard. A configuration page should appear, Click on the `General Tab`, and fill out the necessary fields as follows:

| General Settings | Value | Value | Value | Value | Notes
| :---  | :--- | :--- | :--- | :--- | :---
| pfBlockerNG | `☑` Enable | 
| Keep Settings | `☑` Enable |
| CRON Settings | Every hour | 00 | 0 | 0 | *Generally Leave Default settings*

Then Click `Save` at the bottom of the page.

### 8.2 Configure IP
Go to pfSense WebGUI `Firewall` > `pfBlockerNG` > `IP Tab` and fill out the necessary fields as follows. Whats NOT shown in the below table leave as default.

| IP Configuration | Value | Other Values | Notes
| :---  | :--- | :--- | :---
| De-Duplication | `☑` Enable | |*Check*
| CIDR Aggregation | `☑` Enable ||*Check*
| Suppression | `☑` Enable ||*Check*
| Global Logging | [] ||*Uncheck*
| Placeholder IP Address | 127.1.7.7||*Leave Default*
| MaxMind Localized Language | English||*Leave Default*
| MaxMind Updates | [] Check to disable MaxMind updates ||*Uncheck*
| Global Logging | [] ||*Uncheck*
| **IP Interface/Rules Configuration**
| Inbound Firewall Rules | `VPNGATEWORLD` || *Select ONLY VPNGATEWORLD and VPNGATELOCAL*
|| `VPNGATELOCAL`
| Outbound Firewall Rules | `VPNGATEWORLD` || *Select ONLY VPNGATEWORLD and VPNGATELOCAL*
|| `VPNGATELOCAL`
| Floating Rules | ☑ Enabled || *Check*
| Firewall 'Auto' Rule Order | pfB_Pass/Match/Block/Reject\All other Rules\(Default Format) || *Leave Default*
| Firewall 'Auto' Rule Suffix | `auto rule`
| Kill States | `☑` Enable

### 8.3 Configure DNSBL
Because we have multiple internal interfaces, we are using a Qotom Mini PC Q500G6-S05 with 6x Gigabit NICs, you would want to protect them with DNSBL, so you will need to pay attention to the ‘Permit Firewall Rules’ section. First, place a checkmark in the ‘Enable’ box of `Permit Firewall Rules`. Then, select the various interfaces (to the right, in a box) by holding down the ‘Ctrl’ key and left-click selecting the interfaces you choose to protect with pfBlockerNG. Note, don’t forget to Click the `Save DNSBL settings` at the bottom of the page.

Also if your pfSense OS has plenty of memory enable, 3Gb or more, use TLD. Normally, DNSBL (and other DNS blackhole software) block the domains specified in the feeds and that’s that. What TLD does differently is it will block the domain specified in addition to all of a domain’s subdomains. As a result, a instrusive domain can’t circumvent the blacklist by creating a random subdomain name such as abcd1234.zuckermine.com (if zuckermine.com was in a DNSBL feed). If you have the RAM enable it.

Next go to pfSense WebGUI `Firewall` > `pfBlockerNG` > `DNSBL Tab` and fill out the necessary fields as follows. Whats NOT shown in the below table leave as default. 

| DNSBL | Value | Other Values | Notes
| :---  | :--- | :--- | :---
| DNSBL | `☑` Enable | 
| TLD | `☑` Enable | | *Note: You need at least 3Gb of RAM for this feature*
| **DNSBL Webserver Configuration**
| Virtual IP Address | 10.10.10.1 || *Leave Default*
| VIP Address Type | IP Alias | Leave Blank (Enter Carp Password) | *Leave Default*
| Port | 8081 || *Leave Default*
| SSL Port | 8443 || *Leave Default*
| Webserver Interface | LAN || *Leave Default*
| **DNSBL Configuration**
| Permit Firewall Rules | `☑` Enable |`OPT1` | *Select ONLY OPT1 and OPT2 - Use the Ctrl key to toggle selection*
||| `OPT2`
| Blocked Webpage | dnsbl_default.php || *Leave Default*
| Resolver Live Sync | `[]` Enable || *Uncheck*
| **DNSBL IPs**
| List Action | `Deny Outbound`
| Enable Logging | `Enable`

Now Click `Save DNSBL settings` at the bottom of the page.

### 8.4 Configure DNSBL feeds
Using the pfSense WebGUI  `Firewall` > `pfBlockerNG` > `Feeds Tab` (not DNSBL Feeds) at the top. Here you will see all of the pre-configured feeds for the IPv4, IPv6, and DNSBL categories.

Scroll down to the `DNSBL Category` header then to the Alias/Group labeled `ADs`. Click the blue colour **`+`** next to the `ADs` header (column should be all ADs) to add all the feeds related to ADs category. Note, if you instead clicked the `+` to the far right of each line, you will instead only add that individual feed - this is not what we want.

| Category | Alias/Group | Feed/Website | Header/URL
| :---  | :--- | :--- | :---
| **DNSBL Category**
| DNSBL `I` **`+`** | `ADs` | `Adaway` | `Adaway`

If you clicked the **`+`** next to the ADs category, you are taken to a `DNSBL feeds` page with all of the feeds under that category pre-populated. All of the feeds in the list will initially be in the `OFF` state. You can go through and enable each one individually or you can click `Enable All` at the bottom of the list - then all will switch/change to `ON` state. Then change the Action field to `Unbound`.

Next, make sure you switch the `Action` from Disabled to `Unbound`.

| Value | Value | Value | Value
| :---  | :--- | :--- | :---
| **DNSBL Source Definitions**
| `Auto` | `ON` | `https://adaway.org/hosts.txt` | `Adaway`
| **Settings**
| Action | `Unbound`

Now Click the `Save DNSBL Settings` at the bottom of the page and you should receive a message at the top along the lines of `Saved [ Type:DNSBL, Name:ADs ] configuration`.

To check all went okay go to the `Firewall` > `pfBlockerNG` > `DNSBL` > `DNSBL Feeds` tab and you will see a DNSBL feeds summary. Your feeds summary should look similar to the one below:

| Name | Description | Action | Frequency | Logging
| :---  | :--- | :--- | :--- | :---
| **DNSBL Feeds Summary**
| ADs | ADs - Collection | Unbound | Once a day | Enabled

Now lets add some more. Go back to `Firewall` > `pfBlockerNG` > `Feeds` tab up top and then scroll down to `DNSBL category` section again. We’re going to add another category (after making some changes), but let’s explain everything you see here. Looking at the `DNSBL Catergory` you’ll see the `ADs` category checkmark **`+`** is replaced with a :heavy_check_mark: means this category already exists and is active in the DNSBL ADs category. This distinction is important to recognize because when you add the next category we do not need to enable every feed for a particular category.

Also worth mentioning before we add the `Malicious` category. Some feeds have selectable options such as feed category `Internet Storm Center`. I recommend switching the feed from `ISC_SDH` (high) to `ISC_SDL` (low) as the high feed has under 20 entries and the low feed includes the high feed.

After making the switch to `ISC_SDL`, click the blue colour **`+`** next to the `Malicious` header (column should be all Malicious) to add all the feeds related to that category.
If you clicked the **`+`** next to the Makicious category, you are taken to a `DNSBL feeds` page with all of the feeds under that category pre-populated. As when we added the ADs list, go ahead and click `Enable All` at the bottom of the list - all will switchchange to `ON` state. Then change the Action field to `Unbound`. **Don’t hit save just yet!**

**Important:** Now look for any `Header/label` called **`Pulsedive`** and/or **`Malekal`** and delete them (they were not there in my pfBlockerNG version). You don't want these as they are subscription (paid) services. On deletion they will disappear.

Now Click the `Save DNSBL Settings` at the bottom of the page and you should receive a message at the top along the lines of `Saved [ Type:DNSBL, Name:ADs ] configuration`.

To check all went okay go to the `Firewall` > `pfBlockerNG` > `DNSBL` > `DNSBL Feeds` tab and you will see a DNSBL feeds summary. Your feeds summary should look similar to the one below:

| Name | Description | Action | Frequency | Logging
| :---  | :--- | :--- | :--- | :---
| **DNSBL Feeds Summary**
| ADs | ADs - Collection | Unbound | Once a day | Enabled
| Malicious | Malicious - Collection | Unbound | Once a day | Enabled

Now lets add some more. Scroll down to the `DNSBL Category` header then to the Alias/Group labeled `Easylist`. Click the blue colour **`+`** next to the `Easylist` header (column should be all Easylist) to add all the feeds related to that category. You are taken to a `DNSBL feeds` page with all of the feeds under that category pre-populated. 

**Important:** Now look for any `Header/label` called `EasyPrivacy` and delete it. On deletion the line will disappear.

All of the feeds in the list will initially be in the `OFF` state. You can go through and enable each one individually or you can click `Enable All` at the bottom of the list - all will switch/change to `ON` state. Then change the Action field to `Unbound` and the Update Frequency to `Every 4 hours`.

Now Click the `Save DNSBL Settings` at the bottom of the page and you should receive a message at the top along the lines of `Saved [ Type:DNSBL, Name:ADs ] configuration`.

Now repeat the procedure for:
*  BBcan177 - From the creater of pfBlockerBG
*  hpHosts (all of them) - From Malwarebytes
*  BBC (BBC_DGA_Agr) – From Bambenek Consulting
*  Cryptojackers (all of them) – This blocks cryptojacking software and in-browser miners, but it also blocks various coin exchanges.

After adding all of the above go to the `Firewall` > `pfBlockerNG` > `DNSBL` > `DNSBL Feeds` tab and you will see a DNSBL feeds summary. Your feeds summary should look similar to the one below:

| Name | Description | Action | Frequency | Logging
| :---  | :--- | :--- | :--- | :---
| **DNSBL Feeds Summary**
| ADs | ADs - Collection | Unbound | Once a day | Enabled
| Malicious | Malicious - Collection | Unbound | Once a day | Enabled
| hpHosts | Malwarebytes - Collection | Unbound | Once a day | Enabled
| BBcan177 | BBcan177 - Collection | Unbound | Once a day | Enabled
| BBC | BBC-DGA type - Collection | Unbound | Once a day | Enabled
| Cryptojackers | Cryptojackers - Collection | Unbound | Once a day | Enabled
| Easylist | EasyList Feeds | Unbound | Every 4 hours | Enabled

### 8.5 Force DNSBL Feed Updates
You need to force a update to to `Reload` DNSBL new or changed settings. You must do this to check if your pfBlockerNG is working.

Next go to pfSense WebGUI `Firewall` > `pfBlockerNG` > `Update Tab` and fill out the necessary fields as follows. Whats NOT shown in the below table leave as default. 

| Update Settings | Value | Vale | Value | Notes
| :---  | :--- | :--- | :--- | :---
| Links 
| Select Force option | [] Update | [] Cron | `☑` Reload | *Select Reload*
| Select Reload option | `☑` All | [] IP | [] DNSBL | *Select All*

Now Click the `RUN` below the options and you should see the Logs being created on the page. It may take a while. Be patient.

### 8.6 Check if pfBlockerNG is working
First connect a device (i.e mobile, tablet etc) to either *.vpngate-local or *vpngate-world network. Go and browse a few websites like a news website. Then go to pfSense WebGUI `Firewall` > `pfBlockerNG` > `Reports` > `Alerts Tab` and you should see the DNSBL entry being populated with intercepted data. 

| Date | IF | Source | Domain/Referer/URI/Agent | Feed
| :---  | :--- | :--- | :--- | :---
| **DNSBL Section**
 Jul 26 10:49:13 [65]|OPT2|192.168.40.151|graph.instagram.com [ DNSBL ]S|Yoyo
 ||| Galaxy-Note8|DNSBL-HTTP|DNSBL_ADs
|Jul 26 11:06:05|OPT2|192.168.40.151|connect.facebook.net [ TLD ]|AntiSocial_BD
||||DNSBL-HTTPS | |DNSBL_Malicious

If you see nothing in the DNSBL section then pfBlockerNG is NOT working. Check your configurations to resolve. Remember after any edits or changes always perform a pfBlockerNG Update by following the procedures in **8.5 Force DNSBL Feed Updates**.

If I am left scratching my heading wondering what I've done wrong I find deleting and recreating the pfSense firewall floating rules often fixes things. My procedure is as follows:
*  Step 1: Go to pfSense WebGUI `Firewall` > `pfBlockerNG` > `General Tab` and disable pfBlockerNG. Click `Save` at the bottom of the page.
*  Step 2: Next go to pfSense WebGUI `Firewall` > `pfBlockerNG` > `DNSBL Tab` and disable DNSBL. Click `Save` at the bottom of the page.
*  Step 3: Next go to pfSense WebGUI `Firewall` > `Rules` > `Floating Tab` and delete all 3 rules and click `Save`.
*  Step 4: Next go to pfSense WebGUI `Diagnostics` > `States` > `Reset States` select `Reset the firewall state table` and click `Reset`.
*  Step 5: Re-enable `pfBlockerNG` and `DNSBL` shown in Step 1 and 2.
*  Step 6: Now perform a pfBlockerNG Update by following the procedures in **8.5 Force DNSBL Feed Updates**.

## 9.0 Create a pfSense Backup
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

## 10.0 Create a Cluster
At this stage you should have 3x fully built and ready Proxmox nodes on the same network - Typhoon-01, Typhoon-02 and Typhoon-03. You can need create a 3x node cluster.

### 10.1 Create the Cluster
Now using the pfSense web interface on node-01, Typhoon-01, go to `Datacenter` > `Cluster` > `Create Cluster` and fill out the fields as follows:

| Create Cluster | Value | Notes
| :---  | :--- | :--- |
| Cluster Name | `typhoon-cluster` |
| Ring 0 Address | Leave Blank |

And Click `Create`.

### 10.2 Join the other Nodes to the New Cluster
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

### 10.3 How to delete a existing cluster on a node
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

### 11.0 pfSense – disable firewall with pfctl -d
If for whatever reason you have lost access to the pfSense web management console then go to the Proxmox web interface `typhoon-01` > `251 (pfsense)` > `>_ Console` and `Enter an option` numerical `8` to open a shell.

Then type and execute `pfctl -d` where the -d will temporally disable the firewall (you should see the confirmation in the shell `pf disabled`, where pf is the packet filter = FIREWALL)

Now you can log into the WAN side IP address (192.168.2.1) and govern the pfsense again to fix the problem causing pfSense web management console to sease working on 192.168.1.253.
