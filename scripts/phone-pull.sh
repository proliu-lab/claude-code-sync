#!/usr/bin/env bash
# phone-pull.sh — 从 SERVER 拉取 Claude Code 数据到手机
# 用法: 手机上执行 ./phone-pull.sh
set -euo pipefail

# 替换为你的服务器地址
SERVER="user@your-server-tailscale-ip"
SERVER_LAN="user@192.168.x.x"
SSH_KEY="/root/.ssh/id_rsa"
SSH_OPTS="-i $SSH_KEY -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new"

# 排除列表（与 .stignore 一致）
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
)

echo "[pull] 从 SERVER 拉取数据..."

# 先试 Tailscale，不行走内网
HOST="$SERVER"
if ! ssh $SSH_OPTS "$HOST" "echo ok" &>/dev/null; then
    HOST="$SERVER_LAN"
fi

# rsync 拉取
rsync -avz --delete -e "ssh $SSH_OPTS" \
    "${EXCLUDES[@]}" \
    "$HOST:~/.claude/" \
    ~/.claude/

echo "[pull] 运行桥接修正路径..."
~/.claude/scripts/sync-bridge.sh import

echo "[pull] 完成"
