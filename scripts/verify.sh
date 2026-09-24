#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  printf 'Run as root: sudo bash scripts/verify.sh\n' >&2
  exit 1
fi

hermes_home="/root/.hermes"
env_file="${hermes_home}/.env"

for file in "${env_file}" "${hermes_home}/config.yaml" /etc/systemd/system/hermes-gateway.service; do
  [[ -f "${file}" ]] || { printf 'Missing required file: %s\n' "${file}" >&2; exit 1; }
done

for name in DISCORD_BOT_TOKEN DISCORD_ALLOWED_USERS DISCORD_ALLOWED_CHANNELS; do
  value="$(grep -m 1 "^${name}=" "${env_file}" | cut -d= -f2-)"
  [[ -n "${value}" ]] || { printf 'Set %s in %s\n' "${name}" "${env_file}" >&2; exit 1; }
  case "${value}" in
    replace_with_a_new_bot_token|your_discord_user_id|target_channel_id)
      printf 'Placeholder value "%s" detected for %s in %s. Please enter your actual credentials/IDs.\n' "${value}" "${name}" "${env_file}" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "${hermes_home}/auth.json" ]]; then
  printf 'OpenAI Codex authentication file missing: %s/auth.json\n' "${hermes_home}" >&2
  printf 'Run: sudo -H env HOME=/root HERMES_HOME=/root/.hermes hermes model\n' >&2
  exit 1
fi

grep -qx 'DISCORD_REQUIRE_MENTION=true' "${env_file}" || {
  printf 'DISCORD_REQUIRE_MENTION must remain true.\n' >&2
  exit 1
}
grep -qx 'DISCORD_DM_POLICY=disabled' "${env_file}" || {
  printf 'DISCORD_DM_POLICY must remain disabled.\n' >&2
  exit 1
}

env HOME=/root HERMES_HOME="${hermes_home}" hermes doctor
systemctl is-enabled hermes-gateway.service >/dev/null || true
systemctl is-active hermes-gateway.service >/dev/null && printf 'Hermes gateway is active.\n' || printf 'Hermes gateway is installed but inactive.\n'
