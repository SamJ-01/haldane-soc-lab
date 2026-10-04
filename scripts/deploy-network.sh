#!/usr/bin/env bash
# Phase 0: create the resource group and deploy the lab network.
# Run from the repo folder on your Mac after `az login`:
#   ./scripts/deploy-network.sh
set -euo pipefail

RESOURCE_GROUP="rg-haldane-lab"
LOCATION="uksouth"

# Your home IP, so only you can connect. Re-run this script if it changes.
MY_IP="$(curl -s https://api.ipify.org)"
echo "Allowing remote admin from ${MY_IP} only"

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/network.bicep \
  --parameters adminSourceIp="${MY_IP}/32" \
  --output table
