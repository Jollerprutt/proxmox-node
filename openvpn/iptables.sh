#!/bin/ash

# Flush
iptables -t nat -F
iptables -t mangle -F
iptables -F
iptables -X

service iptables save
