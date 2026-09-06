#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# ==========================================
# 1. Directory Setup
# ==========================================
ROOT_DIR="root_ca"
NC_DIR="nc"
SP_DIR="sp"

echo "Creating output directories..."
mkdir -p "$ROOT_DIR" "$NC_DIR" "$SP_DIR"

# ==========================================
# 2. Generate Root CA
# ==========================================
echo "Generating Root CA in $ROOT_DIR/..."

# Root Key
openssl genrsa -out "$ROOT_DIR/rootCA.key" 4096

# Root Certificate
openssl req -x509 -new -nodes -key "$ROOT_DIR/rootCA.key" -sha256 -days 3650 -out "$ROOT_DIR/rootCA.pem" -subj "/CN=LAB Root CA"


# ==========================================
# 3. Generate NC (Nutanix Central) Certs
# ==========================================
echo "Generating NC Certificates in $NC_DIR/..."

# Create NC Config
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

# NC Private Key & CSR
openssl genrsa -out "$NC_DIR/server-nc.key" 2048
openssl req -new -key "$NC_DIR/server-nc.key" -out "$NC_DIR/server-nc.csr" -config "$NC_DIR/csr-nc.conf"

# Sign NC CSR with Root CA
openssl x509 -req -in "$NC_DIR/server-nc.csr" -CA "$ROOT_DIR/rootCA.pem" -CAkey "$ROOT_DIR/rootCA.key" -CAcreateserial -out "$NC_DIR/server-nc.crt" -days 365 -sha256 -extfile "$NC_DIR/csr-nc.conf" -extensions req_ext

# Convert formats for NC UI
openssl x509 -in "$NC_DIR/server-nc.crt" > "$NC_DIR/server-nc-crt.txt"
openssl rsa -in "$NC_DIR/server-nc.key" > "$NC_DIR/server-nc-key.txt"


# ==========================================
# 4. Generate SP (Service Provider) Certs
# ==========================================
echo "Generating SP Certificates in $SP_DIR/..."

# Create SP Config (Update DNS entries as needed for your specific SP architecture)
cat <<EOF > "$SP_DIR/csr-sp.conf"
[ req ]
prompt = no
req_extensions = req_ext
distinguished_name = dn

[ dn ]
CN = sp.ntnxlab.local

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = sp.ntnxlab.local
# DNS.2 = Add additional SP DNS records here if required
EOF

# SP Private Key & CSR
openssl genrsa -out "$SP_DIR/server-sp.key" 2048
openssl req -new -key "$SP_DIR/server-sp.key" -out "$SP_DIR/server-sp.csr" -config "$SP_DIR/csr-sp.conf"

# Sign SP CSR with Root CA
openssl x509 -req -in "$SP_DIR/server-sp.csr" -CA "$ROOT_DIR/rootCA.pem" -CAkey "$ROOT_DIR/rootCA.key" -CAcreateserial -out "$SP_DIR/server-sp.crt" -days 365 -sha256 -extfile "$SP_DIR/csr-sp.conf" -extensions req_ext

# Convert formats for SP UI (if applicable)
openssl x509 -in "$SP_DIR/server-sp.crt" > "$SP_DIR/server-sp-crt.txt"
openssl rsa -in "$SP_DIR/server-sp.key" > "$SP_DIR/server-sp-key.txt"

echo "================================================="
echo "Certificate generation and organization complete!"
echo "Check the '$ROOT_DIR', '$NC_DIR', and '$SP_DIR' folders."
