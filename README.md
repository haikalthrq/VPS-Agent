# VPS Agent

Reproducible Hermes Agent deployment for a Linux VPS with Discord integration and OpenAI Codex OAuth.

## What Is Tracked

- Hermes v0.20.0-compatible non-secret configuration and `env.example` template.
- Root-owned systemd gateway service.
- Discord safety defaults: mention required, DMs disabled, explicit user and channel allowlists.
- Installation and validation scripts.

The repository deliberately excludes bot tokens, OAuth credentials, session history, logs, databases, cache, pairing state, and Discord IDs.

## Prerequisites

- Ubuntu or another systemd Linux distribution.
- `curl`, `git`, and `sudo`.
- A Discord application with a bot token, invited to the target server with channel access.
- An OpenAI Codex account for OAuth authentication.

## Install

```bash
git clone https://github.com/haikalthrq/VPS-Agent.git
cd VPS-Agent
sudo bash scripts/install.sh
sudoedit /root/.hermes/.env
sudo -H env HOME=/root HERMES_HOME=/root/.hermes hermes model
sudo bash scripts/verify.sh
sudo systemctl enable --now hermes-gateway.service
```

The installer uses the official Hermes installer when `hermes` is not already installed. It preserves an existing `/root/.hermes/.env` so a redeploy does not overwrite secrets.

In the `hermes model` picker, choose OpenAI Codex and complete its OAuth flow. The resulting `/root/.hermes/auth.json` is intentionally never committed.

## Discord Setup

Set these in `/root/.hermes/.env`:

```dotenv
DISCORD_BOT_TOKEN=replace_with_a_new_bot_token
DISCORD_ALLOWED_USERS=your_discord_user_id
DISCORD_ALLOWED_CHANNELS=target_channel_id
DISCORD_HOME_CHANNEL=target_channel_id
DISCORD_HOME_CHANNEL_THREAD_ID=
DISCORD_REQUIRE_MENTION=true
DISCORD_AUTO_THREAD=true
DISCORD_DM_POLICY=disabled
DISCORD_MAX_ATTACHMENT_BYTES=33554432
```

Enable the **Message Content Intent** and **Server Members Intent** in the Discord Developer Portal. Invite the bot with `View Channel`, `Send Messages`, `Create Public Threads`, `Send Messages in Threads`, `Read Message History`, and `Attach Files` for the allowed channel.

Use Discord Developer Mode to copy user and channel IDs. Keep `DISCORD_ALLOWED_USERS` and `DISCORD_ALLOWED_CHANNELS` non-empty. Do not set `GATEWAY_ALLOW_ALL_USERS=true`.

## Operations

```bash
sudo systemctl status hermes-gateway.service
sudo journalctl -u hermes-gateway.service -f
sudo systemctl restart hermes-gateway.service
sudo -H env HOME=/root HERMES_HOME=/root/.hermes hermes doctor
```

The gateway runs as `root` because the current VPS deployment intentionally grants its terminal tools host-level access. This is high risk: restrict Discord access tightly and rotate compromised credentials immediately.

## Validation

After the service is active, invoke `/status` and `/reasoning` from an allowlisted account in the allowlisted channel. The gateway logs each native Discord slash-command invocation to the systemd journal.

`/status` may first show a short acknowledgement before Hermes sends the detailed status message.
