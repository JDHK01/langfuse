#!/usr/bin/env bash
# Langfuse 自托管栈 快速 启动 / 停止 / 清空
# 用法: ./lf.sh {up|down|wipe}
set -euo pipefail
cd "$(dirname "$0")"

case "${1:-}" in
  up|start)
    docker compose up -d
    echo "✓ 已启动 → http://localhost:3000"
    echo "  账号: $(grep -E '^LANGFUSE_INIT_USER_EMAIL=' .env | tail -1 | cut -d= -f2-)"
    echo "  密码: $(grep -E '^LANGFUSE_INIT_USER_PASSWORD=' .env | tail -1 | cut -d= -f2-)"
    ;;
  down|stop)
    docker compose down
    echo "✓ 已停止（数据卷保留）"
    ;;
  wipe)
    docker compose down -v
    echo "✓ 已停止并删除全部数据卷（彻底清空，下次 up 会重新初始化）"
    ;;
  *)
    echo "用法: ./lf.sh {up|down|wipe}"
    echo "  up    启动（保留数据）"
    echo "  down  停止（保留数据）"
    echo "  wipe  停止 + 删除全部卷（彻底清空）"
    exit 1
    ;;
esac
