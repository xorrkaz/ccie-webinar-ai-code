# Network Automation - BGP Deployment

AI-assisted network automation for BGP configuration using Ansible and CML.
Follows a GitOps workflow with strict test/production environment separation.

## AI Prompt

This repo was created almost fully from AI.  The `AGENTS.md` and `SKILL.md` had some manual refinement, but the rest was built based on those files and the initial specification prompt:

```text
I need to establish the baseline configuration in our CML test environment. 
This repository uses a test/prod separated structure with AI-assisted 
development guided by AGENTS.md and SKILL.md.

**Context:**
- This is a fresh repository for demonstrating AI-assisted network automation
- I have a Python venv with Ansible installed
- I have a CML MCP server registered and accessible
- The repository structure needs to be created as we go

**CML Topology Requirements:**
Create a 3-router BGP topology:
- 3 IOSv routers: R1, R2, R3
- R1 and R2: Direct connectivity via GigabitEthernet0/1 (192.168.12.0/24)
  - R1: 192.168.12.1/24 on Gi0/1
  - R2: 192.168.12.2/24 on Gi0/1
- R2 and R3: Direct connectivity via GigabitEthernet0/2 (192.168.23.0/24)
  - R2: 192.168.23.2/24 on Gi0/2
  - R3: 192.168.23.3/24 on Gi0/2
- R1 and R3: NO direct connectivity (for multihop demo)
- All routers: Loopback0 configured
  - R1: 1.1.1.1/32
  - R2: 2.2.2.2/32
  - R3: 3.3.3.3/32
- Static routes for Loopback reachability:
  - R1: route to 3.3.3.3/32 via 192.168.12.2
  - R3: route to 1.1.1.1/32 via 192.168.23.2
- Management interfaces on external bridge for Ansible

**Tasks:**

1. **Use CML MCP** to create/start the lab
   - Lab name: "bgp-demo"
   - Retrieve management IP addresses from CML

2. **Create directory structure**:
   
   inventories/
     cml/
       hosts.yml
       group_vars/
         all.yml
     production/
       hosts.yml
       group_vars/
         all.yml
   host_vars/
   group_vars/
   playbooks/
   docs/

3. **Create CML inventory** (inventories/cml/hosts.yml)
   - Use actual management IPs from CML
   - Set environment_name: cml

4. **Create CML environment settings** (inventories/cml/group_vars/all.yml)
   - Test credentials (plain-text is OK for lab)
   - Enable MCP validation: validate_via_mcp: true
   - Environment type: cml

5. **Create production inventory structure** (placeholders only)
   - inventories/production/hosts.yml with placeholder IPs
   - inventories/production/group_vars/all.yml with vault references
   - Document: "Production - credentials via vault/env vars"

6. **Create host_vars** for all routers:
   - Interfaces (Loopback0, data interfaces)
   - Static routes
   - BGP section (initially empty for R3, basic for R1/R2)

7. **Create playbooks/base_config.yml**
   - Deploy interfaces and IP addressing
   - Deploy static routes
   - Environment-aware

8. **Deploy base configuration** to CML
   - Run against inventories/cml/hosts.yml
   - Verify via playbook output

9. **Validate connectivity** using CML MCP:
   - R1 → R2 (direct)
   - R2 → R3 (direct)
   - R1 Loopback0 → R3 Loopback0 (via static route)

10. **Create initial BGP configuration** for R1-R2 only:
    - R1 (AS 65001) peers with R2 (AS 65002)
    - Direct eBGP over Gi0/1
    - R1 advertises 10.1.1.0/24
    - R2 advertises 10.2.2.0/24

11. **Create playbooks/deploy_bgp.yml**
    - Environment-aware
    - Handles optional parameters (ebgp_multihop, timers, etc.)
    - Uses cisco.ios collection

12. **Deploy R1-R2 BGP** to CML
    - Deploy only to R1 and R2
    - Use inventories/cml/hosts.yml

13. **Validate R1-R2 BGP** using CML MCP:
    - BGP session Established
    - Routes exchanged
    - Routing tables correct

14. **Prepare R3** (don't configure BGP):
    - R3 host_vars with interfaces and routes
    - BGP section empty/commented
    - Document: "R3 ready for eBGP multihop demo"

15. **Update AGENTS.md**:
    - Add "Current Demo Environment" section with baseline state
    - Document: R1-R2 BGP working, R3 prepared

16. **Create documentation**:
    - docs/DEPLOYMENT.md - Deployment workflow
    - docs/ENVIRONMENTS.md - Environment details
    - Update README.md with current state

**Workflow:**
- Work in main branch for this setup (it's infrastructure, not a feature)
- Make incremental commits with clear messages
- Use CML MCP extensively to show integration
- Provide detailed validation results
- Document everything

**Output Requirements:**
- Working CML lab with R1-R2 BGP operational
- Complete repository structure (cml + production)
- R3 prepared but no BGP configured
- All configurations committed to main
- Documentation complete
- Summary report of environment state

**Important:**
- Show MCP usage throughout (lab creation, validation, connectivity tests)
- Create production structure but don't populate with real credentials
- Ensure playbooks work across both environments
- Document the test-before-merge workflow for future features
```

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
