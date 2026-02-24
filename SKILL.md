# SKILL.md - Reusable Network Automation Skills

This document defines reusable skills that the Network Configuration Engineer agent can leverage when building network automation solutions.

---

## Table of Contents
- [Git Workflow Skills](#git-workflow-skills)
- [Ansible BGP Skills](#ansible-bgp-skills)
- [Validation Skills](#validation-skills)
- [Inventory Skills](#inventory-skills)

---

## Git Workflow Skills

### Skill: git_create_branch
**Description**: Create a new feature branch following naming conventions

**Parameters:**
- `task_description` (string): Brief description of the task (kebab-case)
- `branch_type` (string): Either "feature" or "fix" (default: "feature")

**Execution:**
```bash
# Ensure on main and up-to-date
git checkout main
git pull origin main

# Create and checkout new branch
git checkout -b {{ branch_type }}/{{ task_description }}
```

**Example:**
```
Input: task_description="bgp-r1-r2-peering", branch_type="feature"
Output: Creates and checks out branch "feature/bgp-r1-r2-peering"
```

**Agent Response Template:**
```
✓ Created branch: feature/bgp-r1-r2-peering
✓ Switched to new branch
Ready to begin development.
```

---

### Skill: git_commit
**Description**: Create a conventional commit with proper formatting

**Parameters:**
- `commit_type` (string): Type (feat|fix|docs|test|refactor)
- `scope` (string): Component affected (optional)
- `message` (string): Short description (imperative mood, no period)
- `body` (string): Detailed explanation (optional, multi-line)
- `files` (list): Files to stage for this commit

**Execution:**
```bash
# Stage specific files
git add {{ files | join(' ') }}

# Commit with message
git commit -m "{{ commit_type }}{% if scope %}({{ scope }}){% endif %}: {{ message }}" \
{% if body %}-m "{{ body }}"{% endif %}
```

**Example:**
```yaml
Input:
  commit_type: feat
  scope: bgp
  message: add R1 BGP configuration
  body: |
    Configure eBGP with AS 65001
    - Router ID: 1.1.1.1
    - Neighbor: 192.168.12.2 (AS 65002)
    - Network: 10.1.1.0/24
  files:
    - host_vars/R1.yml
```

**Generated Commit:**
```
feat(bgp): add R1 BGP configuration

Configure eBGP with AS 65001
- Router ID: 1.1.1.1
- Neighbor: 192.168.12.2 (AS 65002)
- Network: 10.1.1.0/24
```

**Agent Response Template:**
```
✓ Committed: feat(bgp): add R1 BGP configuration
  Files: host_vars/R1.yml
  [abc123d] 1 file changed, 15 insertions(+)
```

---

### Skill: git_push_branch
**Description**: Push current feature branch to remote

**Parameters:**
- `branch_name` (string): Branch to push (auto-detected from current branch)
- `set_upstream` (boolean): Set upstream tracking (default: true)

**Execution:**
```bash
# Get current branch name
BRANCH=$(git branch --show-current)

# Push with upstream
git push -u origin $BRANCH
```

**Agent Response Template:**
```
✓ Pushed branch: feature/bgp-r1-r2-peering
  Remote: origin/feature/bgp-r1-r2-peering
  7 commits pushed successfully
```

---

### Skill: create_pull_request
**Description**: Create a GitHub pull request from current branch

**Parameters:**
- `title` (string): PR title (should match conventional commit format)
- `body` (string): PR description with context
- `base_branch` (string): Target branch (default: "main")
- `draft` (boolean): Create as draft PR (default: false)

**PR Body Template:**
```markdown
## Purpose
{{ purpose_description }}

## Changes Made
{{ bulleted_list_of_changes }}

## Testing Done
{{ testing_steps_completed }}

## Validation Steps for Reviewer
{{ steps_for_human_to_validate }}

## Related Issues
{{ issue_references_if_any }}

## Commits
{{ commit_list_with_messages }}
```

**Execution:**
```bash
gh pr create \
  --title "{{ title }}" \
  --body "{{ body }}" \
  --base {{ base_branch }} \
  {% if draft %}--draft{% endif %}
```

**Example:**
```yaml
Input:
  title: "feat: Deploy eBGP peering between R1 and R2"
  body: |
    ## Purpose
    Implement eBGP peering between R1 (AS 65001) and R2 (AS 65002) 
    to establish inter-AS routing.

    ## Changes Made
    - Added R1 and R2 to inventory with management IPs
    - Created host_vars for both routers with BGP configuration
    - Built deployment playbook using cisco.ios collection
    - Added pre-flight interface checks
    - Implemented post-deployment BGP state validation
    - Updated README with deployment instructions

    ## Testing Done
    - Syntax validation: ansible-playbook --syntax-check ✓
    - Dry-run mode: ansible-playbook --check ✓
    - Ready for CML testbed deployment

    ## Validation Steps for Reviewer
    1. Review BGP parameters in host_vars/
    2. Check playbook follows established patterns
    3. Verify validation tasks cover neighbor state
    4. Deploy to CML and confirm BGP establishment
    5. Run `show ip bgp summary` on both routers

    ## Commits
    - feat(inventory): add R1 and R2 to routers group
    - feat(vars): create host_vars for R1 BGP configuration
    - feat(vars): create host_vars for R2 BGP configuration
    - feat(playbook): add BGP deployment playbook
    - feat(validation): add pre-flight check tasks
    - feat(validation): add post-deployment verification
    - docs(readme): update with BGP deployment instructions
```

**Agent Response Template:**
```
✓ Pull Request Created: #42
  Title: feat: Deploy eBGP peering between R1 and R2
  URL: https://github.com/your-org/network-automation/pull/42
  Status: Open
  Commits: 7

**Awaiting your review.** I've completed the implementation and it's ready 
for validation in CML. Please review the PR and let me know if you'd like 
any changes.
```

---

### Skill: git_log
**Description**: Query git history to understand previous work

**Parameters:**
- `filter` (string): Keyword to filter commits (optional)
- `author` (string): Filter by author (optional)
- `since` (string): Time period (e.g., "1 week ago")
- `format` (string): Output format (default: "oneline-with-date")

**Execution:**
```bash
git log \
  {% if filter %}--grep="{{ filter }}"{% endif %} \
  {% if author %}--author="{{ author }}"{% endif %} \
  {% if since %}--since="{{ since }}"{% endif %} \
  --pretty=format:"%h - %ar : %s [%an]" \
  -n 20
```

**Example Usage:**
```yaml
Input:
  filter: "bgp"
  since: "2 weeks ago"

Output:
  abc123d - 3 days ago : feat(bgp): add R3-R4 peering [AI Agent]
  def456e - 1 week ago : fix(bgp): correct timer syntax for IOSv [AI Agent]
  789ghij - 2 weeks ago : feat(bgp): initial validation framework [Human]
```

**Agent Response Template:**
```
Found 3 relevant commits related to "bgp":

1. abc123d (3 days ago): feat(bgp): add R3-R4 peering
   - Established eBGP between R3 (AS 65003) and R4 (AS 65004)
   - Can use as reference for current task

2. def456e (1 week ago): fix(bgp): correct timer syntax for IOSv
   - Important: IOSv requires timers in keepalive/holdtime format
   - Must follow this pattern

3. 789ghij (2 weeks ago): feat(bgp): initial validation framework
   - Base validation tasks already exist in playbooks/validate_bgp.yml
   - Should extend these rather than create new file

Based on this history, I'll follow the patterns established in abc123d 
and use the validation framework from 789ghij.
```

---

### Skill: git_checkout_branch
**Description**: Switch to an existing branch

**Parameters:**
- `branch_name` (string): Branch to switch to

**Execution:**
```bash
git checkout {{ branch_name }}
git pull origin {{ branch_name }}
```

**Agent Response Template:**
```
✓ Switched to branch: feature/bgp-r1-r2-peering
✓ Updated with latest remote changes
Ready to continue work.
```

---

### Skill: git_status_report
**Description**: Generate a status report of current work

**Parameters:** None

**Execution:**
```bash
# Current branch
BRANCH=$(git branch --show-current)

# Uncommitted changes
CHANGES=$(git status --short)

# Commits ahead of origin
AHEAD=$(git rev-list --count origin/$BRANCH..$BRANCH 2>/dev/null || echo "0")

# Generate report
echo "Branch: $BRANCH"
echo "Uncommitted changes: $(echo "$CHANGES" | wc -l)"
echo "Commits ahead of remote: $AHEAD"
git log origin/$BRANCH..$BRANCH --oneline 2>/dev/null || echo "No commits yet"
```

**Agent Response Template:**
```
📊 Current Work Status
━━━━━━━━━━━━━━━━━━━━
Branch: feature/bgp-r1-r2-peering
Uncommitted: 2 files modified
Commits ahead: 5

Recent commits on this branch:
  abc123d feat(validation): add post-deployment verification
  def456e feat(validation): add pre-flight check tasks
  789ghij feat(playbook): add BGP deployment playbook
  012klmn feat(vars): create host_vars for R2
  345opqr feat(vars): create host_vars for R1

Next steps: Commit remaining changes and create PR
```

---

### Skill: git_handle_feedback
**Description**: Framework for addressing PR review feedback

**Parameters:**
- `feedback` (string): The review comment from human
- `pr_number` (integer): PR number being updated

**Workflow:**
1. Parse the feedback to understand requested changes
2. Checkout the feature branch
3. Make the necessary changes
4. Create a new commit addressing the feedback
5. Push the update
6. Comment on the PR

**Agent Response Template:**
```
I'll address your feedback on PR #42.

Feedback: "{{ feedback }}"

My plan:
1. {{ action_step_1 }}
2. {{ action_step_2 }}
3. Commit as: fix({{ scope }}): {{ change_description }}
4. Push update to PR

[Executes changes]

✓ Changes committed and pushed to PR #42
✓ Updated commit: fix(bgp): adjust R1 BGP timers to 30/90 seconds

Ready for re-review.
```

---

## Ansible BGP Skills

### Skill: bgp_config
**Description**: Generate Ansible tasks for Cisco IOS BGP configuration using cisco.ios collection

**Parameters:**
- `device_name` (string): Target router hostname
- `local_asn` (integer): Local BGP AS number
- `router_id` (string): BGP router ID (IPv4 address)
- `neighbors` (list): BGP neighbor configurations

**Neighbor Object Schema:**
```yaml
- ip: "192.168.1.2"           # Neighbor IP address
  remote_asn: 65002            # Remote AS number
  description: "eBGP to R2"    # Optional description
  update_source: "GigabitEthernet0/0"  # Optional source interface
  ebgp_multihop: 2             # Optional, for eBGP multihop
```

**Output**: Ansible task block using `cisco.ios.ios_bgp_global` and `cisco.ios.ios_bgp_address_family`

**Example Usage:**
```yaml
# Input specification
device: R1
local_asn: 65001
router_id: 1.1.1.1
neighbors:
  - ip: 192.168.12.2
    remote_asn: 65002
    description: "eBGP to R2"
```

**Generated Output:**
```yaml
- name: Configure BGP on {{ device_name }}
  cisco.ios.ios_bgp_global:
    config:
      as_number: "{{ local_asn }}"
      bgp:
        router_id:
          address: "{{ router_id }}"
      neighbors:
        - neighbor_address: "{{ item.ip }}"
          remote_as: "{{ item.remote_asn }}"
          description: "{{ item.description | default(omit) }}"
          update_source: "{{ item.update_source | default(omit) }}"
          ebgp_multihop:
            max_hop: "{{ item.ebgp_multihop | default(omit) }}"
  loop: "{{ neighbors }}"
  register: bgp_config_result

- name: Configure BGP address family for IPv4 unicast
  cisco.ios.ios_bgp_address_family:
    config:
      as_number: "{{ local_asn }}"
      address_family:
        - afi: ipv4
          safi: unicast
          networks:
            - address: "{{ item }}"
          neighbors:
            - neighbor_address: "{{ item.ip }}"
              activate: true
  loop: "{{ neighbors }}"
  when: bgp_config_result is succeeded
```

---

### Skill: ios_pre_flight_check
**Description**: Generate pre-deployment validation tasks

**Parameters:**
- `device_name` (string): Target router
- `required_interfaces` (list): List of interfaces that must be up

**Output**: Ansible validation tasks

**Example:**
```yaml
- name: Pre-flight check on {{ device_name }}
  block:
    - name: Check interface status
      cisco.ios.ios_command:
        commands:
          - show ip interface brief
      register: interface_status
    
    - name: Verify required interfaces are up
      assert:
        that:
          - item in interface_status.stdout[0]
          - "'up' in interface_status.stdout[0]"
        fail_msg: "Interface {{ item }} is not up"
      loop: "{{ required_interfaces }}"
    
    - name: Check for existing BGP configuration
      cisco.ios.ios_command:
        commands:
          - show running-config | section router bgp
      register: existing_bgp
      failed_when: false
    
    - name: Warn if BGP already configured
      debug:
        msg: "WARNING: BGP configuration already exists on {{ device_name }}"
      when: existing_bgp.stdout[0] | length > 0
```

---

## Validation Skills

### Skill: ios_validation
**Description**: Generate validation tasks to verify IOS BGP state

**Parameters:**
- `device_name` (string): Target router
- `expected_neighbors` (list): List of expected neighbor IPs
- `expected_state` (string): Expected BGP state (default: "Established")

**Output**: Ansible tasks using `cisco.ios.ios_command` for verification

**Example Usage:**
```yaml
device: R1
expected_neighbors:
  - 192.168.12.2
  - 192.168.13.3
expected_state: Established
```

**Generated Output:**
```yaml
- name: Verify BGP neighbor states on {{ device_name }}
  cisco.ios.ios_command:
    commands:
      - show ip bgp summary
  register: bgp_summary

- name: Parse BGP neighbors
  set_fact:
    bgp_neighbors: "{{ bgp_summary.stdout[0] | parse_bgp_summary }}"

- name: Assert all neighbors are Established
  assert:
    that:
      - item in bgp_neighbors.keys()
      - bgp_neighbors[item].state == "{{ expected_state }}"
    fail_msg: "BGP neighbor {{ item }} not in {{ expected_state }} state"
    success_msg: "BGP neighbor {{ item }} is {{ expected_state }}"
  loop: "{{ expected_neighbors }}"
```

---

### Skill: bgp_state_verification
**Description**: Use CML MCP server to verify BGP state (post-deployment)

**Parameters:**
- `device_name` (string): Target router
- `expected_neighbors` (list): List of expected neighbor IPs with AS numbers

**Note**: This skill documents the expected interaction pattern with CML MCP server

**Workflow:**
1. Agent requests BGP neighbor status via MCP
2. MCP executes `show ip bgp summary` on target device
3. Agent parses output to verify all neighbors in Established state
4. Agent checks routing table for expected prefixes
5. Report success/failure with details

**Example Interaction:**
```
Agent → MCP: Execute "show ip bgp summary" on R1
MCP → Agent: [command output]

Agent analysis:
✓ Neighbor 192.168.12.2 (AS 65002): Established
✓ Uptime: 00:05:23
✓ Prefixes received: 1

Agent → MCP: Execute "show ip route bgp" on R1
MCP → Agent: [routing table]

Agent verification:
✓ Route 10.2.2.0/24 via 192.168.12.2 present
✓ BGP deployment successful
```

---

## Inventory Skills

### Skill: ansible_inventory_from_cml
**Description**: Structure for dynamic inventory generation from CML topology (handled by MCP server)

**Note**: This skill documents the expected inventory format from CML MCP server. The MCP server handles the actual inventory generation.

**Expected Output Format:**
```yaml
all:
  children:
    routers:
      hosts:
        R1:
          ansible_host: 192.168.0.101
          ansible_network_os: ios
          ansible_connection: network_cli
          ansible_user: "{{ vault_ios_user }}"
          ansible_password: "{{ vault_ios_password }}"
          mgmt_interface: GigabitEthernet0/0
        R2:
          ansible_host: 192.168.0.102
          ansible_network_os: ios
          ansible_connection: network_cli
          ansible_user: "{{ vault_ios_user }}"
          ansible_password: "{{ vault_ios_password }}"
          mgmt_interface: GigabitEthernet0/0
```

**Usage in Playbooks:**
```yaml
- name: BGP Deployment Playbook
  hosts: routers
  gather_facts: false
  connection: network_cli
  
  tasks:
    - name: Include device-specific variables
      include_vars: "host_vars/{{ inventory_hostname }}.yml"
```
