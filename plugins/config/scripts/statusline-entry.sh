#!/usr/bin/env bash
# statusline 稳定入口(2026-11-20,t43 会诊建议):settings.json 的 statusLine.command
# 指本文件——**不含版本号**,插件升级永不改 settings。
# 本入口每次渲染时解析最新插件版本目录(版本号排序取 max)并转发 stdin。
# 部署位:~/.config/harness-plugins/statusline-entry.sh(setup.sh 负责装)
set -uo pipefail

market="harness-plugins"
plugin="config"
base="$HOME/.claude/plugins/cache/$market/$plugin"

# 取版本号最大目录(ls -1v 尾行);无版本目录时退 1(状态栏空白,stderr 无害)
latest=$(ls -1v "$base" 2>/dev/null | tail -1)
if [ -z "$latest" ] || [ ! -f "$base/$latest/scripts/statusline.sh" ]; then
  exit 1
fi
exec bash "$base/$latest/scripts/statusline.sh"
