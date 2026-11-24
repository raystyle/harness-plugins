#!/usr/bin/env python3
# views mod 环境检测:herdr-app / node(check 用)/ 全局安装位 / 已装 views 清点 / 心跳诊断
# 用法:uv run views_check.py [mod名]   (或 python3 views_check.py;>=3.10,零第三方依赖)
"""dep-check for views-dev skill: environment readiness report."""

from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
MODS_DIR = Path(os.environ.get("HERDR_APP_HOME", str(HOME / ".config" / "herdr-app"))) / "mods"
SHARED = Path(os.environ.get("HERDR_APP_HOME", str(HOME / ".config" / "herdr-app"))) / "shared.json"

OK, WARN, FAIL = "OK", "WARN", "FAIL"


def run(cmd: list[str], timeout: int = 20) -> tuple[int, str]:
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.returncode, (r.stdout or r.stderr or "").strip()
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as e:
        return 127, str(e)


def main() -> int:
    only = sys.argv[1] if len(sys.argv) > 1 else None
    rows: list[tuple[str, str, str]] = []

    # 1 herdr-app 可执行 + 版本
    exe = shutil.which("herdr-app")
    if exe:
        rc, out = run(["herdr-app", "status"])
        ver = ""
        if rc == 0:
            m = re.search(r'"version"\s*:\s*"([^"]+)"', out)
            ver = m.group(1) if m else ""
        rows.append((OK, "herdr-app", f"{exe} {ver}".strip()))
    else:
        rows.append((FAIL, "herdr-app", "不在 PATH——views mod 无处挂载"))

    # 2 node(node --check 语法门用;非硬需求,缺了降级)
    node = shutil.which("node")
    rows.append((OK if node else WARN, "node",
                 node or "不在 PATH——node --check 语法门将跳过(herdr-app check 仍可用)"))

    # 3 全局安装位
    rows.append((OK if MODS_DIR.is_dir() else WARN, "mods 安装位",
                 f"{MODS_DIR}({'在位' if MODS_DIR.is_dir() else '未建——首装时 sync 脚本会建'})"))

    # 4 已装 views 清点(<域>-…-views 命名)
    installed = []
    if MODS_DIR.is_dir():
        for d in sorted(MODS_DIR.iterdir()):
            if d.is_dir() and (d / "main.js").is_file() and d.name.endswith("-views"):
                installed.append(d.name)
    rows.append((OK, "已装 views", ", ".join(installed) or "(无)"))

    # 5 心跳:shared.json 里各 views 的 state.ts(仅当指定 mod 或全量)
    beats = []
    if SHARED.is_file():
        try:
            data = json.loads(SHARED.read_text(encoding="utf-8"))
        except Exception as e:
            data = {}
            rows.append((WARN, "shared.json", f"解析失败:{e}"))
        now = time.time()
        # 只看 views 类的键(已装 views mod 的 state),别的 mod 的 .state 不混进来
        views_names = set(installed)
        targets = [f"{only}.state"] if only else [k for k in data
                                                   if k.endswith(".state") and k[:-len(".state")] in views_names]
        for k in sorted(targets):
            v = data.get(k)
            if not isinstance(v, dict):
                rows.append((FAIL, k, "shared 无此键或非对象——mod 从未跑过"))
                continue
            ts = v.get("ts")
            err = v.get("err")
            if err:
                state, age = FAIL, "无 ts" if not isinstance(ts, (int, float)) else f"{now - ts / 1000:.0f}s 前"
            elif not isinstance(ts, (int, float)):
                state, age = FAIL, "无 ts(数据道没心跳——看 herdr-app status errors + 是否挂载)"
            else:
                age = f"{now - ts / 1000:.0f}s 前"
                state = OK if now - ts / 1000 < 300 else WARN  # 5 分钟没跳 = 面板未挂载或轮询停
            rows.append((state, k, age + (f" | err: {str(err)[:60]}" if err else "")))
    if beats:
        rows.extend(beats)
    elif only:
        rows.append((WARN, f"{only}.state", "shared.json 无此键——mod 未跑过或键名不对"))

    # 6 指定 mod 的安装体检
    if only:
        md = MODS_DIR / only
        if not md.is_dir():
            rows.append((FAIL, only, "未安装(全局位无此目录)"))
        else:
            mj = md / "main.js"
            rows.append((OK if mj.is_file() else FAIL, f"{only}/main.js", "在位" if mj.is_file() else "缺!"))
            cfg = md / "mod.json"
            if cfg.is_file():
                try:
                    json.loads(cfg.read_text(encoding="utf-8"))
                    rows.append((OK, f"{only}/mod.json", "JSON 合法"))
                except Exception as e:
                    rows.append((FAIL, f"{only}/mod.json", f"JSON 坏:{e}"))

    # 输出
    worst = FAIL if any(r[0] == FAIL for r in rows) else (WARN if any(r[0] == WARN for r in rows) else OK)
    print(f"views 环境检测({'指定: ' + only if only else '全量'})")
    for st, name, detail in rows:
        mark = {"OK": "✔", "WARN": "△", "FAIL": "✘"}[st]
        print(f"  [{mark}] {name:24s} {detail}")
    print(f"结论:{'可开发' if worst == OK else ('可开发,有告警' if worst == WARN else '有 FAIL,先修')}")
    return 0 if worst != FAIL else 1


if __name__ == "__main__":
    sys.exit(main())
