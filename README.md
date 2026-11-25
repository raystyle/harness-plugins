# harness-plugins — herdr 生态 harness 插件市场

> 一句话定位:Claude Code 插件市场仓,接替 project-evo 的生态位。四插件:share(搬运四域)、context(对话历史 + 只读 GitHub 搜索 MCP)、herdr(官方 SKILL 收录 + views-dev)、config(开发环境面合一:dev-fix + statusline + typescript-lsp + ty)。原语命令 = [raystyle/agent-primitives](https://github.com/raystyle/agent-primitives)(uv 包 `agent-primitives`,五入口 files/streams/ctxs/ports/pipes)。

## 安装

```text
/plugin marketplace add raystyle/harness-plugins
/plugin install share@harness-plugins
/plugin install context@harness-plugins
/plugin install herdr@harness-plugins
/plugin install config@harness-plugins
```

升级 = 刷新市场快照再逐插件 update(重启会话生效):

```text
/plugin marketplace update harness-plugins
/plugin update <插件>@harness-plugins
```

开发态(指向工作树,改动即生效,免推送):把 `marketplace add` 的源换成仓根路径,如 `/plugin marketplace add D:/repos/herdr-ccoe/harness_plugins`。

## 插件与 SKILL

| 插件 | skill | 做什么 | 何时用 |
|------|-------|--------|--------|
| share | `files` | 文件域:put 上架回内容哈希键 / get 取回 / send 留痕加知会 | 传文件、交付产物、取回共享时 |
| share | `streams` | 流域:room/dm/append/send,流即房间,fleet 回执主频道 | 交回执、广播、私信、回放续读时 |
| share | `pipes` | 实时字节域:start 起收听管道 / send 字节直通 | 实时转发日志流、连管道时 |
| share | `ports` | 端口映射域:serve 面板端口与服务映射 / fwd 本地转发 | 开端口转发、映射远端端口时 |
| context | `ctxs` | 对话历史域:请求头行 / 单请求全链 / 跨请求全文检索 | 查历史对话、回溯细节、跨请求搜索时 |
| context | —(MCP server `gh-mcp`) | 只读 GitHub 检索,自建 [gh-mcp](https://github.com/raystyle/gh-mcp):`search_repositories`(搜公开仓库)/ `search_code`(搜公开代码)/ `get_file_contents`(读公开仓库的文件、列目录、看整棵树) | 搜公开仓库与代码、读搜到的文件时 |
| herdr | `herdr-core` | hc 官方 SKILL:常驻终端跑程序与 agent、子代理委派、消息等待读屏 | 委派任务、编排 agent、跨机操作时 |
| herdr | `herdr-app` | herdr-app 官方 SKILL:spaces/tabs/panes 显示与排布、mod/layout 开发 | 开空间分屏、驱动用户窗口、开发 mod 时 |
| herdr | `views-dev` | views mod(可关闭的工作台 pane)开发与安装规范,任意项目自持:四条铁律、命名防撞、数据道/视图道标准形、调试闭环、安装卸载;配套 `views_check.py`(环境检测 + 心跳诊断)与 `views_sync.py`(装/卸/对照) | 任何项目要开发、安装或排查自己的 views mod 时 |
| config | —(hook+LSP) | 开发环境面合一:dev-fix hook(Windows Git Bash 编码/MSYS 路径/venv 条件激活/自动 git add)+ statusline 状态栏(手动 setup 注入)+ typescript-lsp + ty 两 LSP | Windows 开发环境、状态栏、TS/JS 与 Python 代码智能 |

## 环境前提

- share/context 的命令须在 PATH(安装:`uv tool install git+https://github.com/raystyle/agent-primitives.git`,五命令 files/streams/ctxs/ports/pipes)
- 引擎依赖按域:files/streams 骑 s5,pipes/ports 骑 tailcat,ctxs 骑 ClickHouse(凭据 `CTX_URL/CTX_USER/CTX_PASSWORD`);缺位时 structured error 指路
- context 插件自带的 MCP server `gh-mcp` 需要 PATH 上有 `gh-mcp`(`uv tool install git+https://github.com/raystyle/gh-mcp`),没装这台机器上该 server 会启动失败。GitHub token 读环境变量 `GITHUB_PAT`(可放在 `~/.claude/settings.json` 的 `env` 里):没有 token 时仓库搜索匿名可用,代码搜索会提示需要 token。PAT 不进本仓
- herdr 插件的 herdr-core / herdr-app 两份 SKILL 为官方原文逐字收录;运行时手册以 `hc --skill` / `herdr-app --skill` 为准(skill 只是路由面)。`views-dev` 为本仓自写,脚本需 Python ≥3.10(`uv run` 或 `python3`)
- 客户端:Claude Code(插件市场面)

## 结构

```text
.claude-plugin/marketplace.json   市场清单(七插件)
plugins/share/skills/             files / streams / pipes / ports
plugins/context/skills/           ctxs
plugins/context/.mcp.json         MCP server gh-mcp(命令同名,token 走 ${GITHUB_PAT})
plugins/herdr/skills/             herdr-core / herdr-app(官方原文)+ views-dev(自写,含检测/部署脚本)
plugins/config/scripts/           bash-fix / git-add / error-fix-hint(hook)
                                  + setup(手动)/ services / statusline(状态栏)
plugins/config(LSP manifest)      typescript-language-server + ty server
```

statusline 不走 hook(2026-11-20 裁定):装好后手动跑一次
`bash ~/.claude/plugins/cache/harness-plugins/config/<最新版本>/scripts/setup.sh`(或在仓根 `CLAUDE_PLUGIN_ROOT` 指插件目录跑)。
setup 部署**稳定入口** `~/.config/harness-plugins/statusline-entry.sh` 并把
`statusLine.command` 指向它——入口不含版本号,**升版免改 settings**(t43 会诊判例:
0.1.3→0.1.4 时 settings 钉旧版本路径,每台机器都得手改)。入口每次渲染自选
最新版本目录转发;状态栏渲染自足补算 MCP/LSP 缓存(零 env 依赖,0.1.5 起)。

config 插件为本仓自主实现(2026-11-20;hook 设计蓝本 = 同作者前作 raystyle/claude-plugins,功能面等价,本仓维护上游不回写);两 LSP 配置面等同 anthropics/claude-plugins-official(typescript-lsp)与 andres-ortizl/ty-lsp-claude-code-plugin(Astral ty)的挂载。原独立四插件(dev-fix/statusline/typescript-lsp/ty)已归并入 config。

skill 均为薄壳:动词面 + 判读 + 示例,真源在 agent-primitives 仓(`--llms` 手册单源)。改动词面 = 先改 agent-primitives 再同步此仓 skill。
