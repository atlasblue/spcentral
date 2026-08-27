#!/bin/bash
[ "$EUID" -ne 0 ] && echo "Must run as root" && exit 1

DOMAINS=("mocha.local:3891" "latte.local:3892" "espresso.demo:3893")
USERS=("admin" "consumer")
PASS="Nutanix/4u"

# Disable Firewall & SELinux
systemctl disable --now firewalld 2>/dev/null
setenforce 0 2>/dev/null; sed -i 's/^SELINUX=.*/SELINUX=disabled/g' /etc/selinux/config 2>/dev/null

# Install Docker if missing
if ! command -v docker &>/dev/null; then
    dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
    dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin && systemctl enable --now docker
fi

# Build user creation commands dynamically
U_CMDS=""
for U in "${USERS[@]}"; do U_CMDS+="samba-tool user create $U \"$PASS\"; "; done

for E in "${DOMAINS[@]}"; do
    D="${E%%:*}"; P="${E##*:}"
    SD=$(echo "$D" | cut -d'.' -f1)
    NB=$(echo "$SD" | tr '[:lower:]' '[:upper:]')
    DIR="/opt/samba-tenants/$SD"

    ss -tuln | grep -q ":$P " && echo "Skip $D: Port $P in use" && continue
    mkdir -p "$DIR/data" "$DIR/config"

    # Generate Entrypoint
    cat <<EOF > "$DIR/entrypoint.sh"
#!/bin/bash
if [ ! -f /etc/samba/smb.conf ]; then
    samba-tool domain provision --realm="$D" --domain="$NB" --adminpass="$PASS" --server-role=dc --dns-backend=NONE
    sed -i -e '/\[global\]/a \    ldap server require strong auth = no' /etc/samba/smb.conf
    $U_CMDS
fi
exec /usr/sbin/samba -i
EOF

    # Generate Dockerfile
    cat <<EOF > "$DIR/Dockerfile"
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y samba smbclient winbind && rm -rf /var/lib/apt/lists/*
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
EOF

    # Generate Docker Compose
    cat <<EOF > "$DIR/docker-compose.yml"
services:
  samba-dc:
    build: .
    container_name: samba-$SD
    privileged: true
    ports: ["$P:389"]
    volumes: ["./data:/var/lib/samba", "./config:/etc/samba"]
    restart: unless-stopped
EOF

    echo "Deploying $D on port $P..."
    cd "$DIR" && docker compose up -d --build > /dev/null 2>&1
done
echo "Deployments finished."