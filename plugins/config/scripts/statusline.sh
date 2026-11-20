#!/usr/bin/env bash
# harness-plugins 自主实现(2026-11-20);设计蓝本 = raystyle/claude-plugins statusline(同作者前作,功能面等价)
# 本仓维护:改动在此仓做,上游不回写
# StatusLine — five-line display
# L1: Model:glm-5.1  │  Ctx:▓▓▓▓░░░░░░ 80K/200K 40%  │  Time:15m14s
# L2: MCP:nushell,web_reader
# L3: LSP:nushell,typescript,rust,python
# L4: Git:main staged:5 modified:2 untracked:1  │  Dir:D:/opensource/Plugins
# L5: Cron tasks
set -euo pipefail

input=$(cat | tr -d '\r')

# ── Colors ──
R="\033[0m"
C_MODEL="\033[36m"
C_TIME="\033[37m"
C_MCP="\033[35m"
C_LSP="\033[33m"
C_GIT="\033[34m"
C_DIR="\033[37m"
C_KEY="\033[2m"
# Ctx color set dynamically
C_CTX="\033[32m"
C_BAR_F="\033[32m"   # bar filled
C_BAR_E="\033[2m"    # bar empty (dim)

# ── Parse ──
model=$(echo "$input" | jq -r '.model.display_name // "Unknown"' 2>/dev/null || echo "Unknown")
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // 0' 2>/dev/null || echo "0")
ctx_used=$(echo "$input" | jq -r '
  (.context_window.current_usage.input_tokens // 0)
  + (.context_window.current_usage.cache_creation_input_tokens // 0)
  + (.context_window.current_usage.cache_read_input_tokens // 0)
' 2>/dev/null || echo "0")
ctx_total=$(echo "$input" | jq -r '.context_window.context_window_size // 0' 2>/dev/null || echo "0")
duration_ms=$(echo "$input" | jq -r '.cost.total_duration_ms // 0' 2>/dev/null || echo "0")
session_id=$(echo "$input" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")

# ── Context ──
ctx_int=$(printf "%.0f" "$ctx_pct" 2>/dev/null || echo "0")
if [ "$ctx_int" -gt 100 ]; then ctx_int=100; fi
filled=$((ctx_int / 10))
empty=$((10 - filled))

# Color: all ctx elements turn red/yellow together
if [ "$ctx_int" -ge 80 ]; then
  C_CTX="\033[31m"
  C_BAR_F="\033[31m"
elif [ "$ctx_int" -ge 60 ]; then
  C_CTX="\033[33m"
  C_BAR_F="\033[33m"
fi

bar=""
bar_f=""
for ((i = 0; i < filled; i++)); do bar_f+="▓"; done
bar_e=""
for ((i = 0; i < empty; i++)); do bar_e+="░"; done
bar="${C_BAR_F}${bar_f}${C_BAR_E}${bar_e}${R}"

# Token formatting
fmt_tokens() {
  local n=$1
  if [ "$n" -ge 1000000 ]; then
    local m=$((n / 100000))
    local d=$((m % 10))
    local w=$((m / 10))
    if [ "$d" -eq 0 ]; then echo "${w}M"
    else echo "${w}.${d}M"; fi
  elif [ "$n" -ge 1000 ]; then
    echo "$((n / 1000))K"
  else
    echo "${n}"
  fi
}

ctx_used_fmt=$(fmt_tokens "$ctx_used")
ctx_total_fmt=$(fmt_tokens "$ctx_total")

# ── Duration ──
dur_ms=$((duration_ms % 1000))
dur_s=$((duration_ms / 1000))
dur_h=$((dur_s / 3600))
dur_m=$(( (dur_s % 3600) / 60 ))
dur_sec=$((dur_s % 60))
if [ "$dur_h" -gt 0 ]; then
  dur_fmt="${dur_h}h${dur_m}m${dur_sec}s"
elif [ "$dur_m" -gt 0 ]; then
  dur_fmt="${dur_m}m${dur_sec}s"
else
  if [ "$dur_ms" -ge 100 ]; then
    dur_fmt="${dur_sec}.$((dur_ms / 100))s"
  else
    dur_fmt="${dur_sec}s"
  fi
fi

# ── MCP/LSP from cache(缺失、空或过时时自足:喂合成 JSON 调 services.sh 现算) ──
svc_cache="/tmp/claude-statusline-services-${session_id}.cache"
mcp_names=""
lsp_names=""
svc_body=""
[ -f "$svc_cache" ] && svc_body=$(cat "$svc_cache" 2>/dev/null | tr -d '\r')

# 2026-11-20 判例修正(hvperv-harness t43 实况定案):
# 1) 只判「文件缺失」不够——hook 时代写空的缓存(MCP:/LSP: 双空行)永挡路;双空也触发重算
# 2) statusline 是 settings 命令非插件 hook,进程里没有 CLAUDE_PLUGIN_ROOT——
#    自足道拿它当门闩 = 永不触发。插件根从脚本自身位置推(本脚本就在
#    <插件根>/scripts/ 里,services.sh 是邻座,不依赖任何注入 env)
# 3) 第九判例(t43,2026-11-20):**非空但过时**的缓存永不重算——新加 .mcp.json
#    的 MCP 上不了屏,删缓存才活。触发条件加 TTL:缓存 mtime 超 60s 即重算
#    (与 git 缓存同款机制;.mcp.json mtime 对比法不采用——多源
#    settings/项目/插件面,追不全,TTL 一刀切稳)
_script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
_plugin_root=$(dirname "$_script_dir")
_svc_stale=1  # 默认:无缓存 = 要算
if [ -f "$svc_cache" ]; then
  _svc_age=$(( $(date +%s) - $(stat -c %Y "$svc_cache" 2>/dev/null || stat -f %m "$svc_cache" 2>/dev/null || echo 0) ))
  [ "$_svc_age" -le 60 ] && _svc_stale=0
fi
if { [ "$_svc_stale" -eq 1 ] || [ "$svc_body" = "MCP:
LSP:" ]; } && [ -f "$_plugin_root/scripts/services.sh" ]; then
  # cwd 传给 services.sh 当项目根线索(替代 hook 时代的 CLAUDE_PROJECT_DIR):
  # stdin JSON 里没有 workspace 时兜底进程 cwd
  _proj=""
  _proj=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty' 2>/dev/null | tr -d '\r')
  # 第七判例(hvperv-harness t43 实抓定谳,2026-11-20):合成 JSON 禁 printf 拼——
  # 真实 stdin 的 cwd 是 Windows 反斜杠路径(D:\repos\...),printf '%s' 拼进 JSON
  # 字符串后 \r \h 被 bash 吃成转义 → 非法 JSON → services.sh set -e 下 jq 炸退,
  # 缓存永不成(与 jq -b 判例同族:Windows 反斜杠 + bash 字符串拼接)。
  # 修法:jq -nc --arg 注入,值由 jq 自行 JSON 转义,零手拼。
  jq -nc --arg sid "$session_id" --arg cwd "${_proj:-$(pwd)}" \
    '{session_id: $sid, tool_name: "", cwd: $cwd}' \
    | bash "$_plugin_root/scripts/services.sh" >/dev/null 2>&1 || true
  [ -f "$svc_cache" ] && svc_body=$(cat "$svc_cache" 2>/dev/null | tr -d '\r')
fi
if [ -n "$svc_body" ]; then
  mcp_names=$(printf '%s\n' "$svc_body" | grep "^MCP:" | sed 's/^MCP://' | tr -d '\r' || echo "")
  lsp_names=$(printf '%s\n' "$svc_body" | grep "^LSP:" | sed 's/^LSP://' | tr -d '\r' || echo "")
fi

sep=" ${C_KEY}│${R} "

# ── Line 1: Model │ Ctx │ Time ──
seg_model="${C_KEY}Model:${R} ${C_MODEL}${model}${R}"
seg_ctx="${C_KEY}Ctx:${R} ${C_CTX}${bar}${R} ${C_CTX}${ctx_used_fmt}/${ctx_total_fmt} ${ctx_int}%${R}"
seg_time="${C_KEY}Time:${R} ${C_TIME}${dur_fmt}${R}"
echo -e "${seg_model}${sep}${seg_ctx}${sep}${seg_time}"

# ── Line 2: MCP ──
if [ -n "$mcp_names" ]; then
  echo -e "${C_KEY}MCP:${R} ${C_MCP}${mcp_names}${R}"
fi

# ── Line 3: LSP ──
if [ -n "$lsp_names" ]; then
  echo -e "${C_KEY}LSP:${R} ${C_LSP}${lsp_names}${R}"
fi

# ── Line 4: Git │ Dir ──
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""' 2>/dev/null || echo "" | tr -d '\r')
# Normalize backslashes to forward slashes to avoid \n \t \b interpretation in echo -e
cwd=$(printf '%s' "$cwd" | tr '\\' '/')

git_info=""
if [ -n "$cwd" ] && [ -d "$cwd/.git" ]; then
  cache_file="/tmp/claude-statusline-git-${session_id}.cache"
  now=$(date +%s)
  if [ -f "$cache_file" ]; then
    cache_age=$((now - $(stat -c %Y "$cache_file" 2>/dev/null || echo 0)))
  else
    cache_age=999
  fi

  if [ "$cache_age" -ge 5 ]; then
    branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    if [ -n "$branch" ]; then
      git_status=$(git -C "$cwd" status --porcelain 2>/dev/null || echo "")
      staged=$(echo "$git_status" | grep -cE '^[MADRC]' 2>/dev/null || true)
      modified=$(echo "$git_status" | grep -cE '^[ MADRC][MADRC]' 2>/dev/null || true)
      untracked=$(echo "$git_status" | grep -cE '^\?\?' 2>/dev/null || true)
      staged=${staged:-0}
      modified=${modified:-0}
      untracked=${untracked:-0}
      git_info="${branch}"
      [ "$staged" -gt 0 ] && git_info="${git_info} Staged:${staged}"
      [ "$modified" -gt 0 ] && git_info="${git_info} Modified:${modified}"
      [ "$untracked" -gt 0 ] && git_info="${git_info} Untracked:${untracked}"
    fi
    echo "$git_info" > "$cache_file"
  else
    git_info=$(cat "$cache_file" 2>/dev/null || echo "")
  fi
fi

line4=""
# Git branch
if [ -n "$git_info" ]; then
  branch_name=$(echo "$git_info" | cut -d' ' -f1)
  line4="${C_KEY}Branch:${R} ${C_GIT}${branch_name}${R}"
  # Staged
  staged_part=$(echo "$git_info" | grep -oE 'Staged:[0-9]+' | sed 's/Staged://' || true)
  if [ -n "${staged_part:-}" ]; then
    line4="${line4}${sep}${C_KEY}Staged:${R} ${C_GIT}${staged_part}${R}"
  fi
  # Modified
  modified_part=$(echo "$git_info" | grep -oE 'Modified:[0-9]+' | sed 's/Modified://' || true)
  if [ -n "${modified_part:-}" ]; then
    line4="${line4}${sep}${C_KEY}Modified:${R} ${C_GIT}${modified_part}${R}"
  fi
  # Untracked
  untracked_part=$(echo "$git_info" | grep -oE 'Untracked:[0-9]+' | sed 's/Untracked://' || true)
  if [ -n "${untracked_part:-}" ]; then
    line4="${line4}${sep}${C_KEY}Untracked:${R} ${C_GIT}${untracked_part}${R}"
  fi
fi
if [ -n "$line4" ] && [ -n "$cwd" ]; then
  line4="${line4}${sep}"
fi
if [ -n "$cwd" ]; then
  line4="${line4}${C_KEY}Dir:${R} ${C_DIR}${cwd}${R}"
fi
if [ -n "$line4" ]; then
  echo -e "$line4"
fi

# ── Line 5: Cron (scheduled tasks) ──
cron_file="$cwd/.claude/scheduled_tasks.json"
if [ -n "$cwd" ] && [ -f "$cron_file" ]; then
  cron_count=$(jq '.tasks | length' "$cron_file" 2>/dev/null || echo "0")
  if [ "$cron_count" -gt 0 ] 2>/dev/null; then
    cron_parts=""
    for i in $(seq 0 $((cron_count - 1))); do
      c_cron=$(jq -r ".tasks[$i].cron // \"?\"" "$cron_file" 2>/dev/null || echo "?")
      c_prompt=$(jq -r ".tasks[$i].prompt // \"\"" "$cron_file" 2>/dev/null | tr '\n\r' '  ' | awk '{if(length>30) print substr($0,1,27)"..."; else print}' 2>/dev/null || echo "")
      c_recur=$(jq -r ".tasks[$i].recurring // false" "$cron_file" 2>/dev/null || echo "false")
      if [ "$c_recur" = "true" ]; then
        c_tag="↻"
      else
        c_tag="①"
      fi
      part="${C_MCP}${c_tag} ${c_cron}${R}"
      if [ -n "$c_prompt" ]; then
        part="${part} ${C_TIME}\"${c_prompt}\"${R}"
      fi
      if [ -n "$cron_parts" ]; then
        cron_parts="${cron_parts}${C_KEY} · ${R}${part}"
      else
        cron_parts="$part"
      fi
    done
    echo -e "${C_KEY}Cron:${R} ${C_CTX}${cron_count}${R} ${cron_parts}"
  fi
fi
