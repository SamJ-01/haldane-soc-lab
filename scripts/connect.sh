#!/usr/bin/env bash
# Open a Remote Desktop session to a lab VM (macOS, Windows App).
#
#   ./scripts/connect.sh ws01              # signs in as HALDANE\haldaneadmin
#   ./scripts/connect.sh dc01
#   ./scripts/connect.sh ws01 a.patel      # signs in as HALDANE\a.patel
#
# Request access first with request-access.sh: RDP is closed otherwise.
# The password is typed into Windows App, never stored here.
set -euo pipefail

RESOURCE_GROUP="rg-haldane-lab"
VM="$(echo "${1:?Usage: $0 dc01|ws01 [username]}" | tr '[:lower:]' '[:upper:]')"
USERNAME="HALDANE\\${2:-haldaneadmin}"

IP=$(az vm list-ip-addresses --resource-group "$RESOURCE_GROUP" --name "$VM" \
  --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)
if [ -z "$IP" ]; then
  echo "No public IP for $VM. Is it running? Try ./scripts/start-lab.sh" >&2
  exit 1
fi

RDP_FILE="${TMPDIR:-/tmp}/haldane-${VM}.rdp"
cat > "$RDP_FILE" <<RDP
full address:s:${IP}:3389
username:s:${USERNAME}
prompt for credentials:i:1
RDP

echo "Opening $VM ($IP) as $USERNAME..."
open "$RDP_FILE"
