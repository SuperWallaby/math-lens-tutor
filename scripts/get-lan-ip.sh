#!/usr/bin/env bash
# Mac LAN IP for physical devices (iPhone hotspot USB/Wi‑Fi, home Wi‑Fi, etc.).
set -euo pipefail

is_usable_ip() {
  local ip="$1"
  [[ -n "$ip" && "$ip" != "127.0.0.1" ]] || return 1
  [[ "$ip" =~ ^169\.254\. ]] && return 1
  return 0
}

read_iface_ip() {
  local iface="$1"
  local ip
  ip="$(ipconfig getifaddr "$iface" 2>/dev/null || true)"
  if is_usable_ip "$ip"; then
    echo "$ip"
    return 0
  fi
  # Hotspot/USB (en8 등) — ipconfig 가 비어 있어도 ifconfig 에 IPv4 가 있는 경우
  ip="$(ifconfig "$iface" 2>/dev/null | awk '/inet / {print $2; exit}')"
  if is_usable_ip "$ip"; then
    echo "$ip"
    return 0
  fi
  return 1
}

# Default route interface — iPhone hotspot often en8 / bridge100, not en0.
default_iface=""
default_iface="$(route -n get default 2>/dev/null | awk '/interface:/{print $2; exit}' || true)"
if [[ -n "$default_iface" ]] && read_iface_ip "$default_iface"; then
  exit 0
fi

for iface in bridge100 en0 en1 en2 en3 en4 en5 en6 en7 en8 en9; do
  if read_iface_ip "$iface"; then
    exit 0
  fi
done

# Last resort: link-local
for iface in en0 en1 en2 en3 en4 en5 en6 en7 en8 en9 bridge100; do
  ip="$(ifconfig "$iface" 2>/dev/null | awk '/inet / {print $2; exit}')"
  if [[ -n "$ip" && "$ip" != "127.0.0.1" ]]; then
    echo "$ip"
    exit 0
  fi
done

echo "127.0.0.1"
