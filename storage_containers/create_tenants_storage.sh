#!/bin/bash

# --- NUTANIX PRISM CENTRAL CONFIGURATION ---
PC_IP="x.x.x.x"       # Prism Central IP
PC_USER="admin"            # Prism Central admin username
PC_PASS="" # Prism Central admin password

# --- TENANT LIST ---
DOMAINS=(
  "acme.fr" "nova.fr" "alpha.com" "beta.fr" 
  "delta.com" "zenith.fr" "atlas.com" "orion.fr" 
  "nexus.com" "vertex.fr"
)

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: 'jq' is not installed. Run 'sudo dnf install -y jq' or 'sudo apt install -y jq'"
    exit 1
fi

echo "Authenticating to Prism Central at $PC_IP..."

# 1. Fetch the target Cluster ExtID
CLUSTER_RESPONSE=$(curl -k -s -u "$PC_USER":"$PC_PASS" -X GET \
  -H "Accept: application/json" \
  "https://$PC_IP:9440/api/clustermgmt/v4.0/config/clusters")

CLUSTER_EXT_ID=$(echo "$CLUSTER_RESPONSE" | jq -r '.data[0].extId')

if [ -z "$CLUSTER_EXT_ID" ] || [ "$CLUSTER_EXT_ID" == "null" ]; then
    echo "Failed to retrieve Cluster ExtID. Ensure this IP points to Prism Central and v4 APIs are enabled."
    exit 1
fi
echo "Found Target Cluster ExtID: $CLUSTER_EXT_ID"
echo "---------------------------------------------------"

# 2. Loop through the tenants and create a Storage Container
for FQDN in "${DOMAINS[@]}"; do
    
    # Remove the domain extension to get the short name
    SHORT_NAME="${FQDN%%.*}"
    
    # Create the requested container name format: storage_tenant_<name>
    CTR_NAME="storage_tenant_$SHORT_NAME"
    
    echo "Creating Storage Container: $CTR_NAME..."

    # API v4 Payload 
    PAYLOAD=$(cat <<EOF
{
  "name": "$CTR_NAME",
  "clusterExtId": "$CLUSTER_EXT_ID"
}
EOF
)

    # API Call to create the container
    curl -k -s -u "$PC_USER":"$PC_PASS" -X POST \
      -H "Content-Type: application/json" \
      -H "Accept: application/json" \
      -H "Ntnx-Request-Id: $(uuidgen)" \
      -d "$PAYLOAD" \
      "https://$PC_IP:9440/api/clustermgmt/v4.0/config/storage-containers" > /dev/null

    echo "  -> API POST request sent for $CTR_NAME."
done

echo "---------------------------------------------------"
echo "All Tenant Storage Containers have been provisioned!"
