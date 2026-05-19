#!/usr/bin/env bash
# sync-bridge.sh — Claude Code 跨端会话桥接
# 路径映射 + 命名空间复制 + history 合并
# 部署: E4430, 手机 (PC 不需要, Syncthing 直连 E4430)
set -euo pipefail

# ===== 三端路径映射表 =====
declare -A NODE_HOME
NODE_HOME[pc]="C:\\Users\\YourName"
NODE_HOME[server]="/home/yourname"
NODE_HOME[phone]="/root"

declare -A NODE_NS
NODE_NS[pc]="C--Users-Administrator"
NODE_NS[server]="-home-liu"
NODE_NS[phone]="-root"

# ===== 检测本机 =====
detect_self() {
    local os
    os=$(uname -s)
    case "$os" in
        MINGW*|MSYS*|CYGWIN*)
            echo "pc" ;;
        Linux)
            if [ "$HOME" = "/root" ] && [ "$(whoami)" = "root" ]; then
                echo "phone"
            elif [ "$HOME" = "/home/yourname" ]; then
                echo "server"
            else
                echo "unknown"
            fi ;;
        *) echo "unknown" ;;
    esac
}

SELF=$(detect_self)
CLAUDE_DIR="$HOME/.claude"
SESSIONS_DIR="$CLAUDE_DIR/sessions"
PROJECTS_DIR="$CLAUDE_DIR/projects"
HISTORY_FILE="$CLAUDE_DIR/history.jsonl"

LOCAL_HOME="${NODE_HOME[$SELF]}"
LOCAL_NS="${NODE_NS[$SELF]}"

log() { echo "[bridge] $(date '+%H:%M:%S') $*"; }

# ===== 修正 session cwd (用 JSON 解析, 避免反斜杠转义) =====
fix_sessions() {
    local fix_count=0
    if command -v python3 &>/dev/null; then
        fix_count=$(python3 -c "
import json, os, glob
local_home = '$LOCAL_HOME'
for f in glob.glob('$SESSIONS_DIR/*.json'):
    try:
        with open(f) as fh: d = json.load(fh)
        if d.get('cwd') and d['cwd'] != local_home:
            d['cwd'] = local_home
            with open(f, 'w') as fh: json.dump(d, fh)
            print(1)
    except: pass
" 2>/dev/null | wc -l)
    elif command -v node &>/dev/null; then
        fix_count=$(node -e "
const fs=require('fs'),path=require('path');
const dir='$SESSIONS_DIR', local='$LOCAL_HOME';
fs.readdirSync(dir).filter(f=>f.endsWith('.json')).forEach(f=>{
    const fp=path.join(dir,f);
    try{
        let d=JSON.parse(fs.readFileSync(fp,'utf8'));
        if(d.cwd && d.cwd!==local){d.cwd=local;fs.writeFileSync(fp,JSON.stringify(d));console.log(1)}
    }catch(e){}
});
" 2>/dev/null | wc -l)
    fi
    log "  sess 修正: $fix_count 个"
}

# ===== 合并 history.jsonl =====
merge_history() {
    if [ ! -f "$HISTORY_FILE" ]; then
        return
    fi
    # 用 Node.js 处理 (手机没有 Python)
    if command -v node &>/dev/null; then
        local remote_args="["
        local sep=""
        for node in pc server phone; do
            [ "$node" = "$SELF" ] && continue
            remote_args+="$sep\"${NODE_HOME[$node]}\""
            sep=","
        done
        remote_args+="]"
        node -e "
const fs=require('fs');
const hp='$HISTORY_FILE', local='$LOCAL_HOME', remotes=$remote_args;
if(!fs.existsSync(hp))process.exit(0);
const lines=fs.readFileSync(hp,'utf8').trim().split('\n').filter(l=>l.trim());
const seen=new Set(), out=[];
for(const line of lines){
    try{
        const d=JSON.parse(line);
        for(const rh of remotes){
            if(d.project && d.project.includes(rh)) d.project=d.project.replace(rh, local);
        }
        if(d.sessionId && seen.has(d.sessionId)) continue;
        if(d.sessionId) seen.add(d.sessionId);
        out.push(JSON.stringify(d));
    }catch(e){out.push(line);}
}
fs.writeFileSync(hp, out.join('\n')+'\n');
console.log('  history: '+out.length+' 条 (已去重, 原 '+lines.length+' 条)');
" 2>/dev/null || true
    elif command -v python3 &>/dev/null; then
        python3 "$CLAUDE_DIR/scripts/merge-history.py" "$HISTORY_FILE" "$LOCAL_HOME" "$(
            for node in pc server phone; do
                [ "$node" = "$SELF" ] && continue
                echo -n "${NODE_HOME[$node]} "
            done
        )"
    fi
}

# ===== 拷贝 jsonl 到目标命名空间 =====
copy_jsonl() {
    local from_ns="$1" to_ns="$2" from_node="$3"
    local from_dir="$PROJECTS_DIR/$from_ns"
    local to_dir="$PROJECTS_DIR/$to_ns"

    [ -d "$from_dir" ] || return
    mkdir -p "$to_dir"

    for jsonl in "$from_dir"/*.jsonl; do
        [ -f "$jsonl" ] || continue
        local fname
        fname=$(basename "$jsonl")
        local to_jsonl="$to_dir/$fname"

        if [ ! -f "$to_jsonl" ]; then
            cp "$jsonl" "$to_jsonl"
            log "  +jsonl [$from_node] $fname"
        elif [ "$(wc -l < "$jsonl" 2>/dev/null || echo 0)" -gt "$(wc -l < "$to_jsonl" 2>/dev/null || echo 0)" ]; then
            cp "$jsonl" "$to_jsonl"
            log "  ^jsonl [$from_node] $fname (更新)"
        fi
    done
}

# ===== 主逻辑: import =====
do_import() {
    log "开始导入 (本机: $SELF, NS: $LOCAL_NS)"

    # --- 1. 从所有远程命名空间收集 jsonl 到本地 ---
    for node in pc server phone; do
        [ "$node" = "$SELF" ] && continue
        copy_jsonl "${NODE_NS[$node]}" "$LOCAL_NS" "$node"
    done

    # --- 2. 修正 session cwd ---
    fix_sessions

    # --- 3. 合并 history.jsonl ---
    merge_history

    # --- 4. [仅 E4430] 分发汇总数据回写到其他命名空间 ---
    if [ "$SELF" = "server" ]; then
        log "分发汇总数据到其他命名空间..."
        for node in pc phone; do
            copy_jsonl "$LOCAL_NS" "${NODE_NS[$node]}" "$node"
        done
    fi

    log "导入完成"
}

# ===== 入口 =====
case "${1:-}" in
    import)
        do_import
        ;;
    *)
        echo "用法: $0 import"
        echo "  import - 从其他节点导入会话（修正路径 + 去重 + 分发）"
        exit 1
        ;;
esac
