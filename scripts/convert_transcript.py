#!/usr/bin/env python3
"""将 Claude Code JSONL 转换为可读对话格式"""
import json, sys, os, ast

def is_tool_result(msg):
    """检测是否为工具返回结果"""
    if isinstance(msg, dict):
        content = msg.get('content', '')
        if isinstance(content, str) and content.startswith('[{"tool_use_id"'):
            return True
        if isinstance(content, list) and len(content) > 0:
            if isinstance(content[0], dict) and 'tool_use_id' in content[0]:
                return True
    if isinstance(msg, str):
        s = msg.strip()
        if s.startswith('[{"tool_use_id"') or s.startswith("[{'tool_use_id'"):
            return True
    return False

def parse_message(msg):
    """解析消息体, 可能是 dict 或 stringified dict"""
    if isinstance(msg, dict):
        return msg
    if isinstance(msg, str):
        try:
            return ast.literal_eval(msg)
        except:
            return {"content": msg}
    return {}

def extract_assistant_text(content_items):
    """从 assistant content 中提取纯文本 (跳过 thinking 和 tool_use)"""
    if not isinstance(content_items, list):
        content_items = [content_items]
    texts = []
    for item in content_items:
        if not isinstance(item, dict):
            continue
        t = item.get('type', '')
        if t == 'text' and item.get('text'):
            text = item['text'].strip()
            if text and len(text) > 2:
                texts.append(text)
        # 跳过 thinking, tool_use, tool_result
    return '\n\n'.join(texts)

def convert(jsonl_path, output_path):
    with open(jsonl_path, encoding='utf-8', errors='replace') as f:
        lines = f.readlines()

    output = []
    filename = os.path.basename(jsonl_path).replace('.jsonl', '')
    output.append(f"# Claude Code 三端同步 — 对话记录\n\n会话: {filename}\n\n---\n\n")

    skip_types = {'file-history-snapshot', 'permission-mode', 'last-prompt', 'queue-operation'}

    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            d = json.loads(line)
        except:
            continue

        t = d.get('type', '')
        if t in skip_types:
            continue

        ts = d.get('timestamp', '')[:19].replace('T', ' ')

        if t == 'user':
            msg = parse_message(d.get('message', {}))
            content = msg.get('content', '') if isinstance(msg, dict) else str(msg)

            # 跳过工具返回值
            if is_tool_result(msg):
                continue

            # 只保留真正的用户文本输入
            if isinstance(content, str) and len(content) > 2:
                output.append(f"**用户 [{ts}]**\n\n{content.strip()}\n\n---\n\n")

        elif t == 'assistant':
            msg = parse_message(d.get('message', {}))
            if isinstance(msg, dict):
                text = extract_assistant_text(msg.get('content', []))
                if text:
                    if len(text) > 8000:
                        text = text[:8000] + "\n\n*(内容过长已截断)*"
                    output.append(f"**Claude [{ts}]**\n\n{text}\n\n---\n\n")

        elif t == 'ai-title':
            output.append(f"> 标题: {d.get('aiTitle', '')}\n\n")

        elif t == 'attachment':
            att = parse_message(d.get('attachment', {}))
            if isinstance(att, dict):
                hook = att.get('hookName', '')
                if hook and 'Session' in hook:
                    output.append(f"> [{ts}] 系统事件: {hook}\n\n")

    with open(output_path, 'w', encoding='utf-8') as f:
        f.writelines(output)

    print(f"Done: {output_path} ({len([l for l in output if l.startswith('**用户')])} user msgs, {len([l for l in output if l.startswith('**Claude')])} claude msgs)")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("用法: convert_transcript.py <jsonl文件> [输出文件]")
        sys.exit(1)
    src = sys.argv[1]
    dst = sys.argv[2] if len(sys.argv) > 2 else src.replace('.jsonl', '.md')
    convert(src, dst)
