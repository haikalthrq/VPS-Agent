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

python_bin="/usr/local/lib/hermes-agent/venv/bin/python"
if [[ ! -x "${python_bin}" ]]; then
  python_bin="python3"
fi

"${python_bin}" -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]))' "${repo_dir}/config.yaml"
systemd-analyze verify "${repo_dir}/systemd/hermes-gateway.service"

install -m 600 "${repo_dir}/config.yaml" "${hermes_home}/config.yaml"
install -m 644 "${repo_dir}/SOUL.md" "${hermes_home}/SOUL.md"
install -m 644 "${repo_dir}/systemd/hermes-gateway.service" /etc/systemd/system/hermes-gateway.service
install -o root -g root -m 755 "${repo_dir}/scripts/deploy.sh" /usr/local/sbin/vps-agent-deploy
systemctl daemon-reload

bash "${repo_dir}/scripts/verify.sh"
systemctl restart hermes-gateway.service
sleep 3
systemctl is-active --quiet hermes-gateway.service
printf 'Hermes gateway deployed and active.\n'

# Send Discord notification to DISCORD_HOME_CHANNEL or target channel
env_file="${hermes_home}/.env"
bot_token="$(grep -m 1 '^DISCORD_BOT_TOKEN=' "${env_file}" 2>/dev/null | cut -d= -f2- | tr -d ' "\r\n' || true)"
home_channel="$(grep -m 1 '^DISCORD_HOME_CHANNEL=' "${env_file}" 2>/dev/null | cut -d= -f2- | tr -d ' "\r\n' || true)"
thread_id="$(grep -m 1 '^DISCORD_HOME_CHANNEL_THREAD_ID=' "${env_file}" 2>/dev/null | cut -d= -f2- | tr -d ' "\r\n' || true)"

target_channel="${thread_id:-${home_channel}}"
if [[ -z "${target_channel}" ]]; then
  target_channel="$(grep -m 1 '^DISCORD_ALLOWED_CHANNELS=' "${env_file}" 2>/dev/null | cut -d= -f2- | cut -d, -f1 | tr -d ' "\r\n' || true)"
fi

if [[ -n "${bot_token}" && -n "${target_channel}" ]]; then
  commit_hash="$(git -C "${repo_dir}" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
  commit_msg="$(git -C "${repo_dir}" log -1 --pretty=%B 2>/dev/null | head -n 1 || echo "Updated configuration")"

  payload="$("${python_bin}" -c '
import json, sys
data = {
    "embeds": [{
        "title": "🚀 Hermes Gateway Berhasil Di-update & Aktif",
        "description": "Bot telah di-restart otomatis dengan konfigurasi terbaru.",
        "color": 3066993,
        "fields": [
            {"name": "Commit", "value": f"`{sys.argv[1]}`", "inline": True},
            {"name": "Pesan", "value": sys.argv[2], "inline": True}
        ],
        "footer": {"text": "VPS Agent Auto-Deploy"}
    }]
}
print(json.dumps(data))
' "${commit_hash}" "${commit_msg}" 2>/dev/null || true)"

  if [[ -n "${payload}" ]]; then
    response="$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "https://discord.com/api/v10/channels/${target_channel}/messages" \
      -H "Authorization: Bot ${bot_token}" \
      -H "Content-Type: application/json" \
      -d "${payload}" 2>&1 || true)"
    http_code="$(echo "${response}" | grep 'HTTP_STATUS:' | cut -d: -f2 || true)"
    if [[ "${http_code}" =~ ^20[0-4]$ ]]; then
      printf 'Discord notification sent successfully to channel %s.\n' "${target_channel}"
    else
      printf 'Discord notification status (HTTP %s): %s\n' "${http_code}" "${response}"
    fi
  fi
fi
