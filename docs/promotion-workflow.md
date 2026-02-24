# Promotion Workflow: CML → Production

This document describes the GitOps workflow for promoting network
configuration changes from the CML test environment to production.

---

## Overview

```
Developer Workstation          Git / CI                   Network Devices
┌─────────────────────┐   ┌───────────────────┐   ┌──────────────────────┐
│                     │   │                   │   │                      │
│  feature branch     │──▶│  Pull Request     │   │  CML Lab             │
│  (develop + test)   │   │  (peer review)    │──▶│  (automated tests)   │
│                     │   │                   │   │                      │
└─────────────────────┘   └────────┬──────────┘   └──────────────────────┘
                                   │ merge
                           ┌───────▼──────────┐
                           │  main branch      │
                           │  (source of truth)│
                           └───────┬──────────┘
                                   │ manual gate
                           ┌───────▼──────────┐   ┌──────────────────────┐
                           │  CI/CD Pipeline   │──▶│  Production Devices  │
                           │  (deploy job)     │   │  (controlled change) │
                           └───────────────────┘   └──────────────────────┘
```

---

## Phase 1: Feature Development (Developer Workstation)

### 1.1 — Start from main

```bash
git checkout main
git pull origin main
```

### 1.2 — Create feature branch

```bash
git checkout -b feature/<short-description>
# Examples:
#   feature/bgp-r3-r2-peering
#   feature/bgp-timer-tuning
#   fix/r2-static-route-missing
```

### 1.3 — Develop and test against CML

```bash
# Default inventory is CML (set in ansible.cfg)
# Edit files, then apply to CML lab:
ansible-playbook playbooks/site.yml

# Run validation only (non-destructive):
ansible-playbook playbooks/validate_bgp.yml

# Target specific host:
ansible-playbook playbooks/validate_bgp.yml -e "target_hosts=R1"
```

### 1.4 — Commit incrementally

Follow Conventional Commits for every commit:

```bash
git add inventories/cml/host_vars/R3.yml
git commit -m "feat(vars): add R3 BGP config for eBGP to R2"

git add playbooks/deploy_bgp.yml
git commit -m "feat(bgp): extend deploy_bgp to configure R3 neighbor"
```

---

## Phase 2: Pull Request and Review

### 2.1 — Push and open PR

```bash
git push -u origin feature/<short-description>
gh pr create \
  --title "feat: <concise description>" \
  --body "$(cat .github/PULL_REQUEST_TEMPLATE.md)"
```

### 2.2 — Automated CI checks (on PR)

The CI pipeline runs the following checks automatically:

| Check                   | Tool              | Target        |
|------------------------|-------------------|---------------|
| YAML lint              | yamllint          | All YAML      |
| Ansible lint           | ansible-lint      | All playbooks |
| CML validation run     | ansible-playbook  | CML inventory |
| BGP validation         | validate_bgp.yml  | CML devices   |

A PR cannot be merged until all checks pass.

### 2.3 — Peer review checklist

Reviewers should verify:

- [ ] CML test results are shown (CI log or manual evidence)
- [ ] BGP sessions established and expected prefixes learned
- [ ] Connectivity pings pass
- [ ] No plain-text credentials in any committed file
- [ ] Variable changes in `inventories/cml/` are mirrored in `inventories/production/`
- [ ] Commit messages follow Conventional Commits
- [ ] AGENTS.md constraints are satisfied (IOS 15.x syntax, RFC 4271 compliance)

### 2.4 — Address feedback

Additional commits on the same branch are fine:

```bash
git commit -m "fix(bgp): adjust R3 timers per review feedback"
git push
```

---

## Phase 3: Merge to Main

After PR approval, merge via GitHub (squash+merge or merge commit — both
are acceptable; squash keeps the log cleaner for small changes).

```bash
# Post-merge: always pull and clean up
git checkout main
git pull origin main
```

---

## Phase 4: Production Deployment (Manual Gate)

**Production deployment is never automatic.** After main is updated, a
designated operator (network engineer or change approver) executes the
following sequence:

### 4.1 — Dry run (mandatory)

```bash
export ANSIBLE_VAULT_PASSWORD_FILE=~/.vault_pass_ccie_demo

ansible-playbook -i inventories/production playbooks/site.yml \
  --check \
  --diff
```

Review the diff output carefully. If unexpected changes appear, stop and
investigate before proceeding.

### 4.2 — Obtain change approval

Share the `--check --diff` output with the change approver. Proceed only
after explicit approval.

### 4.3 — Live deployment

```bash
ansible-playbook -i inventories/production playbooks/site.yml
# site.yml will pause and prompt for confirmation before applying changes.
# Press ENTER to proceed or Ctrl+C (then A) to abort.
```

### 4.4 — Post-deployment validation

Validation runs automatically as part of `site.yml`. If running separately:

```bash
ansible-playbook -i inventories/production playbooks/validate_bgp.yml
```

Verify:
- BGP sessions are Established
- Expected prefixes are present in routing tables
- Loopback reachability pings succeed

### 4.5 — Rollback

If validation fails, restore the previous configuration:

```bash
# Option 1: Ansible rollback playbook (if available)
ansible-playbook -i inventories/production playbooks/rollback_bgp.yml

# Option 2: git revert + redeploy
git revert HEAD
git push origin main
ansible-playbook -i inventories/production playbooks/site.yml

# Option 3: Manual CLI on device (last resort - document and reconcile in git)
```

---

## Environment Parity Principle

Changes to `inventories/cml/host_vars/` should **always be mirrored** in
`inventories/production/host_vars/`. The only deliberate differences between
environments are:

| File                      | CML                          | Production                    |
|---------------------------|------------------------------|-------------------------------|
| `hosts.yml` → ansible_host | DHCP from bridge10          | Static production mgmt IP     |
| `group_vars/all.yml` →credentials | Plain text (lab)    | Ansible Vault variables       |
| `group_vars/all.yml` →environment | `cml`              | `production`                  |

Everything else — BGP ASNs, router IDs, peer IPs, timers, networks
— must be identical. This is the **parity principle**: if it works in CML,
it works in production.

---

## Quick Reference

| Task                          | Command                                                         |
|-------------------------------|----------------------------------------------------------------|
| Test in CML (default)         | `ansible-playbook playbooks/site.yml`                          |
| Validate only (CML)           | `ansible-playbook playbooks/validate_bgp.yml`                  |
| Production dry run            | `ansible-playbook -i inventories/production playbooks/site.yml --check --diff` |
| Production deploy             | `ansible-playbook -i inventories/production playbooks/site.yml` |
| Validate production           | `ansible-playbook -i inventories/production playbooks/validate_bgp.yml` |
| Set vault pass (env)          | `export ANSIBLE_VAULT_PASSWORD_FILE=~/.vault_pass_ccie_demo`   |
