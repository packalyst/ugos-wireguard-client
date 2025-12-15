#!/bin/sh
set -e
. /etc/wireguard/wg0.env

iptables -N WG_OUT 2>/dev/null || true
iptables -F WG_OUT

iptables -A WG_OUT -d 127.0.0.0/8 -j ACCEPT
iptables -A WG_OUT -d "$LAN_SUBNET" -j ACCEPT
iptables -A WG_OUT -d 10.0.0.0/8 -j ACCEPT
iptables -A WG_OUT -d 172.16.0.0/12 -j ACCEPT
iptables -A WG_OUT -d 192.168.0.0/16 -j ACCEPT
iptables -A WG_OUT -o wg0 -j ACCEPT
iptables -A WG_OUT -d "$WG_ENDPOINT_IP" -p udp --dport "$WG_ENDPOINT_PORT" -j ACCEPT
iptables -A WG_OUT -j REJECT

iptables -C OUTPUT -j WG_OUT 2>/dev/null || iptables -I OUTPUT 1 -j WG_OUT

iptables -t nat -N WG_DNS_REDIRECT 2>/dev/null || true
iptables -t nat -F WG_DNS_REDIRECT
iptables -t nat -A WG_DNS_REDIRECT -p udp --dport 53 -j DNAT --to-destination "$WG_DNS:53"
iptables -t nat -A WG_DNS_REDIRECT -p tcp --dport 53 -j DNAT --to-destination "$WG_DNS:53"
iptables -t nat -C OUTPUT -p udp --dport 53 -j WG_DNS_REDIRECT 2>/dev/null || iptables -t nat -I OUTPUT 1 -p udp --dport 53 -j WG_DNS_REDIRECT
iptables -t nat -C OUTPUT -p tcp --dport 53 -j WG_DNS_REDIRECT 2>/dev/null || iptables -t nat -I OUTPUT 1 -p tcp --dport 53 -j WG_DNS_REDIRECT
