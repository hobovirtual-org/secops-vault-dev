#!/usr/bin/env bash
set -euo pipefail

SECRETS_DIR=".secrets"
SSH_COMMAND="${VAULT_SSH_COMMAND:-}"

WORKSPACE_NAME="${TF_WORKSPACE:-default}"
if terraform workspace show >/dev/null 2>&1; then
  WORKSPACE_NAME="$(terraform workspace show | tr -d '[:space:]')"
fi

VAULT_DOMAIN="unknown-vault"
if terraform output -raw vault_url >/dev/null 2>&1; then
  VAULT_DOMAIN="$(terraform output -raw vault_url | sed -E 's#^https://##; s#[^A-Za-z0-9.-]#-#g')"
fi

OUTPUT_FILE="${SECRETS_DIR}/${WORKSPACE_NAME}-${VAULT_DOMAIN}-vault-init.json"

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform is required" >&2
  exit 1
fi

if ! command -v ssh >/dev/null 2>&1; then
  echo "ssh is required" >&2
  exit 1
fi

if [ -z "${SSH_COMMAND}" ]; then
  SSH_COMMAND="$(terraform output -raw vault_ssh_command)"
fi

mkdir -p "${SECRETS_DIR}"
chmod 700 "${SECRETS_DIR}"

STATUS_OUTPUT="$(${SSH_COMMAND} '
  export VAULT_ADDR="http://$(hostname -I | awk "{print \$1}"):8200"
  vault status 2>&1 || true
')"

if printf '%s' "${STATUS_OUTPUT}" | grep -q 'Initialized[[:space:]]*true'; then
  echo "Vault is already initialized."
  exit 0
fi

if printf '%s' "${STATUS_OUTPUT}" | grep -q 'Initialized[[:space:]]*false'; then
  :
else
  echo "Unable to determine Vault initialization status." >&2
  printf '%s\n' "${STATUS_OUTPUT}" >&2
  exit 1
fi

if [ -e "${OUTPUT_FILE}" ]; then
  echo "Refusing to overwrite existing ${OUTPUT_FILE}" >&2
  exit 1
fi

INIT_OUTPUT="$(${SSH_COMMAND} '
  set -euo pipefail
  export VAULT_ADDR="http://$(hostname -I | awk "{print \$1}"):8200"
  vault operator init -format=json
')"

printf '%s\n' "${INIT_OUTPUT}" >"${OUTPUT_FILE}"
chmod 600 "${OUTPUT_FILE}"

echo "Vault initialized. Bootstrap material written to ${OUTPUT_FILE}."
echo "Store this file securely and remove it from this machine when appropriate."

${SSH_COMMAND} '
  set -euo pipefail
  export VAULT_ADDR="http://$(hostname -I | awk "{print \$1}"):8200"
  vault status
'
