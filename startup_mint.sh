#!/bin/bash
# Basic startup script for a fresh Linux Mint (Ubuntu-based) VPS
# This script performs system updates, installs essential packages,
# hardens SSH, configures a simple firewall, and optionally installs Docker.
# Modify values (e.g., NEW_SSH_PORT) as needed.

set -euo pipefail

# Variables (customize these as needed)
NEW_SSH_PORT=2222
# Uncomment and set NEW_USER to create a non-root user
# NEW_USER="yourusername"

# 1. Update and upgrade the system
sudo apt update -y
sudo apt full-upgrade -y

# 2. Install essential utilities
sudo apt install -y curl wget git ufw openssh-server apt-transport-https ca-certificates gnupg lsb-release

# 3. Create a new non-root user (if NEW_USER is set)
if [ -n "${NEW_USER:-}" ]; then
    if ! id "$NEW_USER" >/dev/null 2>&1; then
        echo "[*] Creating user $NEW_USER"
        sudo adduser --disabled-password --gecos "" "$NEW_USER"
        sudo usermod -aG sudo "$NEW_USER"
    fi
fi

# 4. Harden SSH configuration
# Change the SSH port and disable root login
sudo sed -i "s/^#\?Port .*/Port $NEW_SSH_PORT/" /etc/ssh/sshd_config
sudo sed -i "s/^#\?PermitRootLogin .*/PermitRootLogin no/" /etc/ssh/sshd_config
sudo systemctl restart ssh

# 5. Configure UFW firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow "$NEW_SSH_PORT"/tcp
sudo ufw --force enable

# 6. Optional: Install Docker
# Comment this section if you do not need Docker.
if ! command -v docker >/dev/null 2>&1; then
    echo "[*] Installing Docker..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt update -y
    sudo apt install -y docker-ce docker-ce-cli containerd.io
    # Add current user to docker group if not already present
    if [ -n "$USER" ]; then
        sudo usermod -aG docker "$USER"
    fi
fi

# 7. Display completion message
cat <<EOM
-------------------------------------------------------------------
Startup tasks complete.
- System updated and upgraded
- Essential packages installed
- SSH secured (port $NEW_SSH_PORT, root login disabled)
- UFW firewall enabled (allowing port $NEW_SSH_PORT/tcp)
- Docker installed (if not already present)

If you created a new user, remember to set a password:
  sudo passwd $NEW_USER

Reboot the system to ensure all changes (especially group membership) take effect.
-------------------------------------------------------------------
EOM
