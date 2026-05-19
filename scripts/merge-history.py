#!/usr/bin/env python3
"""合并 history.jsonl — 修正路径 + sessionId 去重"""
import json, sys, os

def merge(history_path, local_home, *remote_homes):
    if not os.path.exists(history_path):
        return

    lines_out = []
    seen_ids = set()

    with open(history_path, encoding='utf-8', errors='replace') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                d = json.loads(line)
                sid = d.get('sessionId', '')
                proj = d.get('project', '')

                # 替换远程路径 → 本地路径
                for rh in remote_homes:
                    if rh and rh in proj:
                        d['project'] = proj.replace(rh, local_home)

                # 去重
                if sid and sid in seen_ids:
                    continue
                if sid:
                    seen_ids.add(sid)

                lines_out.append(json.dumps(d, ensure_ascii=False))
            except Exception:
                lines_out.append(line)

    if lines_out:
        tmp = history_path + '.tmp'
        with open(tmp, 'w', encoding='utf-8') as f:
            f.write('\n'.join(lines_out) + '\n')
        os.replace(tmp, history_path)
        print(f"  history: {len(lines_out)} 条 (已去重)")

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print("用法: merge-history.py <history文件> <本地HOME> <远程HOME1> [远程HOME2...]")
        sys.exit(1)
    merge(sys.argv[1], sys.argv[2], *sys.argv[3:])
