#!/bin/bash

# Get a list of all the IPs used in the OpenVPN config files
grep -h "remote " /etc/openvpn/*.ovpn| cut -d ' ' -f 2 | sort -u > /tmp/vpn-servers

# Start by wiping the iptables rules completely
iptables -F

# Allow all traffic on the tun interface (OpenVPN)
iptables -A INPUT -i tun+ -j ACCEPT
iptables -A OUTPUT -o tun+ -j ACCEPT

# Allow all localhost traffic
iptables -A INPUT -s 127.0.0.1 -j ACCEPT
iptables -A OUTPUT -d 127.0.0.1 -j ACCEPT

# Loop through the list of OpenVPN servers so we can allow their IPs
IP_LIST=$(tr '\n' ' ' < /tmp/vpn-servers)
for IP in $IP_LIST; do
        iptables -A INPUT -s $IP -j ACCEPT
        iptables -A OUTPUT -d $IP -j ACCEPT
done

# Allow internal network access to / from this server
iptables -A INPUT -s 192.168.0.0/24 -j ACCEPT
iptables -A OUTPUT -d 192.168.0.0/24 -j ACCEPT

# Drop all other traffic, now we'll only have Internet access if the VPN is connected
iptables -A INPUT -j DROP
iptables -A OUTPUT -j DROP

# Setup IP Forwarding
iptables -A FORWARD -o tun0 -i eth0 -s 192.168.0.0/24 -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A POSTROUTING -t nat -j MASQUERADE

# Save the rules so they persist
iptables-save > /etc/iptables/rules.v4

# Remove our temp file
rm /tmp/vpn-servers
