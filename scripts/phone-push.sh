#!/usr/bin/env bash
# phone-push.sh — 将手机 Claude Code 数据推送到 SERVER
# 用法: 手机上执行 ./phone-push.sh
set -euo pipefail

# 替换为你的服务器地址
SERVER="user@your-server-tailscale-ip"
SERVER_LAN="user@192.168.x.x"
SSH_KEY="/root/.ssh/id_rsa"
SSH_OPTS="-i $SSH_KEY -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new"

EXCLUDES=(
    --exclude='settings.local.json'
    --exclude='session-env/'
    --exclude='daemon/'
    --exclude='telemetry/'
    --exclude='tasks/'
    --exclude='temp/'
    --exclude='cache/'
    --exclude='paste-cache/'
    --exclude='shell-snapshots/'
    --exclude='file-history/'
    --exclude='backups/'
    --exclude='plans/'
    --exclude='plugins/'
    --exclude='*.lock'
    --exclude='.last_*'
    --exclude='.tip_index.json'
    --exclude='.last_update_check'
    --exclude='.last_daily_tip'
    --exclude='.last-cleanup'
    --exclude='.title_cache.json'
    --exclude='stats-cache.json'
    --exclude='statusline_debug.json'
    --exclude='scheduled_tasks.json'
    --exclude='scheduled_tasks.lock'
    --exclude='.mcp.json'
    --exclude='.stfolder'
    --exclude='.stignore'
    --exclude='scripts/'
)

echo "[push] 推送数据到 SERVER..."

HOST="$SERVER"
if ! ssh $SSH_OPTS "$HOST" "echo ok" &>/dev/null; then
    HOST="$SERVER_LAN"
fi

# rsync 推送
rsync -avz -e "ssh $SSH_OPTS" \
    "${EXCLUDES[@]}" \
    ~/.claude/ \
    "$HOST:~/.claude/"

echo "[push] 触发 SERVER 桥接导入..."
ssh $SSH_OPTS "$HOST" "~/.claude/scripts/sync-bridge.sh import"

echo "[push] 完成"
