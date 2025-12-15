#!/bin/sh
iptables -t nat -D OUTPUT -p udp --dport 53 -j WG_DNS_REDIRECT 2>/dev/null || true
iptables -t nat -D OUTPUT -p tcp --dport 53 -j WG_DNS_REDIRECT 2>/dev/null || true
iptables -t nat -F WG_DNS_REDIRECT 2>/dev/null || true
iptables -t nat -X WG_DNS_REDIRECT 2>/dev/null || true
