#!/bin/bash
set -euo pipefail

UBUNTU_CODENAME="$(lsb_release -cs 2>/dev/null || echo jammy)"
[[ "$UBUNTU_CODENAME" != "jammy" ]] && UBUNTU_CODENAME="jammy"

echo "[*] apt update/upgrade…"
sudo apt update
sudo apt -y full-upgrade

echo "[*] Installing base packages…"
sudo apt -y install curl wget gnupg lsb-release apt-transport-https ca-certificates \
                     nftables tor proxychains4 torsocks macchanger \
                     net-tools iproute2 iputils-ping dnsutils whois tcpdump git \
                     python3-pip python3-venv golang boxes lolcat || true
# Fallback for lolcat if apt lacks it:
command -v lolcat >/dev/null || { sudo apt -y install ruby && sudo gem install lolcat; }

echo "[*] Installing Docker…"
if [ ! -f /usr/share/keyrings/docker.gpg ]; then
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg
fi
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" \
| sudo tee /etc/apt/sources.list.d/docker.list >/dev/null
sudo apt update
sudo apt -y install docker-ce docker-ce-cli containerd.io || sudo apt -y install docker.io || true
getent group docker >/dev/null && sudo usermod -aG docker "$USER" || true

echo "[*] Preparing work dirs…"
mkdir -p "$HOME/kali-work" scripts

echo "[*] Building my-kali:latest…"
docker pull kalilinux/kali-rolling
docker build -t my-kali:latest -f Dockerfile.kali .

# Store user-supplied proxies
PROXY_STORE="/etc/proxychains.d"
sudo mkdir -p "$PROXY_STORE"
if [ -s ".proxy_lines" ]; then
  sudo tee "$PROXY_STORE/upstreams.list" >/dev/null < .proxy_lines
fi

# nftables kill-switch:
TOR_UID="$(id -u debian-tor 2>/dev/null || echo 0)"
ME_UID="$(id -u)"
sudo tee /etc/nftables.conf >/dev/null <<NFT
define TOR_UID = ${TOR_UID}
define ME_UID  = ${ME_UID}

table inet filter {
  chain output {
    type filter hook output priority 0;

    oif lo accept
    ct state established,related accept

    # Tor daemon may reach the world
    meta skuid \$TOR_UID accept

    # This user may ONLY reach local Tor SOCKS
    ip daddr 127.0.0.1 tcp dport 9050 meta skuid \$ME_UID accept
    ip6 daddr ::1       tcp dport 9050 meta skuid \$ME_UID accept

    drop
  }
}
NFT
sudo nft -f /etc/nftables.conf

# Proxychains header template (strict chain: Tor -> chosen upstream)
sudo tee /etc/proxychains.conf.header >/dev/null <<'PCH'
strict_chain
proxy_dns
tcp_read_time_out 15000
tcp_connect_time_out 8000

[ProxyList]
# Always first hop: local Tor
socks5 127.0.0.1 9050
# Next hop will be appended by pc-refresh (one live proxy)
PCH

# Install refresh & wrapper
sudo install -m 0755 scripts/pc-refresh.sh /usr/local/bin/pc-refresh
sudo tee /usr/local/bin/pc >/dev/null <<'PCW'
#!/bin/bash
# Tor-first (host kill-switch), then a dynamically chosen live proxy with strict_chain
pc-refresh && exec proxychains4 "$@"
PCW
sudo chmod +x /usr/local/bin/pc

# Convenience runner for Kali
install -m 0755 scripts/run-kali.sh ./run-kali.sh

# Start Tor (no systemd): run as debian-tor to match rules
echo "[*] Launching Tor in background…"
sudo -u debian-tor tor >/tmp/tor.log 2>&1 & sleep 3 || true

# MAC randomization (best-effort)
IFACE="$(ip -o -4 route show to default | awk '{print $5}' | head -n1 || true)"
if [ -n "${IFACE}" ]; then
  echo "[*] MAC randomization on ${IFACE}…"
  sudo ip link set "${IFACE}" down || true
  sudo macchanger -r "${IFACE}" || true
  sudo ip link set "${IFACE}" up || true
fi

echo "[*] Running preflight…"
./preflight_check.sh | tee preflight_report.txt

echo
echo "[OK] Baseline ready."
echo "Enter Kali:        ./run-kali.sh"
echo "Tor+Proxies cmd:   pc <command>   (e.g., pc curl https://icanhazip.com)"
