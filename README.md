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
Disk one (sda) is the for proxmox OS so a 30Gb disk is adequate. Use a sata dom if you like.
Disk two (sdb) I recommend a 250Gb SSD as minimum - preferably 500Gb.
Create your proxmox installation USB media, set your nodes bios boot order to USB first (so you can boot off your proxmox installation USB media), and install proxmox. Configure your nodes as follows:

| Option | Node 1 Value | Node 2 Value | Node 3 Value |
| :---  | :---: | :---: | :---: |
| `Filesystem` | ext4 | ext4 | ext4
| `Disk(s)` | sda | sda | sda
| `Country` | "select" | "select" | "select"
| `Timezone` |"select"|"select"|"select"
| `Keymap` |en-us|en-us|en-us
| `E-mail` |"your email"|"your email"|"your email"
| `Management interface` |default|default|default
| `Hostname` |typhoon-01|typhoon-02|typhoon-03
|`IP` |192.168.1.101|192.168.1.102|192.168.1.103
| `Netmask` |255.255.255.0| 255.255.255.0| 255.255.255.0
| `Gateway` |192.168.1.5|192.168.1.5|192.168.1.5
| `DNS` |192.168.1.5|192.168.1.5|192.168.1.5

My Proxmox server and container build
To install turnkeylinux container templates use the CLI
`pveam update`

PiHole LXC Container Proxmox CentOS7

Deploy an LXC container with the CentOS7 image.. 2G RAM, 8G storage, 2 CPU cores.
I added a DHCP reservation for a static IP.

When at the console for the CentOS7 LXC instance:
Install pihole..
curl -sSL https://install.pi-hole.net | bash
