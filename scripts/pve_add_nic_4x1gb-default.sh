# Settings for default 4x NIC

# Please do NOT modify this file directly, unless you know what
# you're doing.
#
# If you want to manage parts of the network configuration manually,
# please utilize the 'source' or 'source-directory' directives to do
# so.
# PVE will preserve these directives, but will NOT read its network
# configuration from sourced files, so do not attempt to move any of
# the PVE managed interfaces into external files!

auto lo
iface lo inet loopback

iface enp${NIC_0_BUS_NO}s${NIC_0_SLOT_NO}f0 inet manual

iface enp${NIC_1_BUS_NO}s${NIC_1_SLOT_NO}f1 inet manual

iface enp${NIC_2_BUS_NO}s${NIC_3_SLOT_NO}f2 inet manual

iface enp${NIC_3_BUS_NO}s${NIC_3_SLOT_NO}f3 inet manual

#Proxmox LAN Bridge
auto vmbr0
iface vmbr0 inet static
        address  $PVE_HOST_IP
        netmask  255.255.255.0
        gateway  $PVE_GW
        bridge-ports enp${I350_BUS_NO}s${I350_SLOT_NO}f0
        bridge-stp off
        bridge-fd 0
        bridge-vlan-aware yes
        bridge-vids 2-4094

#VPN-egress Bridge
auto vmbr1
iface vmbr1 inet manual
        bridge-ports enp${I350_BUS_NO}s${I350_SLOT_NO}f1
        bridge-stp off
        bridge-fd 0
        bridge-vlan-aware yes
        bridge-vids 2-4094

#vpngate-world
auto vmbr2
iface vmbr2 inet manual
        bridge-ports enp${I350_BUS_NO}s${I350_SLOT_NO}f2
        bridge-stp off
        bridge-fd 0
        bridge-vlan-aware yes
        bridge-vids 2-4094

#vpngate-local
auto vmbr3
iface vmbr3 inet manual
        bridge-ports enp${I350_BUS_NO}s${I350_SLOT_NO}f3
        bridge-stp off
        bridge-fd 0
        bridge-vlan-aware yes
        bridge-vids 2-4094
