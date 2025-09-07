#!/bin/bash
set -euo pipefail

# Ask once up-front for proxies; stored in .proxy_lines for startup.sh
: > .proxy_lines
read -p "Enter/Update proxies now? [y/N]: " UPD
if [[ "${UPD:-N}" =~ ^[Yy]$ ]]; then
  echo "Enter proxies ONE PER LINE (blank line to finish):"
  echo "  socks5  IP  PORT [user pass]"
  while true; do
    read -r line || true
    [[ -z "${line:-}" ]] && break
    echo "$line" >> .proxy_lines
  done
fi

chmod +x startup.sh preflight_check.sh scripts/pc-refresh.sh scripts/run-kali.sh || true
./startup.sh
