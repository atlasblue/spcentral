#!/usr/bin/env bash

PC_IP="x.x.x.x"
PC_USER="admin"
PC_PASS='replace-with-your-password'
BASE="https://${PC_IP}:9440/api/clustermgmt/v4.3"

CLUSTER=$(
  curl -ksS -u "$PC_USER:$PC_PASS" \
    -H "Accept: application/json" \
    "$BASE/config/clusters" |
    jq -er '.data[0].extId'
) || {
  echo "Unable to retrieve the cluster ExtID"
  exit 1
}

for DOMAIN in acme.fr nova.fr alpha.com beta.fr delta.com \
              zenith.fr atlas.com orion.fr nexus.com vertex.fr; do
  NAME="storage_tenant_${DOMAIN%%.*}"

  curl -ksS -u "$PC_USER:$PC_PASS" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "X-Cluster-Id: $CLUSTER" \
    -H "NTNX-Request-Id: $(cat /proc/sys/kernel/random/uuid)" \
    -X POST "$BASE/config/storage-containers" \
    -d "$(printf '{"$objectType":"clustermgmt.v4.config.StorageContainer","name":"%s","clusterExtId":"%s","isShared":false}' "$NAME" "$CLUSTER")" \
    -o /dev/null \
    -w "$NAME: HTTP %{http_code}\n" &
done

wait
echo "All creation requests submitted."
