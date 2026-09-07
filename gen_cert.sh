#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# ==========================================
# 1. Directory Setup
# ==========================================
ROOT_DIR="root_ca"
NC_DIR="nc"
SP_DIR="sp"
DNS_DIR="dns_config"

echo "Creating output directories..."
mkdir -p "$ROOT_DIR" "$NC_DIR" "$SP_DIR" "$DNS_DIR"

# ==========================================
# 2. Generate Root CA
# ==========================================
echo "Generating Root CA in $ROOT_DIR/..."
openssl genrsa -out "$ROOT_DIR/rootCA.key" 4096
openssl req -x509 -new -nodes -key "$ROOT_DIR/rootCA.key" -sha256 -days 3650 -out "$ROOT_DIR/rootCA.pem" -subj "/CN=LAB Root CA"

# ==========================================
# 3. Generate Nutanix Central Certs
# ==========================================
echo "Generating NC Certificates in $NC_DIR/..."
cat <<EOF > "$NC_DIR/csr-nc.conf"
[ req ]
prompt = no
req_extensions = req_ext
distinguished_name = dn

[ dn ]
CN = spc.ntnxlab.local

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = nc.ntnxlab.local
DNS.2 = iam.nc.ntnxlab.local
DNS.3 = ncm.data.nc.ntnxlab.local
DNS.4 = *.domains.nc.ntnxlab.local
DNS.5 = *.services.nc.ntnxlab.local
DNS.6 = *.transport.nc.ntnxlab.local
DNS.7 = *.tenants.nc.ntnxlab.local
EOF

openssl genrsa -out "$NC_DIR/server-nc.key" 2048
openssl req -new -key "$NC_DIR/server-nc.key" -out "$NC_DIR/server-nc.csr" -config "$NC_DIR/csr-nc.conf"
openssl x509 -req -in "$NC_DIR/server-nc.csr" -CA "$ROOT_DIR/rootCA.pem" -CAkey "$ROOT_DIR/rootCA.key" -CAcreateserial -out "$NC_DIR/server-nc.crt" -days 365 -sha256 -extfile "$NC_DIR/csr-nc.conf" -extensions req_ext
openssl x509 -in "$NC_DIR/server-nc.crt" > "$NC_DIR/server-nc-crt.txt"
openssl rsa -in "$NC_DIR/server-nc.key" > "$NC_DIR/server-nc-key.txt"

# ==========================================
# 4. Generate SP Central Certs
# ==========================================
echo "Generating SP Certificates in $SP_DIR/..."
cat <<EOF > "$SP_DIR/csr-sp.conf"
[ req ]
prompt = no
req_extensions = req_ext
distinguished_name = dn

[ dn ]
CN = spc.ntnxlab.local

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = spc.ntnxlab.local
DNS.2 = iam.spc.ntnxlab.local
DNS.3 = *.domains.spc.ntnxlab.local
DNS.4 = *.services.spc.ntnxlab.local
DNS.5 = *.transport.spc.ntnxlab.local
DNS.6 = *.tenants.spc.ntnxlab.local
EOF

openssl genrsa -out "$SP_DIR/server-sp.key" 2048
openssl req -new -key "$SP_DIR/server-sp.key" -out "$SP_DIR/server-sp.csr" -config "$SP_DIR/csr-sp.conf"
openssl x509 -req -in "$SP_DIR/server-sp.csr" -CA "$ROOT_DIR/rootCA.pem" -CAkey "$ROOT_DIR/rootCA.key" -CAcreateserial -out "$SP_DIR/server-sp.crt" -days 365 -sha256 -extfile "$SP_DIR/csr-sp.conf" -extensions req_ext
openssl x509 -in "$SP_DIR/server-sp.crt" > "$SP_DIR/server-sp-crt.txt"
openssl rsa -in "$SP_DIR/server-sp.key" > "$SP_DIR/server-sp-key.txt"

# ==========================================
# 5. Generate Windows DNS Setup Script
# ==========================================
echo "Generating PowerShell DNS setup script in $DNS_DIR/..."
cat << 'EOF' > "$DNS_DIR/config_dns.ps1"
# Define variables
$Zone = "ntnxlab.local"
$IPs = "172.16.29.190", "172.16.29.191" # Replace with your actual External IPs

$Names = @(
    # NC Records
    "nc",
    "iam.nc",
    "ncm.data.nc",
    "*.domains.nc",
    "*.services.nc",
    "*.transport.nc",
    "*.tenants.nc",
    # SP Records
    "spc",
    "iam.spc",
    "*.domains.spc",
    "*.services.spc",
    "*.transport.spc",
    "*.tenants.spc"
)

foreach ($IP in $IPs) {
    foreach ($Name in $Names) {
        try {
            Add-DnsServerResourceRecordA -Name $Name -ZoneName $Zone -IPv4Address $IP -ErrorAction Stop
            Write-Host "Successfully added $Name.$Zone pointing to $IP" -ForegroundColor Green
        }
        catch {
            Write-Host "Failed to add $Name for $IP. Error: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
EOF

echo "================================================="
echo "Execution complete!"
echo "Certificates are in '$ROOT_DIR', '$NC_DIR', and '$SP_DIR'."
echo "PowerShell DNS script is located at '$SCRIPTS_DIR/setup_dns.ps1'."
