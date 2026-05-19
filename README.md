# claude-code-sync

Claude Code 三端会话同步方案（PC Windows / SERVER Ubuntu Server / Android Termux）。

## 架构

```
PC ←──Syncthing──→ SERVER ←──rsync按需──→ 手机
```

- **PC ↔ SERVER**：Syncthing 实时双向同步 `.claude/` 目录
- **手机 ↔ SERVER**：`pull`（用前拉取）/ `push`（用后推送）

## 文件说明

| 文件 | 用途 |
|------|------|
| `lessons-learned.md` | 项目踩坑经验总结 |
| `聊天记录.md` | 对话记录整理 |
| `scripts/sync-bridge.sh` | 核心桥接脚本（三端命名空间映射） |
| `scripts/phone-pull.sh` | 手机从 SERVER 拉取数据 |
| `scripts/phone-push.sh` | 手机推送数据到 SERVER |
| `scripts/merge-history.py` | history.jsonl 路径修正 + 去重 |

## 三端环境

| 节点 | HOME | 命名空间 |
|------|------|---------|
| PC | `C:\Users\&lt;USER&gt;` | `C--Users-Administrator` |
| SERVER | `/home/&lt;USER&gt;` | `-home-user` |
| 手机 | `/root` | `-root` |
