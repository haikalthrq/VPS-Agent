#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
hermes_home="/root/.hermes"

if [[ "${EUID}" -ne 0 ]]; then
  printf 'Run as root: sudo bash scripts/install.sh\n' >&2
  exit 1
fi

if ! command -v hermes >/dev/null 2>&1; then
  curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
fi

install -d -m 700 "${hermes_home}"

if [[ ! -f "${hermes_home}/.env" ]]; then
  install -m 600 "${repo_dir}/env.example" "${hermes_home}/.env"
  printf 'Created %s. Populate it before starting Hermes.\n' "${hermes_home}/.env"
fi

install -m 600 "${repo_dir}/config.yaml" "${hermes_home}/config.yaml"
install -m 644 "${repo_dir}/SOUL.md" "${hermes_home}/SOUL.md"
install -m 644 "${repo_dir}/systemd/hermes-gateway.service" /etc/systemd/system/hermes-gateway.service

systemctl daemon-reload
printf 'Authenticate OpenAI Codex with: sudo -H env HOME=/root HERMES_HOME=/root/.hermes hermes model\n'
printf 'Then validate and start with: sudo bash scripts/verify.sh && sudo systemctl enable --now hermes-gateway.service\n'
