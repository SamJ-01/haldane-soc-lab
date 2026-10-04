#!/usr/bin/env bash
# Phase 1: deploy DC01 and WS01 into the lab network.
# Run after deploy-network.sh:
#   ./scripts/deploy-servers.sh
#
# Costs money while the VMs are running. Stop them with ./scripts/stop-lab.sh.
set -euo pipefail

RESOURCE_GROUP="rg-haldane-lab"

echo "Choose the local admin password for both VMs."
echo "12+ characters, with upper case, lower case, a number and a symbol."
echo "Save it in your password manager: it is not stored anywhere else."
read -r -s -p "Password: " PASSWORD; echo
read -r -s -p "Confirm:  " CONFIRM; echo
if [[ "$PASSWORD" != "$CONFIRM" ]]; then
  echo "Passwords don't match." >&2
  exit 1
fi

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/servers.bicep \
  --parameters adminPassword="$PASSWORD" \
  --query "properties.outputs.publicIpAddresses.value" \
  --output table
