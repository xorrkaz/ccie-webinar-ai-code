# BGP Automation — Guide for Network Engineers

This document explains what this repository does and how to work with it
if you are comfortable with BGP and Cisco IOS but are new to Ansible.

---

## Topology

```
        AS 65001              AS 65002              AS 65003
     ┌───────────┐         ┌───────────┐         ┌───────────┐
     │    R1     │         │    R2     │         │    R3     │
     │ 1.1.1.1/32│         │ 2.2.2.2/32│         │ 3.3.3.3/32│
     │ (Lo0)     │         │ (Lo0)     │         │ (Lo0)     │
     │           │Gi0/1    │  Gi0/1    │         │           │
     │ 192.168   ├─────────┤ 192.168   │         │ 192.168   │
     │  .12.1/24 │         │  .12.2/24 │         │  .23.3/24 │
     └─────┬─────┘         └─────┬─────┘         └─────┬─────┘
           │                      │     Gi0/2           │
           │                      └─────────────────────┘
           │                           192.168.23.0/24
           │
           │  eBGP multihop (TTL=2, loopback-to-loopback, no direct link)
           └─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘
                                                                     R3 Lo0
```

| Router | AS    | Loopback | BGP Peers                        |
|--------|-------|----------|----------------------------------|
| R1     | 65001 | 1.1.1.1  | R2 (direct), R3 (eBGP multihop) |
| R2     | 65002 | 2.2.2.2  | R1 (direct)                      |
| R3     | 65003 | 3.3.3.3  | R1 (eBGP multihop via R2)        |

R3 has **no direct link to R1**. The eBGP multihop session between them uses
their Loopback0 addresses as the update-source, with R2 providing IP transit
(static routes: `1.1.1.1/32` on R3, `3.3.3.3/32` on R1, both via R2).

---

## What Ansible Is (in Network Terms)

Think of Ansible as a scripted SSH session that pushes IOS config in bulk.
Instead of typing commands manually on each router, you write the intent once
in YAML and Ansible connects to every device, builds the commands, pushes them,
and optionally checks the result.

| Concept you know      | Ansible equivalent                          |
|-----------------------|---------------------------------------------|
| SSH to a device       | Ansible inventory host + `network_cli`      |
| `conf t` ... `end`    | `cisco.ios.ios_config` task                 |
| `show` command output | `cisco.ios.ios_command` task                |
| Looping over devices  | Ansible `hosts: routers` runs once per host |
| Variable substitution | Jinja2 `{{ variable }}` templates           |
| Idempotency check     | `ios_config` checks running-config diff     |

Nothing here modifies the OS, installs software, or touches management-plane
config that you haven't explicitly defined. All changes map 1:1 to IOS CLI.

---

## Repository Layout

```
inventories/
  cml/
    hosts.yml           ← management IPs for the CML lab routers
    group_vars/
      all.yml           ← SSH credentials, env tag
      routers.yml       ← shared BGP defaults (timers, log-neighbor-changes)
    host_vars/
      R1.yml            ← R1 interfaces, static routes, BGP config
      R2.yml            ← R2 interfaces, static routes, BGP config
      R3.yml            ← R3 interfaces, static routes, BGP config
  production/           ← same structure, production IPs + vault creds

playbooks/
  base_config.yml       ← push interface IPs, descriptions, static routes
  deploy_bgp.yml        ← push BGP process, neighbors, network statements
  validate_bgp.yml      ← show commands + assertions (pass/fail)
  site.yml              ← runs base_config then deploy_bgp in sequence
```

The **host_vars** files are the source of truth for device config — the same
role a Word document or spreadsheet might play in a manual change.

---

## What Each Playbook Pushes

### `base_config.yml`

Translates the `interfaces:` and `routing:` sections from host_vars into:

```
interface GigabitEthernet0/1
  description Link to R2 (192.168.12.0/24)
  ip address 192.168.12.1 255.255.255.0
  no shutdown

ip route 3.3.3.3 255.255.255.255 192.168.12.2 name Route_to_R3_loopback_via_R2_(transit)
```

Ends with `copy running-config startup-config` (`save_when: always`).

### `deploy_bgp.yml`

Translates the `bgp:` section from host_vars into:

```
router bgp 65001
  bgp router-id 1.1.1.1
  bgp log-neighbor-changes
  neighbor 192.168.12.2 remote-as 65002
  neighbor 192.168.12.2 description eBGP to R2
  neighbor 192.168.12.2 timers 60 180
  neighbor 192.168.12.2 update-source GigabitEthernet0/1
  neighbor 3.3.3.3 remote-as 65003
  neighbor 3.3.3.3 description eBGP multihop to R3
  neighbor 3.3.3.3 timers 60 180
  neighbor 3.3.3.3 update-source Loopback0
  neighbor 3.3.3.3 ebgp-multihop 2
  network 10.1.1.0 mask 255.255.255.0

ip route 10.1.1.0 255.255.255.0 Null0 name BGP_black_hole
```

The Null0 route exists solely to satisfy the BGP RIB check — `network` in IOS
requires the prefix to be present in the routing table.

Ends with `copy running-config startup-config` (`save_when: always`).

### `validate_bgp.yml`

Runs `show bgp ipv4 unicast summary` and `show ip route bgp` on every router,
then asserts the following criteria (see below).

---

## Healthy BGP — Criteria and Checks

### 1. No neighbor stuck in `Idle`

`Idle` means BGP has not even attempted a TCP connection. Common causes:
- Peer IP is unreachable (missing static route, interface down)
- `neighbor` statement is misconfigured (wrong IP or remote-as)

**Check:** `show bgp ipv4 unicast summary` — `State/PfxRcd` column must not
show `Idle`.

### 2. No neighbor stuck in `Active`

`Active` means BGP is sending TCP SYNs but the session never establishes.
Common causes for eBGP multihop:
- `ebgp-multihop` TTL too low (need TTL ≥ 2 when transiting one hop)
- `update-source` missing — TCP SYN originates from a transit interface, and
  the peer's return route points elsewhere
- ACL or RPF drop

**Check:** `State/PfxRcd` column must not show `Active`.

### 3. Session is `Established` and exchanging prefixes

A numeric value in `State/PfxRcd` means the session is Established and that
many prefixes have been received. Zero (`0`) is valid if the peer has nothing
to advertise; the session itself is still up.

**Expected values in this topology:**

| Router | Neighbor     | Expected PfxRcd |
|--------|-------------|-----------------|
| R1     | 192.168.12.2 | 1 (10.2.2.0/24) |
| R1     | 3.3.3.3      | 1 (10.3.3.0/24) |
| R2     | 192.168.12.1 | 2 (10.1.1.0 + 10.3.3.0 sourced via R1) |
| R3     | 1.1.1.1      | 2 (10.1.1.0 + 10.2.2.0 sourced via R1) |

### 4. BGP routes installed in RIB

`show ip route bgp` must show `B` entries — the prefix has been selected as
best path and installed. If a prefix is in the BGP table but **not** in the
RIB, it usually means the next-hop is unreachable.

**Expected RIB entries:**

| Router | BGP routes |
|--------|-----------|
| R1 | `B 10.2.2.0/24` via 192.168.12.2, `B 10.3.3.0/24` via 3.3.3.3 |
| R2 | `B 10.1.1.0/24` via 192.168.12.1, `B 10.3.3.0/24` via 192.168.12.1 |
| R3 | `B 10.1.1.0/24` via 1.1.1.1, `B 10.2.2.0/24` via 1.1.1.1 |

### 5. Loopback reachability (control-plane connectivity)

The eBGP multihop peering relies on loopback reachability. Verify with:

```
R1# ping 3.3.3.3 source Loopback0
R3# ping 1.1.1.1 source Loopback0
```

Both must succeed. This tests that the static routes (Loopback reachability
via R2) are in place and that the eBGP multihop path is intact end-to-end.

### 6. Startup-config matches running-config

After any configuration push, verify config has been saved to NVRAM:

```
R1# show archive config differences nvram:startup-config system:running-config
```

Output must be `!No changes were found`. If any diff is shown, the running
config has not been written to NVRAM and **will be lost on reload**.

> The Ansible playbooks in this repo use `save_when: always`, which issues
> `copy running-config startup-config` unconditionally on every run — this
> is what guarantees the startup/running configs remain in sync.

---

## Running the Playbooks

```bash
# Activate the Python virtual environment first
source venv/bin/activate

# Push base config (interfaces, static routes) — safe to re-run
ansible-playbook playbooks/base_config.yml

# Push BGP config — safe to re-run (idempotent)
ansible-playbook playbooks/deploy_bgp.yml

# Run both in sequence
ansible-playbook playbooks/site.yml

# Validate only (no config changes)
ansible-playbook playbooks/validate_bgp.yml

# Target a single router
ansible-playbook playbooks/deploy_bgp.yml --limit R3
```

All commands default to the CML inventory. To target production add
`-i inventories/production`.

---

## Changing BGP Configuration

To change a BGP parameter (e.g., add a neighbor, change timers):

1. Edit the relevant `inventories/cml/host_vars/<router>.yml`
2. Re-run `ansible-playbook playbooks/deploy_bgp.yml`  
3. Run `ansible-playbook playbooks/validate_bgp.yml` to confirm the result

Ansible will only push the lines that differ from the running-config (for most
`ios_config` tasks). The `save_when: always` at the end ensures NVRAM is
always updated regardless.

---

## BGP Timer Reference (this lab)

| Parameter   | Value | IOS command                        |
|-------------|-------|------------------------------------|
| Keepalive   | 60 s  | `neighbor x.x.x.x timers 60 180`  |
| Hold time   | 180 s | (same command, second value)       |

Defined in `inventories/cml/group_vars/routers.yml` as `bgp_defaults.timers`.
