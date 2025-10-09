#!/usr/bin/env bash
# harden_sonic.sh - simple iptables-based demo hardening for the mock server
# Usage inside mock SONiC container: bash /work/harden_sonic.sh <ALLOWED_IP>
set -e

PORT=8080
ALLOWED=${1:-"127.0.0.1"}

echo "[*] Applying demo iptables rules to allow port ${PORT} only from ${ALLOWED}"

# Try to install iptables (alpine vs debian handle differently); best-effort
if command -v apk >/dev/null 2>&1; then
  apk add --no-cache iptables >/dev/null 2>&1 || true
elif command -v apt-get >/dev/null 2>&1; then
  apt-get update >/dev/null 2>&1 || true
  apt-get install -y iptables >/dev/null 2>&1 || true
fi

# Save existing rules
iptables-save > /root/iptables.before || true

# Allow loopback + established
iptables -C INPUT -i lo -j ACCEPT 2>/dev/null || iptables -A INPUT -i lo -j ACCEPT
iptables -C INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow SSH if present
iptables -C INPUT -p tcp --dport 22 -j ACCEPT 2>/dev/null || iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow management port only from ALLOWED
iptables -D INPUT -p tcp --dport ${PORT} -j ACCEPT 2>/dev/null || true
iptables -C INPUT -p tcp --dport ${PORT} -s ${ALLOWED} -j ACCEPT 2>/dev/null || iptables -I INPUT 1 -p tcp --dport ${PORT} -s ${ALLOWED} -j ACCEPT

# Drop any other access to the management port
iptables -C INPUT -p tcp --dport ${PORT} -j DROP 2>/dev/null || iptables -A INPUT -p tcp --dport ${PORT} -j DROP

echo "[*] iptables rules applied. Current relevant rules:"
iptables -S | sed -n '1,120p'
