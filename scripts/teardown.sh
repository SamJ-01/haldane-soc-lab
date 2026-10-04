#!/usr/bin/env bash
# Delete the whole lab: every VM, disk, network and log workspace in the
# resource group. This cannot be undone, so it asks first.
set -euo pipefail

RESOURCE_GROUP="rg-haldane-lab"

read -r -p "Delete everything in ${RESOURCE_GROUP}? Type the group name to confirm: " answer
if [[ "$answer" != "$RESOURCE_GROUP" ]]; then
  echo "Cancelled."
  exit 1
fi

az group delete --name "$RESOURCE_GROUP" --yes
echo "Deleted ${RESOURCE_GROUP}."
