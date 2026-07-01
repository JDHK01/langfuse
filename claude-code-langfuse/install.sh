#!/usr/bin/env bash
# 配置 Claude Code 接入自托管 Langfuse(官方 Stop-hook 方式)
#
# 做的事:用 uv 建 venv → 装 langfuse 4.x → 放官方 hook 脚本 →
#         幂等 merge ~/.claude/settings.json(hooks.Stop 追加一组 + env 加 4 个变量)
#
# 为什么不用 OTLP:Claude Code 的原生 OTLP 只发 logs/metrics、不发 traces,
# 而 Langfuse 只吃 traces,所以 OTEL_EXPORTER_OTLP_* 配下去 traces 永远空。
#
# 用法:
#   ./install.sh                      # 连本地 demo Langfuse
#   LANGFUSE_BASE_URL=... LANGFUSE_PUBLIC_KEY=... LANGFUSE_SECRET_KEY=... ./install.sh
#
# 幂等,可重复运行;不会覆盖你已有的 hooks/env(如 OpenIsland、模型代理)。
set -euo pipefail

# ---------- 可配置项(环境变量覆盖)----------
LANGFUSE_BASE_URL="${LANGFUSE_BASE_URL:-http://127.0.0.1:3000}"
LANGFUSE_PUBLIC_KEY="${LANGFUSE_PUBLIC_KEY:-pk-lf-demo-public-key-2026}"
LANGFUSE_SECRET_KEY="${LANGFUSE_SECRET_KEY:-sk-lf-demo-secret-key-2026}"
PYTHON_VER="${PYTHON_VER:-3.12}"

# ---------- 路径 ----------
CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
HOOKS_DIR="$CLAUDE_DIR/hooks"
VENV_DIR="$HOOKS_DIR/.venv"
HOOK_SCRIPT="$HOOKS_DIR/langfuse_hook.py"
SETTINGS="$CLAUDE_DIR/settings.json"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_HOOK="$HERE/langfuse_hook.py"

# ---------- 1. 前置检查 ----------
echo "[1/4] 前置检查"
command -v uv >/dev/null 2>&1 || {
  echo "✗ 未找到 uv。安装:bash <(curl -LsSf https://astral.sh/uv/install.sh)" >&2
  exit 1
}
[ -f "$SRC_HOOK" ] || { echo "✗ 未找到 $SRC_HOOK(应与本脚本同目录)" >&2; exit 1; }
echo "    uv:    $(command -v uv)"
echo "    hook:  $SRC_HOOK"

# ---------- 2. venv + langfuse SDK ----------
echo "[2/4] 建 venv(Python $PYTHON_VER)+ 装 langfuse 4.x"
uv venv "$VENV_DIR" --python "$PYTHON_VER" >/dev/null
uv pip install --python "$VENV_DIR/bin/python" 'langfuse>=4.0,<5' >/dev/null
echo "    langfuse $("$VENV_DIR/bin/python" -c 'import langfuse; print(langfuse.__version__)')"

# ---------- 3. 放 hook ----------
echo "[3/4] 安装 hook → $HOOK_SCRIPT"
mkdir -p "$HOOKS_DIR"
cp "$SRC_HOOK" "$HOOK_SCRIPT"
chmod +x "$HOOK_SCRIPT"

# ---------- 4. merge settings.json(幂等)----------
echo "[4/4] 合并 $SETTINGS"
LANGFUSE_CMD="$VENV_DIR/bin/python $HOOK_SCRIPT"
python3 - "$SETTINGS" "$LANGFUSE_CMD" "$LANGFUSE_BASE_URL" "$LANGFUSE_PUBLIC_KEY" "$LANGFUSE_SECRET_KEY" <<'PYEOF'
import json, os, sys
path, cmd, base_url, pub, sec = sys.argv[1:6]
cfg = json.load(open(path)) if os.path.exists(path) else {}

# hooks.Stop 追加一组(先剔旧的,幂等)
cfg.setdefault("hooks", {}).setdefault("Stop", [])
cfg["hooks"]["Stop"] = [g for g in cfg["hooks"]["Stop"]
                        if not any(h.get("command") == cmd for h in g.get("hooks", []))]
cfg["hooks"]["Stop"].append({"hooks": [{"type": "command", "command": cmd}]})

# env 写 4 个变量(覆盖式,幂等)
cfg.setdefault("env", {})
cfg["env"].update({
    "TRACE_TO_LANGFUSE": "true",
    "LANGFUSE_BASE_URL": base_url,
    "LANGFUSE_PUBLIC_KEY": pub,
    "LANGFUSE_SECRET_KEY": sec,
})

json.dump(cfg, open(path, "w"), indent=2, ensure_ascii=False)
print("    OK Stop hook 追加(幂等),env 已写")
PYEOF

echo
echo "✓ 完成。跑一次 claude,然后看:"
echo "    $LANGFUSE_BASE_URL/project/<project-id>/traces"
echo "  hook 日志:tail -f $CLAUDE_DIR/state/langfuse_hook.log"
