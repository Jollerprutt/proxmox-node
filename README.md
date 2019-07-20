# Proxmox Node Building
This recipe builds two physical hardware Proxmox nodes and one Synology VM Proxmox node. Such a group of nodes is called a cluster and has a central management WebGUI by a single URL/IP address. Because a cluster of 3x nodes can form a quorum we have High Availability in the event a node fails.

The hardware in this recipe includes:
*  1x Qotom Mini PC Q500G6-S05 with 6x Gigabit NICs;
*  1x Intel i3 NUC model nuc5i3ryh; and,
*  1x Synology DS1515+ with 4x NICs. 

Both the Qotom Mini PC Q500G6-S05 and Intel NUC model nuc5i3ryh are low wattage at 15W TDP, Intel CPU's are all 2x core / 4x thread Intel CPUs, support for Intel AES-NI instruction sets (for OpenVPN which is single threaded only), all have Intel NIC's, and all have at least 2x SATA 6.0 Gb/s Ports each to support SSD's. Each node is installed with a minimum of 16Gb of RAM. 

I also use Ubiquiti Network gear which is a dream to configure and maintain. 

Obviously you can modify these instructions to meet your own hardware requirements.

Network prerequisites are:
- [x] Layer 2 Network kit
- [x] Network Gateway is `192.168.1.5`
- [x] Network DNS server is `192.168.1.5` (Note: your Gateway hardware should enable your to configure DNS server(s), like a UniFi USG Gateway, set the following: primary DNS `192.168.1.254` which will be your PiHole server IP address; and, secondary DNS `1.1.1.1` which is a backup Cloudfare DNS server in the event your PiHole server 192.168.1.254 fails or os down)
- [x] Network DHCP server is `192.168.1.5`
- [x] A DDNS service is fully configured and enabled (I recommend you use the free Synology DDNS service)
- [x] A ExpressVPN account (or any preferred VPN provider) is valid and its smart DNS feature is working (public IP registration is working with your DDNS provider)

Other Prerequisites are:
- [x] Synology NAS is `192.168.1.10`
- [x] Synology NAS is installed with Synology Virtual Machine Manager
- [x] Synology NAS is configured, including NFS, as per [synobuild](https://github.com/ahuacate/synobuild)

Tasks to be performed are:
- [ ] Proxmox OS Installation
- [ ] Update Proxmox OS and enable turnkeylinux templates

## 1.0 Proxmox Base OS Installation
Each Proxmox node requires two SSD hard disks. Basically one is for the Proxmox OS and the other disk is configured as a Proxmox ZFS shared storage disk.

In these instructions SCSi and SATA controller devices designate disk names such as sda,sdb,sdc and so on, a generic linux naming convention, are referred to as `sdx` only. This is because despite Disk 1 often being device sda in some hardware it may not be. So its best to first check your hardware and note which device is designated to which type of hard disk you have installed. This is important because the disk you have chosen to used as your Proxmox ZFS shared storage disk, a SSD size of at least 250 Gb,  should NOT have your OS installed on it. So for ease of writing and to avoid confusion all SATA disk devices are referred to as sdx.

Each Proxmox node requires a OS SSD disk, disk 1, minimum size of 60 Gb. But I recommend a 120 Gb SSD disk - the smallest these days. You could use a USB dom for the Proxmox OS but a generic consumer USB thumbdrive or SDcard is **NOT RECOMMENDED** because Proxmox has a fair amount of Read/Write activity.

For Disk 2 (sdx) I recommend a 500 Gb SSD which will be used as a Proxmox ZFS shared storage disk for the cluster. But my installation uses a 250 Gb SSD.

Create your Proxmox installation USB media (instructions [here](https://pve.proxmox.com/wiki/Install_from_USB_Stick)), set your nodes bios boot loader order to Hard Disk first / USB second (so you can boot from your proxmox installation USB media), and install proxmox.

For your Synology Virtual Machine Proxmox VM pre-setup follow the the instructions [HERE](https://github.com/ahuacate/synobuild#install--configure-synology-virtual-machine-manager).

Remember to remove your USB media on reboot on the hard metal hardware.

Configure each node as follows:

| Option | Node 1 Value | Node 2 Value | Node 3 Value |
| :---  | :---: | :---: | :---: |
| Hardware Type | Qotom - Multi NIC | Generic PC - Single NIC | Synology VM
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

Node 1 should be your Qotom. Choose your own password.

### 1.1 Configure the Proxmox Hardware
Further configuration is done via the Proxmox web interface. Just point your browser to the IP address given during installation (https://yournodesipaddress:8006). Default login is "root" (realm PAM) and the root password you defined during the installation process.

### 1.2 Update Proxmox OS and enable turnkeylinux templates
Using the web interface `updates` > `refresh` search for all the latest required updates.
Next install the updates using the web interface `updates` > `_upgrade` - a pop up terminal will show the installation steps of all your required updates.

Next install turnkeylinux container templates by using the web interface CLI `shell` and type
`pveam update`

### 1.3. Create Disk Two - your shared storage
Create Disk 2 using the web interface `Disks` > `ZFS` > `Create: ZFS` and configure each node as follows:

| Option | Node 1 Value | Node 2 Value | Node 3 Value |
| :---  | :---: | :---: | :---: |
| `Name` |typhoon-share|typhoon-share|typhoon-share
| `RAID Level` |Single Disk|Single Disk|Single Disk
| `Compression` |on|on|on
| `ashift` |12|12|12
| `Device` |/dev/sdx|/dev/sdx|/dev/sdx

Note: If your choose to use a ZFS Raid for storage redundancy change accordingly per node but your must retain the Name ID **typhoon-share**.

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
|||
| `Name` |**LAN-vpngate-local**| This is the network where LAN clients will be restricted to the vpngate-world server |
| `Purpose` |VLAN Only| This is critical. We don't want the UniFi USG to do anything with any client on this VLAN other than be sure that they can get to their gateway. |
| `VLAN` |40|  |
| `IGMP Snooping` |Disabled|  |
| `DHCP Guarding` |Disabled|  |

#### 2.3 Setup network switch ports
In this example network switch ingress port 19 is associated with vpngate-world and ingress port 20 is associted with vpngate-local. The below instructions are for the UniFi controller `Devices` > `Select device - i.e UniFi Switch 24/48` > `Ports`  and select port 19 or 20 and `edit` and `apply` as follows:

| Description | Value | Notes |
| :---  | :---: | :--- |
| `Name` |**Port 19**|  |
| `Switch Port Profile` |LAN-vpngate-world (30)| This will put switch port 19 on VLAN30 |
|||
| `Name` |**Port 20**|  |
| `Switch Port Profile` |LAN-vpngate-local (40)| This will put switch port 20 on VLAN30 |

#### 2.4 Setup network WiFi SSiDs for the VPN service
In this example two VPN secure WiFI SSIDs are created. All traffic on these WiFi connections will exit to the internet via your preset VPN VLAN. The below instructions are for the UniFi controller `Settings` > `Wireless Networks` > `Create New Wireless Network` and fill out the form details as shown below:

| Description | Value | Notes |
| :---  | :---: | :--- |
| `Name/SSID` |**hello-vpngate-world**| Call it whatever you like |
| `Enabled` |[x]| |
| `Security` | WPA Personal | Wouldnt recommend anything less |
| `Security Key` | password | Your choosing |
| `VLAN` |30| Must be set as 30 |
| `Other Settings` | Just leave as default| |
|||
| `Name/SSID` |**hello-vpngate-local**| Call it whatever you like |
| `Enabled` |[x]| |
| `Security` | WPA Personal | Wouldnt recommend anything less |
| `Security Key` | password | Your choosing |
| `VLAN` |40| Must be set as 40 |
| `Other Settings` | Just leave as default| |

## 3.0 Easy Installation Option
If you have gotton this far and completed Steps 1.0 thru to 2.4 you can proceed to Step 4.0 to manually build your nodes or skip some steps by using CLI build bash scripts. But my bash scripts are written for the Qotom Mini PC model Q500G6-S05 (6x NIC variant) and single NIC hardware only. If you have different hardware, such as a 2x or 4x NIC Qotom or similiar hardware, then my scripts will not work and you best proceed to Step 4.0 and build manually.

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
After executing this script you must continue manually to Step 6.0.

Script (B) `typhoon-01-6x_NIC-setup-01.sh` which is for typhoon-02/03 (node-02/03/04 etc), which MUST BE single NIC hardware only. The script will perform the following tasks:
*  Create a New User **storm**
*  Create a new password for user **storm**
*  Create a new user group called **homelab**
*  Update/enable the Proxmox turnkey appliance list
*  Update and upgrade your Proxmox node
*  Install lm sensors SW
*  Create NFS mounts to your NAS
*  Update the hosts file

### 3.1 Qotom Mini PC model Q500G6-S05 build script
This script is for the Qotom Mini PC model Q500G6-S05 model ONLY. 

To execute the script use the Proxmox web interface `typhoon-01` > `>_ Shell` and cut & paste the following into the CLI terminal window and press ENTER:
```
wget https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/typhoon-01-6x_NIC-setup-01.sh -P /tmp && chmod +x /tmp/typhoon-01-6x_NIC-setup-01.sh && bash /tmp/typhoon-01-6x_NIC-setup-01.sh; rm -rf /tmp/typhoon-01-6x_NIC-setup-01.sh
```
If successful you will see on your CLI terminal words **"Looking Good. Rebooting in 5 seconds ......"** and your typhoon-01 machine will reboot. You can now proceed to Step 6.0.

### 3.2 Single NIC Hardware build script
This script is for single NIC hardware ONLY (i.e Intel NUC etc). 

To execute the script use the Proxmox web interface `typhoon-02/03/04` > `>_ Shell` and cut & paste the following into the CLI terminal window and press ENTER:
```
wget https://raw.githubusercontent.com/ahuacate/proxmox-node/master/scripts/typhoon-0X-Single_NIC-setup-01.sh -P /tmp && chmod +x /tmp/typhoon-0X-Single_NIC-setup-01.sh && bash /tmp/typhoon-0X-Single_NIC-setup-01.sh; rm -rf /tmp/typhoon-0X-Single_NIC-setup-01.sh
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

### 4.2 Configure Proxmox bridge networking
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

## 5.0 Create a Proxmox pfSense VM
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
| `Node` |typhoon-01|
| `VM ID` | 251 |
| `Name` | pfsense |
| `Start at Boot` | Enabled |
| `Start/Shutdown order` | 1 |
| `Resource Pool` | Leave blank |
| `Use CD/DVD disc image file (ISO)` | pfSense-CE-2.4.4-RELEASE-p3-amd64.iso |
| `Guest OS` | Other |
| `Graphic card` | Default |
| `Qemu Agent` | Disabled |
| `SCSI Controller` | VirtIO SCSI |
| `BIOS` | Default (SeaBIOS) |
| `Machine` | Default (i440fx) |
| `Bus/Device` | VirtIO Block 0 |
| `Storage` | local-lvm |
| `Disk size (GiB)` | 32 |
| `Cache` | Default (No Cache) |
| `Sockers` | 1 |
| `Cores` | 2 |
| `Type` | host |
| `Memory (MiB)` | 2048 |
| ` Minimum Memory (MiB)` | 2048 |
| `Ballooning Device` | Enabled |
| `Bridge` | vmbr0 |
| `Model` | VirtIO (paravirtualized) |
| `Start after created` | Disabled |

Now using the Proxmox web interface `typhoon-01` > `251 (pfsense)` > `Hardware` > `Add` > `Network Device` create the following additional network bridges as shown below:

| Description | Value |
| :---  | :---: |
| `Bridge` | **vmbr1** |
| `VLAN Tag` | no VLAN |
| `Model` | VirtIO (paravirtualized) |
|||
| `Bridge` | **vmbr2** |
| `VLAN Tag` | no VLAN |
| `Model` | VirtIO (paravirtualized) |
|||
| `Bridge` | **vmbr3** |
| `VLAN Tag` | no VLAN |
| `Model` | VirtIO (paravirtualized) |

Or if you prefer you can simply use Proxmox typhoon-01 cli `>Shell` and type the following to achieve the same thing (Note: the below script is for a Qotom Mini PC Q500G6-S05 with 6x Gigabit NICs ONLY):

For the Stable pfSense 2.4.4 (***Recommended - this is what I use***):
```
qm create 253 --bootdisk virtio0 --cores 2 --cpu host --ide2 local:iso/pfSense-CE-2.4.4-RELEASE-p3-amd64.iso,media=cdrom --memory 2048 --name pfsense --net0 virtio,bridge=vmbr0,firewall=1 --net1 virtio,bridge=vmbr1,firewall=1 --net2 virtio,bridge=vmbr2,firewall=1 --net3 virtio,bridge=vmbr3,firewall=1 --numa 0 --onboot 1 --ostype other --scsihw virtio-scsi-pci --sockets 1 --virtio0 local-lvm:32 --startup order=1
```
For the Development pfSense version 2.5:
```
qm create 253 --bootdisk virtio0 --cores 2 --cpu host --ide2 local:iso/pfSense-CE-2.5.0-DEVELOPMENT-amd64-latest.iso,media=cdrom --memory 2048 --name pfsense --net0 virtio,bridge=vmbr0,firewall=1 --net1 virtio,bridge=vmbr1,firewall=1 --net2 virtio,bridge=vmbr2,firewall=1 --net3 virtio,bridge=vmbr3,firewall=1 --numa 0 --onboot 1 --ostype other --scsihw virtio-scsi-pci --sockets 1 --virtio0 local-lvm:32 --startup order=1
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

### 7.3 Add DHCP Servers to OPT1 and OPT2
Now using the pfSense web interface `Interfaces` > `OPT1` to open a configuration form, then fill up the necessary fields as follows:

| Interfaces/OPT1 (vtnet2) | Value | Notes
| :---  | :---: | :--- |
| Enable | `[x]` | *Check the box*
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
| Block bogon networks | `[x]` | *Uncheck the box*

Now using the pfSense web interface `Interfaces` > `OPT2` to open a configuration form, then fill up the necessary fields as follows:

| Interfaces/OPT2 (vtnet3) | Value | Notes
| :---  | :---: | :--- |
| Enable | `[x]` | *Check the box*
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
| Block private networks and loopback addresses | `[ ]` | *Uncheck the box*
| Block bogon networks | `[]` | *Uncheck the box*

### 7.4 Setup DHCP Servers for OPT1 and OPT2
Now using the pfSense web interface `Services` > `DHCP Server` > `OPT1 Tab` or `OPT2 Tab` to open a configuration form, then fill up the necessary fields as follows:

| General Options | OPT 1 Value | OPT2 Value | Notes |
| :---  | :---: | :---: | :---
| Enable | `[x]` |  `[x]` | *Opt1&2 Check the box*
| BOOTP | `[ ]` | [ ] | *Disable*
| Deny unknown clients | `[ ]` | [ ] | *Disable*
| Ignore denied clients | `[ ]` | [ ] | *Disable*
| Ignore client identifiers | `[ ]` | [ ] | *Disable*
| Subnet | 192.168.30.0 | 192.168.40.0 |
| Subnet mask |255.255.255.0 | 255.255.255.0 | 
| Available range | 192.168.30.1 - 192.168.30.254 | 192.168.40.1 - 192.168.40.254 |
| Range | `192.168.30.150 - 192.168.30.250` | `192.168.40.150 - 192.168.40.250` |
| **Servers**
| WINS servers | Leave blank
| DNS servers | `85.203.37.1` | `85.203.37.1` | *DNS Server 1: Use the DNS IP supplied by your VPN provider (the ones shown are ExpressVPN's). If you dont have any leave blank. Note, for you to use your VPN providers DNS servers you generally need DDNS configured to report to your VPN provider your public IP address on a device on your network such as your router or NAS etc*
|  | `85.203.37.2` | `85.203.37.2` | *DNS Server 2: Use the DNS IP supplied by your VPN provider (the ones shown are ExpressVPN's). If you dont have any leave blank*

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
| TLS Configuration | `[x] Use a TLS Key` | *Check the box*
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
| Don't pull routes | [x] | *Check the box*
| Don't add/remove routes | [x] | *Check the box*
| **Advanced Configuration**
| Custom options : vpngate-world| `route-nopull;fast-io;persist-key;persist-tun;remote sweden-2-ca-version-2.expressnetw.com 1195;remote singapore-cbd-ca-version-2.expressnetw.com 1195;remote germany-frankfurt-1-ca-version-2.expressnetw.com 1195;remote-random;pull;comp-lzo;tls-client;verify-x509-name Server name-prefix;remote-cert-tls server;key-direction 1;route-method exe;route-delay 2;tun-mtu 1500;fragment 1300;mssfix 1450;verb 3;sndbuf 524288;rcvbuf 524288` | *These options are derived from the OpenVPN configuration you have been referencing. We will be pulling out all custom options that we have not used previously. Note, the addition of `route-nopull`. Also, for redundancy we add other remote servers in the event the primary server fails*
| Custom options : vpngate-local| `route-nopull;fast-io;persist-key;persist-tun;remote-random;pull;comp-lzo;tls-client;verify-x509-name Server name-prefix;remote-cert-tls server;key-direction 1;route-method exe;route-delay 2;tun-mtu 1500;fragment 1300;mssfix 1450;verb 3;sndbuf 524288;rcvbuf 524288` | *These options are derived from the OpenVPN configuration you have been referencing. We will be pulling out all custom options that we have not used previously. Note, the addition of `route-nopull`.*
| UDP Fast I/O | `[x] Use fast I/O operations with UDP writes to tun/tap. Experimental.` | *Check the box*
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
| Enable | `[x]` Enable interface | *Check the box*
| Description | `vpngateworld`
| IPv4/IPv6 Configuration | This interface type does not support manual address configuration on this page.
| MAC Address | `None`
| MTU | Leave blank
| MTU | Leave blank
| MSS | Leave blank
| **Reserved Networks**
| Block private networks and loopback addresses | `[ ]` | *Uncheck the box*
| Block bogon networks | `[ ]` | *Uncheck the box*

Now edit `OPT4`:

| Interfaces/OPT4 (ovpnc2) | Value | Notes
| :---  | :---: | :--- |
| Enable | `[x]` Enable interface | *Check the box*
| Description | `vpngatelocal`
| IPv4/IPv6 Configuration | This interface type does not support manual address configuration on this page.
| MAC Address | `None`
| MTU | Leave blank
| MTU | Leave blank
| MSS | Leave blank
| **Reserved Networks**
| Block private networks and loopback addresses | `[ ]` | *Uncheck the box*
| Block bogon networks | `[ ]` | *Uncheck the box*

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
| No XMLRPC Sync | []
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
| No XMLRPC Sync | []
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
| Disabled | [] disable this rule
| Interface | `OPT1`
| Addresss Family | `IPv4+IPv6`
| Protocol | `Any`
| **Extra Options**
| Log | [] Log packets that are handled by this rule
| Description | `VLAN30 Traffic to vpngate-world`
| Advanced Options | Click `Display Advanced` | *This is a important step. You only want to edit one value in `Advanced`!!!!
| **Advanced Options**
| Gateway | `VPNGATEWORLD_VPNV$-x.x.x.x-Interface VPNGATEWORLD_VPNV4 Gateway` | `MUST Change to this gateway!

Click `Save`.

Now do OPT2 / vpngate-local so go `Firewall` > `Rules` > `OPT2 tab` and `Add` a new rule:

| Edit Firewall Rule / OPT2 | Value | Notes|
| :---  | :--- | :--- |
| Action | `Pass`
| Disabled | [] disable this rule
| Interface | `OPT2`
| Addresss Family | `IPv4+IPv6`
| Protocol | `Any`
| **Extra Options**
| Log | [] Log packets that are handled by this rule
| Description | `VLAN40 Traffic to vpngate-local`
| Advanced Options | Click `Display Advanced` | *This is a important step. You only want to edit one value in `Advanced`!!!!*
| **Advanced Options**
| Gateway | `VPNGATELOCAL_VPNV4-x.x.x.x-Interface VPNGATELOCAL_VPNV4 Gateway` | *MUST Change to this gateway!*

Click `Save` and `Apply`.

The above rules will send all the traffic on that interface into the VPN tunnel, you must ensure that the ‘gateway’ option is set to your VPN gateway and that this rule is above any other rule that allows hosts to go out to the internet. pfSense needs to be able to catch this rule before any others.

### 7.9 Setup pfSense DNS
Cloudflare’s DNS service is arguably the best DNS servers to use in pfSense and here we configure Cloudfare DNS over TLS. The first step ensure Cloudflare DNS servers are used even if the DNS queries are not sent over TLS. Navigate to `System` > `General Settings` and under DNS servers add IP addresses for Cloudflare DNS servers and select your WAN gateway.

| DNS Server Settings | Value | Value |
| :---  | :--- | :--- |
| DNS Servers | `1.1.1.1` | `WAN_DHCP - wan-xxxx`
| DNS Servers | `1.0.0.1` | `WAN_DHCP - wan-xxxx`

After entering the DNS IP addresses, scroll down to the bottom of the page and click `Save`. Your pfSense appliance is now using Cloudflare servers as DNS.

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

### 7.9.1 Finish Up
After all your rules are in place head over to `Diagnostics` > `States` > `Reset States Tab` > and tick `Reset the firewall state table` click `Reset`. After doing any firewall changes that involve a gateway change its best doing a state reset before checking if anything has worked (odds are it will not work if you dont). PfSense WebGUI may hang for period but dont despair because it will return in a few seconds for routing to come back and up to a minute, don’t panic.

And finally navigate to `Diagnostics` > `Reboot` and reboot your pfSense machine.

Once you’re done head over to any client PC on the network or mobile on the WiFi SSID on either `vpngate-world` VLAN30 or `vpngate-local` VLAN40 networks and use IP checker to if its all working https://wtfismyip.com

Success! (hopefully)

### 3.4 Automated Installation and Configuration
Under Development.

## 4 Configure Single NIC Hardware Network Setup - Typhoon-02
Seting up a single network NIC host (including Synology Virtual Machines) is simple. In the following setup I used a Intel i3 NUC model nuc5i3ryh machine.
















