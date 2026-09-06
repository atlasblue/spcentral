#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

echo "Generating Root CA..."
# 1. Generate Root Key (No passphrase prompt)
openssl genrsa -out rootCA.key 4096

# 2. Create Root Certificate 
# CORRECTION: Added -subj to avoid a stalling interactive prompt during script execution
openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 3650 -out rootCA.pem -subj "/CN=Lab ROOT CA"

echo "Creating Configuration File (csr-nc.conf)..."
# 3. Create the configuration file dynamically using a heredoc block
cat <<EOF > csr-nc.conf
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

echo "Generating and Signing Server Certificate..."
# 4. Generate Server Private Key
openssl genrsa -out server-nc.key 2048

# 5. Generate the CSR using the config file
openssl req -new -key server-nc.key -out server-nc.csr -config csr-nc.conf

# 6. Sign the certificate with your Root CA
openssl x509 -req -in server-nc.csr -CA rootCA.pem -CAkey rootCA.key -CAcreateserial -out server-nc.crt -days 365 -sha256 -extfile csr-nc.conf -extensions req_ext

echo "Converting Certificates for UI Deployment..."
# 7. Convert certificate files to .txt to import them in the NC UI deployment
openssl x509 -in server-nc.crt > server-nc-crt.txt
openssl rsa -in server-nc.key > server-nc-key.txt

echo "Certificate generation complete!"
