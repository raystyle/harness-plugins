---
name: views-dev
description: >-
  views mod 开发与安装规范(herdr-app 数据面板,任意项目自持):命名防撞、
  数据道/视图道标准形、调试闭环、安装卸载、三条铁律。
  Use when 任何项目要开发/安装/卸载自己的 views mod(数据面板、拓扑视图、
  资源矩阵),或 views mod 渲染出错、数据断链排查时。
  触发词:views、views mod、数据面板、面板开发、mod 开发、mod 安装。
  不要用于 herdr-app 布局结构调试(走 herdr-app --skill)或 mods 目录写状态。
---

# views-dev:views mod 开发与安装(任意项目)

views mod = herdr-app 布局里挂载的数据面板(QuickJS + gpui-kit)。mod 安装位全局唯一(`~/.config/herdr-app/mods/`),跨项目共享——**本项目自持开发,装进全局位用**。

## 三条铁律(真实事故换的)

1. **mod 只渲染,不碰数据源**:数据采集/聚合在数据域 CLI(node dist 或 uv tool exe),mod 侧 `exec(绝对路径, [..., "--json"])`;exec 默认 30s 超时,长查询显式 `{timeout}`;herdr-app 进程 PATH 不含用户目录,程序与脚本路径一律绝对路径正斜杠
2. **运行时状态绝不写 mod 源码目录**(本地开发目录或安装位都算):写 mods/ = 热重载死循环。观测 `setShared("<mod>.state", {ts, ...})`;排序/折叠/拖位 `setShared("<mod>.order")`;大产物 `~/.config/herdr-app/data/<mod>/`
3. **layout 是 space 级持久,switch 作用于当前焦点 space**:调试一律在自己 space;交付后永不主动 layout.switch(两次全屏事故的根因)

## 命名(防撞,全局位共享的代价)

- mod 名 = `<项目域>-<对象>-views`(如 `ccoe-asset-views`、`ccoe-vmtpl-views`);裸名(`files`、`chat`)是官方/公共 mod 的地盘
- shared 键全部带 `<mod>.` 前缀
- 本项目源码放仓内 `views/<mod名>/`(main.js + 可选 mod.json);`mod.json` 最小形:`{"version": "0.1.0", "title": "<面板名>", "place": "none"}`

## 项目内结构(建议)

```text
views/
  <mod名>/main.js        # 唯一入口
  <mod名>/mod.json       # 可选
  sync.sh                # 装到 ~/.config/herdr-app/mods/<mod名>/
```

sync.sh 全文(照抄即用):

```bash
#!/usr/bin/env bash
# 用法:bash views/sync.sh [mod名...];不带参 = 全部
set -euo pipefail
cd "$(dirname "$0")/.."
dest="${HERDR_APP_HOME:-$HOME/.config/herdr-app}/mods"
mkdir -p "$dest"
for d in views/*/; do
  name=$(basename "$d")
  if [ "$#" -gt 0 ] && ! printf '%s\n' "$@" | grep -qx "$name"; then continue; fi
  [ -f "$d/main.js" ] || continue
  mkdir -p "$dest/$name"
  cp -r "$d." "$dest/$name/"
  echo "已装 $name -> $dest/$name"
done
```

## 数据道标准形

```js
import { exec, theme, setShared, shared } from "herdr";

const EXE = "/home/<user>/.local/bin/<数据域cli>";  // 绝对路径;Windows 形 "D:/…",正斜杠
const POLL_MS = 60_000;

refresh(cx) {
  if (this.busy && Date.now() - this.lastStart < 2.5 * POLL_MS) return;  // 看门狗:exec 悬死不锁轮询
  this.busy = true; this.lastStart = Date.now();
  exec(EXE, ["<域>", "--json"], { timeout: 120000 })
    .then(r => { this.data = JSON.parse(r.stdout); setShared("<mod>.state", { ts: Date.now(), err: null, ...摘要 }); })
    .catch(e => { this.err = String(e.message || e); setShared("<mod>.state", { ts: Date.now(), err: this.err }); })
    .finally(() => { this.busy = false; cx.notify(); });
}
```

- 轮询 `cx.timer.every(POLL_MS, …)`;state 必带 `ts`(心跳,排障第一道)
- CLI 断/超时:错误进 state + 面板显示错误行,**不空白**
- 数据 CLI 属数据域所在仓;mod 里写死的绝对路径在 CLI 改名/搬家时同步 grep

## 视图道要点

- 单树返回;busy 门 + `cx.spawn` + finally `cx.notify()`;布局三段式(顶栏 flex_none / 左栏 / 主区 flex_1 + min_w(0) + overflow_y_scrollbar)
- theme 色闭环:只认 theme 色/`#rgb`/`#rrggbb`/`#rrggbbaa`;画布用 canvas 色、卡面用 popover(同明度会一片灰)
- 连线 = 细 div 模拟 L 形(无 line/canvas 元素);曲线 `window.paint_path` 用 **gpui-kit 全局 window**——不要 `import { window } from "herdr"`(那是标题栏状态函数,同名不同物,import 即遮蔽全局)
- 拖拽:状态机 `this.drag={key,src,x,y,dx,dy}` + 鬼影卡 `.absolute().left().top()`,落格 `order[key]={name:[c,r]}` setShared 持久化;拖动中不画线,落格重绘
- QuickJS 全支持 `?.`/`??`/尾逗号;真门禁是 `herdr-app check`

## 调试闭环(在项目仓)

```sh
node --check views/<mod>/main.js
bash views/sync.sh <mod>
herdr-app check ~/.config/herdr-app/mods/<mod>          # 目录路径,不是 mod 名
herdr-app status                                         # errors 必空
herdr-app shot /tmp/<mod>.png                            # 然后看图
```

挂载查看:锚定 `pane.split --direction right --pane <目标 pane> --mod <mod名>`(全流程见 herdr-app 操作纪律;**不带 --pane 会开进用户正看的空间**),看完 `pane.close --pane <新id>`。check 只验无数据首帧——活数据行为要真挂载看屏;数据道心跳看 `~/.config/herdr-app/shared.json` 的 `<mod>.state.ts` 在走。

## 安装与卸载(全局位)

- 安装 = `bash views/sync.sh`(cp 到全局位,热重载即时生效;项目仓是源,全局位是产物)
- 同名冲突:全局位唯一——改自己名(加项目前缀),不覆盖别人的
- 卸载 = `rm -rf ~/.config/herdr-app/mods/<mod名>` + 若在屏:锚定 `pane.close`(禁关空间最后一个 pane)
- mod 想给命令:`<mod>.<命令>` 注册后在 herdr-app 命令面板可寻

## 配套脚本(本 skill 目录,uv/python3 ≥3.10 零依赖)

```sh
# 环境检测:herdr-app/node/安装位/已装 views 清点/心跳(指定 mod 出专项体检)
uv run views_check.py [mod名]

# 安装部署:项目仓 views/ -> 全局位(装/更新/卸载/对照)
uv run views_sync.py install [mod名...]   # 不带名 = 全部;带预检(命名后缀/mod.json/写死安装位路径红线)
uv run views_sync.py uninstall <mod名>
uv run views_sync.py list                 # 项目内 vs 全局位对照
```

脚本从 cwd 向上找含 `views/` 的项目根(最多五层),项目仓是源、全局位是产物——**更新 = 覆盖重装,不在全局位改码**。检测的 FAIL 项(herdr-app 缺 / mod 未装 / shared 无键)先修再开发。

## 排障三道(次序固定)

1. `herdr-app status` errors——加载/语法错误第一现场
2. `shared.json` 的 `<mod>.state.ts`——数据道心跳(ts 停 = CLI 断/轮询死;看 err 字段)
3. `herdr-app check <mod目录> --print-spec`——渲染树(首帧)
