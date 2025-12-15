#!/bin/sh
set -e

# Load config
. /etc/wireguard/wg0.env

# Defaults (if something missing)
LAN_SUBNET="${LAN_SUBNET:-192.168.68.0/24}"
WG_DNS="${WG_DNS:-10.8.0.1}"
WG_ENDPOINT_PORT="${WG_ENDPOINT_PORT:-51820}"

# ---- KILLSWITCH (IPv4) ----
iptables -N WG_OUT 2>/dev/null || true
iptables -F WG_OUT

# Allow loopback + LAN/private nets
iptables -A WG_OUT -d 127.0.0.0/8 -j ACCEPT
iptables -A WG_OUT -d "${LAN_SUBNET}" -j ACCEPT
iptables -A WG_OUT -d 10.0.0.0/8 -j ACCEPT
iptables -A WG_OUT -d 172.16.0.0/12 -j ACCEPT
iptables -A WG_OUT -d 192.168.0.0/16 -j ACCEPT
# Allow traffic via WireGuard interface
iptables -A WG_OUT -o wg0 -j ACCEPT

# Allow WireGuard handshake to the server over WAN
if [ -n "${WG_ENDPOINT_IP}" ]; then
  iptables -A WG_OUT -d "${WG_ENDPOINT_IP}" -p udp --dport "${WG_ENDPOINT_PORT}" -j ACCEPT
fi

# Block everything else (NO WG = NO INTERNET)
iptables -A WG_OUT -j REJECT

# Hook at top of OUTPUT
iptables -C OUTPUT -j WG_OUT 2>/dev/null || iptables -I OUTPUT 1 -j WG_OUT


# ---- DNS PINNING (IPv4 NAT) ----
iptables -t nat -N WG_DNS_REDIRECT 2>/dev/null || true
iptables -t nat -F WG_DNS_REDIRECT

iptables -t nat -A WG_DNS_REDIRECT -p udp --dport 53 -j DNAT --to-destination ${WG_DNS}:53
iptables -t nat -A WG_DNS_REDIRECT -p tcp --dport 53 -j DNAT --to-destination ${WG_DNS}:53

iptables -t nat -C OUTPUT -p udp --dport 53 -j WG_DNS_REDIRECT 2>/dev/null || iptables -t nat -I OUTPUT 1 -p udp --dport 53 -j WG_DNS_REDIRECT
iptables -t nat -C OUTPUT -p tcp --dport 53 -j WG_DNS_REDIRECT 2>/dev/null || iptables -t nat -I OUTPUT 1 -p tcp --dport 53 -j WG_DNS_REDIRECT

exit 0
