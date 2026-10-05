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
# On a mobile connection your IP can change every few minutes within your
# provider's address block; allow the block instead, e.g.:
#   ADMIN_CIDR=92.40.208.0/20 ./scripts/deploy-network.sh
MY_IP="$(curl -s https://api.ipify.org)"
ADMIN_CIDR="${ADMIN_CIDR:-${MY_IP}/32}"
echo "Allowing remote admin from ${ADMIN_CIDR} only"

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
  --parameters adminSourceIp="${ADMIN_CIDR}" \
  --parameters dnsServers="$DNS_JSON" \
  --parameters allowPermanentRdp="${PERMANENT_RDP:-false}" \
  --output table
