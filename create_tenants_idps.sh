#!/bin/bash
[ "$EUID" -ne 0 ] && echo "Must run as root" && exit 1

# --- CONFIGURATION ---
DOMAINS=("acme.test:3891" "nova.local:3892")
USERS=("admin" "consumer")
PASS="Nutanix/4u"
BASE_DIR="/opt/samba-tenants"

# --- 1. HOST PREPARATION ---
systemctl disable --now firewalld 2>/dev/null
setenforce 0 2>/dev/null; sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config 2>/dev/null

if ! command -v docker &>/dev/null; then
    dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
    dnf install -y docker-ce docker-ce-cli containerd.io && systemctl enable --now docker
fi

# --- 2. BUILD BASE IMAGE (ONCE) ---
echo "Building base Samba image..."
mkdir -p "$BASE_DIR/base"

cat << 'EOF' > "$BASE_DIR/base/entrypoint.sh"
#!/bin/bash
if [ ! -f /etc/samba/smb.conf ]; then
    samba-tool domain provision --realm="$DOMAIN" --domain="$NETBIOS" --adminpass="$PASS" --server-role=dc --dns-backend=NONE
    sed -i -e '/\[global\]/a \    ldap server require strong auth = no' /etc/samba/smb.conf
    for U in $USER_LIST; do samba-tool user create "$U" "$PASS"; done
fi
exec /usr/sbin/samba -i
EOF

cat << 'EOF' > "$BASE_DIR/base/Dockerfile"
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y samba smbclient winbind && rm -rf /var/lib/apt/lists/*
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
EOF

docker build -t samba-base "$BASE_DIR/base" -q

# --- 3. DEPLOY TENANTS ---
for E in "${DOMAINS[@]}"; do
    D="${E%%:*}"; P="${E##*:}"
    SD="${D%%.*}"; NB=$(echo "$SD" | tr 'a-z' 'A-Z')
    T_DIR="$BASE_DIR/$D"

    if ss -tuln | grep -q ":$P "; then echo "Skip $D: Port$P in use"; continue; fi
    mkdir -p "$T_DIR/data" "$T_DIR/config"
    
    echo "Deploying $D on port$P..."
    docker run -d --name "$D" --privileged --restart unless-stopped \
        -p "$P:389" \
        -v "$T_DIR/data:/var/lib/samba" \
        -v "$T_DIR/config:/etc/samba" \
        -e DOMAIN="$D" -e NETBIOS="$NB" -e PASS="$PASS" -e USER_LIST="${USERS[*]}" \
        samba-base >/dev/null
done

echo "Deployments finished successfully."
