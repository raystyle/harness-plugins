# harness-plugins — herdr 生态 harness 插件市场

> 一句话定位:Claude Code 插件市场仓,接替 project-evo 的生态位。三插件:share(搬运四域)、context(对话历史)、herdr(官方 SKILL 收录)。原语命令 = [raystyle/agent-primitives](https://github.com/raystyle/agent-primitives)(uv 包 `agent-primitives`,五入口 files/streams/ctxs/ports/pipes)。

## 安装

```text
/plugin marketplace add raystyle/harness-plugins
/plugin install share@harness-plugins
/plugin install context@harness-plugins
/plugin install herdr@harness-plugins
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
| herdr | `herdr-core` | hc 官方 SKILL:常驻终端跑程序与 agent、子代理委派、消息等待读屏 | 委派任务、编排 agent、跨机操作时 |
| herdr | `herdr-app` | herdr-app 官方 SKILL:spaces/tabs/panes 显示与排布、mod/layout 开发 | 开空间分屏、驱动用户窗口、开发 mod 时 |

## 环境前提

- share/context 的命令须在 PATH(安装:`uv tool install git+https://github.com/raystyle/agent-primitives.git`,五命令 files/streams/ctxs/ports/pipes)
- 引擎依赖按域:files/streams 骑 s5,pipes/ports 骑 tailcat,ctxs 骑 ClickHouse(凭据 `CTX_URL/CTX_USER/CTX_PASSWORD`);缺位时 structured error 指路
- herdr 插件两份 SKILL 为官方原文逐字收录;运行时手册以 `hc --skill` / `herdr-app --skill` 为准(skill 只是路由面)
- 客户端:Claude Code(插件市场面)

## 结构

```text
.claude-plugin/marketplace.json   市场清单(三插件)
plugins/share/skills/             files / streams / pipes / ports
plugins/context/skills/           ctxs
plugins/herdr/skills/             herdr-core / herdr-app(官方原文)
```

skill 均为薄壳:动词面 + 判读 + 示例,真源在 agent-primitives 仓(`--llms` 手册单源)。改动词面 = 先改 agent-primitives 再同步此仓 skill。
