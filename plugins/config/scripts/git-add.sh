#!/usr/bin/env bash
# harness-plugins 自主实现(2026-11-20);设计蓝本 = raystyle/claude-plugins dev-fix(同作者前作,功能面等价)
# 本仓维护:改动在此仓做,上游不回写
# PostToolUse hook: auto git-add after Write/Edit/MultiEdit
# submodule 判例(2026-11-20 端到端实测):文件在 submodule 内时,父仓的
# `git add <路径>` 报 "Pathspec is in submodule" 被 || true 吞掉 → 永不 stage。
# 改道:从文件向上找最近的 .git(目录或文件——submodule 的 .git 是文件),
# 在所属仓里 stage;不依赖 CLAUDE_PROJECT_DIR(hook 未注入时同样工作)。
set -euo pipefail
file_path=$(jq -r '.tool_input.file_path')
[ -n "$file_path" ] && [ "$file_path" != "null" ] || exit 0
[ -f "$file_path" ] || exit 0

# Skip vendor/generated directories
case "$file_path" in
  */node_modules/*|*/.git/*|*/dist/*|*/build/*|*/__pycache__/*|*/.venv/*|*/venv/*|*/.next/*) exit 0 ;;
esac

# 归属仓定位:向上找最近 .git(dir 或 file);git 仓外静默退出
repo_dir=$(cd "$(dirname "$file_path")" && pwd)
while [ "$repo_dir" != "/" ]; do
  [ -e "$repo_dir/.git" ] && break
  repo_dir=$(dirname "$repo_dir")
done
[ -e "$repo_dir/.git" ] || exit 0

git -C "$repo_dir" add "$file_path" || true
