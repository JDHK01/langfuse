# Claude Code → Langfuse

把 Claude Code 每轮执行(user 输入 / generation+model+token / tool 调用 / tool 返回)
发到自托管 Langfuse,在 UI 里看到完整 trace 树。

## 为什么不用 OTLP

Claude Code 的原生 OTLP telemetry 只发 logs + metrics(POST `/v1/logs`、`/v1/metrics`),
**从不发 `/v1/traces`**;而 Langfuse 的 OTLP ingestion 只把 traces 转成 trace 记录。
所以 `OTEL_EXPORTER_OTLP_*` 那套环境变量配下去,traces 页永远空
(Langfuse 维护者也在 [#9242](https://github.com/orgs/langfuse/discussions/9242) 确认)。

本目录用 Langfuse 官方的 **Stop-hook** 方案:每次 Claude Code 响应完,
hook 增量读 transcript jsonl,用 langfuse Python SDK 发结构化 trace。

## 前置

1. Langfuse 已在跑。本地 demo:本 repo 根目录 `./lf.sh up` → http://127.0.0.1:3000
2. 在 Langfuse 建好 project,拿到 public / secret key
3. 本机有 `uv`(没有就 `bash <(curl -LsSf https://astral.sh/uv/install.sh | sh)`)
4. system python 太老(如 macOS 自带 3.9)也没关系,脚本用 uv 自动装 3.12

## 用法

```bash
# 连本地 demo Langfuse(pk-lf-demo-...)
./install.sh

# 连别的 Langfuse:
LANGFUSE_BASE_URL=https://your-langfuse.example.com \
LANGFUSE_PUBLIC_KEY=pk-lf-... \
LANGFUSE_SECRET_KEY=sk-lf-... \
./install.sh
```

脚本**幂等**,可重复跑。它只往 `~/.claude/settings.json` 的 `hooks.Stop`
**追加**一组、`env` 写 4 个变量,不动你已有的配置(OpenIsland、模型代理等)。

## 验证

```bash
claude -p "列出当前目录文件"
```

去 Langfuse → 你的 project → Traces,看到:

```
Claude Code - Turn 1
├─ [GENERATION] ... model=glm-5.2  usage={input, output, ...}
├─ [TOOL] Tool: Bash
└─ ...
```

hook 日志:`~/.claude/state/langfuse_hook.log`
(在 settings.json 的 env 加 `"CC_LANGFUSE_DEBUG": "true"` 开 debug)。

## 文件

| 文件 | 说明 |
|---|---|
| `install.sh` | 配置脚本(uv venv + langfuse 4.x + hook + merge settings) |
| `langfuse_hook.py` | Langfuse 官方 hook(读 transcript,发 Langfuse) |

## 卸载

从 `~/.claude/settings.json` 的 `hooks.Stop` 删掉 command 含 `langfuse_hook.py` 的那组,
清掉 `env` 里 `LANGFUSE_*` / `TRACE_TO_LANGFUSE`,
删 `~/.claude/hooks/{langfuse_hook.py,.venv}`。

## 备注

- hook 依赖 langfuse SDK 4.x 内部 API(backdate observation),所以钉 `langfuse>=4.0,<5`。
- Claude 后端是 GLM(`open.bigmodel.cn`)时,Langfuse 里 model 显示 glm-5.2,与接入无关。
