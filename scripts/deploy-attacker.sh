#!/usr/bin/env bash
# Phase 3: deploy KALI01 (10.10.2.4) into the attacker subnet.
#   ./scripts/deploy-attacker.sh
#
# Creates an SSH key on your Mac (~/.ssh/haldane_kali) if you don't have one,
# finds the newest Kali image in the Azure Marketplace and accepts its terms
# (Kali is free; accepting is a one-off formality), then deploys the VM.
# Costs money while running: ./scripts/stop-lab.sh stops it with the others.
set -euo pipefail

RESOURCE_GROUP="rg-haldane-lab"
KEY="$HOME/.ssh/haldane_kali"

if [[ ! -f "$KEY" ]]; then
  echo "Creating SSH key $KEY (press Enter twice for no passphrase, or set one)"
  ssh-keygen -t ed25519 -f "$KEY" -C "haldane-kali"
fi

echo "Finding the newest Kali image..."
# Skip the arm64 images: the lab's VM size (B2s_v2) is an Intel/AMD (x64) size.
URN="$(az vm image list --publisher kali-linux --offer kali --all \
  --query "sort_by([?!contains(sku, 'arm64')], &version)[-1].urn" --output tsv)"
if [[ -z "$URN" ]]; then
  echo "No Kali image found in the Marketplace." >&2
  exit 1
fi
SKU="$(echo "$URN" | cut -d: -f3)"
echo "Using $URN"

az vm image terms accept --urn "$URN" --output none

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/attacker.bicep \
  --parameters sshPublicKey="$(cat "${KEY}.pub")" kaliSku="$SKU" \
  --query "properties.outputs.publicIpAddress.value" \
  --output tsv
