#!/usr/bin/env bash
# harness-plugins 自主实现(2026-11-20);设计蓝本 = raystyle/claude-plugins statusline(同作者前作,功能面等价)
# 本仓维护:改动在此仓做,上游不回写
# 手动一次性安装(2026-11-20 裁定 statusline 不走 hook):部署 statusline-entry.sh
# 稳定入口到 ~/.config/harness-plugins/,再把 statusLine.command 指向它。
# 入口不含版本号——插件升级**永不改 settings**(t43 会诊判例:0.1.3→0.1.4 时
# settings 钉旧版本路径,升版不自动改,所有机器都要手改)。
# 用法:bash <本脚本>(装好 config@harness-plugins 后跑一次,之后升版免管)
set -euo pipefail

settings_file="$HOME/.claude/settings.json"
deploy_dir="$HOME/.config/harness-plugins"
entry_src="${CLAUDE_PLUGIN_ROOT:-}"

# 手动道(hook 不再注入 CLAUDE_PLUGIN_ROOT):从缓存目录解析本插件最新版本
if [ -z "$entry_src" ]; then
  cache_root="$HOME/.claude/plugins/cache/harness-plugins/config"
  if [ -d "$cache_root" ]; then
    latest=$(ls -1v "$cache_root" 2>/dev/null | tail -1)
    [ -n "$latest" ] && entry_src="$cache_root/$latest"
  fi
fi

if [ -z "$entry_src" ]; then
  echo "setup: 未定位到插件根(装好 config@harness-plugins 后重跑本脚本)" >&2
  exit 1
fi

# 部署稳定入口(每次覆盖,入口自身无状态;MSYS 形路径给 bash 用)
mkdir -p "$deploy_dir"
cp "$entry_src/scripts/statusline-entry.sh" "$deploy_dir/statusline-entry.sh"

# Read existing settings or start fresh
if [ -f "$settings_file" ]; then
  content=$(cat "$settings_file")
else
  content="{}"
fi

# Build command — POSIX path;入口跨插件版本稳定
entry_posix=$(cd "$deploy_dir" && pwd)/statusline-entry.sh
cmd="bash $entry_posix"

# Check if command already matches — skip write if unchanged
current_cmd=$(echo "$content" | jq -r '.statusLine.command // ""' 2>/dev/null || echo "")
if [ "$current_cmd" = "$cmd" ]; then
  echo "statusline 已指稳定入口:$cmd"
  exit 0
fi

# Inject/update statusLine config using jq, preserve all other fields
# Atomic write via temp file to avoid corruption on failure
tmp_file="${settings_file}.tmp.$$"
echo "$content" | jq --indent 2 --arg cmd "$cmd" \
  '. + { "statusLine": { "type": "command", "command": $cmd, "padding": 1 } }' \
  > "$tmp_file" && mv "$tmp_file" "$settings_file"
echo "statusLine 已指向稳定入口(升版免改 settings):$cmd"
