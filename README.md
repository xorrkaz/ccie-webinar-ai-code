# Network Automation - BGP Deployment

AI-assisted network automation for BGP configuration using Ansible and CML.
Follows a GitOps workflow with strict test/production environment separation.

## Repository Structure

```text
.
├── inventories/
│   ├── cml/                         # Test environment (CML lab)
│   │   ├── hosts.yml                # CML management IPs (DHCP via bridge10)
│   │   ├── group_vars/
│   │   │   ├── all.yml              # CML connection vars + plain-text creds (lab only)
│   │   │   └── routers.yml          # Shared BGP defaults
│   │   └── host_vars/
│   │       ├── R1.yml  R2.yml  R3.yml
│   └── production/                  # Production environment
│       ├── hosts.yml                # Placeholder IPs → replace with real values
│       ├── group_vars/
│       │   ├── all.yml              # References vault_ variables (no plain-text creds)
│       │   ├── routers.yml          # Same BGP defaults as CML
│       │   ├── vault.yml            # Ansible Vault ENCRYPTED credentials (committed)
│       │   └── vault.yml.example    # Template showing vault structure
│       └── host_vars/
│           ├── R1.yml  R2.yml  R3.yml
├── playbooks/
│   ├── site.yml                     # Top-level: safety gate → deploy → validate
│   ├── deploy_bgp.yml               # BGP configuration deployment
│   └── validate_bgp.yml             # Post-deploy validation and assertions
├── scripts/
│   └── setup_vault.sh               # Bootstrap vault password + encrypt vault.yml
├── docs/
│   ├── promotion-workflow.md        # GitOps workflow: CML → PR → main → production
│   └── credential-management.md    # Vault setup, CI/CD integration, security checklist
├── .github/
│   └── PULL_REQUEST_TEMPLATE.md     # Enforces CML test evidence on every PR
└── ansible.cfg                      # Default inventory = inventories/cml
```

## Quick Start

### CML (Test) Environment

```bash
# Default — ansible.cfg points to inventories/cml
ansible-playbook playbooks/site.yml            # deploy + validate
ansible-playbook playbooks/validate_bgp.yml    # validate only (non-destructive)
```

### Production Environment

```bash
# Step 1: Set vault password
export ANSIBLE_VAULT_PASSWORD_FILE=~/.vault_pass_ccie_demo

# Step 2: Mandatory dry run
ansible-playbook -i inventories/production playbooks/site.yml --check --diff

# Step 3: After change approval — live deploy
ansible-playbook -i inventories/production playbooks/site.yml
```

### Ad-hoc Commands

```bash
# BGP summary across all routers (CML)
ansible routers -m cisco.ios.ios_command -a "commands='show bgp ipv4 unicast summary'"

# BGP summary (production)
ansible routers -i inventories/production -m cisco.ios.ios_command \
  -a "commands='show bgp ipv4 unicast summary'"
```

## Current Demo State

| Router | AS    | Loopback | BGP Peers      | Notes                     |
|--------|-------|----------|----------------|---------------------------|
| R1     | 65001 | 1.1.1.1  | R2 (eBGP)      | Advertises 10.1.1.0/24    |
| R2     | 65002 | 2.2.2.2  | R1 (eBGP)      | Advertises 10.2.2.0/24    |
| R3     | —     | 3.3.3.3  | None (baseline)| Static routing only       |

- R1 ↔ R2: direct link 192.168.12.0/24 (Gi0/1)
- R2 ↔ R3: direct link 192.168.23.0/24 (Gi0/2)
- R1 ↔ R3: no direct link — multihop via R2 (for BGP demo)

## Documentation

| Document | Description |
| ----------- | ------------- |
| [docs/promotion-workflow.md](docs/promotion-workflow.md) | GitOps workflow from dev to production |
| [docs/credential-management.md](docs/credential-management.md) | Vault setup and security practices |

## Production Setup (First Time)

```bash
# 1. Update production IPs
vim inventories/production/hosts.yml

# 2. Create and encrypt production credentials
./scripts/setup_vault.sh

# 3. Run dry-run
ansible-playbook -i inventories/production playbooks/site.yml --check --diff
```
