# WireGuard Client on UGREEN OS (UGOS)

This repository documents how to run **WireGuard as a system-level client** on **UGREEN OS** using SSH.

UGREEN OS is an appliance-style Linux distribution that does not officially expose WireGuard configuration at the OS level.
However, WireGuard **is present in the kernel and userland**, which allows a fully functional system-wide WireGuard client when configured correctly.

This guide provides a **safe, reproducible, reboot-persistent** setup with:

- Full-tunnel routing (all internet traffic goes through WireGuard)
- DNS forced through the WireGuard tunnel (no DNS leaks)
- Kill-switch (no WireGuard = no internet)
- LAN-safe behavior (local network access is preserved)
- No resolvconf or /etc/resolv.conf modifications
- No Docker required

---

## Important warnings

- This configuration intentionally blocks all internet access when WireGuard is down.
- LAN traffic is explicitly allowed to prevent lockouts.
- Perform the initial setup with local console or physical access available.
- UGREEN OS updates may overwrite startup hooks (/etc/rc.local). Always re-check after updates.

---

## Requirements

On the UGREEN NAS:

- SSH access enabled
- WireGuard kernel module available:

  lsmod | grep wireguard

- WireGuard tools present:

  which wg  
  which wg-quick

If these commands return valid paths, this setup is supported.

---

## How this setup works

UGREEN OS:
- Uses an internal DNS forwarder (127.0.0.1)
- Automatically regenerates /etc/resolv.conf
- Does not provide resolvconf or systemd-resolved

Because of this:
- DNS must NOT be configured using the DNS= option in wg0.conf
- DNS is enforced at the firewall level
- Routing uses policy routing, not default route replacement

---

## Architecture overview

### Routing
- wg-quick installs policy routing rules (table 51820)
- All outbound traffic is routed through wg0
- The main routing table is not modified

### DNS
- All outbound DNS traffic (TCP/UDP port 53) is redirected to a DNS server reachable via WireGuard
- This prevents DNS leaks even if UGOS tries to use public resolvers

### Kill-switch
- A dedicated iptables chain (WG_OUT) is attached to OUTPUT
- LAN and WireGuard traffic is allowed
- All other outbound traffic is rejected

---

## Files in this repository

- wg0.conf.template  
  Template for the WireGuard client configuration (no secrets)

- wg0.env.example  
  Environment file defining LAN subnet, DNS server, and WireGuard endpoint

- wg0-up.sh  
  Applies kill-switch and DNS enforcement when WireGuard comes up

- wg0-down.sh  
  Keeps kill-switch active but removes DNS redirect when WireGuard goes down

- rc.local.snippet  
  Snippet used to start WireGuard at boot on UGREEN OS

---

## Installation steps

### 1. Copy scripts

Copy wg0-up.sh and wg0-down.sh to:

  /usr/local/bin/

Make them executable:

  chmod +x /usr/local/bin/wg0-up.sh /usr/local/bin/wg0-down.sh

---

### 2. Create environment file

Create /etc/wireguard/wg0.env based on wg0.env.example:

- LAN_SUBNET: your local network (example: 192.168.68.0/24)
- WG_DNS: DNS server reachable through WireGuard (example: 10.8.0.1)
- WG_ENDPOINT_IP: public IP of your WireGuard server
- WG_ENDPOINT_PORT: WireGuard UDP port (usually 51820)

Set permissions:

  chmod 600 /etc/wireguard/wg0.env

---

### 3. Create WireGuard config

Create /etc/wireguard/wg0.conf using wg0.conf.template.

You must fill in:
- Client private key
- Client tunnel address
- Server public key
- Server endpoint

Bring the tunnel up:

  wg-quick up wg0

Verify:

  wg  
  curl ifconfig.me

---

## Boot persistence

UGREEN OS does not reliably enable wg-quick via systemd.

Use /etc/rc.local instead:

1. Edit /etc/rc.local
2. Add the following before exit 0:

  wg-quick up wg0

3. Ensure it is executable:

  chmod +x /etc/rc.local

Reboot and verify:

  wg  
  curl ifconfig.me

---

## Expected behavior

| State | Internet | DNS | LAN |
|------|----------|-----|-----|
| WireGuard UP | Yes (via WG) | Yes | Yes |
| WireGuard DOWN | No | No | Yes |

---

## Emergency recovery

If you need to restore internet access immediately:

  iptables -D OUTPUT -j WG_OUT 2>/dev/null
  iptables -F WG_OUT 2>/dev/null
  iptables -X WG_OUT 2>/dev/null

---

## Limitations

- DNS over HTTPS (DoH) and DNS over TLS (DoT) are not blocked by default
- IPv6 traffic should be handled separately if required
- UGREEN OS updates may remove rc.local entries

---

## License

MIT License
