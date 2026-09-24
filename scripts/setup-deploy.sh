#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  printf 'Run as root: sudo bash scripts/setup-deploy.sh\n' >&2
  exit 1
fi

repo_url=https://github.com/haikalthrq/VPS-Agent.git
deploy_dir=/root/VPS-Agent
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ ! -d "${deploy_dir}/.git" ]]; then
  if [[ -e "${deploy_dir}" ]]; then
    printf 'Refusing to replace existing non-repository path: %s\n' "${deploy_dir}" >&2
    exit 1
  fi
  git clone "${repo_url}" "${deploy_dir}"
fi

install -o root -g root -m 755 "${script_dir}/deploy.sh" /usr/local/sbin/vps-agent-deploy
printf '%s\n' 'uniserver ALL=(root) NOPASSWD: /usr/local/sbin/vps-agent-deploy' > /etc/sudoers.d/vps-agent-deploy
chmod 440 /etc/sudoers.d/vps-agent-deploy
visudo -cf /etc/sudoers.d/vps-agent-deploy
printf 'Deployment checkout and limited sudo command installed.\n'
