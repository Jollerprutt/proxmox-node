# proxmox
Install proxmox onto your hardware
hostname
IP address
Netmask
Gateway
DNS Server

My Proxmox server and container build
To install turnkeylinux container templates use the CLI
`pveam update`

PiHole LXC Container Proxmox CentOS7

Deploy an LXC container with the CentOS7 image.. 2G RAM, 8G storage, 2 CPU cores.
I added a DHCP reservation for a static IP.

When at the console for the CentOS7 LXC instance:
Install pihole..
curl -sSL https://install.pi-hole.net | bash
