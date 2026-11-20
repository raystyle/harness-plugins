#!/usr/bin/env bash
# harness-plugins 自主实现(2026-11-20);设计蓝本 = raystyle/claude-plugins dev-fix(同作者前作,功能面等价)
# 本仓维护:改动在此仓做,上游不回写
# PreToolUse hook for Bash tool:
#   1. Fixes Windows Git Bash CR line-ending issues
#   2. Prepends UTF-8 encoding environment setup
#   3. Auto-activates Python virtual environment (.venv / venv) if found in CWD

set -euo pipefail

# ── Fix Windows Git Bash \r line endings ──
input=$(cat | tr -d '\r')

# jq 一律 -b(Windows 原生 jq 文本模式把 \n 翻成 \r\n,-r 抽值时 \r 落进值内部:
# jqlang/jq#1854;2026-11-20 本机实证,单行尾带 \r、多行内部夹 \r)。
# -b = binary mode stdout,零翻译;后面 tr -d '\r' 是对旧版 jq 无 -b 的兜底。
JQ="jq -b"
command -v jq >/dev/null 2>&1 || JQ="jq"

# Use jq to safely parse JSON and extract command (handles all escape sequences)
original_cmd=$($JQ -r '.tool_input.command // empty' <<<"$input" 2>/dev/null | tr -d '\r') || true

if [ -z "${original_cmd:-}" ]; then
  echo '{"continue":true}'
  exit 0
fi

# ── Build prefix ──
prefix_parts=(
  "chcp.com 65001 > /dev/null 2>&1"
)

[ -z "${PYTHONUTF8:-}" ] && prefix_parts+=("export PYTHONUTF8=1")
[ -z "${PYTHONIOENCODING:-}" ] && prefix_parts+=("export PYTHONIOENCODING=utf-8")
[ -z "${LESSCHARSET:-}" ] && prefix_parts+=("export LESSCHARSET=utf-8")
[ -z "${LANG:-}" ] && prefix_parts+=("export LANG=C.UTF-8")
[ -z "${LC_ALL:-}" ] && prefix_parts+=("export LC_ALL=C.UTF-8")

# ── Prevent MSYS2/Git Bash path mangling ──
[ -z "${MSYS_NO_PATHCONV:-}" ] && prefix_parts+=("export MSYS_NO_PATHCONV=1")
[ -z "${MSYS2_ARG_CONV_EXCL:-}" ] && prefix_parts+=("export MSYS2_ARG_CONV_EXCL='*'")

# ── Auto-detect and activate venv (only for direct python/pip commands) ──
if echo "$original_cmd" | grep -qE '(^|\s|;|&&|\|)(python|pip|pip3|pytest|mypy|black|ruff|flake8|pylint)\b' \
   && ! echo "$original_cmd" | grep -qE '(^|\s|;|&&|\|)(uv|conda|pipx|poetry)\b'; then
  cwd="${PWD:-$(pwd)}"
  for candidate in .venv venv; do
    candidate_path="$cwd/$candidate"
    if [ -f "$candidate_path/Scripts/activate" ] || [ -f "$candidate_path/bin/activate" ]; then
      venv_posix=$(cd "$candidate_path" && pwd)
      if [ -f "$candidate_path/Scripts/activate" ]; then
        activate_path="$venv_posix/Scripts/activate"
      else
        activate_path="$venv_posix/bin/activate"
      fi
      prefix_parts+=("source \"$activate_path\"")
      break
    fi
  done
fi

# Join prefix parts with "; "
prefix=$(IFS='; '; echo "${prefix_parts[*]}")
prefix="$prefix; "

# Build modified command and output as JSON via jq
# 输出自净(2026-11-20 真会话判例定案,根因 = jqlang/jq#1854 Windows 原生 jq
# text-mode CRLF):抽取道已 -b + tr;本道再 tr 一次兜底旧版 jq。
modified_cmd=$(printf '%s' "$prefix$original_cmd" | tr -d '\r')

# 诊断日志(根因已定案 2026-11-20:jq -r 在 Windows 原生 jq 下抽值夹 \r;
# 保留 BASH_FIX_LOG 观察窗,稳定后撤)
if [ -n "${BASH_FIX_LOG:-}" ]; then
  {
    printf '=== %s ===\n' "$(date -Iseconds)"
    printf 'JQ_BIN=%s JQ_VERSION=%s\n' "$(command -v jq)" "$(jq --version 2>&1)"
    printf 'INPUT_JSON: %s\n' "$input"
    printf 'MODIFIED_REPR: '
    printf '%s' "$modified_cmd" | od -c | head -20
    printf 'ENV_LANG=%s ENV_LC_ALL=%s\n' "${LANG:-}" "${LC_ALL:-}"
  } >> "$BASH_FIX_LOG" 2>&1
fi

$JQ -n \
  --arg cmd "$modified_cmd" \
  '{
    continue: true,
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "allow",
      updatedInput: { command: $cmd }
    }
  }' | tr -d '\r'
