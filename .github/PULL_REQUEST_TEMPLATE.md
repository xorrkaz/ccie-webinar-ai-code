## Purpose

<!-- What problem does this change solve? What is the motivation? -->


## Changes Made

<!-- List the specific changes: playbooks added/modified, variables changed, etc. -->

- 
- 

## CML Test Results

<!-- Paste ansible-playbook output or link to CI run. Every PR must show test evidence. -->

```
# ansible-playbook playbooks/validate_bgp.yml output:

```

## BGP Validation

- [ ] R1-R2 BGP session: Established
- [ ] R1 routing table contains expected BGP prefixes
- [ ] R2 routing table contains expected BGP prefixes
- [ ] Loopback pings pass (R1↔R3 via R2)

## Environment Parity

- [ ] Changes to `inventories/cml/host_vars/` are mirrored in `inventories/production/host_vars/`
- [ ] No environment-specific logic was added to shared playbooks
- [ ] `inventories/production/` differences are limited to: ansible_host IPs, credentials

## Security

- [ ] No plain-text credentials in any committed file
- [ ] No secrets, tokens, or API keys committed
- [ ] `.gitignore` covers any new secret file patterns introduced

## Reviewer Focus

<!-- What should the reviewer pay particular attention to? -->

