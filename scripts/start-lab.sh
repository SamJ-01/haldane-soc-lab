#!/usr/bin/env bash
# Start every VM in the lab, then show their public IPs for RDP.
set -euo pipefail

RESOURCE_GROUP="rg-haldane-lab"

az vm start --ids $(az vm list --resource-group "$RESOURCE_GROUP" --query "[].id" --output tsv)
az vm list-ip-addresses --resource-group "$RESOURCE_GROUP" \
  --query "[].{VM:virtualMachine.name, PublicIP:virtualMachine.network.publicIpAddresses[0].ipAddress}" \
  --output table
