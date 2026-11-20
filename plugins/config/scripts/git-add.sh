#!/usr/bin/env bash
# harness-plugins 自主实现(2026-11-20);设计蓝本 = raystyle/claude-plugins dev-fix(同作者前作,功能面等价)
# 本仓维护:改动在此仓做,上游不回写
# PostToolUse hook: auto git-add after Write/Edit/MultiEdit
set -euo pipefail
file_path=$(jq -r '.tool_input.file_path')
[ -n "$file_path" ] && [ "$file_path" != "null" ] || exit 0
[ -d "${CLAUDE_PROJECT_DIR:-}/.git" ] || exit 0
[ -f "$file_path" ] || exit 0

# Skip vendor/generated directories
case "$file_path" in
  */node_modules/*|*/.git/*|*/dist/*|*/build/*|*/__pycache__/*|*/.venv/*|*/venv/*|*/.next/*) exit 0 ;;
esac

git add "$file_path" || true
