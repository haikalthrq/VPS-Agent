#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  printf 'Run as root.\n' >&2
  exit 1
fi

repo_dir=/root/VPS-Agent
hermes_home=/root/.hermes

if [[ ! -d "${repo_dir}/.git" ]]; then
  printf 'Missing root-owned deployment checkout: %s\n' "${repo_dir}" >&2
  exit 1
fi

git -C "${repo_dir}" pull --ff-only origin main

"/usr/local/lib/hermes-agent/venv/bin/python" -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]))' "${repo_dir}/config.yaml"
systemd-analyze verify "${repo_dir}/systemd/hermes-gateway.service"

install -m 600 "${repo_dir}/config.yaml" "${hermes_home}/config.yaml"
install -m 644 "${repo_dir}/SOUL.md" "${hermes_home}/SOUL.md"
install -m 644 "${repo_dir}/systemd/hermes-gateway.service" /etc/systemd/system/hermes-gateway.service
systemctl daemon-reload

bash "${repo_dir}/scripts/verify.sh"
systemctl restart hermes-gateway.service
systemctl is-active --quiet hermes-gateway.service
printf 'Hermes gateway deployed and active.\n'
