#!/usr/bin/env bash
set -Eeuo pipefail

PC_IP="x.x.x.x"
PC_USER="admin"
PC_PASS=""
API_VERSION="${API_VERSION:-v4.2}"

DOMAINS=(
  acme.fr nova.fr alpha.com beta.fr delta.com
  zenith.fr atlas.com orion.fr nexus.com vertex.fr
)

command -v jq >/dev/null || { echo "jq is required"; exit 1; }
[[ -n "$PC_PASS" ]] || read -rsp "Prism Central password: " PC_PASS; echo

BASE="https://${PC_IP}:9440/api/clustermgmt/v4.3"
TASKS="https://${PC_IP}:9440/api/prism/v4.3/config/tasks"

get() {
  curl -ksS -u "$PC_USER:$PC_PASS" \
    -H "Accept: application/json" "$1"
}

echo "Reading cluster information..."

CLUSTERS=$(get "$BASE/config/clusters")
CLUSTER=$(jq -r '.data[0].extId // empty' <<<"$CLUSTERS")

[[ -n "$CLUSTER" ]] || {
  echo "Unable to determine cluster ExtID"; jq . <<<"$CLUSTERS"; exit 1;
}

HOSTS=$(get "$BASE/config/hosts?\$limit=500")
POOL=$(jq -r --arg c "$CLUSTER" '
  [.data[]? | select(.clusterExtId == $c) | .storagePoolExtId][0] // empty
' <<<"$HOSTS")

[[ -n "$POOL" ]] || {
  echo "Unable to determine storage pool ExtID"; exit 1;
}

EXISTING=$(get "$BASE/config/storage-containers?\$limit=500")

for DOMAIN in "${DOMAINS[@]}"; do
  NAME="storage_tenant_${DOMAIN%%.*}"

  if jq -e --arg n "$NAME" --arg c "$CLUSTER" \
    '.data[]? | select(.name == $n and .clusterExtId == $c)' \
    <<<"$EXISTING" >/dev/null; then
    echo "Skipping existing container: $NAME"
    continue
  fi

  PAYLOAD=$(jq -n \
    --arg n "$NAME" \
    --arg c "$CLUSTER" \
    --arg p "$POOL" '{
      "$objectType": "clustermgmt.v4.config.StorageContainer",
      name: $n,
      clusterExtId: $c,
      storagePoolExtId: $p,
      isShared: false
    }')

  RESPONSE=$(curl -ksS -u "$PC_USER:$PC_PASS" \
    -H "Content-Type: application/json" \
    -H "Accept: application/json" \
    -H "NTNX-Request-Id: $(cat /proc/sys/kernel/random/uuid)" \
    -X POST "$BASE/config/storage-containers" \
    --data "$PAYLOAD" \
    -w $'\n%{http_code}')

  CODE="${RESPONSE##*$'\n'}"
  BODY="${RESPONSE%$'\n'*}"

  [[ "$CODE" == "202" ]] || {
    echo "Failed to create $NAME: HTTP $CODE"
    jq . <<<"$BODY" 2>/dev/null || echo "$BODY"
    exit 1
  }

  TASK=$(jq -r '.data.extId // .data.taskReference.extId // empty' <<<"$BODY")
  [[ -n "$TASK" ]] || { echo "No task ID returned for $NAME"; exit 1; }

  for _ in {1..60}; do
    TASK_RESPONSE=$(get "$TASKS/$TASK")
    STATUS=$(jq -r '.data.status // .data.task.status // empty' <<<"$TASK_RESPONSE")

    case "$STATUS" in
      SUCCEEDED|SUCCESS)
        echo "Created: $NAME"
        break
        ;;
      FAILED|FAILURE|ERROR)
        echo "Creation failed: $NAME"
        jq . <<<"$TASK_RESPONSE"
        exit 1
        ;;
      *) sleep 3 ;;
    esac
  done
done

echo "All storage containers processed."
