#!/usr/bin/env bash
# Just-in-Time access: open RDP to the lab VMs for your CURRENT IP, for 3 hours.
# After that, Azure closes it again by itself.
#   ./scripts/request-access.sh          # DC01 and WS01
#   ./scripts/request-access.sh WS01     # just one VM
set -euo pipefail

RESOURCE_GROUP="rg-haldane-lab"
LOCATION="uksouth"
HOURS=3

if [[ $# -eq 0 ]]; then
  VMS=(DC01 WS01)
else
  VMS=("$@")
fi

MY_IP="$(curl -s https://api.ipify.org)"
# End time in UTC. macOS and Linux spell the date command differently.
END_TIME="$(date -u -v+${HOURS}H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
  || date -u -d "+${HOURS} hours" +%Y-%m-%dT%H:%M:%SZ)"
SUB_ID="$(az account show --query id --output tsv)"
POLICY="/subscriptions/${SUB_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Security/locations/${LOCATION}/jitNetworkAccessPolicies/jit-haldane"

# The request lists each VM, the port to open, who may connect and until when.
ENTRIES=""
for vm in "${VMS[@]}"; do
  VM_ID="/subscriptions/${SUB_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Compute/virtualMachines/${vm}"
  ENTRIES+="{\"id\":\"${VM_ID}\",\"ports\":[{\"number\":3389,\"allowedSourceAddressPrefix\":\"${MY_IP}\",\"endTimeUtc\":\"${END_TIME}\"}]},"
done
BODY="{\"virtualMachines\":[${ENTRIES%,}],\"justification\":\"Lab admin session\"}"

az rest --method post \
  --url "https://management.azure.com${POLICY}/initiate?api-version=2020-01-01" \
  --body "$BODY" --output none

echo "RDP open to ${VMS[*]} from ${MY_IP} until ${END_TIME} (UTC)."
