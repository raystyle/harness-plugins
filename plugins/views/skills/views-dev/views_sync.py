#!/usr/bin/env python3
# views mod 安装/卸载/更新:项目仓 views/<mod>/ -> 全局 ~/.config/herdr-app/mods/<mod>/
# 用法:
#   uv run views_sync.py install [mod名...]     # 装或更新(不带名 = 全部)
#   uv run views_sync.py uninstall <mod名>      # 从全局位移除(源码不动)
#   uv run views_sync.py list                   # 项目内 views 清点 + 全局位对照
"""deploy tool for views-dev skill: install/uninstall views mods to the global slot."""

from __future__ import annotations

import json
import os
import shutil
import sys
from pathlib import Path

HERDR_APP_HOME = Path(os.environ.get("HERDR_APP_HOME", str(Path.home() / ".config" / "herdr-app")))
MODS_DIR = HERDR_APP_HOME / "mods"


def project_root(start: Path) -> Path:
    # 找项目仓根:从 cwd 向上找含 views/ 子目录的层(最多五层)
    p = start.resolve()
    for _ in range(5):
        if (p / "views").is_dir():
            return p
        p = p.parent
    return start.resolve()


def pick_mods(root: Path, names: list[str] | None) -> list[Path]:
    views = root / "views"
    out = []
    for d in sorted(views.iterdir()) if views.is_dir() else []:
        if d.is_dir() and (d / "main.js").is_file():
            if names and d.name not in names:
                continue
            out.append(d)
    if names:
        missing = [n for n in names if not (views / n / "main.js").is_file()]
        for n in missing:
            print(f"  [✘] {n}: 项目 views/ 下无此 mod(main.js 缺)")
    return out


def preflight(mod_dir: Path) -> list[str]:
    errs = []
    src = (mod_dir / "main.js").read_text(encoding="utf-8", errors="replace")
    # 语法门:mod 源里不该写死安装位路径(热重载死循环红线)
    if ".config/herdr-app/mods" in src and "data/" not in src.split(".config/herdr-app/mods")[0][-60:]:
        errs.append("源码疑似写安装位路径(运行时状态必须走 shared()/data/,见 SKILL 铁律 2)")
    mj = mod_dir / "mod.json"
    if mj.is_file():
        try:
            cfg = json.loads(mj.read_text(encoding="utf-8"))
            if "title" not in cfg:
                errs.append("mod.json 缺 title(命令面板显示用)")
        except Exception as e:
            errs.append(f"mod.json JSON 坏:{e}")
    if not mod_dir.name.endswith("-views"):
        errs.append("mod 名未带 -views 后缀(防撞约定:<域>-<对象>-views)")
    return errs


def install(root: Path, names: list[str]) -> int:
    mods = pick_mods(root, names or None)
    if not mods:
        print("无可装的 views mod(项目 views/ 下没有含 main.js 的目录)")
        return 1
    MODS_DIR.mkdir(parents=True, exist_ok=True)
    rc = 0
    for d in mods:
        errs = preflight(d)
        if errs:
            for e in errs:
                print(f"  [✘] {d.name}: {e}")
            rc = 1
            continue
        dest = MODS_DIR / d.name
        if dest.exists():
            shutil.rmtree(dest)  # 全量覆盖更新(项目仓是源,全局位是产物)
        shutil.copytree(d, dest)
        print(f"  [✔] {d.name} -> {dest}(热重载即时生效)")
    print(f"校验:herdr-app check {MODS_DIR}/<mod>(吃目录路径)")
    return rc


def uninstall(names: list[str]) -> int:
    if not names:
        print("用法:uninstall <mod名>")
        return 2
    rc = 0
    for n in names:
        dest = MODS_DIR / n
        if dest.is_dir():
            shutil.rmtree(dest)
            print(f"  [✔] 已卸载 {n}(项目源码未动;若在屏上,pane 请用户自己关)")
        else:
            print(f"  [✘] {n}: 全局位无此目录")
            rc = 1
    return rc


def do_list(root: Path) -> int:
    mods = pick_mods(root, None)
    print(f"项目内 views({root / 'views'}):")
    for d in mods:
        g = MODS_DIR / d.name
        print(f"  {'✔已装' if g.is_dir() else '✘未装'}  {d.name}")
    print(f"全局位:{MODS_DIR}")
    return 0


def main() -> int:
    args = sys.argv[1:]
    if not args or args[0] not in ("install", "uninstall", "list"):
        print(__doc__)
        return 2
    root = project_root(Path.cwd())
    if args[0] == "install":
        return install(root, args[1:])
    if args[0] == "uninstall":
        return uninstall(args[1:])
    return do_list(root)


if __name__ == "__main__":
    sys.exit(main())
