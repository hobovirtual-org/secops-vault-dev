#!/usr/bin/env bash
set -euo pipefail

if ! command -v terraform >/dev/null 2>&1; then
  echo "terraform is required" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

WORKSPACE_NAME="${TF_WORKSPACE:-default}"
if terraform workspace show >/dev/null 2>&1; then
  WORKSPACE_NAME="$(terraform workspace show | tr -d '[:space:]')"
fi

VAULT_URL="$(terraform output -raw vault_url)"
VAULT_DOMAIN="$(printf '%s' "${VAULT_URL}" | sed -E 's#^https://##; s#[^A-Za-z0-9.-]#-#g')"
INIT_FILE=".secrets/${WORKSPACE_NAME}-${VAULT_DOMAIN}-vault-init.json"

if [ ! -f "${INIT_FILE}" ]; then
  echo "Bootstrap file not found: ${INIT_FILE}" >&2
  exit 1
fi

ROOT_TOKEN="$(jq -r '.root_token' "${INIT_FILE}")"
if [ -z "${ROOT_TOKEN}" ] || [ "${ROOT_TOKEN}" = "null" ]; then
  echo "root_token not found in ${INIT_FILE}" >&2
  exit 1
fi

printf 'export VAULT_ADDR=%q\n' "${VAULT_URL}"
printf 'export VAULT_TOKEN=%q\n' "${ROOT_TOKEN}"
