#!/usr/bin/env bash
# Just-in-Time access: open remote access to the lab VMs for your CURRENT IP,
# for 3 hours (RDP for the Windows servers, SSH for Kali). After that, Azure
# closes it again by itself.
#   ./scripts/request-access.sh                    # DC01 and WS01
#   ./scripts/request-access.sh WS01               # just one VM
#   ./scripts/request-access.sh DC01 WS01 KALI01   # all three
set -euo pipefail

RESOURCE_GROUP="rg-haldane-lab"
HOURS=3

if [[ $# -eq 0 ]]; then
  VMS=(DC01 WS01)
else
  VMS=("$@")
fi

MY_IP="$(curl -s https://api.ipify.org)"
# On a mobile connection your IP can change mid-session; set ADMIN_CIDR to
# your provider's address block (e.g. 92.40.208.0/20) to allow all of it.
SOURCE="${ADMIN_CIDR:-$MY_IP}"
# End time in UTC. macOS and Linux spell the date command differently.
END_TIME="$(date -u -v+${HOURS}H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
  || date -u -d "+${HOURS} hours" +%Y-%m-%dT%H:%M:%SZ)"
SUB_ID="$(az account show --query id --output tsv)"

# Find the lab's JIT policy, whatever it's called (jit-haldane if created by
# deploy-jit.sh, "default" if JIT was enabled in the portal).
POLICY="$(az rest --method get \
  --url "https://management.azure.com/subscriptions/${SUB_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Security/jitNetworkAccessPolicies?api-version=2020-01-01" \
  --query "value[0].id" --output tsv)"
if [[ -z "$POLICY" ]]; then
  echo "No JIT policy found in ${RESOURCE_GROUP}. Run ./scripts/deploy-jit.sh first." >&2
  exit 1
fi

# The request lists each VM, the port to open, who may connect and until when.
ENTRIES=""
for vm in "${VMS[@]}"; do
  vm="$(echo "$vm" | tr '[:lower:]' '[:upper:]')"
  if [[ "$vm" == KALI* ]]; then PORT=22; else PORT=3389; fi
  VM_ID="/subscriptions/${SUB_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Compute/virtualMachines/${vm}"
  ENTRIES+="{\"id\":\"${VM_ID}\",\"ports\":[{\"number\":${PORT},\"allowedSourceAddressPrefix\":\"${SOURCE}\",\"endTimeUtc\":\"${END_TIME}\"}]},"
done
BODY="{\"virtualMachines\":[${ENTRIES%,}],\"justification\":\"Lab admin session\"}"

az rest --method post \
  --url "https://management.azure.com${POLICY}/initiate?api-version=2020-01-01" \
  --body "$BODY" --output none

echo "Access open to ${VMS[*]} from ${SOURCE} until ${END_TIME} (UTC)."
