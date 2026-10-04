#!/usr/bin/env bash
# Stop AND deallocate every VM in the lab, so compute billing stops.
# (Shutting down from inside Windows does not deallocate: it keeps billing.)
set -euo pipefail

RESOURCE_GROUP="rg-haldane-lab"

az vm deallocate --ids $(az vm list --resource-group "$RESOURCE_GROUP" --query "[].id" --output tsv)
az vm list --resource-group "$RESOURCE_GROUP" --show-details \
  --query "[].{VM:name, State:powerState}" --output table
