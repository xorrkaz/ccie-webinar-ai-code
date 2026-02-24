#!/usr/bin/env bash
# =============================================================
# setup_vault.sh - Bootstrap the production Ansible Vault
# =============================================================
# Run ONCE when setting up a new workstation or CI/CD runner.
# This script creates the vault password file and the encrypted
# vault.yml from the example template.
#
# Usage:
#   chmod +x scripts/setup_vault.sh
#   ./scripts/setup_vault.sh
# =============================================================
set -euo pipefail

VAULT_FILE="inventories/production/group_vars/vault.yml"
VAULT_EXAMPLE="${VAULT_FILE}.example"
VAULT_PASS_FILE="${HOME}/.vault_pass_ccie_demo"

# ---- Vault password ----------------------------------------
if [[ ! -f "${VAULT_PASS_FILE}" ]]; then
  echo "Creating vault password file at ${VAULT_PASS_FILE}"
  echo "Enter the vault password (will be stored in ${VAULT_PASS_FILE}):"
  read -rs VAULT_PASS
  echo "${VAULT_PASS}" > "${VAULT_PASS_FILE}"
  chmod 600 "${VAULT_PASS_FILE}"
  echo "✓ Vault password file created."
else
  echo "✓ Vault password file already exists at ${VAULT_PASS_FILE}"
fi

# ---- Vault file --------------------------------------------
if [[ -f "${VAULT_FILE}" ]]; then
  # Check if already encrypted
  if head -1 "${VAULT_FILE}" | grep -q '^\$ANSIBLE_VAULT'; then
    echo "✓ ${VAULT_FILE} already encrypted."
  else
    echo "⚠  ${VAULT_FILE} exists but is NOT encrypted. Encrypting..."
    ansible-vault encrypt --vault-password-file "${VAULT_PASS_FILE}" "${VAULT_FILE}"
    echo "✓ Encrypted."
  fi
else
  echo ""
  echo "vault.yml not found. Creating from example..."
  cp "${VAULT_EXAMPLE}" "${VAULT_FILE}"
  echo ""
  echo ">>> Edit ${VAULT_FILE} and replace placeholder values, then re-run this script."
  echo "    Or encrypt manually: ansible-vault encrypt --vault-password-file ${VAULT_PASS_FILE} ${VAULT_FILE}"
  exit 1
fi

# ---- ansible.cfg update ------------------------------------
echo ""
echo "Add the following to ansible.cfg [defaults] section if not present:"
echo "  vault_password_file = ${VAULT_PASS_FILE}"
echo ""
echo "Or export the env var before production runs:"
echo "  export ANSIBLE_VAULT_PASSWORD_FILE=${VAULT_PASS_FILE}"
