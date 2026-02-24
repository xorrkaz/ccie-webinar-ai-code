# Credential Management

This document describes how credentials are managed across the CML test
and production environments, and how to set up the required secrets for
new workstations or CI/CD pipelines.

---

## Overview

| Environment | Credential Storage    | Committed to Git? |
|-------------|----------------------|-------------------|
| CML (test)  | Plain text in `inventories/cml/group_vars/all.yml` | ✅ Yes (lab only) |
| Production  | Ansible Vault encrypted file    | ✅ Encrypted only |

**Golden Rule: Production credentials must NEVER appear in git in plain text.**

---

## CML Environment (Lab)

Plain-text credentials in `inventories/cml/group_vars/all.yml` are acceptable
because:

- The CML environment is an isolated sandboxed lab
- No production systems or data are accessible from CML
- Credentials are shared lab defaults (`admin`/`admin`)
- The network is not routable to production

```yaml
# inventories/cml/group_vars/all.yml
ansible_user:    admin
ansible_password: admin
```

---

## Production Environment

### Architecture: Ansible Vault

Production credentials use [Ansible Vault](https://docs.ansible.com/ansible/latest/user_guide/vault.html):

```
inventories/production/group_vars/
├── all.yml           ← references vault_ variables (committed, plain text)
├── routers.yml       ← BGP config (committed, plain text)
└── vault.yml         ← ENCRYPTED credentials (committed, encrypted)
    vault.yml.example ← Template showing structure (committed, plain text)
```

The `vault.yml` file is **committed to git in encrypted form**. The vault
password is **never committed** — it is provided at runtime via a local file
or CI/CD secret.

### Setup: New Workstation

```bash
# 1. Run the setup script (interactive)
./scripts/setup_vault.sh

# The script will:
# - Create ~/.vault_pass_ccie_demo (chmod 600, git-ignored)
# - Create vault.yml from the example template
# - Prompt you to fill in real credentials
# - Encrypt vault.yml using ansible-vault
```

### Setup: Manual Steps

```bash
# 1. Create the vault password file (never commit this)
echo "your-strong-vault-password" > ~/.vault_pass_ccie_demo
chmod 600 ~/.vault_pass_ccie_demo

# 2. Copy example to real vault file
cp inventories/production/group_vars/vault.yml.example \
   inventories/production/group_vars/vault.yml

# 3. Edit with real credentials
#    Replace REPLACE_WITH_PROD_* values with actual credentials
ansible-vault edit --vault-password-file ~/.vault_pass_ccie_demo \
   inventories/production/group_vars/vault.yml

# 4. Or encrypt an already-edited plain-text file
ansible-vault encrypt --vault-password-file ~/.vault_pass_ccie_demo \
   inventories/production/group_vars/vault.yml

# 5. Commit the encrypted file
git add inventories/production/group_vars/vault.yml
git commit -m "feat(vault): add encrypted production credentials"
```

### Running Production Playbooks

```bash
# Option 1: vault password file
export ANSIBLE_VAULT_PASSWORD_FILE=~/.vault_pass_ccie_demo
ansible-playbook -i inventories/production playbooks/site.yml

# Option 2: explicit flag
ansible-playbook -i inventories/production playbooks/site.yml \
  --vault-password-file ~/.vault_pass_ccie_demo

# Option 3: prompt (useful for manual runs)
ansible-playbook -i inventories/production playbooks/site.yml \
  --ask-vault-pass

# Option 4: CI/CD (see below)
```

### CI/CD Integration

Store the vault password as a secret in your CI/CD platform:

**GitHub Actions:**
```yaml
# In repository Settings → Secrets and variables → Actions
# Add secret: VAULT_PASSWORD

# In workflow .github/workflows/deploy.yml:
- name: Run production playbook
  env:
    ANSIBLE_VAULT_PASSWORD_FILE: /tmp/.vault_pass
  run: |
    echo "${{ secrets.VAULT_PASSWORD }}" > /tmp/.vault_pass
    chmod 600 /tmp/.vault_pass
    ansible-playbook -i inventories/production playbooks/site.yml
    rm -f /tmp/.vault_pass
```

**GitLab CI:**
```yaml
deploy_production:
  script:
    - echo "$VAULT_PASSWORD" > /tmp/.vault_pass
    - chmod 600 /tmp/.vault_pass
    - ansible-playbook -i inventories/production playbooks/site.yml
      --vault-password-file /tmp/.vault_pass
    - rm -f /tmp/.vault_pass
  variables:
    VAULT_PASSWORD: $VAULT_PASSWORD  # CI/CD masked variable
```

---

## Alternative: External Secrets Manager

For teams using HashiCorp Vault, AWS Secrets Manager, or Azure Key Vault,
credentials can be injected as environment variables instead:

```bash
# Retrieve credentials from external vault and export as env vars
export ANSIBLE_USER=$(vault kv get -field=username secret/network/prod)
export ANSIBLE_PASSWORD=$(vault kv get -field=password secret/network/prod)
```

Then update `inventories/production/group_vars/all.yml` to use `lookup('env')`:

```yaml
ansible_user:     "{{ lookup('env', 'ANSIBLE_USER') }}"
ansible_password: "{{ lookup('env', 'ANSIBLE_PASSWORD') }}"
```

This approach works well with cloud-native CI/CD platforms and avoids
maintaining a vault password file entirely.

---

## Security Checklist

Before running any production playbook, verify:

- [ ] `vault.yml` is encrypted: `head -1 inventories/production/group_vars/vault.yml` should show `$ANSIBLE_VAULT;1.1;AES256`
- [ ] No plain-text passwords in git: `git log -p | grep -i password` should return nothing sensitive
- [ ] Vault password file has correct permissions: `ls -la ~/.vault_pass_ccie_demo` should show `-rw-------`
- [ ] `.gitignore` excludes vault password files: check that `.vault_pass*` patterns are present
- [ ] `ansible-playbook --check` runs clean before live deployment
