#!/usr/bin/env bash
# harness-plugins 自主实现(2026-11-20);设计蓝本 = raystyle/claude-plugins statusline(同作者前作,功能面等价)
# 本仓维护:改动在此仓做,上游不回写
# 手动一次性安装(2026-11-20 裁定 statusline 不走 hook):把 statusLine 命令注入 ~/.claude/settings.json
# 用法:bash <本脚本>(装/更新插件后重跑一次,命令路径自动跟到新版本缓存目录)
# Always updates the command path so it tracks the current plugin version
set -euo pipefail

settings_file="$HOME/.claude/settings.json"
plugin_root="${CLAUDE_PLUGIN_ROOT:-}"

# 手动道(hook 不再注入 CLAUDE_PLUGIN_ROOT):从缓存目录解析本插件最新版本
if [ -z "$plugin_root" ]; then
  cache_root="$HOME/.claude/plugins/cache/harness-plugins/config"
  if [ -d "$cache_root" ]; then
    latest=$(ls -1v "$cache_root" 2>/dev/null | tail -1)
    [ -n "$latest" ] && plugin_root="$cache_root/$latest"
  fi
fi

if [ -z "$plugin_root" ]; then
  echo "setup: 未定位到插件根(装好 config@harness-plugins 后重跑本脚本)" >&2
  exit 1
fi

script_path="$plugin_root/scripts/statusline.sh"

# Read existing settings or start fresh
if [ -f "$settings_file" ]; then
  content=$(cat "$settings_file")
else
  content="{}"
fi

# Build command — always use POSIX paths.
# execCommandHook runs the command string through Git Bash (spawn with shell=gitBashPath),
# so Windows backslash paths (C:\Users\...) break — backslashes become escape chars.
# The .sh extension triggers auto-prepend of 'bash' in execCommandHook (line 862).
# On non-Windows, 'bash script.sh' works directly.
cmd="bash $script_path"

# Check if command already matches — skip write if unchanged
current_cmd=$(echo "$content" | jq -r '.statusLine.command // ""' 2>/dev/null || echo "")
if [ "$current_cmd" = "$cmd" ]; then
  exit 0
fi

# Inject/update statusLine config using jq, preserve all other fields
# Atomic write via temp file to avoid corruption on failure
tmp_file="${settings_file}.tmp.$$"
echo "$content" | jq --indent 2 --arg cmd "$cmd" \
  '. + { "statusLine": { "type": "command", "command": $cmd, "padding": 1 } }' \
  > "$tmp_file" && mv "$tmp_file" "$settings_file"
