#!/usr/bin/env bash
# Runs ON KALI01 (sent there by scripts/install-nessus.sh).
# Downloads the newest Nessus for Debian/Kali from Tenable and starts it.
set -euo pipefail

API="https://www.tenable.com/downloads/api/v2/pages/nessus"

# The Azure Kali image is a minimal install without curl.
if ! command -v curl >/dev/null; then
  echo "Installing curl..."
  sudo apt-get update -qq
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq curl ca-certificates
fi

echo "Finding the newest Nessus release..."
FILE="$(curl -fsSL "$API" | grep -o 'Nessus-[0-9.]*-debian10_amd64\.deb' | sort -uV | tail -1)"
if [[ -z "$FILE" ]]; then
  echo "Couldn't find a Nessus download on Tenable's site." >&2
  exit 1
fi

echo "Downloading $FILE..."
curl -fL --progress-bar -o "/tmp/$FILE" "$API/files/$FILE"

echo "Installing..."
sudo dpkg -i "/tmp/$FILE"
sudo systemctl enable --now nessusd
rm -f "/tmp/$FILE"

echo "Nessus is running. Open https://localhost:8834 on your Mac while connected"
echo "with ./scripts/connect.sh kali01"
