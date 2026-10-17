#!/bin/bash

set -e

# Detect distribution and release
DISTRO=$(lsb_release -is | tr '[:upper:]' '[:lower:]')
RELEASE=$(lsb_release -cs)

echo "[INFO] Updating system..."
sudo apt update -y
# Uncomment the next line if you want a full upgrade
# sudo apt dist-upgrade -y

echo "[INFO] Installing prerequisites..."
sudo apt install -y apt-transport-https ca-certificates curl gnupg-agent python3-pip

echo "[INFO] Adding Docker GPG key..."
curl -fsSL https://download.docker.com/linux/$DISTRO/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker.gpg

echo "[INFO] Adding Docker repository..."
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker.gpg] \
https://download.docker.com/linux/$DISTRO $RELEASE stable" | \
sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

echo "[INFO] Installing Docker packages..."
sudo apt update -y
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

echo "[INFO] Restarting Docker service..."
sudo systemctl restart docker
sudo systemctl enable docker

echo "[INFO] Docker installation complete!"
docker --version
docker compose version || true
