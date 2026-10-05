#!/usr/bin/env bash
# Phase 0: create the resource group and deploy the lab network.
# Run from the repo folder on your Mac after `az login`:
#   ./scripts/deploy-network.sh
#
# After DC01 becomes a domain controller (Phase 1), point the network's DNS
# at it so other machines can find the domain:
#   DNS_SERVER=10.10.1.4 ./scripts/deploy-network.sh
#
# RDP is normally opened on request with Just-in-Time access
# (./scripts/request-access.sh). To keep a permanent RDP rule for your IP
# instead (e.g. before JIT is set up):
#   PERMANENT_RDP=true ./scripts/deploy-network.sh
set -euo pipefail

RESOURCE_GROUP="rg-haldane-lab"
LOCATION="uksouth"

# Your home IP, so only you can connect. Re-run this script if it changes.
MY_IP="$(curl -s https://api.ipify.org)"
echo "Allowing remote admin from ${MY_IP} only"

# DNS servers for the network. If DNS_SERVER is given, use it. Otherwise
# keep whatever the network already uses, so re-running this script (e.g.
# after your home IP changes) never breaks the domain's DNS.
if [[ -n "${DNS_SERVER:-}" ]]; then
  DNS_JSON="[\"${DNS_SERVER}\"]"
else
  DNS_JSON="$(az network vnet show --resource-group "$RESOURCE_GROUP" --name vnet-haldane \
    --query "dhcpOptions.dnsServers" --output json 2>/dev/null || true)"
  [[ -z "$DNS_JSON" || "$DNS_JSON" == "null" ]] && DNS_JSON="[]"
fi
echo "Network DNS servers: ${DNS_JSON}"

az group create --name "$RESOURCE_GROUP" --location "$LOCATION" --output none

az deployment group create \
  --resource-group "$RESOURCE_GROUP" \
  --template-file infra/network.bicep \
  --parameters adminSourceIp="${MY_IP}/32" \
  --parameters dnsServers="$DNS_JSON" \
  --parameters allowPermanentRdp="${PERMANENT_RDP:-false}" \
  --output table
