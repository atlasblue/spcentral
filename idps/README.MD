# 🏢 Multi-Tenant Samba AD DC Deployment for Nutanix Prism Central

An automated, lightweight deployment tool for provisioning multiple isolated Samba Active Directory Domain Controller (AD DC) containers on a single Linux host. Designed specifically for LDAP integration testing with Nutanix Prism, Nutanix Central and SP Central lab environments.

---

## 🛠️ Prerequisites & Requirements

* **Host OS:** Rocky Linux 8/9, RHEL, CentOS, or Ubuntu Server.
* **CPU/RAM:** Minimum 2 vCPU and 4 GB (supports ~10–20 active tenants IDPs).
* **Permissions:** Root / `sudo` privileges.
* **Network Notice:** The script automatically disables `firewalld` and sets SELinux to `permissive`/`disabled` to ensure unhindered container port mapping.

---

## 🚀 Deployment Instructions

### 1. Clone the Repository
```bash
git clone https://github.com/atlasblue/spcentral.git
cd spcentral/idps/
```

### 2. Configure Domain Tenants
Edit `create_tenants_idps.sh` to define your desired domains, custom LDAP ports, and default AD users:

```bash
# Configuration section inside create_tenants_idps.sh
DOMAINS=("acme.test:3891" "nova.local:3892" "velo.demo:3893")
USERS=("admin" "consumer")
PASS="Nutanix/4u"
```

### 3. Make Script Executable & Run
```bash
chmod +x create_tenants_idps.sh
sudo ./create_tenants_idps.sh
```

---

## ⚙️ Tenant Management Guide

### ➕ Adding a New Tenant
The script is idempotent—it automatically skips ports already in use.

1. Open `create_tenants_idps.sh` in a text editor.
2. Add your new domain FQDN and port to the `DOMAINS` array:
   ```bash
   DOMAINS=("acme.test:3891" "nova.local:3892" "apex.test:3894")
   ```
3. Re-run the deployment script:
   ```bash
   sudo ./create_tenants_idps.sh
   ```
   *Only the new domain (`apex.test` on port `3894`) will be provisioned; existing containers remain untouched.*

---

### ❌ Removing a Tenant
To permanently delete a tenant domain (e.g., `acme.test`):

1. **Stop and remove the container:**
   ```bash
   docker stop acme.test && docker rm acme.test
   ```

2. **Remove persistent data directories:**
   ```bash
   sudo rm -rf /opt/samba-tenants/acme.test
   ```

3. **Update script array:** Remove `"acme.test:3891"` from `DOMAINS` in `create_tenants_idps.sh` to prevent accidental redeployment.

---

## 🔍 Useful Operations & Maintenance

### Check Running Tenants
List all deployed tenant containers:
```bash
docker ps
```

### View Live Container Logs
Inspect real-time authentication logs or troubleshooting output for a tenant (e.g., `acme.test`):
```bash
docker logs -f acme.test
```

### Restart a Specific Tenant Container
```bash
docker restart acme.test
```

### AD User Management (on a running tenant)
* **List users:** `docker exec -it acme.test samba-tool user list`
* **Create user:** `docker exec -it acme.test samba-tool user create auditor "Nutanix/4u"`
* **Reset password:** `docker exec -it acme.test samba-tool user setpassword admin --newpassword="NewPassword123!"`

### Test LDAP Connection Locally
Verify that a tenant's LDAP directory is responding on host port `3891` (requires `openldap-clients` or `ldap-utils`):
```bash
ldapsearch -H ldap://127.0.0.1:3891 -x \
  -b "DC=acme,DC=test" \
  -D "CN=admin,CN=Users,DC=acme,DC=test" \
  -w "Nutanix/4u"
```

---

## 📌 Nutanix Prism Central Integration Settings

When configuring your Directory Service in Nutanix Prism Central, use the following parameters:

* **Directory Type:** Active Directory / LDAP
* **Domain Name:** `acme.test` (or your configured tenant domain)
* **Server IP / Hostname:** `<Your-Linux-Host-IP>`
* **Port:** `3891` (or tenant custom mapped port)
* **Service Account Distinguished Name (DN):** `CN=admin,CN=Users,DC=acme,DC=test`
* **Service Account Password:** `Nutanix/4u`
