# 🏢 Samba AD DC Tenant Deployment Lab

This repository contains the automated deployment script for provisioning containerized Samba Active Directory Domain Controllers. It is designed to quickly spin up multiple isolated LDAP environments for testing with Nutanix Prism Central.

## 🚀 Quick Start

To deploy the tenants defined in the script, simply run:
```bash
sudo ./deploy-batch-samba.sh
```

## 🛠️ Useful Commands Cheat Sheet

### Docker & Container Management

| Action | Command |
| :--- | :--- |
| **View all running tenants** | `docker ps -a \| grep samba` |
| **View live logs** | `docker logs -f samba-one` |
| **Restart a tenant** | `docker restart samba-one` |

### Active Directory User Management

*(Run these against an existing container)*

**List all users in a domain:**
```bash
docker exec -it samba-one samba-tool user list
```

**Create a new user manually:**
```bash
docker exec -it samba-one samba-tool user create auditor "Nutanix/4u"
```

**Change a user's password:**
```bash
docker exec -it samba-one samba-tool user setpassword admin --newpassword="NewPassword123!"
```

### Network & Troubleshooting

**Verify open ports on the host:**
ss -tuln | grep 389

**Test LDAP connection locally (requires `ldap-utils`):**
ldapsearch -H ldap://127.0.0.1:3891 -x -b "DC=one,DC=com" -D "CN=admin,CN=Users,DC=one,DC=com" -w "Nutanix/4u"
