#!/bin/bash
set -euo pipefail

UPSTREAMS="/etc/proxychains.d/upstreams.list"
HEADER="/etc/proxychains.conf.header"
CONF="/etc/proxychains.conf"

[ -f "$HEADER" ] || { echo "[!] Missing $HEADER"; exit 1; }

LIVE=()
if [ -f "$UPSTREAMS" ]; then
  while read -r line; do
    [[ -z "${line// }" || "${line:0:1}" == "#" ]] && continue
    proto=$(awk '{print $1}' <<<"$line")
    host=$(awk '{print $2}' <<<"$line")
    port=$(awk '{print $3}' <<<"$line")
    # quick liveness: TCP connect to host:port within 2s
    if timeout 2 bash -lc "exec 3<>/dev/tcp/${host}/${port}" 2>/dev/null; then
      LIVE+=("$line")
    fi
  done < "$UPSTREAMS"
fi

pick=""
if [ "${#LIVE[@]}" -gt 0 ]; then
  if [ "${PROXY_SELECT:-first}" = "random" ]; then
    idx=$(( RANDOM % ${#LIVE[@]} ))
    pick="${LIVE[$idx]}"
  else
    pick="${LIVE[0]}"
  fi
fi

sudo cp -f "$HEADER" "$CONF"
if [ -n "$pick" ]; then
  echo "$pick" | sudo tee -a "$CONF" >/dev/null
fi
exit 0
