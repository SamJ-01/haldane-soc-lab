#!/usr/bin/env bash
# Connect to a lab VM from your Mac.
#
#   ./scripts/connect.sh ws01              # Remote Desktop as HALDANE\haldaneadmin
#   ./scripts/connect.sh dc01
#   ./scripts/connect.sh ws01 a.patel      # Remote Desktop as HALDANE\a.patel
#   ./scripts/connect.sh kali01            # SSH to Kali, with Nessus tunnelled to
#                                          # https://localhost:8834 on your Mac
#
# Request access first with request-access.sh: RDP and SSH are closed otherwise.
# Windows passwords are typed into Windows App, never stored here.
set -euo pipefail

RESOURCE_GROUP="rg-haldane-lab"
VM="$(echo "${1:?Usage: $0 dc01|ws01|kali01 [username]}" | tr '[:lower:]' '[:upper:]')"
USER_ARG="${2:-haldaneadmin}"
# zsh doesn't treat "#" as a comment when commands are pasted, so a pasted
# "# comment" would arrive here as the username. Ignore it.
case "$USER_ARG" in "#"*) USER_ARG="haldaneadmin" ;; esac
USERNAME="HALDANE\\${USER_ARG}"

IP=$(az vm list-ip-addresses --resource-group "$RESOURCE_GROUP" --name "$VM" \
  --query "[0].virtualMachine.network.publicIpAddresses[0].ipAddress" --output tsv)
if [ -z "$IP" ]; then
  echo "No public IP for $VM. Is it running? Try ./scripts/start-lab.sh" >&2
  exit 1
fi

if [[ "$VM" == KALI* ]]; then
  echo "SSH to $VM ($IP). Nessus: https://localhost:8834 while this is open. Type exit to leave."
  # Keepalives stop mobile and home routers dropping a quiet connection.
  exec ssh -i "$HOME/.ssh/haldane_kali" -o ServerAliveInterval=30 -o ServerAliveCountMax=4 \
    -L 8834:localhost:8834 "haldaneadmin@${IP}"
fi

RDP_FILE="${TMPDIR:-/tmp}/haldane-${VM}.rdp"
cat > "$RDP_FILE" <<RDP
full address:s:${IP}:3389
username:s:${USERNAME}
prompt for credentials:i:1
RDP

echo "Opening $VM ($IP) as $USERNAME..."
open "$RDP_FILE"
