#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${EUID}" -ne 0 ]]; then
  printf 'Run as root: sudo bash scripts/manage.sh [command]\n' >&2
  exit 1
fi

command_name="${1:-help}"

case "${command_name}" in
  status)
    systemctl status hermes-gateway.service --no-pager
    ;;
  logs)
    journalctl -u hermes-gateway.service -f -n 50
    ;;
  restart)
    systemctl restart hermes-gateway.service
    printf 'Hermes gateway restarted.\n'
    systemctl status hermes-gateway.service --no-pager
    ;;
  start)
    systemctl start hermes-gateway.service
    printf 'Hermes gateway started.\n'
    ;;
  stop)
    systemctl stop hermes-gateway.service
    printf 'Hermes gateway stopped.\n'
    ;;
  doctor)
    env HOME=/root HERMES_HOME=/root/.hermes hermes doctor
    ;;
  verify)
    bash "${script_dir}/verify.sh"
    ;;
  update)
    if [[ -x /usr/local/sbin/vps-agent-deploy ]]; then
      exec /usr/local/sbin/vps-agent-deploy
    fi

    repo_dir="$(cd "${script_dir}/.." && pwd)"
    printf 'Pulling latest changes from git...\n'
    git -C "${repo_dir}" config --global --add safe.directory "${repo_dir}" || true
    git -C "${repo_dir}" pull --ff-only origin main

    printf 'Applying updated configurations...\n'
    install -m 600 "${repo_dir}/config.yaml" /root/.hermes/config.yaml
    install -m 644 "${repo_dir}/SOUL.md" /root/.hermes/SOUL.md
    install -m 644 "${repo_dir}/systemd/hermes-gateway.service" /etc/systemd/system/hermes-gateway.service

    systemctl daemon-reload

    printf 'Verifying deployment...\n'
    bash "${script_dir}/verify.sh"

    printf 'Restarting Hermes gateway...\n'
    systemctl restart hermes-gateway.service

    systemctl is-active hermes-gateway.service >/dev/null && printf 'Hermes gateway successfully updated and active.\n' || { printf 'Hermes gateway failed to activate.\n' >&2; exit 1; }
    ;;
  help|*)
    printf 'Hermes Gateway Management Helper\n'
    printf 'Usage: sudo bash scripts/manage.sh <command>\n\n'
    printf 'Commands:\n'
    printf '  status   Check service status\n'
    printf '  logs     Follow live gateway logs\n'
    printf '  restart  Restart gateway service\n'
    printf '  start    Start gateway service\n'
    printf '  stop     Stop gateway service\n'
    printf '  doctor   Run hermes doctor diagnostics\n'
    printf '  verify   Run verification and configuration audit\n'
    printf '  update   Pull latest git changes, apply config, verify & restart\n'
    exit 0
    ;;
esac
